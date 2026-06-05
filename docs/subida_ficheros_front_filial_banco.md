# Subida de Ficheros por el Front Filial y Banco

> **PO:** Felipe Araya  
> **Ticket:** Pendiente de creación (asignado nominalmente a Rodrigo Castro)  
> **Proceso:** Satélite 22 SHCB — Carga de ficheros CSV vía Front

---

## 1. Resumen Ejecutivo

Al habilitarse la opción de carga vía Front, los ficheros CSV que alimentan el proceso Satélite 22 SHCB se depositan en una ruta específica del volumen de Unity Catalog. Los notebooks de Databricks deben validar que los archivos existen en las rutas esperadas antes de proceder con la ingesta.

### Ficheros involucrados

| Fichero | Descripción | Ruta Front (nueva) | Ruta Motor (actual) |
|---------|-------------|--------------------|--------------------|
| `Base_Filial.csv` | Datos de sociedades filiales (accionistas, montos, % propiedad) | `/Volumes/pro_departure/essenout/salida/front/Base_Filial.csv` | `/Volumes/pro_app/essenneg/motor/CSV_Filiales/Base_Filial_{yyyymmdd}.csv` |
| `DCV.csv` | Registro de accionistas del Depósito Central de Valores | `/Volumes/pro_departure/essenout/salida/front/DCV.csv` | `/Volumes/pro_app/essenneg/motor/CSV_Banco/DCV.csv` |
| `Rutero_SHCB.csv` | Clasificación de accionistas (tipo sociedad, agrupación) | `/Volumes/pro_departure/essenout/salida/front/Rutero_SHCB.csv` | `/Volumes/pro_app/essenneg/motor/CSV_Banco/Rutero_SHCB.csv` |

---

## 2. Arquitectura del Flujo de Carga

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        FRONT FILIAL / BANCO                                  │
│  (Interfaz de carga manual de ficheros)                                      │
└─────────────────────┬───────────────────────────────────────────────────────┘
                      │ Deposita archivos CSV
                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  /Volumes/pro_departure/essenout/salida/front/                               │
│    ├── Base_Filial.csv                                                       │
│    ├── DCV.csv                                                               │
│    └── Rutero_SHCB.csv                                                       │
└─────────────────────┬───────────────────────────────────────────────────────┘
                      │ Notebooks leen y validan
                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  NOTEBOOKS DATABRICKS                                                        │
│                                                                              │
│  ┌─────────────────────────────────────────┐                                 │
│  │ Carga_Satelite_Filiales.py              │                                 │
│  │  • Lee Base_Filial.csv                  │                                 │
│  │  • Valida esquema y registros           │                                 │
│  │  • Escribe tabla de paso                │                                 │
│  │  • INSERT en tabla destino              │                                 │
│  └─────────────────────────────────────────┘                                 │
│                                                                              │
│  ┌─────────────────────────────────────────┐                                 │
│  │ Carga_Banco_SHCB.py                     │                                 │
│  │  • Lee DCV.csv y Rutero_SHCB.csv        │                                 │
│  │  • Detecta separador automáticamente    │                                 │
│  │  • Valida esquema y registros           │                                 │
│  │  • Escribe tablas de paso               │                                 │
│  │  • INSERT cruzado en tablas destino     │                                 │
│  │  • Genera tabla resumen (101 registros) │                                 │
│  │  • Alimenta tablas satélite             │                                 │
│  └─────────────────────────────────────────┘                                 │
└─────────────────────┬───────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  TABLAS DESTINO (Unity Catalog)                                              │
│                                                                              │
│  Filial:                                                                     │
│    └── pro_business.essenexp.master_filiales_interfaz_satelite_22_shcb       │
│                                                                              │
│  Banco:                                                                      │
│    ├── pro_business.essenexp.Banco_Detalle_22_shcb                           │
│    ├── pro_business.essenexp.Banco_Agrupado_22_shcb                          │
│    ├── pro_app.essenneg.master_00051_parametria_automatica_satelite_22_shcb   │
│    ├── pro_app.essenneg.master_00051_satelite_22_shcb                        │
│    └── pro_business.essenexp.master_00051_interfaz_satelite_22_shcb          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Detalle del Flujo por Notebook

