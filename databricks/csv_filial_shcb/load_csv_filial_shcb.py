# Databricks notebook source
# MAGIC %md
# MAGIC # Carga de Base_Filial CSV a pro_business.essenexp.Filial_SHCB
# MAGIC
# MAGIC Este notebook:
# MAGIC 1. Lee el archivo CSV `Base_Filial_yyyymmdd.csv` desde `/Volumes/pro_app/essenneg/motor/`
# MAGIC 2. Lo carga en la tabla de paso `pro_app.essenneg.paso_csv_filial_SHCB`
# MAGIC 3. Elimina registros existentes en `pro_business.essenexp.Filial_SHCB` para la fecha de proceso
# MAGIC 4. Inserta (append) los datos mapeados desde la tabla de paso a `pro_business.essenexp.Filial_SHCB`
# MAGIC
# MAGIC **Estructura del CSV (separado por coma):**
# MAGIC | Columna | Descripción |
# MAGIC |---|---|
# MAGIC | Sociedad | Código de sociedad |
# MAGIC | Shareholder entity code | Código de entidad accionista |
# MAGIC | Name of the shareholder entity | Nombre de la entidad accionista |
# MAGIC | AMOUNT | Monto |
# MAGIC | Number of owned shares | Número de acciones propias |
# MAGIC | % of ownership per issuance | Porcentaje de propiedad por emisión |
# MAGIC | % of voting rights | Porcentaje de derechos de voto |
# MAGIC | BIxxxxx | Código BI |

# COMMAND ----------

# MAGIC %md
# MAGIC ## Parámetros

# COMMAND ----------

from datetime import datetime

# Parámetro: fecha de proceso en formato yyyymmdd.
# Se puede pasar como widget de Databricks o usar la fecha actual por defecto.
dbutils.widgets.text("fecha_proceso", datetime.now().strftime("%Y%m%d"), "Fecha de proceso (yyyymmdd)")
fecha_proceso = dbutils.widgets.get("fecha_proceso")

