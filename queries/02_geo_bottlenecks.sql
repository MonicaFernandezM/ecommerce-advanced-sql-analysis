-- Business Case 02: Cuellos de Botella Geográficos y Riesgo Interestatal
-- Contexto: Diagnóstico de tiempos de tránsito y tasa de retraso por estado de destino,
--           evaluando el impacto del flujo origen-destino (SP hacia el resto de Brasil)
--           con filtro de representatividad estadística (HAVING >= 100 pedidos).

WITH geo_orders AS (
    SELECT 
        o.order_id,
        UPPER(TRIM(c.customer_state)) AS estado_cliente,
        UPPER(TRIM(s.seller_state)) AS estado_vendedor,
        DATE_DIFF('day', 
                  TRY_CAST(o.order_purchase_timestamp AS TIMESTAMP), 
                  TRY_CAST(o.order_delivered_customer_date AS TIMESTAMP)
        ) AS dias_entrega,
        -- Indicador de entrega posterior a la fecha comprometida
        CASE 
            WHEN TRY_CAST(o.order_delivered_customer_date AS TIMESTAMP) > TRY_CAST(o.order_estimated_delivery_date AS TIMESTAMP) 
            THEN 1 
            ELSE 0 
        END AS es_retraso,
        -- Detección de trayecto interestatal
        CASE 
            WHEN UPPER(TRIM(c.customer_state)) != UPPER(TRIM(s.seller_state)) 
            THEN 1 
            ELSE 0 
        END AS es_interestatal
    FROM raw_orders o
    INNER JOIN raw_customers c 
        ON o.customer_id = c.customer_id
    INNER JOIN raw_order_items oi 
        ON o.order_id = oi.order_id
    INNER JOIN raw_sellers s 
        ON oi.seller_id = s.seller_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)
SELECT 
    estado_cliente AS estado,
    COUNT(DISTINCT order_id) AS total_pedidos,
    ROUND(AVG(dias_entrega), 1) AS dias_promedio_entrega,
    ROUND(AVG(es_retraso) * 100.0, 2) AS tasa_retraso_pct,
    ROUND(AVG(es_interestatal) * 100.0, 2) AS envios_interestatales_pct
FROM geo_orders
GROUP BY estado_cliente
HAVING COUNT(DISTINCT order_id) >= 100
ORDER BY tasa_retraso_pct DESC;