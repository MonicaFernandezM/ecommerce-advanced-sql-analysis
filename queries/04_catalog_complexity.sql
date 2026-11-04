-- Business Case 04: Complejidad del Catálogo y Fricción por Peso
-- Contexto: Evaluación del impacto de las características físicas de los productos
--           (peso en kg y categoría) en los tiempos de tránsito y tasas de retraso,
--           aplicando traducción (LEFT JOIN) y filtro de significancia (>= 150 items).

WITH product_deliveries AS (
    SELECT 
        COALESCE(t.product_category_name_english, 'unknown') AS categoria,
        p.product_weight_g / 1000.0 AS peso_kg,
        DATE_DIFF('day', 
                  TRY_CAST(o.order_purchase_timestamp AS TIMESTAMP), 
                  TRY_CAST(o.order_delivered_customer_date AS TIMESTAMP)
        ) AS delivery_days,
        -- Indicador de entrega fuera del plazo prometido
        CASE 
            WHEN TRY_CAST(o.order_delivered_customer_date AS TIMESTAMP) > TRY_CAST(o.order_estimated_delivery_date AS TIMESTAMP) 
            THEN 1.0 
            ELSE 0.0 
        END AS is_delayed
    FROM raw_orders o
    INNER JOIN raw_order_items oi 
        ON o.order_id = oi.order_id
    INNER JOIN raw_products p 
        ON oi.product_id = p.product_id
    LEFT JOIN raw_category_translation t 
        ON p.product_category_name = t.product_category_name
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)
SELECT 
    categoria,
    COUNT(*) AS total_items_vendidos,
    ROUND(AVG(peso_kg), 2) AS avg_peso_kg,
    ROUND(AVG(delivery_days), 1) AS avg_dias_entrega,
    ROUND(AVG(is_delayed) * 100.0, 2) AS pct_retraso,
    -- Ranking analítico por tasa de retraso con desempate por volumen de venta
    DENSE_RANK() OVER (ORDER BY AVG(is_delayed) DESC, COUNT(*) DESC) AS ranking_retraso
FROM product_deliveries
WHERE categoria != 'unknown'
GROUP BY categoria
HAVING COUNT(*) >= 150
ORDER BY ranking_retraso ASC
LIMIT 10;