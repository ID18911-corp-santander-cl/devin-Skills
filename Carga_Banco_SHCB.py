# Databricks notebook source
# MAGIC %md
# MAGIC # Carga de Banco DCV y Rutero CSV a pro_business.essenexp.Banco_SHCB
# MAGIC
# MAGIC Este notebook:
# MAGIC 1. Lee el archivo CSV `pro_app.essenneg.Banco_DCV_paso.csv` y lo carga en la tabla de paso `pro_app.essenneg.Banco_DCV_paso`
# MAGIC 2. Lee el archivo CSV `pro_app.essenneg.Rutero_SHCB.csv` y lo carga en la tabla de paso `pro_app.essenneg.Banco_Rutero_paso`
# MAGIC 3. Elimina registros existentes en `pro_business.essenexp.Banco_SHCB` para la fecha de proceso
# MAGIC 4. Inserta los datos cruzados desde las tablas de paso a `pro_business.essenexp.Banco_SHCB`
# MAGIC
# MAGIC **Nota:** Los archivos CSV pueden venir con separador de campos `,` o `;`. Se detecta automaticamente.
# MAGIC Los archivos pueden tener un separador inicial y/o final en cada linea que genera columnas vacias; se manejan por posicion explicita.

# COMMAND ----------

# MAGIC %md
# MAGIC ## Parametros

# COMMAND ----------

from datetime import datetime

# Parametro: fecha de proceso en formato yyyymmdd.
# Se puede pasar como widget de Databricks o usar la fecha actual por defecto.
dbutils.widgets.text("fecha_proceso", datetime.now().strftime("%Y%m%d"), "Fecha de proceso (yyyymmdd)")
fecha_proceso = dbutils.widgets.get("fecha_proceso")

