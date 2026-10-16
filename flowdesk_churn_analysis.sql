/* =====================================================================
   FlowDesk Technologies - Customer Retention & Churn Analysis
   Database : PostgreSQL
   Tables   : customers, subscriptions, invoices, onboarding,
              product_usage, support_tickets, marketing_campaigns

   Structure
     00  Helper functions and cleaned views
     01  Data validation
     02  Company-wide performance
     03  Marketing channel and acquisition quality
     04  Onboarding speed and product engagement
     05  Support tickets and product bugs
     06  Regional health

   Notes
     - Fiscal year runs April to March (FY23-24 = Apr 2023 to Mar 2024).
     - Date columns are assumed to be DATE type. Mixed formats
       (YYYY-MM-DD and DD/MM/YYYY) were standardised while loading.
     - Run Section 00 first. Every later section uses its views.
   ===================================================================== */


/* =====================================================================
   SECTION 00: HELPER FUNCTIONS AND CLEANED VIEWS
   ===================================================================== */

-- 00.1 Fiscal year label, e.g. 2023-11-23 -> 'FY23-24'
CREATE OR REPLACE FUNCTION fiscal_year(d DATE) RETURNS TEXT AS $$
    SELECT 'FY' || RIGHT(y::TEXT, 2) || '-' || RIGHT((y + 1)::TEXT, 2)
    FROM (
        SELECT CASE WHEN EXTRACT(MONTH FROM d) >= 4
                    THEN EXTRACT(YEAR FROM d)::INT
                    ELSE EXTRACT(YEAR FROM d)::INT - 1
               END AS y
    ) t
$$ LANGUAGE SQL IMMUTABLE;

-- 00.2 Standardise the 20 raw channel spellings into 6 clean channels
CREATE OR REPLACE FUNCTION clean_channel(raw TEXT) RETURNS TEXT AS $$
    SELECT CASE
        WHEN LOWER(REPLACE(TRIM(raw), '_', ' ')) = 'direct content' THEN 'Direct Content'
        WHEN LOWER(TRIM(raw)) = 'direct'                            THEN 'Direct'
        WHEN LOWER(raw) LIKE '%google%'                             THEN 'Google Ads'
        WHEN LOWER(raw) LIKE '%organic%'                            THEN 'Organic Search'
        WHEN LOWER(raw) LIKE '%affiliate%'                          THEN 'Affiliate Referral Network'
        WHEN LOWER(raw) LIKE '%partner%'                            THEN 'Partner Network'
        ELSE raw
    END
$$ LANGUAGE SQL IMMUTABLE;

-- 00.3 Customers with clean channel, campaign_id and fiscal year
CREATE OR REPLACE VIEW clean_customers AS
SELECT c.*,
       clean_channel(c.acquisition_channel)                 AS clean_channel,
       COALESCE(NULLIF(TRIM(c.campaign_id), ''), 'UNKNOWN') AS clean_campaign_id,
       fiscal_year(c.signup_date)                           AS signup_fy
FROM customers c;

-- 00.4 Invoices with exact duplicate rows removed (used for ALL revenue maths)
CREATE OR REPLACE VIEW clean_invoices AS
SELECT DISTINCT * FROM invoices;

-- 00.5 Product usage with one row per customer-month
--      (conflicting duplicate rows are averaged)
CREATE OR REPLACE VIEW clean_product_usage AS
SELECT customer_id,
       activity_month,
       AVG(login_days)       AS login_days,
       AVG(projects_created) AS projects_created,
       AVG(active_users)     AS active_users
FROM product_usage
GROUP BY customer_id, activity_month;


/* =====================================================================
   SECTION 01: DATA VALIDATION
   Purpose: find data-quality issues before any calculation.
   ===================================================================== */

-- 01.1 Exact duplicate invoice rows (expected: 120 extra rows)
SELECT invoice_id, customer_id, subscription_id, invoice_date,
       COUNT(*) AS occurrences
FROM invoices
GROUP BY invoice_id, customer_id, subscription_id, invoice_date,
         invoice_amount, discount_amount, amount_paid, payment_status
HAVING COUNT(*) > 1;

-- 01.2 Raw acquisition_channel spellings (before cleaning)
SELECT acquisition_channel, COUNT(*) AS customer_count
FROM customers
GROUP BY acquisition_channel
ORDER BY customer_count DESC;

-- 01.3 Mapping preview: raw spelling -> clean channel
SELECT DISTINCT acquisition_channel AS raw_channel,
       clean_channel(acquisition_channel) AS clean_channel
