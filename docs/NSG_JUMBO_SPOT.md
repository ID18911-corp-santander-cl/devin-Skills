# Proceso Vader: NSG_JUMBO_SPOT — Jumbo Spot

> **Área:** Derivados — Tesorería  
> **Product Owner:** Felipe Pino  
> **Proceso Vader:** `NSG_JUMBO_SPOT`  
> **Última actualización:** junio 2026

---

## 1. Resumen Ejecutivo

El proceso **NSG_JUMBO_SPOT** es un pipeline de cálculo orquestado por el motor Vader que opera dentro del dominio de **Derivados de Tesorería** de Santander Chile. Su objetivo principal es:

1. **Calcular la caja pasada (Middle Office — MO):** Determinar los flujos de efectivo liquidados (settlement) para operaciones FX Spot de gran volumen ("Jumbo").
2. **Calcular el valor de mercado (Mark-to-Market — MtM):** Valorizar las posiciones vigentes a precio de mercado al cierre del día.

Ambos cálculos se alimentan de datos provenientes de **GBO** (Global Banking Operations) y/o **Murex**, dependiendo del origen de la operación.

---

## 2. Arquitectura del Proceso Vader

### 2.1. Mecanismo General de Vader

Un proceso Vader se compone de:

| Componente | Descripción |
|---|---|
| **Archivo JSON** (orquestador) | Define la secuencia ordenada de archivos `.sql` que se ejecutan. Cada línea referencia un archivo SQL. |
| **Archivos SQL** (pasos) | Cada archivo contiene una query que se ejecuta y almacena su resultado en una **tabla temporal** con el mismo nombre del archivo `.sql`. |
| **Tabla final** | El último archivo `.sql` listado en el JSON produce la tabla de salida definitiva del proceso. |

**Flujo de ejecución:**

```
┌──────────────────────────────────────────────────────────────┐
│                   NSG_JUMBO_SPOT.json                         │
│                                                              │
│  Línea 1 → paso_01_extrae_gbo.sql          → tmp_gbo        │
│  Línea 2 → paso_02_extrae_murex.sql        → tmp_murex      │
│  Línea 3 → paso_03_unifica_operaciones.sql → tmp_ops_unif   │
│  Línea 4 → paso_04_tipo_cambio.sql         → tmp_tc         │
│  Línea 5 → paso_05_caja_pasada_mo.sql      → tmp_caja_mo    │
│  Línea 6 → paso_06_valor_mercado.sql       → tmp_mtm        │
│  Línea 7 → paso_07_salida_final.sql        → NSG_JUMBO_SPOT │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

> **Nota:** Los nombres de los archivos SQL son ilustrativos y reflejan la lógica esperada. Los nombres reales deben verificarse en el archivo `NSG_JUMBO_SPOT.json` del repositorio Vader correspondiente.

### 2.2. Dependencia Secuencial

Cada paso lee tablas temporales producidas por pasos anteriores. El orden del JSON es **estricto**: alterar la secuencia rompe el pipeline.

```
paso_01 ─→ paso_02 ─→ paso_03 (lee tmp_gbo + tmp_murex)
                         │
                         ▼
                      paso_04 ─→ paso_05 (lee tmp_ops_unif + tmp_tc)
                                    │
                                    ▼
                                 paso_06 (lee tmp_caja_mo + tmp_tc)
                                    │
                                    ▼
                                 paso_07 (lee tmp_caja_mo + tmp_mtm) → SALIDA FINAL
```

---

## 3. Fuentes de Datos

### 3.1. GBO (Global Banking Operations)

| Atributo | Detalle |
|---|---|
| **Sistema** | GBO — plataforma de back-office para operaciones de tesorería |
| **Tipo de datos** | Operaciones FX Spot confirmadas y liquidadas |
| **Campos clave esperados** | `id_operacion`, `fecha_contratacion`, `fecha_liquidacion`, `divisa_compra`, `divisa_venta`, `monto_compra`, `monto_venta`, `tipo_cambio_pactado`, `contraparte`, `book`, `trader` |
| **Frecuencia** | Diaria (batch nocturno o intraday) |
| **Esquema origen** | Típicamente tablas en esquema `nsgexp` o vistas sobre staging de GBO |

### 3.2. Murex

| Atributo | Detalle |
|---|---|
| **Sistema** | Murex — sistema de gestión de tesorería, derivados y riesgo de mercado |
| **Tipo de datos** | Operaciones FX Spot, valuaciones MtM, curvas de mercado |
| **Campos clave esperados** | `trade_id`, `trade_date`, `settlement_date`, `currency_pair`, `notional`, `deal_rate`, `counterparty`, `portfolio`, `mtm_value`, `mtm_currency` |
| **Frecuencia** | Diaria (cierre de mercado) |
| **Esquema origen** | Tablas/vistas de extracción Murex en esquema de staging |

### 3.3. Datos de Mercado (Tipo de Cambio)

Para la valorización MtM se requieren **tipos de cambio de cierre** (fixing) proporcionados típicamente por:
- Tablas de mercado internas (curvas FX)
- Feeds del Banco Central de Chile (dólar observado, euro, etc.)

---

## 4. Flujo de Cálculo Detallado

### 4.1. Paso 1 — Extracción GBO

```sql
-- Pseudocódigo: paso_01_extrae_gbo.sql
SELECT
    id_operacion,
    fecha_contratacion,
    fecha_liquidacion,
    divisa_compra,
    divisa_venta,
    monto_compra,
    monto_venta,
    tipo_cambio_pactado,
    contraparte,
    book,
    trader,
    'GBO' AS sistema_origen
