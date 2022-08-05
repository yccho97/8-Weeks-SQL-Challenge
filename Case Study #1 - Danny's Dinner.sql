=========================
-- CASE STUDY QUESTIONS --
=========================
---- 1. What is the total amount each customer spent at the restaurant?
SELECT s.customer_id, SUM(price) AS Total_Sales
FROM dbo.sales as s
JOIN menu as menu
		ON s.product_id = menu.product_id
GROUP BY s.customer_id

---- 2. How many days has each customer visited the restaurant?
SELECT customer_id, COUNT(DISTINCT order_date) AS Visit_Count
FROM sales
GROUP BY customer_ids

-- 3. What was the first item from the menu purchased by each customer?
WITH date_rank_cte AS 
(
 SELECT customer_id, order_date, product_name,
      DENSE_RANK() OVER(PARTITION BY s.customer_id
      ORDER BY s.order_date) AS rank
 FROM dbo.sales AS s
   JOIN dbo.menu AS m
      ON s.product_id = m.product_id
)

SELECT customer_id, product_name
FROM date_rank_cte
WHERE rank = 1
GROUP BY customer_id, product_name;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT TOP 1 sales.product_id, product_name, count (sales.product_id) AS Quantity_Purchased
FROM sales
JOIN menu	
		ON sales.product_id = menu.product_id
GROUP BY sales.product_id, menu.product_name
ORDER BY Quantity_Purchased DESC

-- 5. Which item was the most popular for each customer?
WITH product_rank_cte AS 
(
SELECT customer_id, product_id, count( product_id) AS Quantity_Ordered, 
		DENSE_RANK () OVER(PARTITION BY customer_id ORDER BY count( product_id) DESC) AS Rank
FROM sales
GROUP BY customer_id, product_id
)

SELECT customer_id, menu.product_name, Quantity_Ordered
FROM product_rank_cte
JOIN menu
		ON product_rank_cte.product_id = menu.product_id
WHERE rank = 1

---- 6. Which item was purchased first by the customer after they became a member?
WITH mem_sales_cte AS 
(
SELECT s.customer_id, mem.join_date, s.order_date, s. product_id,
				DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) AS Rank
FROM sales as s
		JOIN members as mem
				ON s.customer_id = mem.customer_id
WHERE s.order_date >= mem.join_date
)

SELECT customer_id, join_date, order_date, menu.product_name
FROM mem_sales_cte
		JOIN menu 
					ON mem_sales_cte.product_id = menu.product_id
WHERE Rank = 1

-- 7. Which item was purchased just before the customer became a member?
WITH mem_before_cte AS 
(
SELECT s.customer_id, s.order_date, s.product_id, mem.join_date, 
				DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS RANK
FROM sales AS s
		JOIN members AS mem
				ON s.customer_id = mem.customer_id
WHERE s.order_date < mem.join_date
)

SELECT cte.customer_id, cte.order_date, menu.product_name
FROM mem_before_cte AS cte
		JOIN menu AS menu
					ON	cte.product_id = menu.product_id
WHERE Rank = 1;

-- 8. What is the total items and amount spent for each member before they became a member?
WITH before_join_cte AS
(
SELECT s.customer_id, s.order_date, s.product_id, menu.price, mem.join_date
FROM sales AS s
		JOIN members AS mem
				on s.customer_id = mem.customer_id
		JOIN menu AS menu
				ON s.product_id = menu.product_id
WHERE s.order_date < mem.join_date
GROUP BY s.customer_id, s.order_date, s.product_id, menu.price, mem.join_date
)

SELECT customer_id, SUM(price) AS Amount_Spent
FROM before_join_cte 
GROUP BY customer_id

-- 9. If each $1 spent equates to 10 points and sushi has a 2X points multiplier 
--	   how many points would each customer have?

CREATE VIEW Points_Table AS
   SELECT *, 
      CASE
         WHEN product_id = 1 THEN price * 20
         ELSE price * 10
      END AS points
   FROM menu

CREATE VIEW Agg_Points_Table AS
SELECT customer_id, s.product_id, SUM(pt.points) AS Agg_Points
FROM sales AS s
			JOIN Points_Table AS pt 
						ON pt.product_id = s.product_id
GROUP BY customer_id, s.product_id

SELECT customer_id, SUM(Agg_Points) AS Total_Points
FROM Agg_Points_Table
GROUP BY customer_id 

-- 10. In the first week after a customer joins the program (including their join date) they earn 2X points on all items, 
--       not just sushi -- how many points do customer A and B have at the end of January?

WITH dates_cte AS 
(
   SELECT *, 
      DATEADD(DAY, 6, join_date) AS valid_date, 
      EOMONTH('2021-01-31') AS last_date
   FROM members AS m
)

SELECT d.customer_id, s.order_date, d.join_date, d.valid_date, d.last_date, m.product_name, m.price,
   SUM(CASE
      WHEN m.product_name = 'sushi' THEN 2 * 10 * m.price
      WHEN s.order_date BETWEEN d.join_date AND d.valid_date THEN 2 * 10 * m.price
      ELSE 10 * m.price
      END) AS points
FROM dates_cte AS d
JOIN sales AS s
   ON d.customer_id = s.customer_id
JOIN menu AS m
   ON s.product_id = m.product_id
WHERE s.order_date < d.last_date
GROUP BY d.customer_id, s.order_date, d.join_date, d.valid_date, d.last_date, m.product_name, m.price

-- BONUS QUESTIONS
-- Join All The Things - Recreate the table with: customer_id, order_date, product_name, price, member(Y/N)
SELECT s.customer_id, s.order_date, m.product_name, m.price, 
				CASE WHEN mem.join_date > s.order_date THEN 'N'
						   WHEN mem.join_date <= s.order_date THEN 'Y'
						   ELSE 'N'
						   END AS member
FROM sales AS s
			JOIN menu AS m
						ON s.product_id = m.product_id
			LEFT JOIN members AS mem
						ON s.customer_id = mem.customer_id

-- Rank All The Thins - Danny also requires further information about the ranking of customer products, bet he purposely
-- does not need the ranking for non-member purchases so he expects null ranking values for the records when customers 
-- are not yet part of the loyalty program.

WITH summary_cte AS 
(
SELECT s.customer_id, s.order_date, m.product_name, m.price, 
				CASE WHEN mem.join_date > s.order_date THEN 'N'
						   WHEN mem.join_date <= s.order_date THEN 'Y'
						   ELSE 'N'
						   END AS member
FROM sales AS s
			JOIN menu AS m
						ON s.product_id = m.product_id
			LEFT JOIN members AS mem
						ON s.customer_id = mem.customer_id
)

SELECT *,
					CASE WHEN member = 'N' THEN NULL
					ELSE
								RANK ()	OVER(PARTITION BY customer_id, member ORDER BY order_date) END AS ranking
FROM summary_cte