FROM customers
ORDER BY clean_channel, raw_channel;

-- 01.4 Missing campaign_id: count and % of customer base
SELECT SUM(CASE WHEN campaign_id IS NULL THEN 1 ELSE 0 END) AS missing_campaign_id,
       COUNT(*)                                             AS total_customers,
       ROUND(100.0 * SUM(CASE WHEN campaign_id IS NULL THEN 1 ELSE 0 END)
             / COUNT(*), 1)                                 AS pct_missing
FROM customers;

-- 01.5 Duplicate customer_id check (expected: zero rows)
SELECT customer_id, COUNT(*) AS occurrences
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- 01.6 Duplicate customer-month rows in product_usage
--      (same customer and month with conflicting values)
SELECT customer_id, activity_month, COUNT(*) AS row_count
FROM product_usage
GROUP BY customer_id, activity_month
HAVING COUNT(*) > 1;
-- Result: 4,956 rows involved (2,478 duplicate customer-month pairs).
-- Fix: averaged per (customer_id, activity_month) in view clean_product_usage.
-- Impact on usage metrics was below 0.2 percent, so no finding changed.

-- 01.7 One subscription per customer? (expected: zero rows)
--      Confirms joins to subscriptions do not repeat customers.
SELECT customer_id, COUNT(*) AS subscriptions
FROM subscriptions
GROUP BY customer_id
HAVING COUNT(*) > 1;


/* =====================================================================
   SECTION 02: COMPANY-WIDE PERFORMANCE
   Purpose: baseline signups, revenue and logo churn, year over year.
   ===================================================================== */

-- 02.1 New signups by fiscal year, with YoY growth
SELECT signup_fy AS fiscal_year,
       COUNT(*)  AS new_signups,
       ROUND(100.0 * (COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY signup_fy))
             / LAG(COUNT(*)) OVER (ORDER BY signup_fy), 1) AS yoy_growth_pct
FROM clean_customers
GROUP BY signup_fy
ORDER BY signup_fy;

-- 02.2 Billing revenue (Paid invoices, duplicates removed) by fiscal year
SELECT fiscal_year(invoice_date) AS fiscal_year,
       SUM(amount_paid)          AS billing_revenue,
       ROUND(100.0 * (SUM(amount_paid) - LAG(SUM(amount_paid)) OVER (ORDER BY fiscal_year(invoice_date)))
             / LAG(SUM(amount_paid)) OVER (ORDER BY fiscal_year(invoice_date)), 1) AS yoy_growth_pct
FROM clean_invoices
WHERE payment_status = 'Paid'
GROUP BY fiscal_year(invoice_date)
ORDER BY fiscal_year;

-- 02.3 Overall logo churn
SELECT COUNT(*) AS total_signups,
       SUM(CASE WHEN account_status = 'Cancelled' THEN 1 ELSE 0 END) AS total_cancelled,
       ROUND(100.0 * SUM(CASE WHEN account_status = 'Cancelled' THEN 1 ELSE 0 END)
             / COUNT(*), 1) AS churn_rate_pct
FROM customers;

