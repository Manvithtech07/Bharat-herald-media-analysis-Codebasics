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
