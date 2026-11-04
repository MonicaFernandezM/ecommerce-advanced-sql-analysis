-- Business Case 01: El Coste del Retraso Logístico en la Satisfacción del Cliente (NPS)
-- Contexto: Evaluación del impacto de los plazos de entrega sobre el review_score
--           y la generación de clientes detractores en Olist Marketplace.

WITH clean_orders AS (
    SELECT 
        o.order_id,
        TRY_CAST(o.order_delivered_customer_date AS TIMESTAMP) AS delivered_at,
        TRY_CAST(o.order_estimated_delivery_date AS TIMESTAMP) AS estimated_at,
        r.review_score,
        -- Clasificación del pedido según cumplimiento del plazo prometido
        CASE 
            WHEN TRY_CAST(o.order_delivered_customer_date AS TIMESTAMP) > TRY_CAST(o.order_estimated_delivery_date AS TIMESTAMP) 
            THEN 'Con Retraso'
            ELSE 'A Tiempo'
            
        END AS delivery_status
    FROM raw_orders o
    INNER JOIN raw_reviews r 
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
      AND r.review_score IS NOT NULL
)
SELECT 
    delivery_status,
    COUNT(*) AS total_pedidos,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_pedidos,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    -- Tasa de clientes detractores (reseñas con puntuación 1 o 2)
    ROUND(AVG(CASE WHEN review_score <= 2 THEN 1.0 ELSE 0.0 END) * 100, 2) AS pct_detractores
FROM clean_orders
GROUP BY delivery_status
ORDER BY avg_review_score DESC;