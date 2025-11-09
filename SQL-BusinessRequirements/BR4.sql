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