CREATE SCHEMA Dannys_Diner DEFAULT CHAR SET = utf8mb4;

USE Dannys_Diner;

CREATE TABLE IF NOT EXISTS members(
customer_id VARCHAR(5) NOT NULL,
join_date DATE NOT NULL,
PRIMARY KEY (customer_id)
)ENGINE = InnoDB , CHAR SET = utf8mb4;

CREATE TABLE IF NOT EXISTS menu(
product_id INT NOT NULL,
product_name VARCHAR(25) NOT NULL,
price INT NOT NULL,
PRIMARY KEY (product_id)
)ENGINE = InnoDB , CHAR SET = utf8mb4;

CREATE TABLE IF NOT EXISTS sales(
customer_id VARCHAR(5) NOT NULL,
order_date DATE NOT NULL,
product_id INT NOT NULL,
FOREIGN KEY (customer_id) REFERENCES members(customer_id),
FOREIGN KEY (product_id) REFERENCES menu(product_id)
)ENGINE = InnoDB , CHAR SET = utf8mb4;

SHOW VARIABLES WHERE Variable_name LIKE '%update%';

SET sql_safe_updates = 0;
COMMIT;


DELETE FROM members
WHERE customer_id = 'C';

INSERT INTO members(customer_id, join_date)
VALUES
  ('A', CAST('2021-01-07'AS DATE)),
  ('B', CAST('2021-01-09'AS DATE)),
  ('C', CAST('2021-01-11'AS DATE));
  COMMIT;
  
INSERT INTO menu
  (product_id,product_name,price)
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  COMMIT;
  
  INSERT INTO sales
  (customer_id,order_date, product_id)
VALUES
  ('A', CAST('2021-01-01' AS DATE), '1'),
  ('A', CAST('2021-01-01' AS DATE), '2'),
  ('A', CAST('2021-01-07' AS DATE), '2'),
  ('A', CAST('2021-01-10' AS DATE), '3'),
  ('A', CAST('2021-01-11' AS DATE), '3'),
  ('A', CAST('2021-01-11' AS DATE), '3'),
  ('B', CAST('2021-01-01' AS DATE), '2'),
  ('B', CAST('2021-01-02' AS DATE), '2'),
  ('B', CAST('2021-01-04' AS DATE), '1'),
  ('B', CAST('2021-01-11' AS DATE), '1'),
  ('B', CAST('2021-01-16' AS DATE), '3'),
  ('B', CAST('2021-02-01' AS DATE), '3'),
  ('C', CAST('2021-01-01' AS DATE), '3'),
  ('C', CAST('2021-01-01' AS DATE), '3'),
  ('C', CAST('2021-01-07' AS DATE), '3');
  COMMIT;
  
 SELECT * FROM sales;
  
  SELECT * FROM menu;
  
  SELECT * FROM members;
  
/* 1. What is the total amount each customer spent at the restaurant? */
-- 1st Approch 
SELECT 
DISTINCT s.customer_id,
SUM(m.price) OVER (PARTITION BY s.customer_id) AS Total_amount
FROM sales AS s
LEFT JOIN menu AS m
	ON s.product_id = m.product_id;

-- 2nd  Approch --
SELECT 
s.customer_id,
SUM(m.price) AS Total_amount
FROM sales AS s
LEFT JOIN menu AS m
	ON s.product_id = m.product_id
GROUP BY s.customer_id;

/* 2. How many days has each customer visited the restaurant ?*/

SELECT 
customer_id AS Customer,
COUNT(DISTINCT order_date) AS no_of_days_visited
FROM sales
GROUP BY customer_id;

/* 3. What was the first item from the menu purchased by each customer */
WITH first_purchase_item AS(
SELECT 
s.customer_id,
order_date,
m.product_name,
DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY order_date ASC ) AS rnk
FROM sales AS s
LEFT JOIN menu AS m
	ON s.product_id = m.product_id)
Select  
customer_id,product_name
FROM first_purchase_item
WHERE rnk = 1
GROUP BY customer_id,product_name;

/* 4. What is the most purchased item on the menu and 
how many times was it purchased by all customers??*/

SELECT
DISTINCT m.product_name,
COUNT(*) OVER (PARTITION BY s.product_id) AS no_of_times_purchased
FROM sales AS s
LEFT JOIN menu AS m
	ON s.product_id = m.product_id 
ORDER BY no_of_times_purchased DESC
LIMIT 1 ;

/* 5. Which item was the most popular for each customer?*/

SELECT
m.product_name,
s.customer_id,
COUNT(*) AS no_of_times_purchased
FROM sales AS s
LEFT JOIN menu AS m
	ON s.product_id = m.product_id
GROUP BY s.customer_id, m.product_name
ORDER BY customer_id ASC , no_of_times_purchased DESC;

WITH most_purchase AS(
SELECT
m.product_name,
s.customer_id,
COUNT(m.product_id) AS no_of_times_purchased,
DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY COUNT(s.customer_id) DESC) AS rnk
FROM sales AS s
LEFT JOIN menu AS m
	ON  m.product_id = s.product_id
