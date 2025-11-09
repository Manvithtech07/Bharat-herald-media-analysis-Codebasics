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
