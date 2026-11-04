# Olist Logistics & Customer Retention Analysis

[![Python](https://img.shields.io/badge/Python-3.10%2B-blue.svg)](https://www.python.org/)
[![DuckDB](https://img.shields.io/badge/DuckDB-Fast%20SQL-FFF000.svg)](https://duckdb.org/)
[![Matplotlib](https://img.shields.io/badge/Matplotlib-Visuals-11557c.svg)](https://matplotlib.org/)

## Descripción

Este proyecto consiste en el análisis de más de 100.000 pedidos del marketplace brasileño Olist, con el objetivo de identificar cuellos de botella en la cadena logística y cuantificar cómo los fallos de entrega impactan directamente en la satisfacción y la retención del cliente.

A diferencia de un análisis logístico tradicional centrado únicamente en medias operativas, este proyecto se enfoca en **decisiones de negocio y rentabilidad**:
- ¿Dónde y por qué se rompen las promesas de entrega?
- ¿Quién es el responsable real: el vendedor o el transportista?
- ¿Cuánto dinero y clientes recurrentes se destruyen por una mala primera entrega?

---

## Tabla de Contenidos

- [Descripción](#descripción)
- [Dataset](#dataset)
- [Preguntas de Investigación](#preguntas-de-investigación)
- [Análisis Realizado](#análisis-realizado)
- [Resultados y Hallazgos Clave](#resultados-y-hallazgos-clave)
- [Conclusiones y Medidas Operativas](#conclusiones-y-medidas-operativas)
- [Visualizaciones](#visualizaciones)
- [Instalación y Uso](#instalación-y-uso)
- [Contribución](#contribución)
- [Autor](#autor)

---

## Dataset

El proyecto utiliza el dataset público de **Brazilian E-Commerce Real Dataset by Olist** disponible en Kaggle. Los datos se cargaron y modelaron directamente en disco persistente mediante **DuckDB** (`olist.db`).

### Tablas y variables clave utilizadas:
| Tabla | Variables clave | Descripción |
| :--- | :--- | :--- |
| `raw_orders` | `order_id`, `purchase_timestamp`, `delivered_customer_date`, `estimated_delivery_date` | Fechas y estados de pedido |
| `raw_customers` | `customer_id`, `customer_unique_id`, `customer_state` | Identificación única de cliente y geografía |
| `raw_reviews` | `order_id`, `review_score` | Puntuación de satisfacción (1 a 5 estrellas) |
| `raw_sellers` | `seller_id`, `seller_state` | Origen y ubicación física del vendedor |
| `raw_order_items`| `order_id`, `product_id`, `seller_id`, `shipping_limit_date` | Detalle del pedido y plazos de envío |
| `raw_products` | `product_id`, `product_category_name`, `product_weight_g` | Dimensiones físicas y categorías |

---

## Preguntas de Investigación

- ¿Cuánto castiga el cliente un retraso en la valoración final de la plataforma?
- ¿Qué regiones de Brasil sufren las peores demoras y cuál es el peso de las rutas interestatales?
- ¿El origen del retraso está en el transportista o en vendedores que tardan días en despachar?
- ¿Cómo condiciona el peso del paquete a la probabilidad de sufrir demoras?
- ¿Tener una primera experiencia con retraso destruye la probabilidad de que el cliente vuelva a comprar?

---

## Análisis Realizado

El proyecto aborda cinco pilares analíticos ejecutados con SQL analítico de alto rendimiento:

1. **Impacto en Satisfacción:** Análisis comparativo de rating promedio y cálculo del porcentaje de detractores (calificaciones de 1 y 2 estrellas) entre entregas a tiempo y fuera de plazo.
2. **Dependencia Geográfica:** Medición de rutas intrarregionales vs. interestatales y cálculo de tasas de demora por estado de destino (filtrando estados con representatividad $\ge 100$ pedidos).
3. **Responsabilidad Operativa:** Descomposición del ciclo total de entrega en dos fases: tiempo de empaquetado/despacho del vendedor (`approved_at` $\to$ `carrier_date`) y tiempo de tránsito del transporte (`carrier_date` $\to$ `customer_date`). Detección de vendedores reincidentes mediante `DENSE_RANK()`.
4. **Restricciones de Catálogo:** Análisis de sensibilidad por tramos de peso (<1 kg, 1-5 kg, 5-10 kg, >10 kg) y clasificación de categorías críticas con mayor tasa de retraso ($\ge 150$ artículos).
5. **Análisis de Cohortes y Recompra:** Aislamiento cronológico de la primera compra de cada cliente mediante `ROW_NUMBER() OVER(PARTITION BY customer_unique_id ORDER BY purchase_at ASC)` para comparar la retención posterior entre clientes que debutaron puntuales vs. con retraso.

---

## Resultados y Hallazgos Clave

### 1. Satisfacción: El umbral crítico de los 4 días
- **Penalización directa:** Entregar a tiempo mantiene una media de **4,29 estrellas**, mientras que un retraso hunde la nota a **2,57 estrellas** (caída de 1,72 estrellas).
- **Disparo de detractores:** En entregas tardías, las reseñas de 1 y 2 estrellas pasan del **9,23% al 54,03%**.
- **Tolerancia del usuario:** Entre 1 y 3 días de demora la satisfacción media aguanta en 3,29; sin embargo, al 4º día colapsa a 2,10 y el 58,5% califica con la nota mínima.

### 2. Geografía: El 70% de la oferta en São Paulo
- **Concentración extrema:** El **70,77% de los pedidos** parten de vendedores de São Paulo (SP).
- **Sobrecoste temporal:** Cruzar fronteras estatales duplica el plazo medio de entrega de **7,9 a 15,0 días** y eleva la tasa de retrasos al 9,00%. Estados del Norte y Nordeste como Alagoas (AL), Maranhão (MA) y Sergipe (SE) sufren demoras de entre el 15% y el 24%.

### 3. Responsabilidad: Bodega agota el margen antes del transporte
- **Despacho tardío:** El 20% de los envíos retrasados son responsabilidad directa del vendedor. Despachar en menos de 48 horas mantiene los retrasos en un 5,81%; tardar más de 5 días los dispara al **19,67%**.
- **Sellers críticos:** Existen vendedores con volumen que promedian entre 11 y 18 días únicamente para entregar el bulto al transportista.

### 4. Catálogo: El peso como fricción física
- **Efecto peso:** Artículos de más de 10 kg registran **15,3 días de entrega y un 10,61% de retraso**, frente a los artículos de menos de 1 kg (11,9 días y 7,53%).
- **Líneas críticas:** `office_furniture` promedia **11,34 kg y 20,8 días de viaje**, mientras que `audio` lidera la tasa de entregas tardías con un 12,71%.

### 5. Retención: Destrucción del Customer Lifetime Value (LTV)
- **Base de recompra reducida:** El 97,00% de los clientes en Olist compra una única vez.
- **Pérdida por debut tardío:** Los clientes con primera compra puntual tienen una recompra del **3,04%**, frente al **2,51%** de quienes sufrieron un retraso.
- **Impacto:** Una pérdida relativa del **16,1% en clientes recurrentes** inducida únicamente por la primera experiencia logística.

> **Insight clave:** *En un modelo donde el 97% de los usuarios nunca regresa, perder casi 1 de cada 6 clientes recurrentes por un fallo en su debut anula por completo la rentabilidad del coste de adquisición publicitario (CAC).*

---

## Conclusiones y Medidas Operativas

- **Blindaje del primer pedido:** La entrega del primer pedido de un usuario nuevo debe monitorearse como el KPI operativo más crítico de la compañía.
- **SLA y penalización a vendedores:** Imponer un límite de despacho de 48-72 horas. Penalizar posicionamiento o pausar catálogo a los vendedores reincidentes que agotan el plazo en bodega.
- **Ajuste de fechas prometidas:** El algoritmo de estimación en el checkout debe parametrizar peso, volumen y distancia real (interestatal). Prometer plazos estándar a un mueble enviado a 2.000 km genera expectativas imposibles de cumplir.
- **Alerta temprana en el día 3:** La comunicación proactiva y compensación antes del cuarto día de demora es la ventana clave para evitar que el cliente deje una valoración de 1 estrella.

---

## Visualizaciones

### Impacto en la Satisfacción del Cliente
![Satisfacción del Cliente](img/01_satisfaccion.png)

### Top 10 Estados Críticos con Mayor % de Retraso
![Geografía y Retraso](img/02_geografia.png)

### Vendedores Reincidentes y Días de Despacho
![Vendedores Críticos](img/03_vendedores.png)

### Categorías Críticas y Peso Promedio
![Catálogo y Peso](img/04_catalogo.png)

### Impacto del Primer Pedido en la Retención (Cohortes)
![Retención de Clientes](img/05_retencion.png)

---

## Instalación y Uso

### 1. Clonar el repositorio
```bash
git clone https://github.com/TU_USUARIO/olist_logistics_retention.git
cd olist_logistics_retention
```

### 2. Crear y activar el entorno virtual
```bash
python -m venv .venv
source .venv/bin/activate  # En Windows: .venv\Scripts\activate
```

### 3. Instalar dependencias
```bash
pip install -r requirements.txt
```

### 4. Ejecutar el Notebook
```bash
jupyter lab notebooks/01_ecommerce_analytics_duckdb.ipynb
```

---

## Contribución

Las contribuciones son bienvenidas. Si deseas proponer nuevas métricas o mejoras al análisis:
1. Haz un fork del repositorio.
2. Crea una rama para tu feature (`git checkout -b feature/nuevo-analisis`).
3. Realiza tus cambios y haz commit (`git commit -m 'Añadir análisis adicional'`).
4. Abre un Pull Request.

---

## Autor

**Mónica Fernández**

- **LinkedIn:** [Tu Perfil](https://www.linkedin.com/in/monicamfm)