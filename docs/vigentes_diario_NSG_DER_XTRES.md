# Documentación Técnica — Proceso "Vigentes Diario"

> **Área**: Derivados Tesorería  
> **Product Owner**: Felipe Pino  
> **Proceso Vader**: `NSG_DER_XTRES`  
> **Tabla destino**: `nsgexp.nsg_derivados_vig_diaria`  
> **Campo clave**: `real_interna_ficticia`  
> **Frecuencia de ejecución**: Diaria

---

## 1. Resumen ejecutivo

El proceso **Vigentes Diario** es un proceso batch de ejecución diaria que consolida las posiciones vigentes (activas) de instrumentos derivados gestionados por el área de Tesorería. Su objetivo es alimentar la tabla `nsgexp.nsg_derivados_vig_diaria` con un snapshot diario de todas las operaciones de derivados vigentes, clasificadas según su naturaleza (`real_interna_ficticia`).

Este proceso es crítico para el reporte regulatorio, la gestión de riesgo y la conciliación operativa del portafolio de derivados del banco.

---

## 2. Arquitectura del proceso Vader

### 2.1 ¿Qué es un proceso Vader?

Un proceso Vader es un pipeline de datos secuencial orquestado por un archivo JSON. Cada entrada en el JSON invoca un archivo `.sql` que ejecuta una consulta y almacena el resultado en una tabla temporal con el mismo nombre del archivo SQL. Las consultas posteriores pueden leer las tablas temporales generadas por pasos anteriores.

### 2.2 Estructura general

```
NSG_DER_XTRES/
├── NSG_DER_XTRES.json          ← Orquestador secuencial
├── paso_01_<nombre>.sql         ← Query 1 → tabla temporal paso_01_<nombre>
├── paso_02_<nombre>.sql         ← Query 2 → tabla temporal paso_02_<nombre>
├── ...
└── paso_N_final.sql             ← Query final → tabla destino nsgexp.nsg_derivados_vig_diaria
```

### 2.3 Flujo de ejecución

```
┌─────────────────────────────────────────────────────────────────────┐
│                    WORKFLOW / SCHEDULER                              │
│              (dispara ejecución diaria del proceso)                  │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  NSG_DER_XTRES.json                                  │
│          (orquestador Vader — lectura secuencial)                    │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
            ┌──────────────┼──────────────┐
            ▼              ▼              ▼
     ┌────────────┐ ┌────────────┐ ┌────────────────┐
     │  SQL paso 1 │ │  SQL paso 2 │ │  ...           │
     │  (extrae    │ │  (transforma│ │                │
     │   fuentes)  │ │   y filtra) │ │                │
     └──────┬─────┘ └──────┬─────┘ └───────┬────────┘
            │              │               │
            ▼              ▼               ▼
     ┌────────────┐ ┌────────────┐ ┌────────────────┐
     │ Tabla temp  │ │ Tabla temp  │ │ Tabla temp     │
     │ paso_1      │ │ paso_2      │ │ ...            │
     └─────────────┘ └─────────────┘ └────────────────┘
                                           │
                                           ▼
                           ┌───────────────────────────────┐
                           │  SQL paso N (FINAL)            │
                           │  Consolida todos los pasos     │
                           │  anteriores en la tabla destino│
                           └──────────────┬────────────────┘
                                          │
                                          ▼
                           ┌───────────────────────────────┐
                           │  nsgexp.nsg_derivados_vig_diaria │
                           │  (tabla final persistente)     │
                           └───────────────────────────────┘
```

**Principios clave:**
1. Cada paso SQL se ejecuta en **orden secuencial** definido en el JSON.
2. El resultado de cada paso se almacena en una **tabla temporal** nombrada igual que el archivo `.sql`.
3. Las consultas posteriores pueden **leer tablas temporales** generadas por pasos anteriores.
4. El **último paso** del JSON produce el resultado final que se escribe en la tabla destino `nsgexp.nsg_derivados_vig_diaria`.

