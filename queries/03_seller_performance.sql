-- Business Case 03: Responsabilidad Operativa (Vendedor vs. Transportista)
-- Contexto: Descomposición de tiempos en la cadena de fulfillment (días de 
--           preparación del seller vs. tránsito en transportista) y ranking de
--           vendedores críticos mediante DENSE_RANK() con umbral >= 30 pedidos.

WITH seller_metrics AS (
    SELECT 
        oi.seller_id,
        s.seller_state,
        COUNT(DISTINCT o.order_id) AS total_pedidos,
        -- Tramo 1: Días de preparación interna en almacén del vendedor
        ROUND(AVG(DATE_DIFF('day', 
            TRY_CAST(o.order_approved_at AS TIMESTAMP), 
            TRY_CAST(o.order_delivered_carrier_date AS TIMESTAMP)
        )), 1) AS avg_dias_despacho,
        -- Tramo 2: Días de tránsito en manos del transportista hasta entrega
        ROUND(AVG(DATE_DIFF('day', 
            TRY_CAST(o.order_delivered_carrier_date AS TIMESTAMP), 
            TRY_CAST(o.order_delivered_customer_date AS TIMESTAMP)
        )), 1) AS avg_dias_transito,
        -- Tasa de pedidos entregados fuera de la fecha estimada
        ROUND(AVG(CASE 
            WHEN TRY_CAST(o.order_delivered_customer_date AS TIMESTAMP) > TRY_CAST(o.order_estimated_delivery_date AS TIMESTAMP) 
            THEN 1.0 ELSE 0.0 
        END) * 100, 2) AS pct_retraso
    FROM raw_orders o
    INNER JOIN raw_order_items oi 
        ON o.order_id = oi.order_id
    INNER JOIN raw_sellers s 
        ON oi.seller_id = s.seller_id
    WHERE o.order_status = 'delivered'
      AND o.order_approved_at IS NOT NULL
      AND o.order_delivered_carrier_date IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
    GROUP BY oi.seller_id, s.seller_state
    HAVING COUNT(DISTINCT o.order_id) >= 30
)
SELECT 
    seller_id,
    seller_state,
    total_pedidos,
    avg_dias_despacho,
    avg_dias_transito,
    pct_retraso,
    -- Ranking analítico de vendedores con mayor incidencia en retrasos
    DENSE_RANK() OVER (ORDER BY pct_retraso DESC, total_pedidos DESC) AS ranking_retraso
FROM seller_metrics
ORDER BY ranking_retraso ASC
LIMIT 10;