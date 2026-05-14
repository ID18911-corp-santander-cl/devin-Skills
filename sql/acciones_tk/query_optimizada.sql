-- =============================================================================
-- QUERY OPTIMIZADA - Notas de Crédito (NC MAN + NC OP)
-- Motor: Spark SQL
-- =============================================================================
-- RESUMEN DE OPTIMIZACIONES APLICADAS:
--   1. Eliminadas subconsultas (SELECT * FROM ...) innecesarias en tablas nsgtemp
--   2. CTEs globales para PED y SUC (compartidas por los 3 bloques UNION ALL)
--   3. LEFT JOIN -> INNER JOIN donde WHERE anulaba el LEFT implícitamente
--   4. Reorden de JOINs para filtrar tempranamente
--   5. Proyección mínima en tablas grandes + partition pruning (data_date_part)
--   6. Operador unario negativo (-valor) en lugar de valor*(-1)
--   7. Precálculo de concat(trim(estado),trim(glosa1)) en CTE tk3_prep (SELECT 3)
--   8. Eliminados JOINs innecesarios a tradch y subsch en subconsulta t2 (SELECT 3)
--   9. Simplificación de lógica CASE -> IF/IN (SELECT 3)
--  10. Subconsulta t2 simplificada: solo trad con filtro br='01' (SELECT 3)
-- =============================================================================

WITH
-- CTEs compartidas: evitan repetir las mismas subconsultas en cada bloque UNION ALL
ped AS (
    SELECT penumpue, penumsuc
    FROM pro_curated.bu_per_hist.pedt021
    WHERE data_date_part = '${fecha}'
),
suc AS (
    SELECT tccofici, tccreal1
    FROM pro_curated.bu_tc_hist.tcdt050
    WHERE data_date_part = '${fecha}'
),
-- CTE para SELECT 3: precalcula estado_glosa y aplica filtro br='01'
tk3_prep AS (
    SELECT
        br, accountno, numfact, numnot,
        subtotal, comision, derechos, otrgastos, iva,
        fechaimpr, fechaproceso, fecha_liquidacion,
        CONCAT(TRIM(estado), TRIM(glosa1)) AS estado_glosa
    FROM pro_app.nsgtemp.nsg_acciones_tk3
    WHERE br = '01'
)

-- =============================================================================
-- BLOQUE 1: NC MAN - NO simultánea (tk4 + tk2)
-- =============================================================================
SELECT
    tk6.codigo_sucursal                   AS cod_suc_orden,
    COALESCE(suc.tccreal1, '')            AS cod_region_orden,
    tk5.trad_sacc                         AS cod_agte_orden,
    tk6.tradname                          AS nombre_agte_orden,
    tk5.port                              AS cod_agte_dueno,
    tk8.codigo_sucursal                   AS cod_suc_dueno,
    tk8.nombre_sucursal                   AS nombre_suc_dueno,
    tk5.trad_sacc                         AS cod_agte_corredora,
    tk6.tradname                          AS nombre_agte_corredora,
    tk4.numnot                            AS num_fact_o_nc,
    tk5.cno                               AS rut,
    tk5.accttitle                         AS nombre_cliente,
    tk4.accountno                         AS cuenta,
    IF(tk2.ps = 'P', -tk4.subtotal, 0)   AS monto_compras,
    IF(tk2.ps = 'S', -tk4.subtotal, 0)   AS monto_ventas,
    -tk4.comision                         AS comision,
    -tk4.derechos                         AS derechos,
    -tk4.otrgastos                        AS gastos,
    IF(tk2.ps = 'P',
       -(tk4.subtotal + tk4.comision + tk4.derechos + tk4.otrgastos + tk4.iva),
       -(tk4.subtotal - tk4.comision - tk4.derechos - tk4.otrgastos - tk4.iva)
    )                                     AS total,
    IF(tk2.prodtype = 'SD', 'RV', tk2.prodtype) AS tipo_op,
    COALESCE(tk5.desc_tipocliente, '')    AS tipo_cliente,
    tk5.descr                             AS segmento,
    DATE_FORMAT(tk4.fechaimpr, 'yyyyMMdd')    AS fechaimpr,
    DATE_FORMAT(tk4.fechaproceso, 'yyyyMMdd') AS fecha_proceso,
    tk4.numfact                           AS factura_anula,
    DATE_FORMAT(tk2.fechaimpr, 'yyyyMMdd')    AS fecha_factura_anula,
    'NC MAN'                              AS tipo_factura,
    'NO'                                  AS simultanea,
    DATE_FORMAT(tk4.settdate, 'yyyyMMdd')     AS fecha_liquidacion
