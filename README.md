# FlowDesk Technologies: Customer Retention & Churn Analysis
An end-to-end data analysis of a SaaS company whose revenue is growing fast while its customer base is not. Using **SQL, Excel and PowerPoint**, we investigate why customers leave and what management should do about it.
## Project Highlights

* **10,000 customers analyzed** across seven interconnected datasets covering three fiscal years.
* **37.9% overall customer churn** identified, highlighting a significant customer retention challenge.
* **76.7% churn in the Affiliate channel** revealed a major retention concern associated with discount-driven customer acquisition.
* **71.9% churn among customers with slow or incomplete onboarding** highlighted an opportunity to improve onboarding effectiveness.
* **Actionable business recommendations** developed to optimize discount strategies, improve onboarding, establish support SLAs, and strengthen marketing attribution.
* **PostgreSQL, Excel, and PowerPoint** used to clean data, analyze business performance, uncover churn patterns, and communicate insights for data-driven decision-making.

Business Problem:
FlowDesk's billing revenue nearly tripled in two years, but new signups stayed flat and more than a third of all customers ever signed have cancelled. Three teams each blamed someone else:
| Team | Hypothesis |
| Marketing | Acquisition is performing well. Blame Customer Success and Product. |
| Customer Success | Marketing brings poor-fit customers, and onboarding fails to retain them. |
| Product | Bugs and slow integration fixes are driving churn. |

**Goal:** use the data to test each hypothesis, find the real churn drivers, and recommend actions.

## Dataset

Seven tables for a SaaS company with **10,000 customers** over three fiscal years (FY23-24 to FY25-26).

| Table | Description |
|-------|-------------|
| customers | Signup date, region, city, industry, acquisition channel, campaign, account status |
| subscriptions | Plan, billing cycle, price, discount, cancellation date |
| invoices | About 100,000 invoices with amounts, discounts and payment status |
| onboarding | Onboarding start/completion dates, training attendance |
| product_usage | Monthly logins, projects created, active users per customer |
| support_tickets | About 37,000 tickets with category, subcategory, resolution time, CSAT |
| marketing_campaigns | Campaign channel, spend and discount offered |

## Tools Used

- **SQL (PostgreSQL):** data validation, cleaning views, churn and revenue analysis
- **Excel:** analytical workbook with raw data, analysis sheets and charts
- **PowerPoint:** executive presentation with findings and recommendations

## Data Cleaning

| Issue | What we found | Action |
|-------|---------------|--------|
| Inconsistent channel names | 20 raw spellings of 6 real channels (for example Direct, direct, DIRECT) | Standardised into 6 clean channels |
| Missing campaign_id | 3,422 customers (34.2%) | Marked as `UNKNOWN` and excluded from campaign-level maths |
| Duplicate invoices | 120 exact duplicate rows (100,338 to 100,218) | Removed before any revenue calculation |
| Mixed date formats | YYYY-MM-DD and DD/MM/YYYY mixed | Parsed and checked, 0 unparseable dates remained |
| Duplicate usage rows | 4,956 rows in conflicting customer-month pairs | Averaged per customer-month, impact under 0.2% |
| Missing case fields | No rep-commission or shipping/returns data in this SaaS dataset | Used churn, discount and usage by region instead |


## Key Findings

**1. Growth is not coming from more customers.**
Signups were flat (3,326 → 3,365 → 3,297) while billing revenue grew from about ₹11.95 Cr to ₹33.4 Cr. Overall logo churn is **37.9%** (3,789 of 10,000 customers).

**2. The Affiliate channel is a discount cliff.**
Affiliate Referral Network churn is **76.7%**, against 22.5% for Organic Search and 24.9% for Direct. About **70.2%** of Affiliate customers cancel within 90 days, right when the discount ends. Marketing's hypothesis is **not supported**.

**3. Slow onboarding is a strong churn driver.**
Slow or incomplete onboarding: **71.9% churn**. Fast onboarding: **30.8%**. Customers who attended the training webinar churned at 31.6% versus 41.9% for those who did not. Customer Success's hypothesis is **partly supported**.

**4. Integration issues are real, but a smaller piece of the puzzle.**
Integration tickets take about **33 hours** to resolve with a CSAT of **2.0/5**, compared with 3.5 hours and 4.7/5 for general tickets. Product's hypothesis is **partly supported**.

**5. Churn is not a regional problem.**
All four regions sit between 37.7% and 38.1% churn, so the North and South concerns are not explained by region.

## Recommendations

1. **Restructure Affiliate discounting.** Taper the discount instead of a hard cliff, and shift budget to Organic Search and Direct.
2. **Make the onboarding webinar mandatory** and target onboarding completion within 14 days.
3. **Set an SLA (for example 8 hours)** for Integration tickets on Growth and Business plans.
4. **Fix campaign attribution at signup.** 34.2% of customers have no campaign_id, which blocks CAC and LTV analysis.
5. **Do not approve the proposed 50% acquisition budget increase** until Affiliate churn is fixed.

## Limitations

- Customers with Integration tickets on premium plans actually churned *less* (21.1%) than all premium customers (39.4%), and active customers raised more bug tickets than cancelled ones. This is likely because customers who stay longer have more time to raise tickets, so ticket volume alone should not be read as a cause of churn.
- Campaign-level analysis excludes the 34.2% of customers with no campaign_id.
- This is observational data. The findings show association, not proven cause.

## Repository Structure

flowdesk-churn-analysis/
├── sql/
│   └── flowdesk_churn_analysis.sql
├── excel/
│   └── flowdesk_analytical_workbook.xlsx
├── presentation/
│   └── flowdesk_executive_presentation.pptx
└── README.md


## How to Use

1. Load the seven tables into a PostgreSQL database.
2. Open `sql/flowdesk_churn_analysis.sql` and run **Section 00** first. It creates helper functions and cleaned views.
3. Run Sections 01 to 06 in order.
4. Open the Excel workbook to see the analysis sheets and charts, and the PowerPoint for the executive summary.

## Skills Demonstrated

Data cleaning and validation · SQL (CTEs, window functions, views, joins) · cohort and churn analysis · hypothesis testing · Excel reporting · business storytelling


