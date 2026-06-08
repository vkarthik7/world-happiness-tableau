-- ================================================
-- World Happiness Report (2015-2019) - Data Cleaning
-- ================================================
-- Dataset: UN World Happiness Report
-- Source: Kaggle (5 separate CSV files, one per year)
-- Challenge: Each year had completely different column names
-- Solution: UNION ALL with aliases to standardize all 5 years
-- ================================================

-- Step 0: Create and select database
CREATE DATABASE world_happiness;
USE world_happiness;

-- ================================================
-- Step 1: Explore Raw Data
-- ================================================

-- Preview 2015 data
SELECT * FROM `2015` LIMIT 5;

-- Check column names across all 5 years
-- Note: Each year has completely different column names!
SHOW COLUMNS FROM `2015`;
SHOW COLUMNS FROM `2016`;
SHOW COLUMNS FROM `2017`;  -- Uses dot notation e.g. Happiness.Score
SHOW COLUMNS FROM `2018`;  -- Completely renamed e.g. Score, GDP per capita
SHOW COLUMNS FROM `2019`;  -- Same as 2018

-- ================================================
-- Step 2: Combine All 5 Years Using UNION ALL
-- ================================================
-- Problem: Column names are inconsistent across years
-- Solution: Use column aliases to standardize names
--           Use NULL AS Region for years missing the Region column
--           Add a year column to track which year each row belongs to

CREATE TABLE happiness_combined AS

-- 2015 data
SELECT 
    Country,
    Region,
    `Happiness Score` AS happiness_score,
    `Economy (GDP per Capita)` AS gdp_per_capita,
    Family AS social_support,
    `Health (Life Expectancy)` AS life_expectancy,
    Freedom AS freedom,
    Generosity AS generosity,
    `Trust (Government Corruption)` AS corruption,
    2015 AS year
FROM `2015`

UNION ALL

-- 2016 data
SELECT 
    Country,
    Region,
    `Happiness Score` AS happiness_score,
    `Economy (GDP per Capita)` AS gdp_per_capita,
    Family AS social_support,
    `Health (Life Expectancy)` AS life_expectancy,
    Freedom AS freedom,
    Generosity AS generosity,
    `Trust (Government Corruption)` AS corruption,
    2016 AS year
FROM `2016`

UNION ALL

-- 2017 data — uses dot notation for column names, no Region column
SELECT 
    Country,
    NULL AS Region,
    `Happiness.Score` AS happiness_score,
    `Economy..GDP.per.Capita.` AS gdp_per_capita,
    Family AS social_support,
    `Health..Life.Expectancy.` AS life_expectancy,
    Freedom AS freedom,
    Generosity AS generosity,
    `Trust..Government.Corruption.` AS corruption,
    2017 AS year
FROM `2017`

UNION ALL

-- 2018 data — completely renamed columns, no Region column
SELECT 
    `Country or region` AS Country,
    NULL AS Region,
    Score AS happiness_score,
    `GDP per capita` AS gdp_per_capita,
    `Social support` AS social_support,
    `Healthy life expectancy` AS life_expectancy,
    `Freedom to make life choices` AS freedom,
    Generosity AS generosity,
    `Perceptions of corruption` AS corruption,
    2018 AS year
FROM `2018`

UNION ALL

-- 2019 data — same structure as 2018
SELECT 
    `Country or region` AS Country,
    NULL AS Region,
    Score AS happiness_score,
    `GDP per capita` AS gdp_per_capita,
    `Social support` AS social_support,
    `Healthy life expectancy` AS life_expectancy,
    `Freedom to make life choices` AS freedom,
    Generosity AS generosity,
    `Perceptions of corruption` AS corruption,
    2019 AS year
FROM `2019`;

-- Verify combined table
SELECT * FROM happiness_combined;
SELECT COUNT(*) FROM happiness_combined;

-- Check row counts per year
SELECT year, COUNT(*) AS country_count
FROM happiness_combined
GROUP BY year
ORDER BY year;

-- ================================================
-- Step 3: Handle NULL Values
-- ================================================

-- Check NULL counts across key columns
SELECT 
    SUM(CASE WHEN country IS NULL THEN 1 ELSE 0 END) AS null_country,
    SUM(CASE WHEN happiness_score IS NULL THEN 1 ELSE 0 END) AS null_score,
    SUM(CASE WHEN gdp_per_capita IS NULL THEN 1 ELSE 0 END) AS null_gdp,
    SUM(CASE WHEN region IS NULL THEN 1 ELSE 0 END) AS null_region
FROM happiness_combined;

