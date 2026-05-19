-- ============================================================
-- QUERY DE VERIFICACION DE EQUIVALENCIA (Spark SQL)
-- Tabla: pro_app.conrepneg.master_00051_satelite_22_shcb
-- ============================================================
--
-- Comprueba que la query original y la query optimizada producen
-- EXACTAMENTE el mismo resultado. Usa 6 niveles de validacion:
--
--   1. Comparacion de conteo de filas
--   2. EXCEPT bidireccional (original -> optimizada y viceversa)
--   3. Hash SHA-256 por fila con manejo determinista de NULLs
--   4. Hash global ordenado para comparacion de conjuntos completos
--   5. Auditoria de NULLs por columna
--   6. Veredicto consolidado PASS/FAIL
--
-- Prerequisito: SET fecha_de_cierre = '2026-05-19'; (o la fecha correspondiente)
-- ============================================================

WITH
original AS (
    SELECT  reporting_soc AS empresa,
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
            ) AS detalle_concatenado,
            data_date_part
    FROM pro_app.conrepneg.master_00051_satelite_22_shcb
    WHERE data_date_part = fecha_de_cierre
),
optimizada AS (
    SELECT  reporting_soc AS empresa,
            concat_ws(
                '|',
                reporting_soc,
                counterparty_soc,
                adjustment_code,
                id_comb,
                amount,
                shcode,
                shname,
                isin,
                ic,
                osha,
                ownpi,
                votr
            ) AS detalle_concatenado,
            data_date_part
    FROM pro_app.conrepneg.master_00051_satelite_22_shcb
    WHERE data_date_part = '${fecha_de_cierre}'
),
-- Check 1: Conteo de filas
conteo AS (
    SELECT
        (SELECT count(*) FROM original)   AS filas_original,
        (SELECT count(*) FROM optimizada) AS filas_optimizada
),
-- Check 2: Filas exclusivas en cada resultado (EXCEPT bidireccional)
solo_en_original AS (
    SELECT * FROM original
    EXCEPT
    SELECT * FROM optimizada
),
solo_en_optimizada AS (
    SELECT * FROM optimizada
    EXCEPT
    SELECT * FROM original
),
diferencias_except AS (
    SELECT
        (SELECT count(*) FROM solo_en_original)   AS filas_solo_en_original,
        (SELECT count(*) FROM solo_en_optimizada)  AS filas_solo_en_optimizada
),
-- Check 3: Hash SHA-256 por fila con manejo de NULLs
hash_original AS (
    SELECT
        sha2(
            concat_ws(
                '||',
                coalesce(empresa,              '__NULL__'),
                coalesce(detalle_concatenado,   '__NULL__'),
                coalesce(cast(data_date_part AS STRING), '__NULL__')
            ),
            256
        ) AS hash_fila
    FROM original
),
hash_optimizada AS (
    SELECT
        sha2(
            concat_ws(
                '||',
                coalesce(empresa,              '__NULL__'),
                coalesce(detalle_concatenado,   '__NULL__'),
                coalesce(cast(data_date_part AS STRING), '__NULL__')
            ),
            256
        ) AS hash_fila
    FROM optimizada
),
-- Check 4: Hash global ordenado
hash_global AS (
    SELECT
        (SELECT sha2(concat_ws(',', collect_list(hash_fila)), 256)
         FROM (SELECT hash_fila FROM hash_original ORDER BY hash_fila)) AS hash_global_original,
        (SELECT sha2(concat_ws(',', collect_list(hash_fila)), 256)
         FROM (SELECT hash_fila FROM hash_optimizada ORDER BY hash_fila)) AS hash_global_optimizada
),
-- Check 5: Auditoria de NULLs por columna
nulls_original AS (
    SELECT
        sum(CASE WHEN empresa IS NULL THEN 1 ELSE 0 END)              AS nulls_empresa_orig,
        sum(CASE WHEN detalle_concatenado IS NULL THEN 1 ELSE 0 END)  AS nulls_detalle_orig,
        sum(CASE WHEN data_date_part IS NULL THEN 1 ELSE 0 END)       AS nulls_fecha_orig
    FROM original
),
nulls_optimizada AS (
    SELECT
        sum(CASE WHEN empresa IS NULL THEN 1 ELSE 0 END)              AS nulls_empresa_opt,
        sum(CASE WHEN detalle_concatenado IS NULL THEN 1 ELSE 0 END)  AS nulls_detalle_opt,
        sum(CASE WHEN data_date_part IS NULL THEN 1 ELSE 0 END)       AS nulls_fecha_opt
    FROM optimizada
)
-- Check 6: Veredicto consolidado
SELECT
    CASE
        WHEN c.filas_original = c.filas_optimizada
             AND d.filas_solo_en_original = 0
             AND d.filas_solo_en_optimizada = 0
             AND h.hash_global_original = h.hash_global_optimizada
        THEN 'PASS - Los resultados son IDENTICOS'
        ELSE 'FAIL - Se detectaron DIFERENCIAS'
    END AS verificacion,
    c.filas_original,
    c.filas_optimizada,
    CASE
        WHEN c.filas_original = c.filas_optimizada
        THEN 'OK - Mismo numero de filas'
        ELSE concat('DIFERENCIA: ', cast(c.filas_original - c.filas_optimizada AS STRING), ' filas')
    END AS check_conteo_filas,
    d.filas_solo_en_original,
    d.filas_solo_en_optimizada,
    CASE
        WHEN d.filas_solo_en_original = 0 AND d.filas_solo_en_optimizada = 0
        THEN 'OK - Sin filas exclusivas en ninguno'
        ELSE concat(
            'DIFERENCIA: ',
            cast(d.filas_solo_en_original AS STRING), ' filas solo en original, ',
            cast(d.filas_solo_en_optimizada AS STRING), ' filas solo en optimizada'
        )
    END AS check_except,
    h.hash_global_original,
    h.hash_global_optimizada,
    CASE
        WHEN h.hash_global_original = h.hash_global_optimizada
        THEN 'OK - Hash global identico'
        ELSE 'DIFERENCIA: Los hashes globales no coinciden'
    END AS check_hash,
    no.nulls_empresa_orig,      nop.nulls_empresa_opt,
    no.nulls_detalle_orig,      nop.nulls_detalle_opt,
    no.nulls_fecha_orig,        nop.nulls_fecha_opt,
    CASE
        WHEN no.nulls_empresa_orig = nop.nulls_empresa_opt
             AND no.nulls_detalle_orig = nop.nulls_detalle_opt
             AND no.nulls_fecha_orig = nop.nulls_fecha_opt
        THEN 'OK - Mismo patron de NULLs'
        ELSE 'DIFERENCIA: Distinta cantidad de NULLs por columna'
    END AS check_nulls
FROM conteo c
CROSS JOIN diferencias_except d
CROSS JOIN hash_global h
CROSS JOIN nulls_original no
CROSS JOIN nulls_optimizada nop;
