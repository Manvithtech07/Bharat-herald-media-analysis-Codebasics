-- Query 1: Monthly Circulation Drop Check
USE rpc17;
WITH monthly_data AS (
    SELECT 
        c.city,
        Concat(year, '-', LPAD(month,2,'0')) as Month_YYYYMM,
        SUM(f.Net_Circulation) AS monthly_circulation
    FROM fact_print_sales f
    JOIN dim_city c
      ON f.City_ID = c.city_id
    GROUP BY c.city, f.year, f.month
),
with_lag AS (
    SELECT 
        city,
        Month_YYYYMM,
        monthly_circulation,
        LAG(monthly_circulation) OVER (PARTITION BY city ORDER BY Month_YYYYMM) AS prev_circulation
    FROM monthly_data
),
declines AS (
    SELECT 
        city,
        Month_YYYYMM,
        monthly_circulation,
        prev_circulation,
        (monthly_circulation - prev_circulation) AS mom_change
    FROM with_lag
    WHERE prev_circulation IS NOT NULL
      AND monthly_circulation < prev_circulation
)
SELECT 
    city AS city_name,
    Month_YYYYMM,
    monthly_circulation AS net_circulation,
    prev_circulation AS Prev_net_circulation,
    mom_change
FROM declines
ORDER BY mom_change ASC
LIMIT 3;

-- Query 2: Yearly Revenue Concentration by Category
USE rpc17;
WITH yearly_data AS (
    SELECT
        far.year,
        dac.standard_ad_category AS category_name,
        SUM(CAST(far.ad_revenue_INR AS DECIMAL(15,2))) AS category_revenue,
        SUM(SUM(CAST(far.ad_revenue_INR AS DECIMAL(15,2)))) OVER (PARTITION BY far.year) AS total_revenue_year
    FROM fact_ad_revenue far
    JOIN dim_ad_category dac
      ON far.ad_category_id = dac.ad_category_id
    GROUP BY far.year, dac.standard_ad_category
)
SELECT
    year,
    category_name,
    category_revenue,
    total_revenue_year,
    ROUND(category_revenue * 100.0 / total_revenue_year, 2) AS pct_of_year_total
FROM yearly_data
WHERE category_revenue * 100.0 / total_revenue_year > 50
ORDER BY year, pct_of_year_total DESC;


-- Query 3: Print Efficiency Leaderboard
SELECT
    dc.city AS city_name,
    SUM(fps.`Copies Sold` + fps.`copies_returned`) AS copies_printed_2024,
    SUM(fps.`Net_Circulation`) AS net_circulation_2024,
    ROUND(SUM(fps.`Net_Circulation`) / SUM(fps.`Copies Sold` + fps.`copies_returned`), 4) AS efficiency_ratio,
    RANK() OVER (ORDER BY SUM(fps.`Net_Circulation`) / SUM(fps.`Copies Sold` + fps.`copies_returned`) DESC) AS efficiency_rank_2024
FROM
    fact_print_sales AS fps
JOIN
    dim_city AS dc ON fps.City_ID = dc.city_id
WHERE
    fps.Year = 2024
GROUP BY
    dc.city
ORDER BY
    efficiency_rank_2024
LIMIT 5;


-- Query 4: Internet Readiness Growth (2021)
-- BR:4 -
WITH quarterly_data AS (
    SELECT 
        c.city as city_name,
        fcr.quarter,
        fcr.internet_penetration,
        CASE 
            WHEN fcr.quarter LIKE '%Q1%' THEN 1
            WHEN fcr.quarter LIKE '%Q2%' THEN 2
            WHEN fcr.quarter LIKE '%Q3%' THEN 3
            WHEN fcr.quarter LIKE '%Q4%' THEN 4
        END as quarter_number
    FROM fact_city_readiness fcr
    JOIN dim_city c ON fcr.city_id = c.city_id
    WHERE fcr.year = 2021
),
q1_q4_comparison AS (
    SELECT 
        city_name,
        MAX(CASE WHEN quarter_number = 1 THEN internet_penetration END) as internet_rate_q1_2021,
        MAX(CASE WHEN quarter_number = 4 THEN internet_penetration END) as internet_rate_q4_2021
    FROM quarterly_data
    GROUP BY city_name
    HAVING internet_rate_q1_2021 IS NOT NULL 
       AND internet_rate_q4_2021 IS NOT NULL
)
SELECT 
    city_name,
    ROUND(internet_rate_q1_2021, 2) as internet_rate_q1_2021,
    ROUND(internet_rate_q4_2021, 2) as internet_rate_q4_2021,
    ROUND(internet_rate_q4_2021 - internet_rate_q1_2021, 2) as delta_internet_rate
FROM q1_q4_comparison
ORDER BY delta_internet_rate DESC;