data_date_part = f"{fecha_proceso[:4]}-{fecha_proceso[4:6]}-{fecha_proceso[6:8]}"
print(f"Fecha de proceso: {fecha_proceso}")
print(f"data_date_part:   {data_date_part}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 1. Definición de rutas y esquema

# COMMAND ----------

from pyspark.sql.types import (
    StructType,
    StructField,
    StringType,
    DecimalType,
)

# Ruta del archivo CSV en el volumen de Unity Catalog
csv_path = f"/Volumes/pro_app/essenneg/motor/Base_Filial_{fecha_proceso}.csv"

# Esquema explícito para evitar inferencia incorrecta de tipos
schema = StructType(
    [
        StructField("Sociedad", StringType(), True),
        StructField("Shareholder_entity_code", StringType(), True),
        StructField("Name_of_the_shareholder_entity", StringType(), True),
        StructField("AMOUNT", DecimalType(38, 0), True),
        StructField("Number_of_owned_shares", DecimalType(38, 0), True),
        StructField("Pct_ownership_per_issuance", DecimalType(10, 2), True),
        StructField("Pct_voting_rights", DecimalType(10, 2), True),
        StructField("BIxxxxx", StringType(), True),
    ]
)

print(f"Ruta del CSV: {csv_path}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 2. Lectura del archivo CSV

# COMMAND ----------

df = (
    spark.read.format("csv")
    .option("header", "true")
    .option("delimiter", ",")
    .option("encoding", "UTF-8")
    .option("mode", "PERMISSIVE")
    .option("columnNameOfCorruptRecord", "_corrupt_record")
    .schema(schema)
    .load(csv_path)
)

print(f"Registros leídos: {df.count()}")
df.show(10, truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 3. Validaciones básicas

# COMMAND ----------

from pyspark.sql.functions import col, count, when, trim, coalesce

# Filtrar registros donde todas las columnas son nulas o vacías
all_columns = df.columns
not_all_empty = ~(
    col(all_columns[0]).isNull() | (trim(col(all_columns[0]).cast("string")) == "")
)
for c in all_columns[1:]:
    not_all_empty = not_all_empty | ~(
        col(c).isNull() | (trim(col(c).cast("string")) == "")
    )

records_before = df.count()
df = df.filter(not_all_empty)
records_after = df.count()
print(f"Registros leídos: {records_before}")
print(f"Registros descartados (todas las columnas vacías/nulas): {records_before - records_after}")
print(f"Registros válidos: {records_after}")

# Verificar registros nulos en columnas clave
null_checks = df.select(
    count(when(col("Sociedad").isNull(), 1)).alias("nulls_Sociedad"),
    count(when(col("Shareholder_entity_code").isNull(), 1)).alias("nulls_Shareholder_entity_code"),
    count(when(col("AMOUNT").isNull(), 1)).alias("nulls_AMOUNT"),
)
null_checks.show()

total_records = df.count()
if total_records == 0:
    raise ValueError(f"El archivo CSV está vacío o todos los registros tienen columnas vacías: {csv_path}")

print(f"Total de registros a cargar: {total_records}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 4. Escritura en la tabla pro_app.essenneg.paso_csv_filial_SHCB

# COMMAND ----------

target_table = "pro_app.essenneg.paso_csv_filial_SHCB"

# Escritura con overwrite: reemplaza la tabla completa en cada ejecución
(
    df.write
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .saveAsTable(target_table)
)

print(f"Tabla '{target_table}' creada/actualizada exitosamente con {total_records} registros.")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 5. Verificación de la tabla

# COMMAND ----------

df_verify = spark.table(target_table)
print(f"Registros en tabla de paso: {df_verify.count()}")
df_verify.show(10, truncate=False)
df_verify.printSchema()

# COMMAND ----------

# MAGIC %md
# MAGIC ## 6. DELETE por data_date_part en pro_business.essenexp.Filial_SHCB

# COMMAND ----------

dest_table = "pro_business.essenexp.Filial_SHCB"

spark.sql(f"""
    DELETE FROM {dest_table}
    WHERE data_date_part = '{data_date_part}'
""")

print(f"Registros eliminados de '{dest_table}' para data_date_part = '{data_date_part}'")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 7. Mapeo e INSERT append en pro_business.essenexp.Filial_SHCB
# MAGIC
# MAGIC | Campo Destino | Campo Origen |
# MAGIC |---|---|
# MAGIC | data_date_part | fecha_proceso (yyyy-mm-dd) |
# MAGIC | counterparty_soc | Shareholder_entity_code |
# MAGIC | adjustment_code | BIxxxxx |
# MAGIC | id_comb | Literal: 'B03;MC23;PR18' |
# MAGIC | amount | AMOUNT |
# MAGIC | shcode | Shareholder_entity_code |
# MAGIC | shname | Name_of_the_shareholder_entity |
# MAGIC | isin | Literal: '0' |
# MAGIC | ic | Literal: '152' |
# MAGIC | osha | Number_of_owned_shares |
# MAGIC | ownpi | Pct_ownership_per_issuance |
# MAGIC | votr | Pct_voting_rights |

# COMMAND ----------

from pyspark.sql.functions import lit

df_paso = spark.table(target_table)

df_mapped = df_paso.select(
    lit(data_date_part).alias("data_date_part"),
    col("Shareholder_entity_code").alias("counterparty_soc"),
    col("BIxxxxx").alias("adjustment_code"),
    lit("B03;MC23;PR18").alias("id_comb"),
    col("AMOUNT").alias("amount"),
    col("Shareholder_entity_code").alias("shcode"),
    col("Name_of_the_shareholder_entity").alias("shname"),
    lit("0").alias("isin"),
    lit("152").alias("ic"),
    col("Number_of_owned_shares").alias("osha"),
    col("Pct_ownership_per_issuance").alias("ownpi"),
    col("Pct_voting_rights").alias("votr"),
)

(
    df_mapped.write
    .mode("append")
    .saveAsTable(dest_table)
)

insert_count = df_mapped.count()
print(f"Insertados {insert_count} registros en '{dest_table}' para data_date_part = '{data_date_part}'")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 8. Verificación de la tabla destino

# COMMAND ----------

df_dest_verify = spark.sql(f"""
    SELECT * FROM {dest_table}
    WHERE data_date_part = '{data_date_part}'
""")
print(f"Registros en '{dest_table}' para data_date_part = '{data_date_part}': {df_dest_verify.count()}")
df_dest_verify.show(10, truncate=False)
