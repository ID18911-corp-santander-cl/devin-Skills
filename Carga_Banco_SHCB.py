# Databricks notebook source
# MAGIC %md
# MAGIC # Carga de Banco DCV y Rutero CSV a pro_business.essenexp.Banco_Detalle_22_shcb y Banco_Agrupado_22_shcb
# MAGIC
# MAGIC Este notebook:
# MAGIC 1. Lee el archivo CSV `pro_app.essenneg.CSV_Banco_DCV_22_shcb.csv` y lo carga en la tabla de paso `pro_app.essenneg.CSV_Banco_DCV_22_shcb`
# MAGIC 2. Lee el archivo CSV `pro_app.essenneg.Rutero_SHCB.csv` y lo carga en la tabla de paso `pro_app.essenneg.CSV_Banco_Rutero_22_shcb`
# MAGIC 3. Elimina registros existentes en `pro_business.essenexp.Banco_Detalle_22_shcb` para la fecha de proceso
# MAGIC 4. Inserta los datos cruzados desde las tablas de paso a `pro_business.essenexp.Banco_Detalle_22_shcb`
# MAGIC 5. Genera la tabla resumen `pro_business.essenexp.Banco_Agrupado_22_shcb` con 101 registros a partir de `Banco_Detalle_22_shcb`
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

from pyspark.sql.functions import col, regexp_replace, split as spark_split, trim, count, when
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

# Databricks notebook source
# MAGIC %md
# MAGIC # Carga de Banco DCV y Rutero CSV a pro_business.essenexp.Banco_Detalle_22_shcb y Banco_Agrupado_22_shcb
# MAGIC
# MAGIC Este notebook:
# MAGIC 1. Lee el archivo CSV `pro_app.essenneg.CSV_Banco_DCV_22_shcb.csv` y lo carga en la tabla de paso `pro_app.essenneg.CSV_Banco_DCV_22_shcb`
# MAGIC 2. Lee el archivo CSV `pro_app.essenneg.Rutero_SHCB.csv` y lo carga en la tabla de paso `pro_app.essenneg.CSV_Banco_Rutero_22_shcb`
# MAGIC 3. Elimina registros existentes en `pro_business.essenexp.Banco_Detalle_22_shcb` para la fecha de proceso
# MAGIC 4. Inserta los datos cruzados desde las tablas de paso a `pro_business.essenexp.Banco_Detalle_22_shcb`
# MAGIC 5. Genera la tabla resumen `pro_business.essenexp.Banco_Agrupado_22_shcb` con 101 registros a partir de `Banco_Detalle_22_shcb`
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

from pyspark.sql.functions import col, regexp_replace, split as spark_split, trim, count, when
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

null_checks_dcv = df_dcv.select(
    count(when(col("Rut").isNull(), 1)).alias("nulls_Rut"),
    count(when(col("Acciones").isNull(), 1)).alias("nulls_Acciones"),
    count(when(col("Total_Acciones").isNull(), 1)).alias("nulls_Total_Acciones"),
)
null_checks_dcv.show()

if records_after_dcv == 0:
    raise ValueError(f"El archivo CSV DCV esta vacio o todos los registros tienen columnas vacias: {csv_path_dcv}")

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

null_checks_rutero = df_rutero.select(
    count(when(col("Rut_Accionista").isNull(), 1)).alias("nulls_Rut_Accionista"),
    count(when(col("Clasificacion").isNull(), 1)).alias("nulls_Clasificacion"),
)
null_checks_rutero.show()

if records_after_rutero == 0:
    raise ValueError(f"El archivo CSV Rutero esta vacio o todos los registros tienen columnas vacias: {csv_path_rutero}")

