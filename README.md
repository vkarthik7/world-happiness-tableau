# World Happiness Report Analysis (2015-2019)
### SQL Data Cleaning + Tableau Visualization

## Dashboard Preview

### Dashboard 1 — World Happiness Overview
![World Happiness Overview](Dashboard_1.png)

### Dashboard 2 — What Drives Happiness?
![What Drives Happiness](Dashboard_2.png)

## 🔗 Live Interactive Dashboard
**[View on Tableau Public](https://public.tableau.com/app/profile/karthik.vajja/viz/WorldHappinessReport2015-2019_17809599904580/AnalysisDashboard)**

---

## Overview
I analyzed 5 years of UN World Happiness Report data (2015-2019) covering 155-158 countries per year. The project involved cleaning and combining 5 separate CSV files with inconsistent column names using MySQL, then building an interactive Tableau dashboard to uncover what makes countries happy — and whether it's really just about money.

## Tools Used
- MySQL — data cleaning, combining and feature engineering
- Tableau Public — interactive dashboard and visualization

## Project Structure
| File | Description |
|------|-------------|
| `world_happiness_cleaning.sql` | Full SQL cleaning and transformation script |
| `world_happiness_clean.csv` | Final cleaned dataset — 781 rows, 13 columns |
| `World_Happiness_Report_2015-2019.twb` | Tableau workbook |

---

## The Data Challenge
Each year's CSV had completely different column names:

| Column | 2015/2016 | 2017 | 2018/2019 |
|--------|-----------|------|-----------|
| Happiness Score | `Happiness Score` | `Happiness.Score` | `Score` |
| GDP | `Economy (GDP per Capita)` | `Economy..GDP.per.Capita.` | `GDP per capita` |
| Region | ✅ Present | ❌ Missing | ❌ Missing |

I solved this using `UNION ALL` with column aliases to standardize all 5 years into one clean table.

---

## SQL Cleaning Steps

**1. Combined 5 CSV files into one table**
Used `UNION ALL` with column aliases to standardize inconsistent column names across years and add a `year` column for time analysis.

**2. Filled 466 missing Region values**
2017-2019 had no Region column. Used a self join to copy region values from 2015/2016 rows of the same country. 8 remaining NULLs filled manually.

**3. Standardized country names**
Fixed inconsistencies like `Taiwan Province of China` → `Taiwan` and `Trinidad & Tobago` → `Trinidad and Tobago` so Tableau's map could recognize them.

**4. Feature Engineering with CTEs and Window Functions**
```sql
CREATE TABLE happiness_final AS
WITH ranked AS (
    SELECT *,
    RANK() OVER(PARTITION BY year ORDER BY happiness_score DESC) AS happiness_rank,
    CASE 
        WHEN happiness_score >= 6 THEN 'Happy'
        WHEN happiness_score >= 4 THEN 'Neutral'
        ELSE 'Unhappy'
    END AS happiness_category
    FROM happiness_combined
)
SELECT * FROM ranked;
```

**5. Added Year-over-Year Change**
Used a self join to calculate how each country's happiness score changed from the previous year.

---

## Dashboard Overview

### Dashboard 1 — World Happiness Overview
- **World Map** — color coded by average happiness score (blue = happy, orange = unhappy)
- **Top 10 Happiest Countries** — Denmark, Norway and Finland consistently lead
- **Bottom 10 Unhappiest Countries** — Burundi, Central African Republic and Syria at the bottom

### Dashboard 2 — What Drives Happiness? A Global Analysis
- **Happiness Trend (2015-2019)** — line chart by region showing how happiness changed over time
- **GDP vs Happiness** — scatter plot with trend line showing wealth-happiness correlation
- **Social Factors by Happiness** — comparison of social support, freedom, life expectancy, corruption and generosity across happy vs unhappy countries

---

## Key Findings

**Who is happiest?**
- Nordic countries dominate — Denmark, Norway, Finland, Switzerland, Iceland in top 5 every year
- North America and Western Europe consistently score highest
- Sub-Saharan Africa and Southern Asia score lowest

**Does money buy happiness?**
- GDP strongly correlates with happiness — the scatter plot shows a clear upward trend
- BUT high GDP alone doesn't guarantee happiness — some wealthy countries score lower due to social issues

**What actually drives happiness?**
- Happy countries have 2x higher social support than unhappy countries
- Happy countries have 2.5x more freedom than unhappy countries
- Happy countries have significantly lower corruption
- Life expectancy gap between happy and unhappy countries is dramatic
- **Conclusion: Social conditions matter as much as — or more than — wealth**

**Trends over time:**
- North America shows a slight happiness decline from 2015-2019
- Sub-Saharan Africa remains consistently the lowest scoring region
- Western Europe remains stable at the top

---

## What I Learned
- How to combine multiple datasets with inconsistent schemas using UNION ALL and column aliases
- Using window functions (RANK, PARTITION BY) for feature engineering
- Self joins for filling missing values across related rows
- Building multi-chart Tableau dashboards that tell a cohesive data story
- The difference between correlation (GDP vs happiness) and causation (social factors)
- How to frame data findings as actionable insights rather than just numbers
