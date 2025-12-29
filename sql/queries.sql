/* =========================================================
   PROJECT: E-commerce Sales Analysis (PostgreSQL)
   FILE: queries.sql
   ========================================================= */

-- 0) SANITY CHECKS
SELECT 'customers' AS table_name, COUNT(*) AS rows FROM customers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'payments', COUNT(*) FROM payments;


-- 1) KPI SUMMARY (ventas, órdenes, AOV, clientes)
-- Nota: usamos payments para ingresos (incluye refunds negativos)
WITH revenue AS (
  SELECT
    o.order_id,
    o.customer_id,
    DATE_TRUNC('month', o.order_date) AS month,
    SUM(p.amount) AS net_revenue
  FROM orders o
  JOIN payments p ON p.order_id = o.order_id
  GROUP BY 1,2,3
)
SELECT
  month,
  COUNT(DISTINCT order_id) AS orders,
  COUNT(DISTINCT customer_id) AS active_customers,
  ROUND(SUM(net_revenue)::numeric, 2) AS net_revenue,
  ROUND((SUM(net_revenue) / NULLIF(COUNT(DISTINCT order_id),0))::numeric, 2) AS aov
FROM revenue
GROUP BY month
ORDER BY month;


-- 2) VENTAS MENSUALES (tendencia) + crecimiento vs mes anterior (MoM)
WITH monthly AS (
  SELECT
    DATE_TRUNC('month', o.order_date) AS month,
    SUM(p.amount) AS net_revenue
  FROM orders o
  JOIN payments p ON p.order_id = o.order_id
  GROUP BY 1
)
SELECT
  month,
  ROUND(net_revenue::numeric, 2) AS net_revenue,
  ROUND(
    (net_revenue - LAG(net_revenue) OVER (ORDER BY month))
    / NULLIF(LAG(net_revenue) OVER (ORDER BY month), 0) * 100
  , 2) AS mom_growth_pct
FROM monthly
ORDER BY month;


-- 3) TOP CATEGORÍAS POR INGRESO (neto) + % contribución
WITH order_value AS (
  SELECT
    o.order_id,
    SUM(p.amount) AS net_revenue
  FROM orders o
  JOIN payments p ON p.order_id = o.order_id
  GROUP BY 1
),
category_sales AS (
  SELECT
    pr.category,
    SUM(oi.quantity * pr.price) AS gross_sales
  FROM order_items oi
  JOIN products pr ON pr.product_id = oi.product_id
  GROUP BY 1
),
total AS (
  SELECT SUM(gross_sales) AS total_gross FROM category_sales
)
SELECT
  cs.category,
  ROUND(cs.gross_sales::numeric, 2) AS gross_sales,
  ROUND((cs.gross_sales / NULLIF(t.total_gross,0) * 100)::numeric, 2) AS pct_of_total
FROM category_sales cs
CROSS JOIN total t
ORDER BY gross_sales DESC;


-- 4) TOP 10 PRODUCTOS (por unidades y por ingresos brutos)
-- 4a) por unidades
SELECT
  pr.product_id,
  pr.product_name,
  pr.category,
  SUM(oi.quantity) AS units_sold
FROM order_items oi
JOIN products pr ON pr.product_id = oi.product_id
GROUP BY 1,2,3
ORDER BY units_sold DESC
LIMIT 10;

-- 4b) por ingresos brutos (qty * price)
SELECT
  pr.product_id,
  pr.product_name,
  pr.category,
  ROUND(SUM(oi.quantity * pr.price)::numeric, 2) AS gross_revenue
FROM order_items oi
JOIN products pr ON pr.product_id = oi.product_id
GROUP BY 1,2,3
ORDER BY gross_revenue DESC
LIMIT 10;


-- 5) CLIENTES VIP (Top 20) por revenue neto (payments)
WITH customer_revenue AS (
  SELECT
    o.customer_id,
    SUM(p.amount) AS net_revenue,
    COUNT(DISTINCT o.order_id) AS orders_count,
    MIN(o.order_date) AS first_order_date,
    MAX(o.order_date) AS last_order_date
  FROM orders o
  JOIN payments p ON p.order_id = o.order_id
  GROUP BY 1
)
SELECT
  c.customer_id,
  c.full_name,
  c.country,
  cr.orders_count,
  ROUND(cr.net_revenue::numeric, 2) AS net_revenue,
  cr.first_order_date,
  cr.last_order_date,
  ROUND((cr.net_revenue / NULLIF(cr.orders_count,0))::numeric, 2) AS avg_order_value
FROM customer_revenue cr
JOIN customers c ON c.customer_id = cr.customer_id
ORDER BY cr.net_revenue DESC
LIMIT 20;


-- 6) ANÁLISIS DE CANCELLED vs REFUNDED (tasa y impacto)
WITH order_status AS (
  SELECT
    status,
    COUNT(*) AS orders
  FROM orders
  GROUP BY 1
),
revenue_by_status AS (
  SELECT
    o.status,
    SUM(p.amount) AS net_revenue
  FROM orders o
  LEFT JOIN payments p ON p.order_id = o.order_id
  GROUP BY 1
)
SELECT
  s.status,
  s.orders,
  ROUND((s.orders / NULLIF((SELECT SUM(orders) FROM order_status),0)::numeric) * 100, 2) AS pct_orders,
  ROUND(COALESCE(r.net_revenue,0)::numeric, 2) AS net_revenue
FROM order_status s
LEFT JOIN revenue_by_status r ON r.status = s.status
ORDER BY s.orders DESC;


-- 7) MÉTODOS DE PAGO (mix) + revenue neto por método
SELECT
  payment_method,
  COUNT(*) AS payments_count,
  ROUND(SUM(amount)::numeric, 2) AS net_revenue
FROM payments
GROUP BY 1
ORDER BY net_revenue DESC;


-- 8) COHORTS (signup month vs compras) - nivel PRO (simple)
-- Cohorte = mes de signup. Medimos si compró en su mes 0/1/2...
WITH customer_cohort AS (
  SELECT
    customer_id,
    DATE_TRUNC('month', signup_date) AS cohort_month
  FROM customers
),
customer_orders AS (
  SELECT
    o.customer_id,
    DATE_TRUNC('month', o.order_date) AS order_month
  FROM orders o
),
cohort_activity AS (
  SELECT
    cc.cohort_month,
    co.order_month,
    (DATE_PART('year', co.order_month) - DATE_PART('year', cc.cohort_month)) * 12 +
    (DATE_PART('month', co.order_month) - DATE_PART('month', cc.cohort_month)) AS months_since_signup,
    COUNT(DISTINCT co.customer_id) AS active_customers
  FROM customer_cohort cc
  JOIN customer_orders co ON co.customer_id = cc.customer_id
  GROUP BY 1,2,3
)
SELECT
  cohort_month,
  months_since_signup,
  active_customers
FROM cohort_activity
WHERE months_since_signup BETWEEN 0 AND 6
ORDER BY cohort_month, months_since_signup;


-- 9) DATA QUALITY CHECKS (para mostrar pensamiento profesional)
-- 9a) Órdenes sin items
SELECT
  o.order_id
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
WHERE oi.order_id IS NULL
LIMIT 20;

-- 9b) Payments sin order (no debería pasar)
SELECT
  p.payment_id, p.order_id
FROM payments p
LEFT JOIN orders o ON o.order_id = p.order_id
WHERE o.order_id IS NULL
LIMIT 20;
