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
