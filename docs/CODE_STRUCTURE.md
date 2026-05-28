# Code Structure

## Carga_Satelite_Fliliales.py

Databricks notebook (PySpark) que ejecuta el pipeline ETL para la carga de datos de filiales.

### Secciones del notebook

| Sección | Descripción |
|---------|-------------|
| 1. Definición de rutas y esquema | Define la ruta del CSV y el esquema de lectura (`StructType`) |
| 2. Lectura del archivo CSV | Lee `Base_Filial_yyyymmdd.csv` con `spark.read` |
| 3. Validaciones básicas | Filtra filas completamente vacías y verifica nulos en columnas clave |
| 4. Escritura tabla de paso | Escribe en `pro_app.essenneg.csv_filial_paso1_22_shcb` (overwrite) |
| 5. Verificación tabla de paso | Muestra conteo y schema de la tabla de paso |
| 6. DELETE por data_date_part | Elimina registros existentes en la tabla destino para la fecha de proceso |
| 7. Mapeo e INSERT | Construye `df_mapped` con las 15 columnas del esquema destino e inserta (append) en `pro_business.essenexp.master_filiales_interfaz_satelite_22_shcb` |
| 8. Verificación tabla destino | Consulta y muestra los registros insertados |

### Campo concatenado

La columna `REPORTING_SOC|COUNTERPARTY_SOC|ADJUSTMENT_CODE|ID_COMB|AMOUNT|SHCODE|SHNAME|ISIN|IC|OSHA|OWNPI|VOTR` se genera con `concat_ws("|", ...)` aplicando `coalesce(..., lit(""))` a cada campo para reemplazar nulos por cadena vacía antes de concatenar.
