-- Ejecutar con psql (porque usa \copy)
-- Ajusta la ruta si tu carpeta data no está en la raíz.

\copy customers(customer_id, full_name, email, country, signup_date) FROM 'data/customers.csv' DELIMITER ',' CSV HEADER;
\copy products(product_id, product_name, category, price) FROM 'data/products.csv' DELIMITER ',' CSV HEADER;
\copy orders(order_id, customer_id, order_date, status) FROM 'data/orders.csv' DELIMITER ',' CSV HEADER;
\copy order_items(order_item_id, order_id, product_id, quantity) FROM 'data/order_items.csv' DELIMITER ',' CSV HEADER;
\copy payments(payment_id, order_id, payment_date, amount, payment_method) FROM 'data/payments.csv' DELIMITER ',' CSV HEADER;