-- Fill NULL regions using self join
-- Logic: If a country appears in 2015/2016 with a region, copy it to 2017/2018/2019
UPDATE happiness_combined t1       
JOIN happiness_combined t2         
    ON t1.country = t2.country     
    AND t2.region IS NOT NULL       
SET t1.region = t2.region           
WHERE t1.region IS NULL;            

-- Verify how many NULLs remain
SELECT 
    SUM(CASE WHEN region IS NULL THEN 1 ELSE 0 END) AS null_region
FROM happiness_combined;

-- Find which countries still have NULL region
-- These are countries that only appear in 2017/2018/2019 — no 2015/2016 row to copy from
SELECT DISTINCT country
FROM happiness_combined
WHERE region IS NULL;

-- Manually assign regions for remaining NULL countries
UPDATE happiness_combined SET region = 'Eastern Asia' WHERE country = 'Taiwan Province of China';
UPDATE happiness_combined SET region = 'Eastern Asia' WHERE country = 'Hong Kong S.A.R., China';
UPDATE happiness_combined SET region = 'Latin America and Caribbean' WHERE country = 'Trinidad & Tobago';
UPDATE happiness_combined SET region = 'Western Europe' WHERE country = 'Northern Cyprus';
UPDATE happiness_combined SET region = 'Central and Eastern Europe' WHERE country = 'North Macedonia';
UPDATE happiness_combined SET region = 'Sub-Saharan Africa' WHERE country = 'Gambia';

-- Verify all NULLs are fixed
SELECT SUM(CASE WHEN region IS NULL THEN 1 ELSE 0 END) AS null_region
FROM happiness_combined;

-- ================================================
-- Step 4: Standardize Country Names
-- ================================================
-- Problem: Same country has different names across years
-- e.g. Taiwan Province of China (2017) vs Taiwan (2015/2016)
-- This would create duplicate dots on the Tableau map!

UPDATE happiness_combined SET country = 'Taiwan' WHERE country = 'Taiwan Province of China';
UPDATE happiness_combined SET country = 'Hong Kong' WHERE country = 'Hong Kong S.A.R., China';
UPDATE happiness_combined SET country = 'Trinidad and Tobago' WHERE country = 'Trinidad & Tobago';
UPDATE happiness_combined SET country = 'North Macedonia' WHERE country = 'Macedonia';
UPDATE happiness_combined SET country = 'Northern Cyprus' WHERE country = 'North Cyprus';

-- ================================================
-- Step 5: Check for Duplicates
-- ================================================

-- Each country should appear exactly once per year
SELECT country, year, COUNT(*) AS count
FROM happiness_combined
GROUP BY country, year
HAVING COUNT(*) > 1;
-- Result: No duplicates found

-- ================================================
-- Step 6: Final Verification of Combined Table
-- ================================================

SELECT COUNT(*) FROM happiness_combined;
SELECT * FROM happiness_combined LIMIT 10;

SELECT year, COUNT(*) AS countries
FROM happiness_combined
GROUP BY year
ORDER BY year;

-- ================================================
-- Step 7: Feature Engineering — Create Final Table
-- ================================================
-- Added two new columns using CTE and window functions:
-- 1. happiness_rank — rank within each year using RANK() OVER (PARTITION BY year)
-- 2. happiness_category — Happy/Neutral/Unhappy using CASE WHEN

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

-- Verify final table
SELECT * FROM happiness_final;

-- ================================================
-- Step 8: Add Year-over-Year Change Column
-- ================================================
-- Shows how each country's happiness score changed from previous year
-- Uses a self join matching same country, previous year
-- 2015 rows will have NULL (no previous year to compare)

ALTER TABLE happiness_final ADD COLUMN yoy_change DOUBLE;

UPDATE happiness_final t1
LEFT JOIN happiness_final t2
    ON t1.country = t2.country
    AND t1.year = t2.year + 1
SET t1.yoy_change = ROUND(t1.happiness_score - t2.happiness_score, 3);

-- Verify year-over-year change for Finland (known to be improving)
SELECT country, year, happiness_score, yoy_change
FROM happiness_final
WHERE country = 'Finland'
ORDER BY year;

-- ================================================
-- Step 9: Final Data Quality Fix
-- ================================================

-- Fix Somaliland capitalization inconsistency
UPDATE happiness_final 
SET country = 'Somaliland Region'
WHERE country = 'Somaliland region';

-- ================================================
-- Final Clean Dataset
-- ================================================
-- Total rows: 781
-- Years: 2015-2019
-- Countries per year: 155-158
-- Columns: country, region, happiness_score, gdp_per_capita,
--          social_support, life_expectancy, freedom, generosity,
--          corruption, year, happiness_rank, happiness_category, yoy_change

SELECT * FROM happiness_final;