FROM esquema_staging.gbo_fx_spot
WHERE fecha_liquidacion BETWEEN :fecha_inicio AND :fecha_fin
  AND tipo_operacion = 'SPOT'
  AND monto_compra >= :umbral_jumbo   -- Filtro de operaciones "Jumbo"
```

**Objetivo:** Extraer operaciones FX Spot de gran volumen desde GBO, filtradas por fecha de liquidación y umbral de monto (criterio "Jumbo").

### 4.2. Paso 2 — Extracción Murex

```sql
-- Pseudocódigo: paso_02_extrae_murex.sql
SELECT
    trade_id        AS id_operacion,
    trade_date      AS fecha_contratacion,
    settlement_date AS fecha_liquidacion,
    buy_currency    AS divisa_compra,
    sell_currency   AS divisa_venta,
    buy_amount      AS monto_compra,
    sell_amount     AS monto_venta,
    deal_rate       AS tipo_cambio_pactado,
    counterparty    AS contraparte,
    portfolio       AS book,
    trader,
    'MUREX' AS sistema_origen
FROM esquema_staging.murex_fx_spot
WHERE settlement_date BETWEEN :fecha_inicio AND :fecha_fin
  AND product_type = 'FX_SPOT'
  AND buy_amount >= :umbral_jumbo
```

**Objetivo:** Extraer las mismas operaciones desde Murex, normalizando los nombres de columnas al esquema unificado.

### 4.3. Paso 3 — Unificación de Operaciones

```sql
-- Pseudocódigo: paso_03_unifica_operaciones.sql
SELECT * FROM tmp_gbo
UNION ALL
SELECT * FROM tmp_murex
-- Con deduplicación si una operación existe en ambos sistemas:
-- Se prioriza Murex como fuente de verdad para MtM
```

**Objetivo:** Consolidar operaciones de ambas fuentes en un dataset unificado, aplicando reglas de deduplicación cuando una misma operación aparece en GBO y Murex.

### 4.4. Paso 4 — Tipo de Cambio de Mercado

```sql
-- Pseudocódigo: paso_04_tipo_cambio.sql
SELECT
    fecha,
    divisa_base,
    divisa_cotizacion,
    tipo_cambio_cierre,
    fuente
FROM esquema_mercado.tipos_cambio_cierre
WHERE fecha = :fecha_proceso
```

**Objetivo:** Obtener los tipos de cambio de cierre necesarios para la valorización MtM.

### 4.5. Paso 5 — Cálculo de Caja Pasada (MO)

```sql
-- Pseudocódigo: paso_05_caja_pasada_mo.sql
SELECT
    o.id_operacion,
    o.fecha_liquidacion,
    o.divisa_compra,
    o.divisa_venta,
    o.monto_compra,
    o.monto_venta,
    o.tipo_cambio_pactado,
    o.contraparte,
    o.book,
    o.sistema_origen,
    -- Caja pasada: flujo efectivo neto en moneda local (CLP)
    CASE
        WHEN o.fecha_liquidacion <= :fecha_proceso THEN
            (o.monto_compra * tc_compra.tipo_cambio_cierre)
            - (o.monto_venta * tc_venta.tipo_cambio_cierre)
        ELSE 0
    END AS caja_pasada_clp,
    CASE
        WHEN o.fecha_liquidacion <= :fecha_proceso THEN 'LIQUIDADA'
        ELSE 'PENDIENTE'
    END AS estado_liquidacion
FROM tmp_ops_unif o
LEFT JOIN tmp_tc tc_compra
    ON tc_compra.divisa_base = o.divisa_compra
LEFT JOIN tmp_tc tc_venta
    ON tc_venta.divisa_base = o.divisa_venta