---

## 3. Tabla destino: `nsgexp.nsg_derivados_vig_diaria`

### 3.1 Esquema y convenciones de nombres

| Componente | Valor | Descripción |
|---|---|---|
| **Schema** | `nsgexp` | Esquema de exportación/exposición de datos NSG |
| **Tabla** | `nsg_derivados_vig_diaria` | Derivados vigentes con granularidad diaria |
| **Prefijo** | `nsg_` | Namespace del sistema NSG (Norma Santander Global) |

### 3.2 Campo clave: `real_interna_ficticia`

El campo `real_interna_ficticia` es el **campo clave de clasificación** de cada operación de derivados. Categoriza las operaciones según su naturaleza:

| Valor | Significado | Descripción |
|---|---|---|
| `REAL` | Operación real | Operación de derivados ejecutada con una contraparte externa en el mercado. Representa una posición real del banco. |
| `INTERNA` | Operación interna | Operación entre mesas o unidades del mismo banco (back-to-back, transferencias internas de riesgo). No genera exposición neta al mercado. |
| `FICTICIA` | Operación ficticia/sintética | Operación sintética creada para fines contables, regulatorios o de cobertura interna. No corresponde a una transacción de mercado real. |

**Importancia:**
- Este campo es fundamental para la **segregación de reportes regulatorios** (las operaciones internas y ficticias se tratan distinto que las reales).
- Afecta el cálculo de **exposición al riesgo de contraparte** (solo las reales generan exposición).
- Es clave para la **conciliación** entre front-office y back-office.

### 3.3 Campos esperados de la tabla

A continuación se listan los campos típicos esperados para una tabla de derivados vigentes diarios. Los campos exactos deben verificarse contra el último paso SQL del proceso Vader o contra el DDL de la tabla en base de datos.

| # | Campo (estimado) | Tipo | Descripción |
|---|---|---|---|
| 1 | `fecha_proceso` | `DATE` | Fecha de ejecución del proceso (fecha del snapshot diario) |
| 2 | `real_interna_ficticia` | `VARCHAR` | Clasificación de la operación: REAL, INTERNA o FICTICIA **(campo clave)** |
| 3 | `numero_operacion` | `VARCHAR / NUMBER` | Identificador único de la operación de derivado |
| 4 | `tipo_derivado` | `VARCHAR` | Tipo de instrumento derivado (Forward, Swap, Opción, Futuro, etc.) |
| 5 | `tipo_producto` | `VARCHAR` | Subtipo de producto dentro de la categoría de derivados |
| 6 | `contraparte` | `VARCHAR` | Identificador o nombre de la contraparte |
| 7 | `rut_contraparte` | `VARCHAR` | RUT de la contraparte (si aplica) |
| 8 | `moneda_base` | `VARCHAR` | Moneda del nocional principal (USD, CLP, UF, EUR, etc.) |
| 9 | `moneda_secundaria` | `VARCHAR` | Moneda secundaria (para swaps de moneda, forwards) |
| 10 | `monto_nocional` | `DECIMAL` | Monto nocional de la operación |
| 11 | `fecha_inicio` | `DATE` | Fecha de inicio/contratación de la operación |
| 12 | `fecha_vencimiento` | `DATE` | Fecha de vencimiento del contrato |
| 13 | `tasa_fija` | `DECIMAL` | Tasa fija pactada (si aplica) |
| 14 | `tasa_variable` | `VARCHAR` | Referencia de tasa variable (TAB, SOFR, etc.) |
| 15 | `valor_mercado` | `DECIMAL` | Mark-to-Market (MtM) de la operación a la fecha del proceso |
| 16 | `mesa` | `VARCHAR` | Mesa de trading responsable |
| 17 | `trader` | `VARCHAR` | Identificador del trader |
| 18 | `estado` | `VARCHAR` | Estado de la operación (vigente, vencida, cancelada, etc.) |
| 19 | `sistema_origen` | `VARCHAR` | Sistema fuente (GBO, Murex, etc.) |
| 20 | `fecha_carga` | `TIMESTAMP` | Timestamp de la carga en la tabla |

