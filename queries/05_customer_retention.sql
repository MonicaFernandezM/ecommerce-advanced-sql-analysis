-- Business Case 05: Destrucción de Valor y Fidelidad (Análisis de Cohortes)
-- Contexto: Cuantificación del impacto de la primera experiencia de entrega
--           (a tiempo vs. retraso) sobre la tasa de recompra recurrente,
--           utilizando ROW_NUMBER() para aislar la primera compra por usuario único.

WITH ranked_customer_orders AS (
    SELECT 
        c.customer_unique_id,
        o.order_id,
        TRY_CAST(o.order_purchase_timestamp AS TIMESTAMP) AS purchase_at,
        -- Detección de retraso en la orden evaluada
        CASE 
            WHEN TRY_CAST(o.order_delivered_customer_date AS TIMESTAMP) > TRY_CAST(o.order_estimated_delivery_date AS TIMESTAMP) 
            THEN 1 
            ELSE 0 
        END AS is_delayed,
        -- Orden cronológico de las compras de cada cliente único
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id 
            ORDER BY TRY_CAST(o.order_purchase_timestamp AS TIMESTAMP) ASC
        ) AS order_sequence
    FROM raw_orders o
    INNER JOIN raw_customers c 
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
),
first_order_cohort AS (
    SELECT 
        customer_unique_id,
        CASE 
            WHEN is_delayed = 1 THEN 'Primera Compra Con Retraso'
            ELSE 'Primera Compra A Tiempo'
        END AS cohorte_primer_pedido
    FROM ranked_customer_orders
    WHERE order_sequence = 1
),
customer_total_orders AS (
    SELECT 
        customer_unique_id,
        COUNT(order_id) AS total_pedidos_historicos
    FROM ranked_customer_orders
    GROUP BY customer_unique_id
)
SELECT 
    f.cohorte_primer_pedido,
    COUNT(f.customer_unique_id) AS total_clientes,
    SUM(CASE WHEN t.total_pedidos_historicos > 1 THEN 1 ELSE 0 END) AS clientes_recurrentes,
    -- Tasa porcentual de recompra en la plataforma
    ROUND(
        SUM(CASE WHEN t.total_pedidos_historicos > 1 THEN 1.0 ELSE 0.0 END) * 100.0 / COUNT(f.customer_unique_id), 
        2
    ) AS pct_tasa_recompra
FROM first_order_cohort f
INNER JOIN customer_total_orders t 
    ON f.customer_unique_id = t.customer_unique_id
GROUP BY f.cohorte_primer_pedido;