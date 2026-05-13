-- =====================================================
-- QUERY DE VERIFICACIÓN: Original vs Optimizada
-- Compara que ambas queries producen EXACTAMENTE
-- el mismo resultado (excluye fecha_de_ejecucion)
-- Motor: Spark SQL
-- =====================================================

WITH
-- -------------------------------------------------------
-- CTE 1: Query ORIGINAL (sin fecha_de_ejecucion)
-- -------------------------------------------------------
original AS (
    SELECT  C.empresa,
            C.cargabal,
            C.cuenta_contable,
            C.tipo_informacion,
            C.tipo_ajuste,
            C.intergrupo,
            if(C.moneda = 'UF', 'CLF', C.moneda) AS moneda,
            C.monto,
            P.id_comb,
            '${fecha}' AS data_date_part,
            glosa_cuenta_contable,
            cmf,
            tipo_cuenta
    FROM (
        SELECT  empresa,
                cod_cargabal AS cargabal,
                cta_contable AS cuenta_contable,
                CASE
                  WHEN origen_part = 'SYP' THEN 'CONTABLE'
                  WHEN origen_part = 'ONL' THEN 'ONLINE'
                END AS tipo_informacion,
                'BI00051' AS tipo_ajuste,
                cod_intergrupo AS intergrupo,
                des_moneda AS moneda,
                cast(round(sdo_acum_peso, 0) AS BIGINT) AS monto,
                tipo_cuenta
          FROM pro_business.nsgexp.nsg_cierre_financiero_mes
          WHERE data_date_part = '${dia_de_cierre}'
            AND origen_part IN ('SYP', 'ONL')
            AND empresa = '00051'
            AND fecha_datos = replace(
                  (SELECT ultimo_habil
                     FROM pro_business.nsgexp.nsg_habiles
                    WHERE ultimo_calendario = '${fecha}'
                    LIMIT 1), '-', '')
            AND sdo_acum_peso != 0

        UNION ALL

        SELECT  empresa,
                cod_cargabal AS cargabal,
                cta_contable AS cuenta_contable,
                'SIMULACION' AS tipo_informacion,
                'BI00051' AS tipo_ajuste,
                cod_intergrupo AS intergrupo,
                des_moneda AS moneda,
                cast(round(sdo_acum_peso, 0) AS BIGINT) AS monto,
                tipo_cuenta
          FROM pro_business.nsgexp.nsg_cierre_financiero_mes_simulada
          WHERE data_date_part = '${dia_de_cierre}'
            AND fecha_datos = replace(
                  (SELECT ultimo_habil
                     FROM pro_business.nsgexp.nsg_habiles
                    WHERE ultimo_calendario = '${fecha}'
                    LIMIT 1), '-', '')
            AND origen_part = 'SIM'
            AND empresa = '00051'
            AND sdo_acum_peso != 0
    ) C
    LEFT JOIN (
        SELECT  cod_cuenta,
                glosa AS glosa_cuenta_contable,
                cod_hijo_master AS id_comb,
                cod_cmf AS cmf
          FROM pro_business.nsgexp.nsg_parametros_cierre_contable
          WHERE cod_empresa = '00051'
    ) P
      ON C.cuenta_contable = P.cod_cuenta
),

-- -------------------------------------------------------
-- CTE 2: Query OPTIMIZADA (sin fecha_de_ejecucion)
-- -------------------------------------------------------
fecha_habil AS (
    SELECT REPLACE(ultimo_habil, '-', '') AS fecha_datos_habil
      FROM pro_business.nsgexp.nsg_habiles
     WHERE ultimo_calendario = '${fecha}'
     LIMIT 1
),

parametros AS (
    SELECT cod_cuenta,
           glosa            AS glosa_cuenta_contable,
           cod_hijo_master  AS id_comb,
           cod_cmf          AS cmf
      FROM pro_business.nsgexp.nsg_parametros_cierre_contable
     WHERE cod_empresa = '00051'
),

