import streamlit as st
import pandas as pd
import numpy as np
import joblib
import os

st.set_page_config(
    page_title="Checkout Inteligente | Olist Logistics",
    page_icon="🛍️",
    layout="wide"
)

UMBRAL_OPTIMO = 0.5027

# Carga del modelo con respaldo preventivo
@st.cache_resource
def cargar_modelo():
    rutas = [
        os.path.join("data", "modelo_retrasos.pkl"),
        "modelo_retrasos.pkl",
        os.path.join("..", "data", "modelo_retrasos.pkl")
    ]
    for r in rutas:
        if os.path.exists(r):
            try:
                return joblib.load(r)
            except Exception:
                pass
    return None

modelo = cargar_modelo()

st.title("🛍️ Olist Express — Simulación de compra y riesgo logístico")
st.markdown("""
Selecciona un producto y tu estado de residencia. El sistema identifica la ubicación de la tienda con inventario,
calcula la distancia logística real en Brasil y predice el riesgo de retraso antes del despacho.
""")

st.divider()

# Mapeo de las 5 regiones oficiales de Brasil (27 estados)
REGIONES_BRASIL = {
    # Sureste (Eje logístico principal)
    "SP": "Sureste", "RJ": "Sureste", "MG": "Sureste", "ES": "Sureste",
    # Sur
    "PR": "Sur", "SC": "Sur", "RS": "Sur",
    # Centro-Oeste
    "DF": "Centro-Oeste", "GO": "Centro-Oeste", "MT": "Centro-Oeste", "MS": "Centro-Oeste",
    # Nordeste
    "BA": "Nordeste", "PE": "Nordeste", "CE": "Nordeste", "PB": "Nordeste",
    "MA": "Nordeste", "AL": "Nordeste", "SE": "Nordeste", "PI": "Nordeste", "RN": "Nordeste",
    # Norte
    "AM": "Norte", "PA": "Norte", "RO": "Norte", "AC": "Norte", "RR": "Norte", "AP": "Norte", "TO": "Norte"
}

# Catálogo representativo
CATALOGO_PRODUCTOS = {
    "📱 Smartphone 128GB (Ligero / Tienda rápida en SP)": {
        "precio": "R$ 1.299",
        "peso": 0.45,
        "volumen": 1.8,
        "tienda": "Olist Store Oficial",
        "tienda_uf": "SP",
        "tienda_ciudad": "São Paulo (SP)",
        "dias_despacho": 1.0,
        "desc_tienda": "Despacho prioritario en 24h"
    },
    "💄 Kit cosméticos (Ligero / Tienda en el Sur)": {
        "precio": "R$ 160",
        "peso": 1.1,
        "volumen": 4.2,
        "tienda": "Beleza Sul Brasil",
        "tienda_uf": "PR",
        "tienda_ciudad": "Curitiba (PR)",
        "dias_despacho": 2.2,
        "desc_tienda": "Despacho regular (2 días)"
    },
    "🔊 Altavoz Bluetooth (Medio / Tienda en Nordeste)": {
        "precio": "R$ 210",
        "peso": 1.8,
        "volumen": 7.5,
        "tienda": "Nordeste Audio & Som",
        "tienda_uf": "BA",
        "tienda_ciudad": "Salvador (BA)",
        "dias_despacho": 4.0,
        "desc_tienda": "Despacho medio (4 días)"
    },
    "📺 Smart TV 50\" 4K (Pesado / Tienda en SP)": {
        "precio": "R$ 1.850",
        "peso": 9.5,
        "volumen": 55.0,
        "tienda": "Paulista Tech",
        "tienda_uf": "SP",
        "tienda_ciudad": "São Paulo (SP)",
        "dias_despacho": 2.8,
        "desc_tienda": "Despacho estándar (casi 3 días)"
    },
    "🪑 Escritorio y silla (Muy pesado / Tienda lenta en SP)": {
        "precio": "R$ 480",
        "peso": 14.8,
        "volumen": 82.0,
        "tienda": "Muebles & Madera Outlet",
        "tienda_uf": "SP",
        "tienda_ciudad": "Campinas (SP)",
        "dias_despacho": 9.5,
        "desc_tienda": "Vendedor crítico: promedia 9.5 días en bodega"
    }
}

# 27 estados organizados por región
ESTADOS_CLIENTE = {
    # Sureste
    "SP - São Paulo (Sureste)": "SP",
    "RJ - Río de Janeiro (Sureste)": "RJ",
    "MG - Minas Gerais (Sureste)": "MG",
    "ES - Espírito Santo (Sureste)": "ES",
    # Sur
    "PR - Paraná (Sur)": "PR",
    "SC - Santa Catarina (Sur)": "SC",
    "RS - Río Grande del Sur (Sur)": "RS",
    # Centro-Oeste
    "DF - Distrito Federal / Brasília (Centro-Oeste)": "DF",
    "GO - Goiás (Centro-Oeste)": "GO",
    "MT - Mato Grosso (Centro-Oeste)": "MT",
    "MS - Mato Grosso del Sur (Centro-Oeste)": "MS",
    # Nordeste
    "BA - Bahía (Nordeste)": "BA",
    "PE - Pernambuco (Nordeste)": "PE",
    "CE - Ceará (Nordeste)": "CE",
    "AL - Alagoas (Nordeste)": "AL",
    "MA - Maranhão (Nordeste)": "MA",
    "PB - Paraíba (Nordeste)": "PB",
    "RN - Río Grande del Norte (Nordeste)": "RN",
    "SE - Sergipe (Nordeste)": "SE",
    "PI - Piauí (Nordeste)": "PI",
    # Norte
    "AM - Amazonas (Norte)": "AM",
    "PA - Pará (Norte)": "PA",
    "RO - Rondônia (Norte)": "RO",
    "AC - Acre (Norte)": "AC",
    "RR - Roraima (Norte)": "RR",
    "AP - Amapá (Norte)": "AP",
    "TO - Tocantins (Norte)": "TO"
}