```

**Objetivo:** Calcular el flujo de caja efectivo (caja pasada) para operaciones ya liquidadas, expresado en moneda local (CLP). Este es el cálculo de **Middle Office (MO)**.

**Lógica de negocio:**
- Solo se calcula caja para operaciones cuya `fecha_liquidacion ≤ fecha_proceso`.
- El monto se convierte a CLP usando el tipo de cambio de cierre correspondiente.
- El resultado neto (compra − venta en CLP) representa el flujo de caja real.

### 4.6. Paso 6 — Cálculo de Valor de Mercado (MtM)

```sql
-- Pseudocódigo: paso_06_valor_mercado.sql
SELECT
    o.id_operacion,
    o.fecha_contratacion,
    o.fecha_liquidacion,
    o.divisa_compra,
    o.divisa_venta,
    o.monto_compra,
    o.monto_venta,
    o.tipo_cambio_pactado,
    o.book,
    o.sistema_origen,
    -- Mark-to-Market: diferencia entre tasa pactada y tasa de mercado
    (o.monto_compra * (tc_mercado.tipo_cambio_cierre - o.tipo_cambio_pactado))
        AS mtm_clp,
    tc_mercado.tipo_cambio_cierre AS tc_mercado_cierre,
    :fecha_proceso AS fecha_valuacion
FROM tmp_ops_unif o
LEFT JOIN tmp_tc tc_mercado
    ON tc_mercado.divisa_base = o.divisa_compra
WHERE o.fecha_liquidacion > :fecha_proceso  -- Solo posiciones vigentes (no liquidadas)
```

**Objetivo:** Valorizar a mercado (Mark-to-Market) las posiciones FX Spot vigentes (aún no liquidadas).

**Lógica de negocio:**
- Se calcula la diferencia entre el tipo de cambio pactado y el tipo de cambio de cierre del mercado.
- El MtM se expresa en CLP y representa la ganancia/pérdida no realizada.
- Solo se valorizan operaciones con `fecha_liquidacion > fecha_proceso` (posiciones abiertas).

### 4.7. Paso 7 — Tabla de Salida Final

```sql
-- Pseudocódigo: paso_07_salida_final.sql
SELECT
    cm.id_operacion,
    cm.fecha_liquidacion,
    cm.divisa_compra,
    cm.divisa_venta,
    cm.monto_compra,
    cm.monto_venta,
    cm.tipo_cambio_pactado,
    cm.contraparte,
    cm.book,
    cm.sistema_origen,
    cm.caja_pasada_clp,
    cm.estado_liquidacion,
    COALESCE(mtm.mtm_clp, 0)           AS valor_mercado_clp,
    COALESCE(mtm.tc_mercado_cierre, 0)  AS tc_mercado_cierre,
    COALESCE(mtm.fecha_valuacion, NULL) AS fecha_valuacion
FROM tmp_caja_mo cm
LEFT JOIN tmp_mtm mtm
    ON cm.id_operacion = mtm.id_operacion
```

**Objetivo:** Consolidar caja pasada y valor de mercado en una tabla final unificada.

---

## 5. Campos de Salida (Tabla Final)

| # | Campo | Tipo | Descripción |
|---|---|---|---|
| 1 | `id_operacion` | `VARCHAR` | Identificador único de la operación FX Spot |
| 2 | `fecha_liquidacion` | `DATE` | Fecha de liquidación (settlement) |
| 3 | `divisa_compra` | `VARCHAR(3)` | Código ISO de la divisa comprada (e.g., `USD`) |
| 4 | `divisa_venta` | `VARCHAR(3)` | Código ISO de la divisa vendida (e.g., `CLP`) |
| 5 | `monto_compra` | `DECIMAL(18,2)` | Monto nominal en divisa de compra |
| 6 | `monto_venta` | `DECIMAL(18,2)` | Monto nominal en divisa de venta |
| 7 | `tipo_cambio_pactado` | `DECIMAL(12,6)` | Tipo de cambio acordado al momento de la operación |
| 8 | `contraparte` | `VARCHAR` | Nombre o código de la contraparte |
| 9 | `book` | `VARCHAR` | Portafolio / book de trading |
| 10 | `sistema_origen` | `VARCHAR` | Sistema fuente: `GBO` o `MUREX` |
| 11 | `caja_pasada_clp` | `DECIMAL(18,2)` | Flujo de caja neto liquidado en CLP (Middle Office) |
| 12 | `estado_liquidacion` | `VARCHAR` | `LIQUIDADA` o `PENDIENTE` |
| 13 | `valor_mercado_clp` | `DECIMAL(18,2)` | Valor Mark-to-Market en CLP (posiciones vigentes) |
| 14 | `tc_mercado_cierre` | `DECIMAL(12,6)` | Tipo de cambio de mercado usado para MtM |
| 15 | `fecha_valuacion` | `DATE` | Fecha a la que se realiza la valorización MtM |

---

## 6. Diagrama de Dependencias de Datos

```
 ┌─────────────┐     ┌──────────────┐
 │  GBO (FX    │     │ Murex (FX    │
 │  Spot Back  │     │  Spot Front/ │
 │  Office)    │     │  Risk)       │
 └──────┬──────┘     └──────┬───────┘
        │                   │
        ▼                   ▼
  ┌───────────┐      ┌────────────┐
  │ tmp_gbo   │      │ tmp_murex  │
  └─────┬─────┘      └─────┬──────┘
        │                   │
        └─────────┬─────────┘
                  ▼
         ┌───────────────┐     ┌─────────────────────┐
         │ tmp_ops_unif  │     │ Mercado: Tipos de    │
         │ (unificado)   │     │ Cambio de Cierre     │
         └───────┬───────┘     └──────────┬───────────┘
                 │                        │
                 │         ┌──────────────┘
                 ▼         ▼
         ┌──────────────────┐
         │ tmp_caja_mo      │ ← Caja Pasada (MO)
         │ (liquidaciones)  │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │ tmp_mtm          │ ← Valor de Mercado (MtM)
         │ (posiciones      │
         │  vigentes)       │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │ NSG_JUMBO_SPOT   │ ← TABLA FINAL
         │ (consolidado)    │
         └──────────────────┘