data_date_part = f"{fecha_proceso[:4]}-{fecha_proceso[4:6]}-{fecha_proceso[6:8]}"
print(f"Fecha de proceso: {fecha_proceso}")
print(f"data_date_part:   {data_date_part}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 1. Definicion de rutas

# COMMAND ----------

# Rutas de los archivos CSV en el volumen de Unity Catalog
csv_path_dcv = "/Volumes/pro_app/essenneg/motor/CSV_Banco/DCV.csv"
csv_path_rutero = "/Volumes/pro_app/essenneg/motor/CSV_Banco/Rutero_SHCB.csv"

print(f"Ruta CSV DCV:    {csv_path_dcv}")
print(f"Ruta CSV Rutero: {csv_path_rutero}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 2. Funcion para detectar separador

# COMMAND ----------

from pyspark.sql.functions import col, regexp_replace, split as spark_split, trim, count, when, lit, current_timestamp, date_format, from_utc_timestamp
from pyspark.sql.types import LongType


def detect_separator(file_path):
    """
    Detecta si el archivo CSV usa ',' o ';' como separador de campos.
    Lee la primera linea del archivo y cuenta las ocurrencias de cada separador.
    """
    first_line = dbutils.fs.head(file_path, 1024).split("\n")[0]
    count_comma = first_line.count(",")
    count_semicolon = first_line.count(";")
    separator = ";" if count_semicolon > count_comma else ","
    print(f"Separador detectado para '{file_path}': '{separator}' (comas={count_comma}, puntoycoma={count_semicolon})")
    return separator

# COMMAND ----------

# MAGIC %md
# MAGIC ## 3. Lectura y mapeo del archivo CSV DCV
# MAGIC
# MAGIC Estructura real del CSV DCV (separado por `;`, con `;` inicial y final en cada linea):
# MAGIC ```
# MAGIC ;Nemotecnico;Numero de Registro;Nombre o Razon Social;Rut;DV;Direccion;Comuna;Ciudad;Acciones;Total Acciones;
# MAGIC ```
# MAGIC
# MAGIC Al leer con Spark, las posiciones de las columnas son:
# MAGIC - Posicion 0: columna vacia (generada por el `;` inicial)
# MAGIC - Posicion 1: Nemotecnico
# MAGIC - Posicion 2: Numero de Registro (se descarta, no existe en tabla destino)
# MAGIC - Posicion 3: Nombre o Razon Social -> Razon_Social
# MAGIC - Posicion 4: Rut (se limpian los puntos: "96.501.440" -> "96501440")
# MAGIC - Posicion 5: DV
# MAGIC - Posicion 6: Direccion
# MAGIC - Posicion 7: Comuna
# MAGIC - Posicion 8: Ciudad
# MAGIC - Posicion 9: Acciones
# MAGIC - Posicion 10: Total Acciones
# MAGIC - Posicion 11: columna vacia (generada por el `;` final)

# COMMAND ----------

separator_dcv = detect_separator(csv_path_dcv)

df_dcv_raw = (
    spark.read.format("csv")
    .option("header", "true")
    .option("delimiter", separator_dcv)
    .option("encoding", "UTF-8")
    .option("mode", "PERMISSIVE")
    .option("inferSchema", "false")
    .load(csv_path_dcv)
)

print(f"Columnas detectadas en DCV ({len(df_dcv_raw.columns)}): {df_dcv_raw.columns}")
print(f"Registros leidos (DCV): {df_dcv_raw.count()}")
df_dcv_raw.show(3, truncate=False)

# Mapeo por posicion explicita (posiciones conocidas del CSV)
dcv_cols = df_dcv_raw.columns

df_dcv = df_dcv_raw.select(
    trim(col(f"`{dcv_cols[1]}`")).alias("Nemotecnico"),
    trim(col(f"`{dcv_cols[2]}`")).alias("Numero_registro"),
    trim(col(f"`{dcv_cols[3]}`")).alias("Razon_Social"),
    regexp_replace(trim(col(f"`{dcv_cols[4]}`")), "\\.", "").alias("Rut"),
    trim(col(f"`{dcv_cols[5]}`")).alias("DV"),
    trim(col(f"`{dcv_cols[6]}`")).alias("Direccion"),
    trim(col(f"`{dcv_cols[7]}`")).alias("Comuna"),
    trim(col(f"`{dcv_cols[8]}`")).alias("Ciudad"),
    regexp_replace(trim(col(f"`{dcv_cols[9]}`")), "\\.", "").cast(LongType()).alias("Acciones"),
    regexp_replace(trim(col(f"`{dcv_cols[10]}`")), "\\.", "").cast(LongType()).alias("Total_Acciones"),
)

print("DataFrame DCV mapeado:")
df_dcv.show(5, truncate=False)
df_dcv.printSchema()

# COMMAND ----------

# MAGIC %md
# MAGIC ## 4. Lectura y mapeo del archivo CSV Rutero
# MAGIC
# MAGIC Estructura real del CSV Rutero (separado por `;`, con `;` final en cada linea):
# MAGIC ```
# MAGIC Rut Accionista;Razon Social o Nombre Accionista;Tipo de sociedad;Clasificacion;
# MAGIC ```
# MAGIC
# MAGIC Al leer con Spark, las posiciones de las columnas son:
# MAGIC - Posicion 0: Rut Accionista (se limpian puntos y se elimina guion+DV: "97.004.000-5" -> "97004000")
# MAGIC - Posicion 1: Razon Social o Nombre Accionista -> Razon_Social
# MAGIC - Posicion 2: Tipo de sociedad -> Tipo_sociedad
# MAGIC - Posicion 3: Clasificacion
# MAGIC - Posicion 4: columna vacia (generada por el `;` final)

# COMMAND ----------

separator_rutero = detect_separator(csv_path_rutero)

df_rutero_raw = (
    spark.read.format("csv")
    .option("header", "true")
    .option("delimiter", separator_rutero)
    .option("encoding", "UTF-8")
    .option("mode", "PERMISSIVE")
    .option("inferSchema", "false")
    .load(csv_path_rutero)
)

print(f"Columnas detectadas en Rutero ({len(df_rutero_raw.columns)}): {df_rutero_raw.columns}")
print(f"Registros leidos (Rutero): {df_rutero_raw.count()}")
df_rutero_raw.show(3, truncate=False)

# Mapeo por posicion explicita
rutero_cols = df_rutero_raw.columns

df_rutero = df_rutero_raw.select(
    # Rut Accionista: quitar guion+DV primero, luego eliminar puntos
    # Ejemplo: "97.004.000-5" -> split("-")[0] = "97.004.000" -> quitar puntos = "97004000"
    regexp_replace(
        spark_split(trim(col(f"`{rutero_cols[0]}`")), "-").getItem(0),
        "\\.", ""
    ).alias("Rut_Accionista"),
    trim(col(f"`{rutero_cols[1]}`")).alias("Razon_Social"),
    trim(col(f"`{rutero_cols[2]}`")).alias("Tipo_sociedad"),
    trim(col(f"`{rutero_cols[3]}`")).alias("Clasificacion"),
)

print("DataFrame Rutero mapeado:")
df_rutero.show(5, truncate=False)
df_rutero.printSchema()

# COMMAND ----------

# MAGIC %md
# MAGIC ## 5. Validaciones basicas

# COMMAND ----------

# --- Validacion DCV ---
all_columns_dcv = df_dcv.columns
not_all_empty_dcv = ~(
    col(all_columns_dcv[0]).isNull() | (trim(col(all_columns_dcv[0]).cast("string")) == "")
)
for c in all_columns_dcv[1:]:
    not_all_empty_dcv = not_all_empty_dcv | ~(
        col(c).isNull() | (trim(col(c).cast("string")) == "")
    )

records_before_dcv = df_dcv.count()
df_dcv = df_dcv.filter(not_all_empty_dcv)
records_after_dcv = df_dcv.count()
print(f"[DCV] Registros leidos: {records_before_dcv}")
print(f"[DCV] Registros descartados (vacios/nulos): {records_before_dcv - records_after_dcv}")
print(f"[DCV] Registros validos: {records_after_dcv}")

# --- Validacion Rutero ---
all_columns_rutero = df_rutero.columns
not_all_empty_rutero = ~(
    col(all_columns_rutero[0]).isNull() | (trim(col(all_columns_rutero[0]).cast("string")) == "")
)
for c in all_columns_rutero[1:]:
    not_all_empty_rutero = not_all_empty_rutero | ~(
        col(c).isNull() | (trim(col(c).cast("string")) == "")
    )

records_before_rutero = df_rutero.count()
df_rutero = df_rutero.filter(not_all_empty_rutero)
records_after_rutero = df_rutero.count()
print(f"[Rutero] Registros leidos: {records_before_rutero}")
print(f"[Rutero] Registros descartados (vacios/nulos): {records_before_rutero - records_after_rutero}")
print(f"[Rutero] Registros validos: {records_after_rutero}")

if records_after_dcv == 0:
    raise ValueError(f"El archivo CSV DCV esta vacio o todos los registros tienen columnas vacias: {csv_path_dcv}")
if records_after_rutero == 0:
    raise ValueError(f"El archivo CSV Rutero esta vacio o todos los registros tienen columnas vacias: {csv_path_rutero}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 6. Escritura en tablas de paso

# COMMAND ----------

target_table_dcv = "pro_app.essenneg.Banco_DCV_paso"
target_table_rutero = "pro_app.essenneg.Banco_Rutero_paso"

(
    df_dcv.write
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .saveAsTable(target_table_dcv)
)
print(f"Tabla '{target_table_dcv}' creada/actualizada con {records_after_dcv} registros.")

(
    df_rutero.write
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .saveAsTable(target_table_rutero)
)
print(f"Tabla '{target_table_rutero}' creada/actualizada con {records_after_rutero} registros.")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 7. DELETE por data_date_part en pro_business.essenexp.Banco_SHCB

# COMMAND ----------

dest_table = "pro_business.essenexp.Banco_SHCB"

spark.sql(f"""
    DELETE FROM {dest_table}
    WHERE data_date_part = '{data_date_part}'
""")

print(f"Registros eliminados de '{dest_table}' para data_date_part = '{data_date_part}'")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 8. Cruce e INSERT append en pro_business.essenexp.Banco_SHCB

# COMMAND ----------

df_dcv_paso = spark.table(target_table_dcv)
df_rutero_paso = spark.table(target_table_rutero)

df_cruce = df_dcv_paso.join(df_rutero_paso, df_dcv_paso["Rut"] == df_rutero_paso["Rut_Accionista"], "left")

df_mapped = df_cruce.select(
    col("Nemotecnico"),
    col("Razon_Social"),
    col("Rut"),
    col("DV"),
    col("Direccion"),
    col("Comuna"),
    col("Ciudad"),
    col("Acciones"),
    col("Total_Acciones"),
    col("Tipo_sociedad"),
    col("Clasificacion"),
    lit(data_date_part).alias("data_date_part"),
    date_format(from_utc_timestamp(current_timestamp(), "America/Santiago"), "yyyy-MM-dd HH:mm:ss.SSS").alias("fecha_de_ejecucion"),
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
# MAGIC ## 9. Verificacion de la tabla destino

# COMMAND ----------

df_dest_verify = spark.sql(f"""
    SELECT * FROM {dest_table}
    WHERE data_date_part = '{data_date_part}'
""")
print(f"Registros en '{dest_table}' para data_date_part = '{data_date_part}': {df_dest_verify.count()}")
df_dest_verify.show(10, truncate=False)