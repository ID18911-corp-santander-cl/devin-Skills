# Databricks notebook source
# MAGIC %md
# MAGIC # Carga de Base_Filial CSV a tabla paso_csv_filial_SHCB
# MAGIC
# MAGIC Este notebook lee el archivo CSV `Base_Filial_yyyymmdd.csv` desde el volumen
# MAGIC `/Volumes/pro_app/essenneg/motor/` y lo carga en la tabla `pro_app.essenneg.paso_csv_filial_SHCB`.
# MAGIC
# MAGIC **Estructura del CSV (separado por tabulación):**
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

print(f"Fecha de proceso: {fecha_proceso}")

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
    .option("delimiter", "\t")
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

from pyspark.sql.functions import col, count, when

# Verificar registros nulos en columnas clave
null_checks = df.select(
    count(when(col("Sociedad").isNull(), 1)).alias("nulls_Sociedad"),
    count(when(col("Shareholder_entity_code").isNull(), 1)).alias("nulls_Shareholder_entity_code"),
    count(when(col("AMOUNT").isNull(), 1)).alias("nulls_AMOUNT"),
)
null_checks.show()

total_records = df.count()
if total_records == 0:
    raise ValueError(f"El archivo CSV está vacío: {csv_path}")

print(f"Total de registros válidos: {total_records}")

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
print(f"Registros en tabla: {df_verify.count()}")
df_verify.show(10, truncate=False)
df_verify.printSchema()