### 3.1 Carga Filial (`Carga_Satelite_Filiales.py`)

#### Parámetros de entrada

| Parámetro | Formato | Valor por defecto | Descripción |
|-----------|---------|-------------------|-------------|
| `fecha_proceso` | `yyyymmdd` | Fecha actual del sistema | Fecha de corte del proceso |

#### Pipeline ETL

```
1. Parametrización
   └── fecha_proceso → data_date_part (yyyy-mm-dd)

2. Lectura CSV
   └── Ruta: /Volumes/.../Base_Filial_{fecha_proceso}.csv
   └── Esquema explícito (StructType):
       • Sociedad (STRING)
       • Shareholder_entity_code (STRING)
       • Name_of_the_shareholder_entity (STRING)
       • AMOUNT (DECIMAL(38,0))
       • Number_of_owned_shares (DECIMAL(38,0))
       • Pct_ownership_per_issuance (DECIMAL(10,2))
       • Pct_voting_rights (DECIMAL(10,2))
       • BIxxxxx (STRING)

3. Validaciones
   └── Filtrar filas completamente vacías/nulas
   └── Verificar nulos en columnas clave (Sociedad, Shareholder_entity_code, AMOUNT)
   └── Abortar si 0 registros válidos

4. Tabla de paso (OVERWRITE)
   └── pro_app.essenneg.csv_filial_paso1_22_shcb

5. DELETE + INSERT en tabla destino
   └── DELETE WHERE data_date_part = '{fecha}'
   └── INSERT con mapeo de 15 campos (incluyendo campo concatenado con '|')
   └── Destino: pro_business.essenexp.master_filiales_interfaz_satelite_22_shcb

6. Verificación final
   └── Conteo de registros insertados
```

#### Mapeo de campos (Filial)

| Campo Destino | Campo Origen | Transformación |
|---------------|-------------|----------------|
| `reporting_soc` | Sociedad | Directo |
| `counterparty_soc` | Shareholder_entity_code | Directo |
| `adjustment_code` | BIxxxxx | Directo |
| `id_comb` | — | Literal `'B03;MC23;PR18'` |
| `amount` | AMOUNT | Cast a DOUBLE |
| `shcode` | Shareholder_entity_code | Directo |
| `shname` | Name_of_the_shareholder_entity | Directo |
| `isin` | — | Literal `'000000000000'` |
| `ic` | — | Literal `'152'` |
| `osha` | Number_of_owned_shares | Cast a BIGINT |
| `ownpi` | Pct_ownership_per_issuance | Cast a DOUBLE |
| `votr` | Pct_voting_rights | Cast a DOUBLE |
| Campo concatenado | Todos los anteriores | `concat_ws('\|', coalesce(campo, ''))` |
| `data_date_part` | fecha_proceso | Formato `yyyy-mm-dd` |
| `fecha_de_ejecucion` | — | `current_timestamp()` en TZ America/Santiago |

---

### 3.2 Carga Banco (`Carga_Banco_SHCB.py`)

#### Parámetros de entrada

| Parámetro | Formato | Valor por defecto | Descripción |
|-----------|---------|-------------------|-------------|
| `fecha_proceso` | `yyyymmdd` | Fecha actual del sistema | Fecha de corte del proceso |

#### Pipeline ETL

