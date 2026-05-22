# API Reference

## Databricks Notebooks

### load_csv_filial_shcb

**Ubicación:** `databricks/csv_filial_shcb/load_csv_filial_shcb.py`

#### Parámetros (Widgets)

| Widget | Tipo | Default | Descripción |
|---|---|---|---|
| `fecha_proceso` | text | `yyyymmdd` (fecha actual) | Fecha del archivo CSV a procesar |

#### Entrada

| Campo | Tipo | Fuente |
|---|---|---|
| Archivo CSV | Tab-separated | `/Volumes/pro_app/essenneg/motor/Base_Filial_{fecha_proceso}.csv` |

#### Esquema de columnas del CSV

| Columna original | Columna mapeada | Tipo Spark |
|---|---|---|
| Sociedad | Sociedad | `StringType` |
| Shareholder entity code | Shareholder_entity_code | `StringType` |
| Name of the shareholder entity | Name_of_the_shareholder_entity | `StringType` |
| AMOUNT | AMOUNT | `DecimalType(38, 0)` |
| Number of owned shares | Number_of_owned_shares | `DecimalType(38, 0)` |
| % of ownership per issuance | Pct_ownership_per_issuance | `DecimalType(10, 2)` |
| % of voting rights | Pct_voting_rights | `DecimalType(10, 2)` |
| BIxxxxx | BIxxxxx | `StringType` |

#### Salida

| Tabla destino | Modo de escritura |
|---|---|
| `paso_csv_filial_SHCB` | `overwrite` (reemplaza la tabla completa) |

#### Validaciones

- Verifica que el archivo no esté vacío (lanza `ValueError` si tiene 0 registros)
- Reporta conteo de nulos en columnas: `Sociedad`, `Shareholder_entity_code`, `AMOUNT`

#### Errores comunes

| Error | Causa | Solución |
|---|---|---|
| `AnalysisException: Path does not exist` | El archivo CSV no existe en la ruta | Verificar que el archivo existe y que `fecha_proceso` es correcto |
| `ValueError: El archivo CSV está vacío` | El CSV tiene header pero 0 filas de datos | Verificar el contenido del archivo fuente |