GROUP BY s.customer_id, m.product_name)
SELECT customer_id AS Customer , product_name, no_of_times_purchased FROM most_purchase WHERE rnk = 1;

/* 6. Which item was purchased first by the customer after they became a member*/
WITH CTE1 AS (
SELECT s.*, m.product_name, mem.join_date
FROM sales AS s
LEFT JOIN members AS mem
	ON s.customer_id = mem.customer_id
LEFT JOIN menu AS m
	ON s.product_id = m.product_id
WHERE s.order_date > mem.join_date),
CTE2 AS( SELECT customer_id, product_name, order_date, join_date,
DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY order_date ASC) AS rnk
FROM CTE1)
SELECT DISTINCT customer_id , product_name 
FROM CTE2 WHERE rnk = 1;

/* 7. Which item was purchased just before the customer became a member? */
WITH purchase_before_member AS(
SELECT
m.customer_id,
s.product_id,
ROW_NUMBER() OVER (PARTITION BY m.customer_id ORDER BY s.order_date DESC) AS rnk
FROM members AS m
INNER JOIN sales AS s
	ON m.customer_id = s.customer_id
    AND s.order_date < m.join_date)
SELECT
pbm.customer_id AS Customer,
mn.product_name AS Product_Name
FROM purchase_before_member AS pbm
INNER JOIN menu AS mn
	ON pbm.product_id = mn.product_id
WHERE pbm.rnk = 1
ORDER BY pbm.customer_id;

/* 8. What is the total items and amount spent for each member before they became a member? */

WITH CTE1 AS (
SELECT
mem.customer_id,
s.product_id
FROM members AS mem
LEFT JOIN sales AS s
	ON mem.customer_id = s.customer_id
	AND s.order_date < mem.join_date)
SELECT 
CTE1.customer_id AS Customer,
COUNT(CTE1.product_id) AS Total_items, SUM(m.price) AS Total_amount_spent
FROM CTE1
LEFT JOIN menu AS m
	ON CTE1.product_id = m.product_id
GROUP BY CTE1.customer_id;

/* 9. If each $1 spent equates to 10 points and 
sushi has a 2x points multiplier - how many points would each customer have? */

WITH points AS(
SELECT *,
CASE WHEN product_id = 1 THEN price * (2*10) 
ELSE price * 10 END AS product_point
FROM menu)
SELECT
DISTINCT s.customer_id AS Customer,
SUM(p.product_point) OVER (PARTITION BY s.customer_id) AS Total_points
FROM SALES AS s
LEFT JOIN points p
 ON s.product_id = p.product_id;
 
/* 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, 
not just sushi - how many points do customer A and B have at the end of January */

WITH date_cte AS(
SELECT customer_id, join_date,
CAST(join_date + 6 AS DATE) AS Valid_date,
CAST('2021-01-31' AS DATE) AS Last_date
FROM members)
SELECT s.customer_id AS Customer,
SUM(CASE 
WHEN s.order_date BETWEEN d.join_date AND d.Valid_date THEN 2 * 10 * m.price
WHEN s.order_date NOT BETWEEN d.join_date AND d.Valid_date AND m.product_name LIKE 'sushi' THEN 2 * 10 * m.price
ELSE 10 * m.price END) AS Total_points
FROM sales AS s
INNER JOIN date_cte AS d
	ON s.customer_id = d.customer_id
    AND s.order_date <= d.Last_date
INNER JOIN menu AS m
	ON s.product_id = m.product_id
GROUP BY s.customer_id;

/* Bonus Questions
Join All The Things
The following questions are related creating basic data tables that Danny and 
his team can use to quickly derive insights without needing to join the underlying tables using SQL */

SELECT s.customer_id AS Customer, s.order_date AS Order_Date, mn.product_name AS Product_Name, mn.price AS Price,
CASE 
WHEN s.order_date < m.join_date THEN 'N'
WHEN s.order_date > m.join_date THEN 'Y'
ELSE 'N' END AS Membership
FROM sales AS s
LEFT JOIN members AS m
	ON s.customer_id = m.customer_id
LEFT JOIN menu AS mn
	ON s.product_id = mn.product_id
ORDER BY s.customer_id, s.order_date;


/* Rank All The Things
Danny also requires further information about the ranking of customer products, 
but he purposely does not need the ranking for non-member purchases so he expects null ranking values for 
the records when customers are not yet part of the loyalty program. */

WITH CTE1 AS (
SELECT s.customer_id AS Customer, s.order_date AS Order_Date, 
mn.product_name AS Product_Name, mn.price AS Price,
CASE 
WHEN s.order_date < m.join_date THEN 'N'
WHEN s.order_date >= m.join_date THEN 'Y'
ELSE 'N' END AS Membership
FROM sales AS s
LEFT JOIN members AS m
	ON s.customer_id = m.customer_id
INNER JOIN menu AS mn
	ON s.product_id = mn.product_id
ORDER BY s.customer_id, s.order_date)
SELECT *,
CASE
WHEN Membership = 'N' THEN NULL
ELSE RANK() OVER (PARTITION BY Customer, Membership ORDER BY order_date) 
END AS Ranking
FROM CTE1;
