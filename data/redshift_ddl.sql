-- Redshift Target Table DDL
-- Execute this SQL in your Redshift cluster after deployment

-- Create the target table for ETL results
CREATE TABLE IF NOT EXISTS public.customer_order_summary (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    country VARCHAR(50),
    total_order_amount DECIMAL(10,2),
    order_count INTEGER,
    avg_order_amount DECIMAL(10,2),
    last_order_date VARCHAR(50)
)
SORTKEY(customer_id)
DISTKEY(customer_id);

-- Verify table creation
SELECT 
    schemaname,
    tablename,
    tableowner
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'customer_order_summary';

-- Grant permissions (adjust as needed)
-- GRANT SELECT ON public.customer_order_summary TO reporting_user;
-- GRANT ALL ON public.customer_order_summary TO etl_user;

-- Sample query to view results after ETL job runs
SELECT 
    customer_id,
    customer_name,
    country,
    total_order_amount,
    order_count,
    avg_order_amount,
    last_order_date
FROM public.customer_order_summary
ORDER BY total_order_amount DESC
LIMIT 10;

-- Analytics query examples
-- Top customers by total spend
SELECT 
    customer_name,
    country,
    total_order_amount,
    order_count,
    ROUND(avg_order_amount, 2) as avg_order_value
FROM public.customer_order_summary
WHERE total_order_amount > 0
ORDER BY total_order_amount DESC;

-- Customer spending by country
SELECT 
    country,
    COUNT(*) as customer_count,
    SUM(total_order_amount) as country_total,
    AVG(total_order_amount) as avg_customer_spend,
    AVG(order_count) as avg_orders_per_customer
FROM public.customer_order_summary
GROUP BY country
ORDER BY country_total DESC;

-- High-value customers (more than 3 orders and >$500 total)
SELECT 
    customer_name,
    email,
    country,
    total_order_amount,
    order_count,
    avg_order_amount
FROM public.customer_order_summary
WHERE order_count >= 3 
AND total_order_amount > 500
ORDER BY total_order_amount DESC;
