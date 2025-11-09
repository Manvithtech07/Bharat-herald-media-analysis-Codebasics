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