cierre AS (
    SELECT empresa,
           cod_cargabal   AS cargabal,
           cta_contable   AS cuenta_contable,
           CASE
               WHEN origen_part = 'SYP' THEN 'CONTABLE'
               WHEN origen_part = 'ONL' THEN 'ONLINE'
           END            AS tipo_informacion,
           cod_intergrupo AS intergrupo,
           des_moneda     AS moneda,
           sdo_acum_peso,
           tipo_cuenta
      FROM pro_business.nsgexp.nsg_cierre_financiero_mes
     WHERE data_date_part = '${dia_de_cierre}'
       AND empresa        = '00051'
       AND origen_part   IN ('SYP', 'ONL')
       AND fecha_datos    = (SELECT fecha_datos_habil FROM fecha_habil)
       AND sdo_acum_peso != 0

    UNION ALL

    SELECT empresa,
           cod_cargabal   AS cargabal,
           cta_contable   AS cuenta_contable,
           'SIMULACION'   AS tipo_informacion,
           cod_intergrupo AS intergrupo,
           des_moneda     AS moneda,
           sdo_acum_peso,
           tipo_cuenta
      FROM pro_business.nsgexp.nsg_cierre_financiero_mes_simulada
     WHERE data_date_part = '${dia_de_cierre}'
       AND empresa        = '00051'
       AND origen_part    = 'SIM'
       AND fecha_datos    = (SELECT fecha_datos_habil FROM fecha_habil)
       AND sdo_acum_peso != 0
),

optimizada AS (
    SELECT C.empresa,
           C.cargabal,
           C.cuenta_contable,
           C.tipo_informacion,
           'BI00051'                                                AS tipo_ajuste,
           C.intergrupo,
           CASE WHEN C.moneda = 'UF' THEN 'CLF' ELSE C.moneda END  AS moneda,
           CAST(ROUND(C.sdo_acum_peso, 0) AS BIGINT)               AS monto,
           P.id_comb,
           '${fecha}'                                               AS data_date_part,
           P.glosa_cuenta_contable,
           P.cmf,
           C.tipo_cuenta
      FROM cierre C
      LEFT JOIN parametros P
        ON C.cuenta_contable = P.cod_cuenta
),

-- -------------------------------------------------------
-- PASO A: Comparación de conteo total de filas
-- -------------------------------------------------------
conteo AS (
    SELECT
        (SELECT count(*) FROM original)   AS filas_original,
        (SELECT count(*) FROM optimizada) AS filas_optimizada
),

-- -------------------------------------------------------
-- PASO B: EXCEPT en ambas direcciones
-- Detecta filas presentes en una query pero no en la otra
-- -------------------------------------------------------
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
diferencias AS (
    SELECT
        (SELECT count(*) FROM solo_en_original)   AS filas_solo_original,
        (SELECT count(*) FROM solo_en_optimizada) AS filas_solo_optimizada
),