FROM pro_app.nsgtemp.nsg_acciones_tk4 tk4
INNER JOIN pro_app.nsgtemp.nsg_acciones_tk2 tk2
    ON  tk4.br      = tk2.br
    AND tk4.numfact = tk2.numfact
    AND tk2.fechaimpr IS NOT NULL
LEFT JOIN pro_app.nsgtemp.nsg_acciones_tk5 tk5
    ON  tk4.br        = tk5.br
    AND tk4.accountno = tk5.accountno
INNER JOIN pro_app.nsgtemp.nsg_acciones_tk8 tk8
    ON tk5.port = tk8.port
LEFT JOIN pro_app.nsgtemp.nsg_acciones_tk6 tk6
    ON  tk5.trad_sacc = tk6.trad
    AND tk5.br        = tk6.br
LEFT JOIN ped
    ON tk5.trad_sacc = ped.penumpue
LEFT JOIN suc
    ON ped.penumsuc = suc.tccofici
WHERE tk4.br = '01'

UNION ALL

-- =============================================================================
-- BLOQUE 2: NC MAN - SI simultánea (tk4 + tk1, filtro ANTICIPO)
-- =============================================================================
SELECT
    tk6.codigo_sucursal                   AS cod_suc_orden,
    COALESCE(suc.tccreal1, '')            AS cod_region_orden,
    tk5.trad_sacc                         AS cod_agte_orden,
    tk6.tradname                          AS nombre_agte_orden,
    tk5.port                              AS cod_agte_dueno,
    tk8.codigo_sucursal                   AS cod_suc_dueno,
    tk8.nombre_sucursal                   AS nombre_suc_dueno,
    tk5.trad_sacc                         AS cod_agte_corredora,
    tk6.tradname                          AS nombre_agte_corredora,
    tk4.numnot                            AS num_fact_o_nc,
    tk5.cno                               AS rut,
    tk5.accttitle                         AS nombre_cliente,
    tk4.accountno                         AS cuenta,
    IF(tk1.ps = 'P', -tk4.subtotal, 0)   AS monto_compras,
    IF(tk1.ps = 'S', -tk4.subtotal, 0)   AS monto_ventas,
    -tk4.comision                         AS comision,
    -tk4.derechos                         AS derechos,
    -tk4.otrgastos                        AS gastos,
    IF(tk1.ps = 'P',
       -(tk4.subtotal + tk4.comision + tk4.derechos + tk4.otrgastos + tk4.iva),
       -(tk4.subtotal - tk4.comision - tk4.derechos - tk4.otrgastos - tk4.iva)
    )                                     AS total,
    IF(tk1.prodtype = 'SD', 'RV', tk1.prodtype) AS tipo_op,
    COALESCE(tk5.desc_tipocliente, '')    AS tipo_cliente,
    tk5.descr                             AS segmento,
    DATE_FORMAT(tk4.fechaimpr, 'yyyyMMdd')    AS fechaimpr,
    DATE_FORMAT(tk4.fechaproceso, 'yyyyMMdd') AS fecha_proceso,
    tk4.numfact                           AS factura_anula,
    DATE_FORMAT(tk1.fechaimpr, 'yyyyMMdd')    AS fecha_factura_anula,
    'NC MAN'                              AS tipo_factura,
    'SI'                                  AS simultanea,
    DATE_FORMAT(tk4.settdate, 'yyyyMMdd')     AS fecha_liquidacion
FROM pro_app.nsgtemp.nsg_acciones_tk4 tk4
INNER JOIN pro_app.nsgtemp.nsg_acciones_tk1 tk1
    ON  tk4.br      = tk1.br
    AND tk4.numfact = tk1.numfact
    AND tk1.fechaimpr IS NOT NULL
LEFT JOIN pro_app.nsgtemp.nsg_acciones_tk5 tk5
    ON  tk4.br        = tk5.br
    AND tk4.accountno = tk5.accountno
INNER JOIN pro_app.nsgtemp.nsg_acciones_tk8 tk8
    ON tk5.port = tk8.port
LEFT JOIN pro_app.nsgtemp.nsg_acciones_tk6 tk6
    ON  tk5.trad_sacc = tk6.trad
    AND tk5.br        = tk6.br
LEFT JOIN ped
    ON tk5.trad_sacc = ped.penumpue
LEFT JOIN suc
    ON ped.penumsuc = suc.tccofici