> ⚠️ **Nota**: El esquema anterior es una **estimación basada en el dominio** de derivados financieros y las convenciones de nomenclatura del sistema NSG. Los campos exactos, tipos de dato y sus restricciones deben validarse contra:
> - El **último archivo `.sql`** del proceso Vader `NSG_DER_XTRES` (que define los campos finales).
> - El **DDL de la tabla** `nsgexp.nsg_derivados_vig_diaria` en la base de datos.

---

## 4. Fuentes de datos (dependencias upstream)

El proceso Vader `NSG_DER_XTRES` típicamente consume datos de las siguientes fuentes:

| Fuente | Descripción | Tipo |
|---|---|---|
| **GBO** (Global Banking Operations) | Sistema de registro de operaciones de derivados del front-office | Sistema fuente primario |
| **Murex** | Plataforma de trading y gestión de riesgo para derivados | Sistema fuente primario |
| **Tablas intermedias NSG** | Tablas del esquema `nsgexp` o similares que consolidan datos de múltiples fuentes | Tablas intermedias |
| **Tablas de referencia** | Catálogos de contrapartes, monedas, productos, mesas de trading | Datos maestros |
| **Proceso anterior del día** | Posibles dependencias con otros procesos Vader que deben ejecutarse antes | Dependencia secuencial |

### 4.1 Dependencias de ejecución

```
 ┌──────────────┐     ┌──────────────┐     ┌──────────────────────┐
 │  Fuentes      │     │  Procesos     │     │  NSG_DER_XTRES       │
 │  (GBO, Murex) │────▶│  previos      │────▶│  (Vigentes Diario)   │
 │               │     │  (si existen) │     │                      │
 └──────────────┘     └──────────────┘     └──────────┬───────────┘
                                                       │
                                                       ▼
                                            ┌──────────────────────┐
                                            │  nsgexp.              │
                                            │  nsg_derivados_       │
                                            │  vig_diaria           │
                                            └──────────┬───────────┘
                                                       │
                                          ┌────────────┼────────────┐
                                          ▼            ▼            ▼
                                   ┌───────────┐ ┌──────────┐ ┌──────────┐
                                   │ Reportes   │ │ Riesgo   │ │ Regulat. │
                                   │ internos   │ │ mercado  │ │ (CMF,    │
                                   │            │ │          │ │  SBIF)   │
                                   └───────────┘ └──────────┘ └──────────┘
```

---

## 5. Consumidores (dependencias downstream)

La tabla `nsgexp.nsg_derivados_vig_diaria` es consumida por:

| Consumidor | Uso | Frecuencia |
|---|---|---|
| **Reportes regulatorios** | Reporte de posiciones de derivados a la CMF/SBIF | Diaria / Mensual |
| **Gestión de riesgo** | Cálculo de exposición al riesgo de contraparte y mercado | Diaria |
| **Conciliación operativa** | Verificación de consistencia entre front-office y back-office | Diaria |
| **Reportes gerenciales** | Dashboards de posiciones vigentes para la gerencia de Tesorería | Bajo demanda |
| **Otros procesos Vader** | Procesos downstream que leen esta tabla como insumo | Variable |

---

## 6. Reglas de negocio clave

1. **Clasificación obligatoria**: Toda operación debe tener un valor válido en `real_interna_ficticia`. No se admiten valores nulos.
2. **Snapshot diario**: Cada ejecución genera un corte completo de las posiciones vigentes a la fecha del proceso. No es incremental.
3. **Vigencia**: Solo se incluyen operaciones cuya `fecha_vencimiento` sea mayor o igual a la `fecha_proceso` (operaciones que aún no han vencido).
4. **Unicidad**: La combinación de `fecha_proceso` + `numero_operacion` + `real_interna_ficticia` debe ser única.
5. **Consistencia de montos**: El `monto_nocional` y `valor_mercado` deben expresarse en la moneda indicada en los campos correspondientes.