-- -------------------------------------------------------
-- PASO C: Checksum global por hash de fila
-- Genera un hash MD5 por cada fila y luego un checksum
-- agregado ordenado para comparar conjuntos completos
-- (detecta diferencias incluso con filas duplicadas)
-- -------------------------------------------------------
hash_original AS (
    SELECT md5(concat_ws('||',
        coalesce(cast(empresa              AS STRING), '__NULL__'),
        coalesce(cast(cargabal             AS STRING), '__NULL__'),
        coalesce(cast(cuenta_contable      AS STRING), '__NULL__'),
        coalesce(cast(tipo_informacion     AS STRING), '__NULL__'),
        coalesce(cast(tipo_ajuste          AS STRING), '__NULL__'),
        coalesce(cast(intergrupo           AS STRING), '__NULL__'),
        coalesce(cast(moneda               AS STRING), '__NULL__'),
        coalesce(cast(monto                AS STRING), '__NULL__'),
        coalesce(cast(id_comb              AS STRING), '__NULL__'),
        coalesce(cast(data_date_part       AS STRING), '__NULL__'),
        coalesce(cast(glosa_cuenta_contable AS STRING), '__NULL__'),
        coalesce(cast(cmf                  AS STRING), '__NULL__'),
        coalesce(cast(tipo_cuenta          AS STRING), '__NULL__')
    )) AS row_hash
    FROM original
),
hash_optimizada AS (
    SELECT md5(concat_ws('||',
        coalesce(cast(empresa              AS STRING), '__NULL__'),
        coalesce(cast(cargabal             AS STRING), '__NULL__'),
        coalesce(cast(cuenta_contable      AS STRING), '__NULL__'),
        coalesce(cast(tipo_informacion     AS STRING), '__NULL__'),
        coalesce(cast(tipo_ajuste          AS STRING), '__NULL__'),
        coalesce(cast(intergrupo           AS STRING), '__NULL__'),
        coalesce(cast(moneda               AS STRING), '__NULL__'),
        coalesce(cast(monto                AS STRING), '__NULL__'),
        coalesce(cast(id_comb              AS STRING), '__NULL__'),
        coalesce(cast(data_date_part       AS STRING), '__NULL__'),
        coalesce(cast(glosa_cuenta_contable AS STRING), '__NULL__'),
        coalesce(cast(cmf                  AS STRING), '__NULL__'),
        coalesce(cast(tipo_cuenta          AS STRING), '__NULL__')
    )) AS row_hash
    FROM optimizada
),
checksum_original AS (
    SELECT md5(cast(sort_array(collect_list(row_hash)) AS STRING)) AS checksum_total
    FROM hash_original
),
checksum_optimizada AS (
    SELECT md5(cast(sort_array(collect_list(row_hash)) AS STRING)) AS checksum_total
    FROM hash_optimizada
)

-- -------------------------------------------------------
-- RESULTADO FINAL: Veredicto de equivalencia
-- -------------------------------------------------------
SELECT
    '--- CONTEO DE FILAS ---'                       AS seccion_1,
    co.filas_original,
    co.filas_optimizada,
    (co.filas_original = co.filas_optimizada)        AS conteo_coincide,

    '--- DIFERENCIAS (EXCEPT) ---'                  AS seccion_2,
    d.filas_solo_original,
    d.filas_solo_optimizada,
    (d.filas_solo_original = 0
     AND d.filas_solo_optimizada = 0)                AS sin_diferencias_except,

    '--- CHECKSUM GLOBAL ---'                       AS seccion_3,
    cko.checksum_total                               AS checksum_original,
    ckop.checksum_total                              AS checksum_optimizada,
    (cko.checksum_total = ckop.checksum_total)       AS checksum_coincide,

    '--- VEREDICTO ---'                             AS seccion_4,
    CASE
        WHEN co.filas_original = co.filas_optimizada
             AND d.filas_solo_original    = 0
             AND d.filas_solo_optimizada  = 0
             AND cko.checksum_total = ckop.checksum_total
        THEN 'EQUIVALENTES - Las queries producen EXACTAMENTE el mismo resultado'
        ELSE 'DIFERENTES  - Las queries NO producen el mismo resultado. Revisar filas_solo_original y filas_solo_optimizada'
    END AS veredicto

FROM      conteo              co
CROSS JOIN diferencias         d
CROSS JOIN checksum_original   cko
CROSS JOIN checksum_optimizada ckop
;


-- =====================================================
-- QUERY AUXILIAR: Detalle de filas diferentes
-- Ejecutar solo si el veredicto es 'DIFERENTES'
-- para inspeccionar las filas que no coinciden.
-- =====================================================

-- Filas que están en ORIGINAL pero NO en OPTIMIZADA:
-- SELECT 'SOLO_EN_ORIGINAL' AS origen, o.*
-- FROM solo_en_original o
-- LIMIT 100;

-- Filas que están en OPTIMIZADA pero NO en ORIGINAL:
-- SELECT 'SOLO_EN_OPTIMIZADA' AS origen, p.*
-- FROM solo_en_optimizada p
-- LIMIT 100;