WHERE tk4.br = '01'
    AND tk4.glosa1 LIKE '%ANTICIPO%'

UNION ALL

-- =============================================================================
-- BLOQUE 3: NC OP (tk3 + tk1 + t2)
-- =============================================================================
SELECT
    tk6.codigo_sucursal                                    AS cod_suc_orden,
    COALESCE(suc.tccreal1, '')                             AS cod_region_orden,
    tk1.trad                                               AS cod_agte_orden,
    t2.tradname                                            AS nombre_agte_orden,
    tk5.port                                               AS cod_agte_dueno,
    tk8.codigo_sucursal                                    AS cod_suc_dueno,
    tk8.nombre_sucursal                                    AS nombre_suc_dueno,
    tk5.trad_sacc                                          AS cod_agte_corredora,
    tk6.tradname                                           AS nombre_agte_corredora,
    tk3.numnot                                             AS num_fact_o_nc,
    tk5.cno                                                AS rut,
    tk5.accttitle                                          AS nombre_cliente,
    tk3.accountno                                          AS cuenta,
    IF(tk1.ps = 'P', -tk3.subtotal, 0)                    AS monto_compras,
    IF(tk1.ps = 'S', -tk3.subtotal, 0)                    AS monto_ventas,
    IF(tk3.estado_glosa IN ('IG','GG'), 0, -tk3.comision)   AS comision,
    IF(tk3.estado_glosa IN ('IG','GG'), 0, -tk3.derechos)   AS derechos,
    IF(tk3.estado_glosa IN ('IG','GG'), 0, -tk3.otrgastos)  AS gastos,
    IF(tk1.ps = 'P',
        -(tk3.subtotal
          + IF(tk3.estado_glosa IN ('IG','GG'), 0, tk3.comision)
          + IF(tk3.estado_glosa IN ('IG','GG'), 0, tk3.derechos)
          + IF(tk3.estado_glosa IN ('IG','GG'), 0, tk3.otrgastos)
          + IF(tk3.estado_glosa IN ('IG','GG'), 0, tk3.iva)),
        -(tk3.subtotal
          - IF(tk3.estado_glosa IN ('IG','GG'), 0, tk3.comision)
          - IF(tk3.estado_glosa IN ('IG','GG'), 0, tk3.derechos)
          - IF(tk3.estado_glosa IN ('IG','GG'), 0, tk3.otrgastos)
          - IF(tk3.estado_glosa IN ('IG','GG'), 0, tk3.iva))
    )                                                      AS total,
    IF(tk1.prodtype = 'SD', 'RV', tk1.prodtype)            AS tipo_op,
    COALESCE(tk5.desc_tipocliente, '')                     AS tipo_cliente,
    tk5.descr                                              AS segmento,
    DATE_FORMAT(tk3.fechaimpr, 'yyyyMMdd')                 AS fechaimpr,
    DATE_FORMAT(tk3.fechaproceso, 'yyyyMMdd')              AS fecha_proceso,
    tk3.numfact                                            AS factura_anula,
    DATE_FORMAT(tk1.fechaimpr, 'yyyyMMdd')                 AS fecha_factura_anula,
    'NC OP'                                                AS tipo_factura,
    IF(TRIM(tk1.cond_liquidacion) IN ('CN','PM','PH'), 'NO', 'SI') AS simultanea,
    DATE_FORMAT(tk3.fecha_liquidacion, 'yyyyMMdd')         AS fecha_liquidacion
FROM tk3_prep tk3
LEFT JOIN pro_app.nsgtemp.nsg_acciones_tk5 tk5
    ON  tk3.br        = tk5.br
    AND tk3.accountno = tk5.accountno
INNER JOIN pro_app.nsgtemp.nsg_acciones_tk8 tk8
    ON tk5.port = tk8.port
LEFT JOIN pro_app.nsgtemp.nsg_acciones_tk6 tk6
    ON tk5.trad_sacc = tk6.trad
INNER JOIN pro_app.nsgtemp.nsg_acciones_tk1 tk1
    ON  tk3.br      = tk1.br
    AND tk3.numfact = tk1.numfact
LEFT JOIN (
    SELECT tradname, trad
    FROM pro_curated.bu_neh_hist.trad
    WHERE data_date_part = '${fecha}'
      AND br = '01'
) t2
    ON t2.trad = tk1.trad
LEFT JOIN ped
    ON tk1.trad = ped.penumpue
LEFT JOIN suc
    ON ped.penumsuc = suc.tccofici
WHERE tk1.fechaimpr IS NOT NULL
;