```
1. Parametrización
   └── fecha_proceso → data_date_part (yyyy-mm-dd)

2. Detección de separador
   └── Función detect_separator(): lee primera línea y compara conteo ',' vs ';'

3. Lectura CSV DCV
   └── Ruta: /Volumes/.../DCV.csv
   └── Separador: auto-detectado (';' típicamente)
   └── Estructura: ;Nemotecnico;Num_Registro;Razon_Social;Rut;DV;Direccion;Comuna;Ciudad;Acciones;Total_Acciones;
   └── Mapeo por posición explícita (columnas extra por ';' inicial/final)
   └── Limpieza de Rut: eliminar puntos ("96.501.440" → "96501440")
   └── Cast Acciones y Total_Acciones a LongType

4. Lectura CSV Rutero
   └── Ruta: /Volumes/.../Rutero_SHCB.csv
   └── Separador: auto-detectado (';' típicamente)
   └── Estructura: Rut_Accionista;Razon_Social;Tipo_sociedad;Clasificacion;
   └── Limpieza de Rut: eliminar puntos y DV ("97.004.000-5" → "97004000")

5. Validaciones
   └── Filtrar filas completamente vacías en ambos DataFrames
   └── Verificar nulos en columnas clave (Rut, Acciones, Total_Acciones para DCV)
   └── Abortar si 0 registros válidos en cualquiera

6. Tablas de paso (OVERWRITE)
   └── pro_app.essenneg.CSV_Banco_DCV_22_shcb
   └── pro_app.essenneg.CSV_Banco_Rutero_22_shcb

7. DELETE + INSERT cruzado → Banco_Detalle_22_shcb
   └── DELETE WHERE data_date_part = '{fecha}'
   └── INSERT: JOIN DCV × Rutero_Intergrupo × CSV_Rutero
   └── ROW_NUMBER() OVER (ORDER BY Acciones DESC) → campo 'orden'
   └── Cálculo: porc_sobre_total = Acciones / MAX(Total_Acciones)

8. DELETE + INSERT → Banco_Agrupado_22_shcb (101 registros)
   └── Top 100 accionistas por orden + registro 101 "OTROS ACCIONISTAS"
   └── Registro 101: porc_sobre_total = 100 - SUM(top_100)

9. INSERT en tablas satélite
   └── pro_app.essenneg.master_00051_parametria_automatica_satelite_22_shcb
   └── pro_app.essenneg.master_00051_satelite_22_shcb
   └── pro_business.essenexp.master_00051_interfaz_satelite_22_shcb

10. Verificación final
    └── Conteo de registros en todas las tablas destino
```

---

## 4. Validaciones Necesarias en Notebooks

Al habilitarse la carga por Front, se requieren las siguientes validaciones adicionales:

### 4.1 Validación de existencia de archivos

```python
# Validar que el archivo existe antes de intentar leerlo
def validate_file_exists(path):
    """Verifica que el archivo CSV existe en el volumen."""
    try:
        files = dbutils.fs.ls(path)
        if not files:
            raise FileNotFoundError(f"Archivo no encontrado: {path}")
        print(f"[OK] Archivo encontrado: {path}")
        return True
    except Exception as e:
        raise FileNotFoundError(
            f"El archivo no existe o no es accesible en la ruta: {path}. "
            f"Verifique que la carga por Front se completó correctamente. Error: {e}"
        )
```

### 4.2 Validación de rutas Front vs Motor

```python
# Rutas Front (nueva fuente de carga)
RUTAS_FRONT = {
    "Base_Filial": "/Volumes/pro_departure/essenout/salida/front/Base_Filial.csv",
    "DCV": "/Volumes/pro_departure/essenout/salida/front/DCV.csv",
    "Rutero_SHCB": "/Volumes/pro_departure/essenout/salida/front/Rutero_SHCB.csv",
}

# Rutas Motor (fuente actual)
RUTAS_MOTOR = {
    "Base_Filial": f"/Volumes/pro_app/essenneg/motor/CSV_Filiales/Base_Filial_{fecha_proceso}.csv",
    "DCV": "/Volumes/pro_app/essenneg/motor/CSV_Banco/DCV.csv",
    "Rutero_SHCB": "/Volumes/pro_app/essenneg/motor/CSV_Banco/Rutero_SHCB.csv",
}

def resolver_ruta(nombre_archivo, fuente="front"):
    """Resuelve la ruta del archivo según la fuente de carga."""
    rutas = RUTAS_FRONT if fuente == "front" else RUTAS_MOTOR
    path = rutas[nombre_archivo]
    validate_file_exists(path)
    return path
```

### 4.3 Validaciones de integridad de datos