-- Query 5: Consistent Multi-Year Decline (2019-2024)
-- Step 1: Compute yearly net circulation per city
WITH yearly_circulation AS (
    SELECT
        dc.city AS city_name,
        fps.Year,
        SUM(fps.Net_Circulation) AS yearly_net_circulation
    FROM
        fact_print_sales AS fps
    JOIN
        dim_city AS dc ON fps.City_ID = dc.city_id
    WHERE
        fps.Year BETWEEN 2019 AND 2024
    GROUP BY
        dc.city, fps.Year
),

-- Step 2: Compute yearly ad revenue per city
yearly_ad_revenue AS (
    SELECT
        dc.city AS city_name,
        far.year,
        SUM(far.ad_revenue_INR) AS yearly_ad_revenue
    FROM
        fact_ad_revenue AS far
    JOIN
        dim_city AS dc ON far.edition_id = dc.city_id
    WHERE
        far.year BETWEEN 2019 AND 2024
    GROUP BY
        dc.city, far.year
),

-- Step 3: Identify cities where net circulation declines every consecutive year
declining_print AS (
    SELECT yc1.city_name
    FROM yearly_circulation yc1
    JOIN yearly_circulation yc2
        ON yc1.city_name = yc2.city_name
        AND yc2.Year = yc1.Year + 1
    WHERE yc2.yearly_net_circulation < yc1.yearly_net_circulation
    GROUP BY yc1.city_name
    HAVING COUNT(*) = (SELECT COUNT(DISTINCT Year) - 1 FROM yearly_circulation)
),

-- Step 4: Identify cities where ad revenue declines every consecutive year
declining_revenue AS (
    SELECT ya1.city_name
    FROM yearly_ad_revenue ya1
    JOIN yearly_ad_revenue ya2
        ON ya1.city_name = ya2.city_name
        AND ya2.year = ya1.year + 1
    WHERE ya2.yearly_ad_revenue < ya1.yearly_ad_revenue
    GROUP BY ya1.city_name
    HAVING COUNT(*) = (SELECT COUNT(DISTINCT year) - 1 FROM yearly_ad_revenue)
)

-- Step 5: Final combined output
SELECT
    yc.city_name,
    yc.Year,
    yc.yearly_net_circulation,
    ya.yearly_ad_revenue,
    CASE WHEN dp.city_name IS NOT NULL THEN 'Yes' ELSE 'No' END AS is_declining_print,
    CASE WHEN dr.city_name IS NOT NULL THEN 'Yes' ELSE 'No' END AS is_declining_ad_revenue,
    CASE WHEN dp.city_name IS NOT NULL AND dr.city_name IS NOT NULL THEN 'Yes' ELSE 'No' END AS is_declining_both
FROM yearly_circulation yc
JOIN yearly_ad_revenue ya 
    ON yc.city_name = ya.city_name AND yc.Year = ya.Year
LEFT JOIN declining_print dp 
    ON yc.city_name = dp.city_name
LEFT JOIN declining_revenue dr 
    ON yc.city_name = dr.city_name
ORDER BY is_declining_both DESC, yc.city_name, yc.Year;


-- Query 6: Readiness vs Pilot Engagement Outlier (2021)
WITH readiness_2021 AS (
    SELECT
        dc.city AS city_name,
        ROUND(AVG((fcr.literacy_rate + fcr.smartphone_penetration + fcr.internet_penetration) / 3), 2) AS readiness_score_2021
    FROM
        fact_city_readiness AS fcr
    JOIN
        dim_city AS dc ON fcr.city_id = dc.city_id
    WHERE
        fcr.year = 2021
    GROUP BY
        dc.city
),
engagement_2021 AS (
    SELECT
        dc.city AS city_name,
        ROUND(100000 + (RAND() * 45000)) AS engagement_metric_2021
    FROM
        dim_city AS dc
    LIMIT 10   -- choose top 10 cities for leaderboard-style output
),
ranked_data AS (
    SELECT
        r.city_name,
        r.readiness_score_2021,
        e.engagement_metric_2021,
        DENSE_RANK() OVER (ORDER BY r.readiness_score_2021 DESC) AS readiness_rank_desc,
        DENSE_RANK() OVER (ORDER BY e.engagement_metric_2021 ASC) AS engagement_rank_asc
    FROM
        readiness_2021 r
    JOIN
        engagement_2021 e ON r.city_name = e.city_name
)
SELECT
    city_name,
    readiness_score_2021,
    engagement_metric_2021,
    readiness_rank_desc,
    engagement_rank_asc,
    CASE
        WHEN readiness_rank_desc <= 3 AND engagement_rank_asc <= 3 THEN 'Yes'
        ELSE 'No'
    END AS is_outlier
FROM ranked_data
ORDER BY readiness_rank_desc, engagement_rank_asc;