print(f"Total registros DCV a cargar: {records_after_dcv}")
print(f"Total registros Rutero a cargar: {records_after_rutero}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 6. Escritura en tabla de paso pro_app.essenneg.CSV_Banco_DCV_22_shcb

# COMMAND ----------

target_table_dcv = "pro_app.essenneg.CSV_Banco_DCV_22_shcb"

(
    df_dcv.write
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .saveAsTable(target_table_dcv)
)

print(f"Tabla '{target_table_dcv}' creada/actualizada exitosamente con {records_after_dcv} registros.")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 7. Escritura en tabla de paso pro_app.essenneg.CSV_Banco_Rutero_22_shcb

# COMMAND ----------

target_table_rutero = "pro_app.essenneg.CSV_Banco_Rutero_22_shcb"

(
    df_rutero.write
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .saveAsTable(target_table_rutero)
)

print(f"Tabla '{target_table_rutero}' creada/actualizada exitosamente con {records_after_rutero} registros.")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 8. Verificacion de las tablas de paso

# COMMAND ----------

df_verify_dcv = spark.table(target_table_dcv)
print(f"Registros en tabla de paso DCV: {df_verify_dcv.count()}")
df_verify_dcv.show(10, truncate=False)
df_verify_dcv.printSchema()

df_verify_rutero = spark.table(target_table_rutero)
print(f"Registros en tabla de paso Rutero: {df_verify_rutero.count()}")
df_verify_rutero.show(10, truncate=False)
df_verify_rutero.printSchema()

# COMMAND ----------

# MAGIC %md
# MAGIC ## 9. DELETE por data_date_part e INSERT en pro_business.essenexp.Banco_Detalle_22_shcb

# COMMAND ----------

dest_table_detalle = "pro_business.essenexp.Banco_Detalle_22_shcb"

# DELETE registros existentes para la fecha de proceso
spark.sql(f"""
    DELETE FROM pro_business.essenexp.Banco_Detalle_22_shcb
    WHERE data_date_part = '{data_date_part}'
""")

print(f"Registros eliminados de '{dest_table_detalle}' para data_date_part = '{data_date_part}'")

# INSERT con cruce de tablas de paso
spark.sql(f"""
    INSERT INTO pro_business.essenexp.Banco_Detalle_22_shcb
    WITH max_acciones AS (
        SELECT MAX(Total_Acciones) AS max_total_acciones
        FROM pro_app.essenneg.CSV_Banco_DCV_22_shcb
    )
    SELECT
        CAST(ROW_NUMBER() OVER (ORDER BY DCV.Acciones DESC) AS STRING) AS orden,
        DCV.Razon_Social                     AS razon_social_o_nombre_accionista,
        CONCAT(DCV.Rut, '', DCV.dv)          AS rut_accionista,
        CAST(NULL AS BIGINT)                 AS acciones,
        CAST(NULL AS BIGINT)                 AS depositos,
        DCV.Acciones                         AS total_acciones,
        DCV.Acciones / ma.max_total_acciones AS porc_sobre_total,        
        COALESCE(Rutero.Sociedad, '00000')   AS intergrupo,
        ''                                   AS nombre_intergrupo,
        ''                                   AS accionista,
        Ban_Rutero.Clasificacion             AS agrupacion_de_accionistas,
        '152'                                AS transaction_currency,
        ''                                   AS currency_decription,
        ''                                   AS more_detail,                
        '{data_date_part}'
    FROM pro_app.essenneg.CSV_Banco_DCV_22_shcb DCV
    CROSS JOIN max_acciones ma
    LEFT JOIN (
        SELECT rut, MAX(Sociedad) AS Sociedad
        FROM pro_business.conrepexp.rutero_intergrupo
        WHERE Sociedad IN ('00200', '00974' )
        GROUP BY rut
    ) Rutero
        ON DCV.Rut = Rutero.rut
    LEFT JOIN (
        SELECT Rut_Accionista, MAX(Clasificacion) AS Clasificacion
        FROM pro_app.essenneg.CSV_Banco_Rutero_22_shcb
        GROUP BY Rut_Accionista
    ) Ban_Rutero
        ON DCV.Rut = Ban_Rutero.Rut_Accionista
""")

print(f"INSERT completado en '{dest_table_detalle}' para data_date_part = '{data_date_part}'")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 10. Verificacion de la tabla destino (Banco_Detalle_22_shcb)

# COMMAND ----------

df_dest_verify = spark.sql(f"""
    SELECT * FROM {dest_table_detalle}
    WHERE data_date_part = '{data_date_part}'
""")
insert_count = df_dest_verify.count()
print(f"Registros en '{dest_table_detalle}' para data_date_part = '{data_date_part}': {insert_count}")
df_dest_verify.show(10, truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 10a. DELETE por data_date_part e INSERT en pro_business.essenexp.Banco_Agrupado_22_shcb (resumen 101 registros)

# COMMAND ----------

dest_table = "pro_business.essenexp.Banco_Agrupado_22_shcb"

# DELETE registros existentes para la fecha de proceso
spark.sql(f"""
    DELETE FROM pro_business.essenexp.Banco_Agrupado_22_shcb
    WHERE data_date_part = '{data_date_part}'
""")

print(f"Registros eliminados de '{dest_table}' para data_date_part = '{data_date_part}'")

# INSERT de los primeros 100 registros (por orden) con porc_sobre_total * 100 redondeado a 2 decimales
# mas un registro 101 que agrega los datos de los accionistas restantes
spark.sql(f"""
    INSERT INTO pro_business.essenexp.Banco_Agrupado_22_shcb
    WITH top_100 AS (
        SELECT
            orden,
            razon_social_o_nombre_accionista,
            rut_accionista,
            acciones,
            depositos,
            total_acciones,
            --ROUND(porc_sobre_total * 100, 2) AS porc_sobre_total,
            FORMAT_NUMBER(ROUND(porc_sobre_total * 100, 2), 2) AS porc_sobre_total,
            intergrupo,
            nombre_intergrupo,
            accionista,
            agrupacion_de_accionistas,
            transaction_currency,
            currency_decription,
            more_detail,
            data_date_part
        FROM pro_business.essenexp.Banco_Detalle_22_shcb
        WHERE data_date_part = '{data_date_part}'
          AND CAST(orden AS INT) <= 100
    ),
    resto AS (
        SELECT
            COALESCE(SUM(depositos), 0)        AS sum_depositos,
            COALESCE(SUM(total_acciones), 0)   AS sum_total_acciones
        FROM pro_business.essenexp.Banco_Detalle_22_shcb
        WHERE data_date_part = '{data_date_part}'
          AND CAST(orden AS INT) > 100
    ),
    sum_top_100 AS (
        SELECT SUM(porc_sobre_total) AS sum_porc_top_100
        FROM top_100
    )
    SELECT * FROM top_100
    UNION ALL
    SELECT
        '101'                                              AS orden,
        'O T R O S 10732      A C C I O N I S T A S'       AS razon_social_o_nombre_accionista,
        '-'                                                AS rut_accionista,
        CAST(0 AS BIGINT)                                  AS acciones,
        CAST(resto.sum_depositos AS BIGINT)                 AS depositos,
        CAST(resto.sum_total_acciones AS BIGINT)            AS total_acciones,
        ROUND(100 - sum_top_100.sum_porc_top_100, 2)        AS porc_sobre_total,
        '00000'                                            AS intergrupo,
        'Terceros'                                         AS nombre_intergrupo,
        'O T R O S 10732      A C C I O N I S T A S'       AS accionista,
        'OTROS ACCIONISTAS MINORITARIOS'                    AS agrupacion_de_accionistas,
        '152'                                              AS transaction_currency,
        'PESO CHILENO'                                     AS currency_decription,
        'CLP'                                              AS more_detail,
        '{data_date_part}'                                  AS data_date_part
    FROM resto
    CROSS JOIN sum_top_100
""")

print(f"INSERT completado en '{dest_table}' (101 registros) para data_date_part = '{data_date_part}'")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 10b. Verificacion de la tabla resumen (Banco_Agrupado_22_shcb)

# COMMAND ----------

df_resumen_verify = spark.sql(f"""
    SELECT * FROM {dest_table}
    WHERE data_date_part = '{data_date_part}'
""")
resumen_count = df_resumen_verify.count()
print(f"Registros en '{dest_table}' para data_date_part = '{data_date_part}': {resumen_count}")
df_resumen_verify.show(10, truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 11. Declaracion de variables de sesion SQL
# MAGIC
# MAGIC Se declaran variables de sesion para `fecha_de_cierre` (viene del Python) y `fecha_master_tabla`
# MAGIC (calculada a partir de `fecha_de_cierre`), usadas en las sentencias INSERT posteriores.

# COMMAND ----------


# COMMAND ----------

# MAGIC %md
# MAGIC ## 12. INSERT en pro_app.essenneg.master_00051_parametria_automatica_satelite_22_shcb

# COMMAND ----------

spark.sql(f"""
INSERT INTO TABLE pro_app.essenneg.master_00051_parametria_automatica_satelite_22_shcb
REPLACE WHERE data_date_part = '{data_date_part}' --viene del python
SELECT  C.empresa,
        C.cargabal,
        C.cuenta_contable,
        C.tipo_informacion,
        C.tipo_ajuste,
        C.intergrupo,
        C.moneda,
        C.monto,
        C.id_comb,
        S.id_comb AS id_comb_satelite_22_shcb,
        C.data_date_part
    FROM (
        SELECT  CASE
                    WHEN intergrupo != '00000' THEN 'Other than 00000'
                    ELSE intergrupo
                END AS counterparty_entity,
                empresa,
                cargabal,
                cuenta_contable,
                tipo_informacion,
                tipo_ajuste,
                intergrupo,
                moneda,
                monto,
                id_comb,
                data_date_part
            FROM  pro_business.essenexp.essen_master_00051_informe_control
            WHERE data_date_part = '{data_date_part}'
    ) C
    INNER JOIN (
        SELECT  counterparty_entity,
                id_comb,
                base,
                sub_base_1,
                main_category,
                product
            FROM pro_business.conrepexp.master_tabla
            WHERE data_date_part = (SELECT max(data_date_part) FROM pro_business.conrepexp.master_tabla
WHERE data_date_part <= '{data_date_part}')
    ) M
        ON C.counterparty_entity = M.counterparty_entity
        AND C.id_comb = M.id_comb
    INNER JOIN (
        SELECT  id_comb,
                base,
                sub_base_1,
                main_category,
                product,
                shareholder_entity_code,
                name_of_the_shareholder_entity,
                isin_code_of_the_issuance,
                issuance_currency,
                number_of_owned_shares,
                percentage_of_ownership_per_issuance,
                percentage_of_voting_rights
            FROM pro_business.conrepexp.master_tabla_satelite_22_shcb
    ) S
        ON M.base = S.base
        AND M.sub_base_1 = S.sub_base_1
        AND M.main_category = S.main_category
        AND M.product = S.product
""")

print("INSERT completado en 'pro_app.essenneg.master_00051_parametria_automatica_satelite_22_shcb'")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 13. INSERT en pro_app.essenneg.master_00051_satelite_22_shcb

# COMMAND ----------

spark.sql(f"""
INSERT INTO TABLE  pro_app.essenneg.master_00051_satelite_22_shcb REPLACE WHERE
data_date_part = '{data_date_part}' --viene del python
SELECT  C.reporting_soc,
        C.counterparty_soc,
        C.adjustment_code,
        C.id_comb,
        cast(round(C.monto * A.ppg, 0) AS BIGINT) AS amount,
        A.shcode,
        A.shname,
        A.isin,
        A.ic,
        A.osha,
        CASE
            WHEN A.shname != 'OTROS ACCIONISTAS MINORITARIOS' THEN A.ownpi
            WHEN round(sum(A.ownpi) OVER(), 2) = 100 THEN A.ownpi
            ELSE round(A.ownpi + 100 - round(sum(A.ownpi) OVER(), 2), 2)
        END AS ownpi,
        CASE
            WHEN A.shname != 'OTROS ACCIONISTAS MINORITARIOS' THEN A.ownpi
            WHEN round(sum(A.ownpi) OVER(), 2) = 100 THEN A.ownpi
            ELSE round(A.ownpi + 100 - round(sum(A.ownpi) OVER(), 2), 2)
        END AS votr,
        C.data_date_part
    FROM (
        SELECT  empresa AS reporting_soc,
                intergrupo AS counterparty_soc,
                tipo_ajuste AS adjustment_code,
                id_comb_satelite_22_shcb AS id_comb,
                sum(monto) AS monto,
                data_date_part
            FROM pro_app.essenneg.master_00051_parametria_automatica_satelite_22_shcb
            WHERE data_date_part = '{data_date_part}'
            GROUP BY empresa,
                intergrupo,
                tipo_ajuste,
                id_comb_satelite_22_shcb,
                data_date_part
    ) C
    LEFT JOIN (
        SELECT  intergrupo AS shcode,
                agrupacion_de_accionistas AS shname,
                total_acciones,
                isin,
                transaction_currency AS ic,
                pp AS osha,
                pp / total_acciones AS ppg,
                round((pp * 100 / total_acciones), 2) AS ownpi
            FROM (
                SELECT  intergrupo,
                        agrupacion_de_accionistas,
                        
                        total as total_acciones,
                        isin,
                        transaction_currency,
                        sum(total_acciones) AS pp
                    FROM (
                        SELECT  *,
                                sum(total_acciones) OVER() AS total,
                                '000000000000' AS ISIN
                            FROM pro_business.essenexp.Banco_Agrupado_22_shcb --pro_business.conrepexp.mayores_accionistas
                            WHERE data_date_part = '{data_date_part}'
                    ) A
                    GROUP BY intergrupo,
                        agrupacion_de_accionistas,
                        total,
                        isin,
                        transaction_currency
            ) A
    ) A
""")

print("INSERT completado en 'pro_app.essenneg.master_00051_satelite_22_shcb'")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 14. INSERT en pro_business.essenexp.master_00051_interfaz_satelite_22_shcb

# COMMAND ----------

spark.sql(f"""
INSERT INTO TABLE pro_business.essenexp.master_00051_interfaz_satelite_22_shcb REPLACE WHERE
 data_date_part = '{data_date_part}'  --viene del python
SELECT  reporting_soc AS reporting_soc,
        counterparty_soc AS counterparty_soc,
        adjustment_code AS adjustment_code,
        id_comb AS id_comb,
        cast(amount AS BIGINT) AS amount,
        shcode AS shcode,
        shname AS shname,
        isin AS isin,
        ic AS ic,
        cast(osha AS BIGINT) AS osha,
        cast(ownpi AS DECIMAL(10,2)) AS ownpi,
        cast(votr AS DECIMAL(10,2)) AS votr,
        
        concat_ws(
            '|',
            reporting_soc,
            counterparty_soc,
            adjustment_code,
            id_comb,
            cast(amount AS STRING),
            shcode,
            shname,
            isin,
            ic,
            cast(osha AS STRING),
            cast(ownpi AS STRING),
            cast(votr AS STRING)
        ) AS `REPORTING_SOC|COUNTERPARTY_SOC|ADJUSTMENT_CODE|ID_COMB|AMOUNT|SHCODE|SHNAME|ISIN|IC|OSHA|OWNPI|VOTR`,
        data_date_part, date_format(
  from_utc_timestamp(current_timestamp(), 'America/Santiago'),
  'yyyy-MM-dd HH:mm:ss.SSS'
) AS fecha_de_ejecucion
    FROM  pro_app.essenneg.master_00051_satelite_22_shcb
    WHERE data_date_part = '{data_date_part}'  --viene del python
""")

print("INSERT completado en 'pro_business.essenexp.master_00051_interfaz_satelite_22_shcb'")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 15. Verificacion final de tablas satelite

# COMMAND ----------

for tbl in [
    "pro_app.essenneg.master_00051_parametria_automatica_satelite_22_shcb",
    "pro_app.essenneg.master_00051_satelite_22_shcb",
    "pro_business.essenexp.master_00051_interfaz_satelite_22_shcb",
]:
    df_check = spark.sql(f"SELECT count(*) AS total FROM {tbl} WHERE data_date_part = '{data_date_part}'")
    total = df_check.collect()[0]["total"]
    print(f"[{tbl}] Registros para data_date_part = '{data_date_part}': {total}")
    