| Validación | Archivo | Criterio | Acción si falla |
|-----------|---------|----------|-----------------|
| Archivo no vacío | Todos | `df.count() > 0` | `raise ValueError` |
| Filas completamente vacías | Todos | Todas las columnas `NULL` o `""` | Filtrar y registrar descarte |
| Nulos en columnas clave | Base_Filial | `Sociedad`, `Shareholder_entity_code`, `AMOUNT` | Log warning, no abortar |
| Nulos en columnas clave | DCV | `Rut`, `Acciones`, `Total_Acciones` | Log warning, no abortar |
| Nulos en columnas clave | Rutero | `Rut_Accionista`, `Clasificacion` | Log warning, no abortar |
| Formato de separador | DCV, Rutero | Detectar `,` vs `;` automáticamente | Usar el detectado |
| Esquema compatible | Base_Filial | 8 columnas con tipos esperados | `raise SchemaError` si no coincide |
| Formato de Rut | DCV | Patrón numérico tras limpiar puntos | Log warning |
| Consistencia de fecha | Base_Filial | Nombre del archivo contiene `fecha_proceso` | Validar parámetro |

### 4.4 Validación de esquema CSV

```python
def validate_csv_schema(df, expected_columns, file_name):
    """Valida que el DataFrame tiene las columnas esperadas."""
    actual_cols = set(df.columns)
    expected_cols = set(expected_columns)
    
    missing = expected_cols - actual_cols
    extra = actual_cols - expected_cols
    
    if missing:
        raise ValueError(
            f"[{file_name}] Columnas faltantes en el CSV: {missing}. "
            f"Verifique el formato del archivo cargado por Front."
        )
    if extra:
        print(f"[WARN][{file_name}] Columnas adicionales no esperadas: {extra}")
```

---

## 5. Dependencias de Rutas

### 5.1 Mapa de dependencias

```
ENTRADA (Front)
│
├── /Volumes/pro_departure/essenout/salida/front/Base_Filial.csv
│   └── Notebook: Carga_Satelite_Filiales.py
│       └── Tabla paso: pro_app.essenneg.csv_filial_paso1_22_shcb
│           └── Tabla destino: pro_business.essenexp.master_filiales_interfaz_satelite_22_shcb
│
├── /Volumes/pro_departure/essenout/salida/front/DCV.csv
│   └── Notebook: Carga_Banco_SHCB.py
│       └── Tabla paso: pro_app.essenneg.CSV_Banco_DCV_22_shcb
│           └── Tabla destino: pro_business.essenexp.Banco_Detalle_22_shcb
│               └── Tabla resumen: pro_business.essenexp.Banco_Agrupado_22_shcb
│                   └── Tablas satélite (ver sección 5.2)
│
└── /Volumes/pro_departure/essenout/salida/front/Rutero_SHCB.csv
    └── Notebook: Carga_Banco_SHCB.py
        └── Tabla paso: pro_app.essenneg.CSV_Banco_Rutero_22_shcb
            └── (JOIN con DCV para INSERT en Banco_Detalle_22_shcb)
```

### 5.2 Tablas satélite downstream (generadas por Carga_Banco_SHCB.py)

| Tabla | Catálogo.Schema | Dependencia |
|-------|-----------------|-------------|
| `master_00051_parametria_automatica_satelite_22_shcb` | `pro_app.essenneg` | Cruza `essen_master_00051_informe_control` × `master_tabla` × `master_tabla_satelite_22_shcb` |
| `master_00051_satelite_22_shcb` | `pro_app.essenneg` | Cruza parametría automática × `Banco_Agrupado_22_shcb` |
| `master_00051_interfaz_satelite_22_shcb` | `pro_business.essenexp` | Transforma y escribe resultado final del satélite 22 |

### 5.3 Dependencias externas (tablas de referencia)

| Tabla | Uso |
|-------|-----|
| `pro_business.conrepexp.rutero_intergrupo` | JOIN para determinar intergrupo (sociedades '00200', '00974') |
| `pro_business.essenexp.essen_master_00051_informe_control` | Fuente de datos contables para satélite |
| `pro_business.conrepexp.master_tabla` | Parametría de productos/categorías |
| `pro_business.conrepexp.master_tabla_satelite_22_shcb` | Parametría específica del satélite 22 |

---

