-- =============================================================================
-- Query Optimizada: Cierre Financiero Mes (empresa 00051) — Spark SQL
-- =============================================================================
-- Tablas involucradas:
--   nsg_cierre_financiero_mes:          3,454,317 filas
--   nsg_habiles:                            8,189 filas
--   nsg_cierre_financiero_mes_simulada:    10,139 filas
--   nsg_parametros_cierre_contable:       107,101 filas
-- =============================================================================
--
-- Optimizaciones aplicadas:
--
-- 1. CTE fecha_habil: La subconsulta a nsg_habiles se ejecutaba 2 veces
--    (una por cada rama del UNION ALL). Ahora se ejecuta una sola vez y
--    además aplica REPLACE dentro del CTE para evitar repetir la función.
--
-- 2. Orden de filtros WHERE: Los filtros de partición (data_date_part, empresa)
--    se colocan primero para aprovechar partition pruning en la tabla de 3.4M
--    filas, reduciendo drásticamente el volumen de datos escaneados.
--
-- 3. CTE parametros: Materializa el subquery de nsg_parametros_cierre_contable
--    (107K filas) filtrado por cod_empresa = '00051' una sola vez.
--
-- 4. BROADCAST hint: La tabla de parámetros filtrada (~pocos miles de filas)
--    es candidata ideal para broadcast join en Spark, evitando shuffle de la
--    tabla principal.
--
-- 5. IF reemplazado por CASE WHEN: Más portátil y estándar SQL.
--
-- 6. Transformaciones comunes (CAST/ROUND, literal 'BI00051') movidas al
--    SELECT final para evitar duplicación en ambas ramas del UNION ALL.
--
-- 7. Subquery anidado eliminado y reemplazado por CTE cierre, mejorando
--    legibilidad y permitiendo al optimizador materializar el resultado.
--
-- =============================================================================

WITH fecha_habil AS (
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
)

SELECT /*+ BROADCAST(parametros) */
       C.empresa,
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
       NOW()                                                    AS fecha_de_ejecucion,
       C.tipo_cuenta
  FROM cierre C
  LEFT JOIN parametros P
    ON C.cuenta_contable = P.cod_cuenta;