---

## 7. Consideraciones operativas

### 7.1 Ejecución

| Aspecto | Detalle |
|---|---|
| **Frecuencia** | Diaria (días hábiles bancarios) |
| **Ventana de ejecución** | Batch nocturno / madrugada (posterior al cierre de mercado) |
| **Tiempo estimado** | Depende del volumen de datos; verificar en logs del scheduler |
| **Reintentos** | Configurados a nivel del workflow que invoca el proceso Vader |

### 7.2 Monitoreo y alertas

- Verificar que el número de registros sea consistente con días anteriores (variaciones bruscas pueden indicar problemas en fuentes).
- Validar que no existan registros con `real_interna_ficticia` nulo o con valores fuera del catálogo esperado.
- Monitorear el timestamp de finalización del proceso para detectar degradaciones de performance.

### 7.3 Estrategia de carga

| Estrategia | Descripción |
|---|---|
| **Tipo** | Probablemente `INSERT OVERWRITE` o `TRUNCATE + INSERT` para la partición del día |
| **Particionamiento** | Posiblemente particionada por `fecha_proceso` |
| **Retención** | Según política de datos del banco (verificar con el PO) |

---

## 8. Glosario

| Término | Definición |
|---|---|
| **Vader** | Framework de orquestación de procesos SQL secuenciales mediante archivos JSON |
| **NSG** | Norma Santander Global — estándar de nomenclatura y procesos del banco |
| **Derivado** | Instrumento financiero cuyo valor depende del precio de un activo subyacente (moneda, tasa, commodity, etc.) |
| **Nocional** | Monto de referencia sobre el cual se calculan los flujos de un derivado |
| **MtM** | Mark-to-Market — valorización a precio de mercado de una posición abierta |
| **GBO** | Global Banking Operations — sistema de registro de operaciones |
| **Murex** | Plataforma de gestión de trading y riesgo para derivados |
| **CMF** | Comisión para el Mercado Financiero — regulador del mercado financiero chileno |
| **Back-to-back** | Operación interna que replica una operación de mercado entre dos unidades del banco |

---

## 9. Contactos y responsabilidades

| Rol | Persona | Descripción |
|---|---|---|
| **Product Owner** | Felipe Pino | Responsable funcional del proceso. Define reglas de negocio y priorización. |
| **Ingeniería de datos** | Equipo NSG / Derivados Tesorería | Mantenimiento del proceso Vader y los archivos SQL. |
| **Soporte operativo** | Equipo de operaciones | Monitoreo de ejecución diaria y resolución de incidentes. |

---

## 10. Apéndice — Checklist de verificación para ingenieros

Al trabajar con este proceso, verificar:

- [ ] Acceso al archivo `NSG_DER_XTRES.json` para confirmar el orden de ejecución de los pasos SQL.
- [ ] Revisar cada archivo `.sql` del proceso para entender las transformaciones aplicadas.
- [ ] Validar el DDL de `nsgexp.nsg_derivados_vig_diaria` contra los campos documentados.
- [ ] Confirmar las fuentes de datos reales (GBO, Murex, u otras) revisando los primeros pasos SQL.
- [ ] Verificar la estrategia de carga (INSERT OVERWRITE, MERGE, etc.) en el último paso SQL.
- [ ] Revisar los logs del scheduler para confirmar ventana de ejecución y tiempos.
- [ ] Validar dependencias upstream y downstream con el equipo del PO.

---

*Documento generado como referencia técnica para ingenieros de software. Los campos de tabla y fuentes de datos son estimaciones basadas en el dominio y deben validarse contra el código fuente del proceso Vader `NSG_DER_XTRES`.*