## 6. Diferencias entre Ruta Front y Ruta Motor

| Aspecto | Ruta Motor (actual) | Ruta Front (nueva) |
|---------|--------------------|--------------------|
| Volumen base | `/Volumes/pro_app/essenneg/motor/` | `/Volumes/pro_departure/essenout/salida/front/` |
| Nombre Base_Filial | `Base_Filial_{yyyymmdd}.csv` (con fecha) | `Base_Filial.csv` (sin fecha) |
| Nombre DCV | `DCV.csv` | `DCV.csv` |
| Nombre Rutero | `Rutero_SHCB.csv` | `Rutero_SHCB.csv` |
| Subdirectorio | Separado en `CSV_Filiales/` y `CSV_Banco/` | Todos en directorio `front/` |
| Convención fecha | Embebida en nombre de archivo (Filial) | No embebida (se asume fecha del día o parámetro) |

### Impacto en notebooks

1. **Carga_Satelite_Filiales.py**: Actualmente construye la ruta con `f"...Base_Filial_{fecha_proceso}.csv"`. Al usar la ruta Front, el nombre del archivo NO incluye la fecha. Se debe parametrizar la fuente.

2. **Carga_Banco_SHCB.py**: Las rutas de DCV y Rutero no incluyen fecha en ningún caso, por lo que el cambio es solo de directorio base.

---

## 7. Checklist de Habilitación

### Pre-requisitos

- [ ] Confirmar que el volumen `/Volumes/pro_departure/essenout/salida/front/` existe en Unity Catalog
- [ ] Verificar permisos de lectura del Service Principal de Databricks sobre el volumen `pro_departure`
- [ ] Confirmar que el proceso Front deposita los 3 archivos con los nombres exactos esperados
- [ ] Validar formato de los CSV generados por Front (separador, encoding UTF-8, headers)
- [ ] Confirmar que el archivo `Base_Filial.csv` (vía Front) NO incluye fecha en el nombre

### Modificaciones en Notebooks

- [ ] Agregar parámetro `fuente_carga` (widget) con opciones: `"front"` / `"motor"` (default: `"motor"`)
- [ ] Implementar lógica de resolución de rutas según `fuente_carga`
- [ ] Agregar validación de existencia de archivos (`validate_file_exists`)
- [ ] Agregar validación de esquema CSV (`validate_csv_schema`)
- [ ] Para Filial: ajustar lógica de nombre de archivo (sin `{fecha_proceso}` cuando `fuente="front"`)
- [ ] Para Banco: actualizar rutas base de DCV y Rutero
- [ ] Agregar logs de auditoría indicando la fuente de los archivos procesados

### Testing

- [ ] Ejecutar notebooks con archivos de prueba en ruta Front
- [ ] Verificar que la detección de separador funciona con archivos del Front
- [ ] Validar que los registros se insertan correctamente en tablas destino
- [ ] Confirmar que la verificación final muestra conteos esperados
- [ ] Probar escenario de archivo no encontrado (mensaje de error claro)
- [ ] Probar escenario de archivo vacío (abortar con error descriptivo)
- [ ] Probar escenario de esquema incorrecto (abortar con error descriptivo)

### Despliegue

- [ ] Crear ticket en Jira (asignado a Rodrigo Castro)
- [ ] PR con cambios en notebooks revisado y aprobado
- [ ] Desplegar notebooks actualizados en workspace de Databricks (PRO)
- [ ] Validar ejecución end-to-end en ambiente pre-productivo
- [ ] Documentar runbook de operación para mesa de soporte
- [ ] Comunicar habilitación al equipo de Front

---

## 8. Ejemplo de Implementación de Parametrización de Fuente