-- 02.4 Cohort view: signups, cancelled and retained by signup fiscal year
SELECT signup_fy AS fiscal_year,
       COUNT(*)  AS signups,
       SUM(CASE WHEN account_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_from_cohort,
       COUNT(*) - SUM(CASE WHEN account_status = 'Cancelled' THEN 1 ELSE 0 END) AS net_retained
FROM clean_customers
GROUP BY signup_fy
ORDER BY signup_fy;


/* =====================================================================
   SECTION 03: MARKETING CHANNEL AND ACQUISITION QUALITY
   Purpose: test the Marketing hypothesis that "acquisition is fine".
   ===================================================================== */

-- 03.1 Churn rate by clean acquisition channel
SELECT clean_channel,
       COUNT(*) AS signups,
       SUM(CASE WHEN account_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
       ROUND(100.0 * SUM(CASE WHEN account_status = 'Cancelled' THEN 1 ELSE 0 END)
             / COUNT(*), 1) AS churn_rate_pct
FROM clean_customers
GROUP BY clean_channel
ORDER BY churn_rate_pct DESC;

-- 03.2 Affiliate channel: Month-3 churn (cancelled within 90 days of signup)
SELECT COUNT(*) AS affiliate_customers,
       SUM(CASE WHEN c.account_status = 'Cancelled'
                 AND s.cancellation_date IS NOT NULL
                 AND s.cancellation_date - c.signup_date <= 90
                THEN 1 ELSE 0 END) AS month3_cancels,
       ROUND(100.0 * SUM(CASE WHEN c.account_status = 'Cancelled'
                               AND s.cancellation_date IS NOT NULL
                               AND s.cancellation_date - c.signup_date <= 90
                              THEN 1 ELSE 0 END) / COUNT(*), 1) AS month3_churn_pct
FROM clean_customers c
JOIN subscriptions s ON s.customer_id = c.customer_id
WHERE c.clean_channel = 'Affiliate Referral Network';

-- 03.3 Affiliate vs Organic Search: signups and churn
SELECT clean_channel AS channel,
       COUNT(*) AS signups,
       ROUND(100.0 * SUM(CASE WHEN account_status = 'Cancelled' THEN 1 ELSE 0 END)
             / COUNT(*), 1) AS churn_rate_pct
FROM clean_customers
WHERE clean_channel IN ('Affiliate Referral Network', 'Organic Search')
GROUP BY clean_channel;

-- 03.4 Campaign performance: spend vs signups vs revenue
--      Revenue is summed per customer first, so signups are not double counted.
--      Customers with no campaign_id cannot be attributed and are excluded.
WITH customer_revenue AS (
    SELECT customer_id, SUM(amount_paid) AS revenue
    FROM clean_invoices
    WHERE payment_status = 'Paid'
    GROUP BY customer_id
)
SELECT mc.campaign_id,
       clean_channel(mc.acquisition_channel)                      AS channel,
       mc.campaign_spend,
       COUNT(c.customer_id)                                       AS attributed_signups,
       COALESCE(SUM(cr.revenue), 0)                               AS attributed_revenue,
       ROUND(mc.campaign_spend / NULLIF(COUNT(c.customer_id), 0), 0)           AS spend_per_signup,
       ROUND(COALESCE(SUM(cr.revenue), 0) / NULLIF(mc.campaign_spend, 0), 2)   AS revenue_per_rupee_spent
FROM marketing_campaigns mc
LEFT JOIN customers c          ON c.campaign_id  = mc.campaign_id
LEFT JOIN customer_revenue cr  ON cr.customer_id = c.customer_id
GROUP BY mc.campaign_id, mc.acquisition_channel, mc.campaign_spend
ORDER BY attributed_revenue DESC;


/* =====================================================================
   SECTION 04: ONBOARDING SPEED AND PRODUCT ENGAGEMENT
   Purpose: test the Customer Success hypothesis on onboarding and
            customer quality.
   ===================================================================== */

-- 04.1 Churn: slow or incomplete onboarding (over 14 days) vs fast onboarding
WITH onb AS (
    SELECT c.customer_id,
           c.account_status,
           o.onboarding_completed,
           o.completion_date - o.onboarding_start AS onboarding_days
    FROM customers c
    LEFT JOIN onboarding o ON o.customer_id = c.customer_id
)
SELECT CASE WHEN onboarding_completed IS DISTINCT FROM TRUE
              OR onboarding_days IS NULL
              OR onboarding_days > 14
            THEN 'Slow/Incomplete' ELSE 'Fast (<=14 days)' END AS onboarding_status,
       COUNT(*) AS customers,
       SUM(CASE WHEN account_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
       ROUND(100.0 * SUM(CASE WHEN account_status = 'Cancelled' THEN 1 ELSE 0 END)
             / COUNT(*), 1) AS churn_rate_pct
FROM onb
GROUP BY 1;

-- 04.2 Average onboarding days: active vs cancelled customers
SELECT c.account_status,
       ROUND(AVG(o.completion_date - o.onboarding_start), 1) AS avg_onboarding_days
FROM customers c
JOIN onboarding o ON o.customer_id = c.customer_id
GROUP BY c.account_status;

-- 04.3 Training webinar attendance vs churn
SELECT o.training_attended,
       COUNT(*) AS customers,
       SUM(CASE WHEN c.account_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
       ROUND(100.0 * SUM(CASE WHEN c.account_status = 'Cancelled' THEN 1 ELSE 0 END)
             / COUNT(*), 1) AS churn_rate_pct
FROM customers c
JOIN onboarding o ON o.customer_id = c.customer_id
GROUP BY o.training_attended;

-- 04.4 Product usage: active vs cancelled customers (deduplicated usage)
SELECT c.account_status,
       ROUND(AVG(u.login_days), 1)       AS avg_login_days,
       ROUND(AVG(u.projects_created), 1) AS avg_projects_created
FROM customers c
JOIN clean_product_usage u ON u.customer_id = c.customer_id
GROUP BY c.account_status;

-- 04.5 Sample of customer-months with zero logins (active but disengaged)
SELECT customer_id, activity_month, login_days
FROM clean_product_usage
WHERE login_days = 0
LIMIT 20;


/* =====================================================================
   SECTION 05: SUPPORT TICKETS AND PRODUCT BUGS
   Purpose: test the Product hypothesis on bugs and integration lag.
   ===================================================================== */

-- 05.1 Ticket volume, resolution time and CSAT by subcategory
SELECT ticket_subcategory,
       COUNT(*)                             AS ticket_count,
       ROUND(AVG(resolution_time_hours), 1) AS avg_resolution_hours,
       ROUND(AVG(satisfaction_score), 1)    AS avg_csat
FROM support_tickets
GROUP BY ticket_subcategory
ORDER BY avg_resolution_hours DESC;

-- 05.2 Premium plans (Growth/Business): churn for customers with Integration tickets
WITH premium AS (
    SELECT c.customer_id, c.account_status
    FROM customers c
    JOIN subscriptions s ON s.customer_id = c.customer_id
    WHERE s.plan IN ('Growth', 'Business')
),
integration_customers AS (
    SELECT DISTINCT customer_id
    FROM support_tickets
    WHERE ticket_subcategory = 'Integration'
)
SELECT 'Premium + Integration ticket' AS segment,
       COUNT(*) AS customers,
       SUM(CASE WHEN p.account_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
       ROUND(100.0 * SUM(CASE WHEN p.account_status = 'Cancelled' THEN 1 ELSE 0 END)
             / COUNT(*), 1) AS churn_rate_pct
FROM premium p
JOIN integration_customers ic ON ic.customer_id = p.customer_id
UNION ALL
SELECT 'All Premium (Growth/Business)',
       COUNT(*),
       SUM(CASE WHEN account_status = 'Cancelled' THEN 1 ELSE 0 END),
       ROUND(100.0 * SUM(CASE WHEN account_status = 'Cancelled' THEN 1 ELSE 0 END)
             / COUNT(*), 1)
FROM premium;

-- 05.3 Average tickets per customer by category: active vs cancelled
--      Includes customers with zero tickets, so averages are not inflated.
--      Caution: cancelled customers have shorter lifetimes, so they have
--      less time to raise tickets. Read this as a signal, not proof.
WITH categories AS (
    SELECT DISTINCT ticket_category FROM support_tickets
),
ticket_counts AS (
    SELECT customer_id, ticket_category, COUNT(*) AS ticket_count
    FROM support_tickets
    GROUP BY customer_id, ticket_category
)
SELECT c.account_status,
       cat.ticket_category,
       ROUND(AVG(COALESCE(tc.ticket_count, 0)), 2) AS avg_tickets_per_customer
FROM customers c
CROSS JOIN categories cat
LEFT JOIN ticket_counts tc
       ON tc.customer_id = c.customer_id
      AND tc.ticket_category = cat.ticket_category
GROUP BY c.account_status, cat.ticket_category
ORDER BY cat.ticket_category, c.account_status;


/* =====================================================================
   SECTION 06: REGIONAL HEALTH
   Purpose: answer the North concentration and South decline questions.
   The dataset has no sales-rep commission or shipping/logistics/returns
   fields, so the regional view uses churn, discounting, account
   concentration and product usage instead.
   ===================================================================== */

-- 06.1 Region-level signups, churn and average discount
SELECT region,
       COUNT(*) AS signups,
       SUM(CASE WHEN account_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
       ROUND(100.0 * SUM(CASE WHEN account_status = 'Cancelled' THEN 1 ELSE 0 END)
             / COUNT(*), 1) AS churn_rate_pct,
       ROUND((100.0 * AVG(discount_percentage))::NUMERIC, 1) AS avg_discount_pct
FROM customers
GROUP BY region
ORDER BY churn_rate_pct DESC;

-- 06.2 North region: customers by city (concentration)
SELECT city, COUNT(*) AS customers
FROM customers
WHERE region = 'North'
GROUP BY city
ORDER BY customers DESC;

-- 06.3 South region: product usage vs company average
SELECT 'South' AS region,
       ROUND(AVG(u.login_days), 1)   AS avg_login_days,
       ROUND(AVG(u.active_users), 1) AS avg_active_users
FROM customers c
JOIN clean_product_usage u ON u.customer_id = c.customer_id
WHERE c.region = 'South'
UNION ALL
SELECT 'Company-wide',
       ROUND(AVG(login_days), 1),
       ROUND(AVG(active_users), 1)
FROM clean_product_usage;