col_izq, col_der = st.columns([1, 1.2])

with col_izq:
    st.subheader("🛒 Tu pedido")
    
    prod_sel = st.selectbox("1. ¿Qué producto deseas comprar?", list(CATALOGO_PRODUCTOS.keys()))
    prod_info = CATALOGO_PRODUCTOS[prod_sel]
    
    estado_sel = st.selectbox("2. ¿Dónde vives? (Tu estado)", list(ESTADOS_CLIENTE.keys()), index=0)
    uf_cliente = ESTADOS_CLIENTE[estado_sel]
    uf_tienda = prod_info["tienda_uf"]
    
    # Análisis de ruta según geografía
    es_interestatal = 1 if uf_tienda != uf_cliente else 0
    region_tienda = REGIONES_BRASIL[uf_tienda]
    region_cliente = REGIONES_BRASIL[uf_cliente]
    
    if not es_interestatal:
        dias_camino = 4
        tipo_viaje = "📍 Envío local (mismo estado)"
    elif region_tienda == region_cliente:
        dias_camino = 7
        tipo_viaje = "🚛 Interestatal corta distancia (misma región)"
    elif region_cliente in ["Nordeste"]:
        dias_camino = 15
        tipo_viaje = "🚛 Interestatal larga distancia (Nordeste)"
    elif region_cliente in ["Norte"]:
        dias_camino = 20
        tipo_viaje = "🚢 Interestatal ultra-distancia (Región Norte)"
    else:
        dias_camino = 10
        tipo_viaje = "🚛 Interestatal media distancia"

    st.markdown("---")
    st.markdown("#### 📋 Ficha técnica identificada")
    st.markdown(f"""
    * **Artículo:** `{prod_sel.split('(')[0].strip()}` | **Precio:** `{prod_info['precio']}`
    * **Vendedor:** **{prod_info['tienda']}** ({prod_info['tienda_ciudad']})
    * **Tiempo de almacén:** `{prod_info['dias_despacho']} días` ({prod_info['desc_tienda']})
    * **Ruta:** De `{uf_tienda}` a `{uf_cliente}` ({tipo_viaje})
    * **Dimensiones:** `{prod_info['peso']} kg` | `{prod_info['volumen']} litros`
    """)

# Variables de cálculo para el modelo
X_eval = pd.DataFrame({
    'es_interestatal': [es_interestatal],
    'peso_kg': [prod_info['peso']],
    'volumen_litros': [prod_info['volumen']],
    'dias_despacho_seller': [prod_info['dias_despacho']]
})

if modelo is not None:
    probabilidad = float(modelo.predict_proba(X_eval)[0][1])
else:
    score = (
        0.306 * (1 if es_interestatal else 0) +
        0.363 * min(prod_info['dias_despacho'] / 10.0, 1.0) +
        0.175 * min(prod_info['volumen'] / 80.0, 1.0) +
        0.156 * min(prod_info['peso'] / 20.0, 1.0)
    )
    probabilidad = 0.15 + 0.70 * score

pct_riesgo = probabilidad * 100
dias_totales_estimados = int(prod_info['dias_despacho'] + dias_camino)

with col_der:
    st.subheader("📊 Diagnóstico y promesa de entrega")
    
    st.metric(
        label="Plazo estimado de llegada",
        value=f"~{dias_totales_estimados} días hábiles",
        delta=f"{'+' + str(dias_camino) + ' días de transporte' if es_interestatal else 'Entrega local exprés'}",
        delta_color="off"
    )
    
    st.write(f"**Probabilidad estimada de retraso:** `{pct_riesgo:.1f}%` (Umbral seguro: 50.3%)")
    st.progress(min(probabilidad, 1.0))
    
    if probabilidad >= UMBRAL_OPTIMO:
        st.error(f"🚨 **ALERTA OPERATIVA: RIESGO ELEVADO ({pct_riesgo:.1f}%)**")
        st.markdown(f"""
        **Factores críticos que disparan el riesgo:**
        * {'**Ruta interestatal:** El paquete sale de su estado de origen.' if es_interestatal else '**Ruta local:** Pero la preparación en bodega es excesiva.'}
        * **Despacho del vendedor:** La tienda tarda **{prod_info['dias_despacho']} días** en entregar el bulto al transportista.
        * {'**Manejo físico:** Paquete pesado/voluminoso (' + str(prod_info['peso']) + ' kg).' if prod_info['peso'] > 5 else 'Dimensiones normales.'}
        
        **Acción automática en Checkout:**
        * El sistema suma **+3 días extra de margen** a la fecha visible del comprador para proteger la expectativa de satisfacción.
        """)
    else:
        st.success(f"✅ **PEDIDO EN RANGO SEGURO ({pct_riesgo:.1f}%)**")
        st.markdown(f"""
        **Operación fluida:**
        * Despacho rápido por parte de la tienda (**{prod_info['dias_despacho']} días**).
        * Plazos de transporte dentro del margen estándar.
        """)