```python
# --- Agregar al inicio de cada notebook ---

# Widget para seleccionar la fuente de carga
dbutils.widgets.dropdown(
    "fuente_carga", "motor", ["motor", "front"],
    "Fuente de carga CSV"
)
fuente_carga = dbutils.widgets.get("fuente_carga")

# Resolución de rutas según fuente
if fuente_carga == "front":
    # Ruta Front: archivos depositados por la interfaz de carga manual
    BASE_PATH_FILIAL = "/Volumes/pro_departure/essenout/salida/front"
    BASE_PATH_BANCO = "/Volumes/pro_departure/essenout/salida/front"
    csv_path_filial = f"{BASE_PATH_FILIAL}/Base_Filial.csv"
    csv_path_dcv = f"{BASE_PATH_BANCO}/DCV.csv"
    csv_path_rutero = f"{BASE_PATH_BANCO}/Rutero_SHCB.csv"
else:
    # Ruta Motor: archivos generados por el motor automático
    BASE_PATH_FILIAL = "/Volumes/pro_app/essenneg/motor/CSV_Filiales"
    BASE_PATH_BANCO = "/Volumes/pro_app/essenneg/motor/CSV_Banco"
    csv_path_filial = f"{BASE_PATH_FILIAL}/Base_Filial_{fecha_proceso}.csv"
    csv_path_dcv = f"{BASE_PATH_BANCO}/DCV.csv"
    csv_path_rutero = f"{BASE_PATH_BANCO}/Rutero_SHCB.csv"

print(f"Fuente de carga: {fuente_carga}")
print(f"Rutas configuradas:")
print(f"  Filial: {csv_path_filial}")
print(f"  DCV:    {csv_path_dcv}")
print(f"  Rutero: {csv_path_rutero}")
```

---

## 9. Consideraciones de Seguridad y Auditoría

| Aspecto | Recomendación |
|---------|---------------|
| Permisos de volumen | Otorgar `READ` mínimo al SP del cluster sobre `/Volumes/pro_departure/essenout/salida/front/` |
| Trazabilidad | Registrar en log: usuario que ejecuta, fuente seleccionada, timestamp, conteo de registros |
| Idempotencia | El patrón DELETE + INSERT por `data_date_part` garantiza re-ejecución segura |
| Retención | Los archivos en ruta Front deben tener política de retención (evitar reprocesar archivos antiguos) |
| Concurrencia | Si múltiples usuarios cargan simultáneamente, el último DELETE+INSERT prevalece — considerar locks |

---

## 10. Diagrama de Secuencia

```
Usuario Front       Volumen DBFS           Notebook              Tablas Unity Catalog
     │                   │                    │                         │
     │── Sube CSV ──────▶│                    │                         │
     │                   │                    │                         │
     │                   │◀── Lee archivos ───│                         │
     │                   │                    │                         │
     │                   │                    │── Valida existencia ────▶│ (N/A)
     │                   │                    │                         │
     │                   │                    │── Valida esquema ───────▶│ (N/A)
     │                   │                    │                         │
     │                   │                    │── OVERWRITE paso ───────▶│ csv_*_paso
     │                   │                    │                         │
     │                   │                    │── DELETE destino ────────▶│ tablas destino
     │                   │                    │                         │
     │                   │                    │── INSERT destino ────────▶│ tablas destino
     │                   │                    │                         │
     │                   │                    │── INSERT satélite ───────▶│ tablas satélite
     │                   │                    │                         │
     │                   │                    │── Verificación ──────────▶│
     │                   │                    │◀── Conteo OK ────────────│
     │                   │                    │                         │
```

---

## 11. Glosario

| Término | Definición |
|---------|-----------|
| **SHCB** | Shareholders Composition Book — libro de composición accionaria |
| **Satélite 22** | Reporte regulatorio satélite número 22 (composición accionaria) |
| **Front** | Interfaz web de carga manual de archivos |
| **Motor** | Proceso automático que genera los archivos CSV |
| **DCV** | Depósito Central de Valores — entidad que registra accionistas |
| **Rutero** | Tabla de clasificación de accionistas por tipo de sociedad |
| **Unity Catalog** | Servicio de gobernanza de datos de Databricks |
| **data_date_part** | Campo de partición temporal (formato `yyyy-mm-dd`) |
| **Tabla de paso** | Tabla intermedia (staging) para validación antes del INSERT final |

---

*Documento generado el 2026-06-05. Última actualización de notebooks analizada: rama `devin/1780075370-rename-tablas-banco-shcb` y `devin/1779991773-adaptar-esquema-satelite-22-shcb`.*
