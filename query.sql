SELECT COUNT(*) FROM auto_sales_rfm.sales_data;
SELECT * FROM auto_sales_rfm.sales_data
LIMIT 20;

USE auto_sales_rfm;
SET SQL_SAFE_UPDATES = 0;
UPDATE sales_data
SET order_date_clean = STR_TO_DATE(ORDERDATE, '%d/%m/%Y');
SET SQL_SAFE_UPDATES = 1;

SELECT COUNT(*) FROM sales_data WHERE order_date_clean IS NULL;

SELECT STATUS, COUNT(*) AS order_count
FROM sales_data
GROUP BY STATUS
ORDER BY order_count DESC;

CREATE OR REPLACE VIEW sales_clean AS
SELECT *
FROM sales_data
WHERE STATUS <> 'Cancelled';

SELECT COUNT(*) AS clean_rows FROM sales_clean;

CREATE OR REPLACE VIEW rfm_base AS
SELECT
    CUSTOMERNAME,
    COUNTRY,
    DATEDIFF(
        (SELECT MAX(order_date_clean) + INTERVAL 1 DAY FROM sales_clean),
        MAX(order_date_clean)
    ) AS recency,
    COUNT(DISTINCT ORDERNUMBER) AS frequency,
    ROUND(SUM(SALES), 2)        AS monetary
FROM sales_clean
GROUP BY CUSTOMERNAME, COUNTRY;

SELECT * FROM rfm_base ORDER BY monetary DESC LIMIT 10;

CREATE OR REPLACE VIEW rfm_scores AS
SELECT
    CUSTOMERNAME,
    COUNTRY,
    recency,
    frequency,
    monetary,
    NTILE(5) OVER (ORDER BY recency DESC)  AS r_score,
    NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
    NTILE(5) OVER (ORDER BY monetary ASC)  AS m_score
FROM rfm_base;

SELECT * FROM rfm_scores ORDER BY monetary DESC LIMIT 10;


CREATE OR REPLACE VIEW rfm_segments AS
SELECT
    CUSTOMERNAME,
    COUNTRY,
    recency,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    CONCAT(r_score, f_score, m_score) AS rfm_cell,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 4 AND f_score >= 2                  THEN 'Loyal Customers'
        WHEN r_score >= 4                                   THEN 'New / Promising'
        WHEN r_score <= 2 AND f_score >= 3                  THEN 'At Risk'
        WHEN r_score <= 2 AND m_score >= 4                  THEN 'Cannot Lose Them'
        WHEN r_score  = 3                                   THEN 'Needs Attention'
        ELSE 'Hibernating'
    END AS segment
FROM rfm_scores;

SELECT segment, COUNT(*) AS customers, ROUND(SUM(monetary),0) AS revenue
FROM rfm_segments
GROUP BY segment
ORDER BY revenue DESC;