```

---

## 7. Parámetros de Ejecución

| Parámetro | Tipo | Descripción |
|---|---|---|
| `:fecha_proceso` | `DATE` | Fecha de proceso/valuación (normalmente T o T-1) |
| `:fecha_inicio` | `DATE` | Inicio del rango de extracción |
| `:fecha_fin` | `DATE` | Fin del rango de extracción |
| `:umbral_jumbo` | `DECIMAL` | Monto mínimo para clasificar una operación como "Jumbo" |

---

## 8. Workflow de Ejecución

El proceso se ejecuta a través de un **workflow** que invoca el motor Vader:

```
Workflow (scheduler/orquestador)
    │
    ├── Trigger: Diario (post-cierre de mercado)
    │
    ├── Input: NSG_JUMBO_SPOT.json
    │
    ├── Vader Engine:
    │   ├── Lee NSG_JUMBO_SPOT.json
    │   ├── Ejecuta cada .sql en orden secuencial
    │   ├── Almacena resultados en tablas temporales
    │   └── Genera tabla final NSG_JUMBO_SPOT
    │
    └── Post-proceso:
        ├── Validación de registros (count, nulls, duplicados)
        └── Notificación de éxito/error
```

---

## 9. Consideraciones Técnicas para Ingenieros

### 9.1. Idempotencia
- El proceso debe ser **idempotente**: re-ejecutar con los mismos parámetros debe producir el mismo resultado.
- Las tablas temporales se recrean en cada ejecución (DROP + CREATE o TRUNCATE + INSERT).

### 9.2. Manejo de Errores
- Si un paso SQL falla, Vader **detiene** la ejecución completa del JSON.
- Verificar disponibilidad de las fuentes (GBO, Murex) antes de iniciar.
- Implementar alertas si el conteo de registros de salida es 0 o difiere significativamente del día anterior.

### 9.3. Performance
- Los filtros de fecha y monto deben aprovechar índices existentes en las tablas fuente.
- Para volúmenes grandes, considerar particionamiento por fecha en las tablas temporales.

### 9.4. Deduplicación
- Una operación puede existir en **ambos sistemas** (GBO y Murex). La lógica de unificación debe definir cuál es la fuente de verdad (típicamente Murex para MtM, GBO para settlement).

### 9.5. Moneda de Reporte
- Todos los cálculos finales se expresan en **CLP** (Peso Chileno).
- Los tipos de cambio de cierre deben corresponder a la `fecha_proceso`.

---

## 10. Glosario

| Término | Definición |
|---|---|
| **FX Spot** | Operación de compra/venta de divisas con liquidación T+2 (o T+1, T+0) |
| **Jumbo** | Operación de monto notional elevado que supera un umbral definido |
| **Caja Pasada (MO)** | Flujo de efectivo neto ya liquidado, calculado por Middle Office |
| **MtM (Mark-to-Market)** | Valorización a precio de mercado de posiciones vigentes |
| **GBO** | Global Banking Operations — sistema de back-office de operaciones |
| **Murex** | Plataforma de gestión de tesorería, derivados y riesgo |
| **Vader** | Motor de ejecución de procesos SQL secuenciales vía archivos JSON |
| **CLP** | Peso Chileno — moneda de reporte |
| **Book** | Portafolio de trading donde se registra la operación |
| **Settlement** | Liquidación efectiva de una operación financiera |

---

## 11. Contacto

| Rol | Persona |
|---|---|
| **Product Owner** | Felipe Pino |
| **Área** | Derivados — Tesorería, Santander Chile |
