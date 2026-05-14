-- =============================================================================
-- QUERY DE VERIFICACION: ORIGINAL vs OPTIMIZADA
-- Motor: Spark SQL
-- =============================================================================
-- INSTRUCCIONES:
--   1. Ejecuta esta query completa en Spark SQL.
--   2. Revisa la columna "resultado": si todos los checks muestran 'PASS',
--      las queries son equivalentes.
-- =============================================================================

WITH original_result AS (
    -- =======================================================================
    -- QUERY ORIGINAL (sin modificaciones)
    -- =======================================================================
    select
    tk6.codigo_sucursal as cod_suc_orden,
    coalesce(suc.tccreal1,'') as cod_region_orden,
    tk5.trad_sacc as cod_agte_orden,
    tk6.tradname as nombre_agte_orden,
    tk5.port cod_agte_dueno,
    tk8.codigo_sucursal as cod_suc_dueno,
    tk8.nombre_sucursal as nombre_suc_dueno,
    tk5.trad_sacc as cod_agte_corredora,
    tk6.tradname as nombre_agte_corredora,
    tk4.numnot as  num_fact_o_nc,
    tk5.cno as rut,
    tk5.accttitle as nombre_cliente,
    tk4.accountno as cuenta,
    if(tk2.ps = 'P', tk4.subtotal*(-1), 0) as monto_compras,
    if(tk2.ps = 'S', tk4.subtotal*(-1), 0) as monto_ventas,
    tk4.comision*(-1) comision,
    tk4.derechos*(-1) derechos,
    tk4.otrgastos*(-1) gastos,
    if(tk2.ps = 'P', (tk4.subtotal+tk4.comision+tk4.derechos+tk4.otrgastos+tk4.iva)*(-1),
                                (tk4.subtotal-tk4.comision-tk4.derechos-tk4.otrgastos-tk4.iva)*(-1)) as total,
    if(tk2.prodtype = 'SD', 'RV', tk2.prodtype) as tipo_op,
    coalesce(tk5.desc_tipocliente,'') as tipo_cliente,
    tk5.descr as segmento,
    date_format(tk4.fechaimpr,'yyyyMMdd') as fechaimpr,
    date_format(tk4.fechaproceso,'yyyyMMdd') as fecha_proceso,
    tk4.numfact as factura_anula,
    date_format(tk2.fechaimpr,'yyyyMMdd') as fecha_factura_anula,
    'NC MAN' as tipo_factura,
    'NO' as simultanea,
    date_format(tk4.settdate,'yyyyMMdd') as fecha_liquidacion
    from (select * from pro_app.nsgtemp.nsg_acciones_tk4 ) tk4
    left join (select * from pro_app.nsgtemp.nsg_acciones_tk5) tk5
    on tk4.br = tk5.br
    and tk4.accountno = tk5.accountno
    inner join (select * from pro_app.nsgtemp.nsg_acciones_tk8 ) tk8
    on tk5.port = tk8.port
    left join (select * from pro_app.nsgtemp.nsg_acciones_tk6 ) tk6
    on tk5.trad_sacc = tk6.trad
    and tk5.br = tk6.br
    left join (select * from pro_app.nsgtemp.nsg_acciones_tk2 ) tk2
    on tk4.br = tk2.br
    and tk4.numfact = tk2.numfact
    left join (select penumpue, penumsuc from pro_curated.bu_per_hist.pedt021 where data_date_part = '${fecha}') PED
    on tk5.trad_sacc = PED.penumpue
    left join (select tccofici, tccreal1 from pro_curated.bu_tc_hist.tcdt050 where data_date_part = '${fecha}') SUC
    on PED.penumsuc = SUC.tccofici
    where tk4.br = '01'
    and tk2.fechaimpr is not null
    union all
    select
    tk6.codigo_sucursal as cod_suc_orden,
    coalesce(suc.tccreal1,'') as cod_region_orden,
    tk5.trad_sacc as cod_agte_orden,
    tk6.tradname as nombre_agte_orden,
    tk5.port cod_agte_dueno,
    tk8.codigo_sucursal as cod_suc_dueno,
    tk8.nombre_sucursal as nombre_suc_dueno,
    tk5.trad_sacc as cod_agte_corredora,
    tk6.tradname as nombre_agte_corredora,
    tk4.numnot as  num_fact_o_nc,
    tk5.cno as rut,
    tk5.accttitle as nombre_cliente,
    tk4.accountno as cuenta,
    if(tk1.ps = 'P', tk4.subtotal*(-1), 0) as monto_compras,
    if(tk1.ps = 'S', tk4.subtotal*(-1), 0) as monto_ventas,
    tk4.comision*(-1) comision,
    tk4.derechos*(-1) derechos,
    tk4.otrgastos*(-1) gastos,
    if(tk1.ps = 'P', (tk4.subtotal+tk4.comision+tk4.derechos+tk4.otrgastos+tk4.iva)*(-1),
                        (tk4.subtotal-tk4.comision-tk4.derechos-tk4.otrgastos-tk4.iva)*(-1)) as total,
    if(tk1.prodtype = 'SD', 'RV', tk1.prodtype) as tipo_op,
    coalesce(tk5.desc_tipocliente,'') as tipo_cliente,
    tk5.descr as segmento,
    date_format(tk4.fechaimpr,'yyyyMMdd') as fechaimpr,
    date_format(tk4.fechaproceso,'yyyyMMdd') as fecha_proceso,
    tk4.numfact  as factura_anula,
    date_format(tk1.fechaimpr,'yyyyMMdd') as fecha_factura_anula,
    'NC MAN' as tipo_factura,
    'SI' as simultanea,
    date_format(tk4.settdate,'yyyyMMdd') as fecha_liquidacion
    from (select * from pro_app.nsgtemp.nsg_acciones_tk4 ) tk4
    left join (select * from pro_app.nsgtemp.nsg_acciones_tk5 ) tk5
    on tk4.br = tk5.br
    and tk4.accountno = tk5.accountno
    inner join (select * from pro_app.nsgtemp.nsg_acciones_tk8 ) tk8
    on tk5.port = tk8.port
    left join (select * from pro_app.nsgtemp.nsg_acciones_tk6 ) tk6
    on tk5.trad_sacc = tk6.trad
    and tk5.br = tk6.br
    left join (select * from pro_app.nsgtemp.nsg_acciones_tk1 ) tk1
    on tk4.br = tk1.br
    and tk4.numfact = tk1.numfact
    left join (select penumpue, penumsuc  from pro_curated.bu_per_hist.pedt021 where data_date_part = '${fecha}') PED
    on tk5.trad_sacc = PED.penumpue
    left join (select tccofici, tccreal1 from pro_curated.bu_tc_hist.tcdt050 where data_date_part = '${fecha}') SUC
    on PED.penumsuc = SUC.tccofici
    where tk4.br = '01'
    and tk4.glosa1 like '%ANTICIPO%'
    and tk1.fechaimpr is not null
    union all
    select
    tk6.codigo_sucursal as cod_suc_orden,
    coalesce(suc.tccreal1,'') as cod_region_orden,
    tk1.trad as cod_agte_orden,
    t2.tradname as nombre_agte_orden,
    tk5.port as cod_agte_dueno,
    tk8.codigo_sucursal as cod_suc_dueno,
    tk8.nombre_sucursal as nombre_suc_dueno,
    tk5.trad_sacc as cod_agte_corredora,
    tk6.tradname as nombre_agte_corredora,
    tk3.numnot as num_fact_o_nc,
    tk5.cno as Rut,
    tk5.accttitle as Nombre_cliente,
    tk3.accountno as cuenta,
    if(tk1.ps = 'P', tk3.subtotal*(-1), 0) as monto_compras,
    if(tk1.ps =  'S', tk3.subtotal*(-1), 0) as monto_ventas,
    case when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'IG' then 0
    when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'GG' then 0
    else tk3.comision*(-1)
    end as comision,
    case when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'IG' then 0
    when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'GG' then 0
    else tk3.derechos*(-1)
    end as derechos,
    case when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'IG' then 0
    when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'GG' then 0
    else tk3.otrgastos*(-1)
    end as gastos,
    if(tk1.ps ='P', (tk3.subtotal
      + (case when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'IG' then 0
                when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'GG' then 0
             else tk3.comision
      end)
    + (case when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'IG' then 0
                when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'GG' then 0
             else tk3.derechos
          end)
    + (case when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'IG' then 0
                when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'GG' then 0
             else tk3.otrgastos
          end)
    + (case when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'IG' then 0
                when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'GG' then 0
             else tk3.iva
          end))*(-1)
    , (tk3.subtotal
    - (case when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'IG' then 0
                when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'GG' then 0
             else tk3.comision
      end)
    - (case when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'IG' then 0
                when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'GG' then 0
             else tk3.derechos
      end)
    - (case when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'IG' then 0
                when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'GG' then 0
             else tk3.otrgastos
      end)
    - (case when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'IG' then 0
                when concat(trim(tk3.estado),trim(tk3.glosa1)) = 'GG' then 0
             else tk3.iva
      end))*(-1)) as total,
    if(tk1.prodtype = 'SD', 'RV', tk1.prodtype) as tipo_op,
    coalesce(tk5.desc_tipocliente,'') as tipo_cliente,
    tk5.descr as segmento,
    date_format(tk3.fechaimpr,'yyyyMMdd') as fechaimpr,
    date_format(tk3.fechaproceso,'yyyyMMdd') as fecha_proceso,
    tk3.numfact as factura_anula ,
    date_format(tk1.fechaimpr,'yyyyMMdd') as fecha_factura_anula,
    'NC OP' as tipo_factura,
    case
    when trim(tk1.cond_liquidacion) = 'CN'then 'NO'
    when trim(tk1.cond_liquidacion) = 'PM' then 'NO'
    when trim(tk1.cond_liquidacion) = 'PH' then 'NO'
    else 'SI' end as simultanea,
    date_format(tk3.fecha_liquidacion,'yyyyMMdd') as fecha_liquidacion
    from (select * from pro_app.nsgtemp.nsg_acciones_tk3) tk3
    left join (select * from pro_app.nsgtemp.nsg_acciones_tk5 ) tk5
    on tk3.br  = tk5.br
    and tk3.accountno = tk5.accountno
    inner join (select * from pro_app.nsgtemp.nsg_acciones_tk8 ) tk8
    on tk5.port = tk8.port
    left join (select * from pro_app.nsgtemp.nsg_acciones_tk6 ) tk6
    on tk5.trad_sacc = tk6.trad
    left join (select * from pro_app.nsgtemp.nsg_acciones_tk1 ) tk1
    on tk3.br = tk1.br
    and tk3.numfact = tk1.numfact
    left join (select tradname, trad.trad
    from (select tradname,br,trad from pro_curated.bu_neh_hist.trad where data_date_part ='${fecha}') trad
    left join (select codigo_sucursal,br,trad trad_ch from pro_curated.bu_neh_hist.tradch where data_date_part ='${fecha}') tradch
    on trad.trad = tradch.trad_ch
    and trad.br = tradch.br
    and trad.trad = tradch.trad_ch
    left join (select codigo_sucursal,cod_region from pro_curated.bu_neh_hist.subsch where data_date_part = '${fecha}') subsch
    on tradch.codigo_sucursal = subsch.codigo_sucursal
    where trad.br = '01') t2
    on t2.trad = tk1.trad
    left join (select penumpue, penumsuc  from pro_curated.bu_per_hist.pedt021 where data_date_part = '${fecha}') PED
    on tk1.trad = PED.penumpue
    left join (select tccofici, tccreal1 from pro_curated.bu_tc_hist.tcdt050 where data_date_part = '${fecha}') SUC
    on PED.penumsuc = SUC.tccofici
    where tk3.br = '01'
    and tk1.fechaimpr is not null
),

optimized_result AS (
    -- =======================================================================
    -- QUERY OPTIMIZADA
    -- =======================================================================
    WITH
    ped_opt AS (
        SELECT penumpue, penumsuc
        FROM pro_curated.bu_per_hist.pedt021
        WHERE data_date_part = '${fecha}'
    ),
    suc_opt AS (
        SELECT tccofici, tccreal1
        FROM pro_curated.bu_tc_hist.tcdt050
        WHERE data_date_part = '${fecha}'
    ),
    tk3_prep AS (
        SELECT
            br, accountno, numfact, numnot,
            subtotal, comision, derechos, otrgastos, iva,
            fechaimpr, fechaproceso, fecha_liquidacion,
            CONCAT(TRIM(estado), TRIM(glosa1)) AS estado_glosa
        FROM pro_app.nsgtemp.nsg_acciones_tk3
        WHERE br = '01'
    )
    SELECT
        tk6.codigo_sucursal                   AS cod_suc_orden,
        COALESCE(suc_opt.tccreal1, '')        AS cod_region_orden,
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
    LEFT JOIN ped_opt
        ON tk5.trad_sacc = ped_opt.penumpue
    LEFT JOIN suc_opt
        ON ped_opt.penumsuc = suc_opt.tccofici
    WHERE tk4.br = '01'

    UNION ALL

    SELECT
        tk6.codigo_sucursal                   AS cod_suc_orden,
        COALESCE(suc_opt.tccreal1, '')        AS cod_region_orden,
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
    LEFT JOIN ped_opt
        ON tk5.trad_sacc = ped_opt.penumpue
    LEFT JOIN suc_opt
        ON ped_opt.penumsuc = suc_opt.tccofici
    WHERE tk4.br = '01'
        AND tk4.glosa1 LIKE '%ANTICIPO%'

    UNION ALL

    SELECT
        tk6.codigo_sucursal                                    AS cod_suc_orden,
        COALESCE(suc_opt.tccreal1, '')                         AS cod_region_orden,
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
    LEFT JOIN ped_opt
        ON tk1.trad = ped_opt.penumpue
    LEFT JOIN suc_opt
        ON ped_opt.penumsuc = suc_opt.tccofici
    WHERE tk1.fechaimpr IS NOT NULL
),

-- ============================================================================
-- CHECK 1: CONTEO DE FILAS
-- ============================================================================
cnt_original AS (
    SELECT COUNT(*) AS total_filas FROM original_result
),
cnt_optimized AS (
    SELECT COUNT(*) AS total_filas FROM optimized_result
),
check_conteo AS (
    SELECT
        'CHECK_1_CONTEO_FILAS' AS check_name,
        CASE
            WHEN o.total_filas = p.total_filas THEN 'PASS'
            ELSE 'FAIL'
        END AS resultado,
        CONCAT(
            'Original: ', CAST(o.total_filas AS STRING),
            ' | Optimizada: ', CAST(p.total_filas AS STRING),
            CASE
                WHEN o.total_filas = p.total_filas THEN ' | Conteos iguales'
                ELSE CONCAT(' | Diferencia: ', CAST(ABS(o.total_filas - p.total_filas) AS STRING), ' filas')
            END
        ) AS detalle
    FROM cnt_original o
    CROSS JOIN cnt_optimized p
),

-- ============================================================================
-- CHECK 2a: FILAS EN ORIGINAL QUE NO ESTAN EN OPTIMIZADA
-- ============================================================================
filas_solo_original AS (
    SELECT * FROM original_result
    EXCEPT
    SELECT * FROM optimized_result
),
cnt_solo_original AS (
    SELECT COUNT(*) AS cnt FROM filas_solo_original
),
check_except_orig AS (
    SELECT
        'CHECK_2a_FILAS_SOLO_EN_ORIGINAL' AS check_name,
        CASE
            WHEN c.cnt = 0 THEN 'PASS'
            ELSE 'FAIL'
        END AS resultado,
        CASE
            WHEN c.cnt = 0 THEN 'No hay filas en original ausentes en optimizada'
            ELSE CONCAT(CAST(c.cnt AS STRING), ' filas en original NO encontradas en optimizada')
        END AS detalle
    FROM cnt_solo_original c
),

-- ============================================================================
-- CHECK 2b: FILAS EN OPTIMIZADA QUE NO ESTAN EN ORIGINAL
-- ============================================================================
filas_solo_optimized AS (
    SELECT * FROM optimized_result
    EXCEPT
    SELECT * FROM original_result
),
cnt_solo_optimized AS (
    SELECT COUNT(*) AS cnt FROM filas_solo_optimized
),
check_except_opt AS (
    SELECT
        'CHECK_2b_FILAS_SOLO_EN_OPTIMIZADA' AS check_name,
        CASE
            WHEN c.cnt = 0 THEN 'PASS'
            ELSE 'FAIL'
        END AS resultado,
        CASE
            WHEN c.cnt = 0 THEN 'No hay filas en optimizada ausentes en original'
            ELSE CONCAT(CAST(c.cnt AS STRING), ' filas en optimizada NO encontradas en original')
        END AS detalle
    FROM cnt_solo_optimized c
),

-- ============================================================================
-- CHECK 3: VERIFICACION DE AGREGADOS NUMERICOS POR tipo_factura Y simultanea
-- ============================================================================
agg_original AS (
    SELECT
        COALESCE(CAST(tipo_factura AS STRING), '__NULL__') AS tipo_factura,
        COALESCE(CAST(simultanea AS STRING), '__NULL__')   AS simultanea,
        COUNT(*)                                           AS cnt_filas,
        COALESCE(SUM(CAST(monto_compras AS DOUBLE)), 0)    AS sum_monto_compras,
        COALESCE(SUM(CAST(monto_ventas  AS DOUBLE)), 0)    AS sum_monto_ventas,
        COALESCE(SUM(CAST(comision      AS DOUBLE)), 0)    AS sum_comision,
        COALESCE(SUM(CAST(derechos      AS DOUBLE)), 0)    AS sum_derechos,
        COALESCE(SUM(CAST(gastos        AS DOUBLE)), 0)    AS sum_gastos,
        COALESCE(SUM(CAST(total         AS DOUBLE)), 0)    AS sum_total
    FROM original_result
    GROUP BY
        COALESCE(CAST(tipo_factura AS STRING), '__NULL__'),
        COALESCE(CAST(simultanea AS STRING), '__NULL__')
),
agg_optimized AS (
    SELECT
        COALESCE(CAST(tipo_factura AS STRING), '__NULL__') AS tipo_factura,
        COALESCE(CAST(simultanea AS STRING), '__NULL__')   AS simultanea,
        COUNT(*)                                           AS cnt_filas,
        COALESCE(SUM(CAST(monto_compras AS DOUBLE)), 0)    AS sum_monto_compras,
        COALESCE(SUM(CAST(monto_ventas  AS DOUBLE)), 0)    AS sum_monto_ventas,
        COALESCE(SUM(CAST(comision      AS DOUBLE)), 0)    AS sum_comision,
        COALESCE(SUM(CAST(derechos      AS DOUBLE)), 0)    AS sum_derechos,
        COALESCE(SUM(CAST(gastos        AS DOUBLE)), 0)    AS sum_gastos,
        COALESCE(SUM(CAST(total         AS DOUBLE)), 0)    AS sum_total
    FROM optimized_result
    GROUP BY
        COALESCE(CAST(tipo_factura AS STRING), '__NULL__'),
        COALESCE(CAST(simultanea AS STRING), '__NULL__')
),
agg_diff AS (
    SELECT
        COALESCE(o.tipo_factura, p.tipo_factura)           AS tipo_factura,
        COALESCE(o.simultanea, p.simultanea)               AS simultanea,
        COALESCE(o.cnt_filas, 0)           AS orig_cnt,
        COALESCE(p.cnt_filas, 0)           AS opt_cnt,
        COALESCE(o.sum_monto_compras, 0)   AS orig_monto_compras,
        COALESCE(p.sum_monto_compras, 0)   AS opt_monto_compras,
        COALESCE(o.sum_monto_ventas, 0)    AS orig_monto_ventas,
        COALESCE(p.sum_monto_ventas, 0)    AS opt_monto_ventas,
        COALESCE(o.sum_comision, 0)        AS orig_comision,
        COALESCE(p.sum_comision, 0)        AS opt_comision,
        COALESCE(o.sum_derechos, 0)        AS orig_derechos,
        COALESCE(p.sum_derechos, 0)        AS opt_derechos,
        COALESCE(o.sum_gastos, 0)          AS orig_gastos,
        COALESCE(p.sum_gastos, 0)          AS opt_gastos,
        COALESCE(o.sum_total, 0)           AS orig_total,
        COALESCE(p.sum_total, 0)           AS opt_total
    FROM agg_original o
    FULL OUTER JOIN agg_optimized p
        ON  o.tipo_factura = p.tipo_factura
        AND o.simultanea   = p.simultanea
),
agg_mismatches AS (
    SELECT *
    FROM agg_diff
    WHERE orig_cnt           != opt_cnt
       OR orig_monto_compras != opt_monto_compras
       OR orig_monto_ventas  != opt_monto_ventas
       OR orig_comision      != opt_comision
       OR orig_derechos      != opt_derechos
       OR orig_gastos        != opt_gastos
       OR orig_total         != opt_total
),
cnt_agg_mismatches AS (
    SELECT COUNT(*) AS cnt FROM agg_mismatches
),
check_agregados AS (
    SELECT
        'CHECK_3_AGREGADOS_NUMERICOS' AS check_name,
        CASE
            WHEN c.cnt = 0 THEN 'PASS'
            ELSE 'FAIL'
        END AS resultado,
        CASE
            WHEN c.cnt = 0 THEN 'Todos los agregados por tipo_factura/simultanea coinciden'
            ELSE CONCAT(CAST(c.cnt AS STRING), ' grupo(s) con diferencias en agregados numericos')
        END AS detalle
    FROM cnt_agg_mismatches c
),

-- ============================================================================
-- RESULTADO CONSOLIDADO
-- ============================================================================
all_checks AS (
    SELECT * FROM check_conteo
    UNION ALL
    SELECT * FROM check_except_orig
    UNION ALL
    SELECT * FROM check_except_opt
    UNION ALL
    SELECT * FROM check_agregados
),
resumen AS (
    SELECT
        CASE
            WHEN SUM(CASE WHEN resultado = 'FAIL' THEN 1 ELSE 0 END) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END AS resultado_global
    FROM all_checks
)

-- ============================================================================
-- SALIDA FINAL
-- ============================================================================
SELECT
    '>>> RESULTADO GLOBAL <<<' AS check_name,
    r.resultado_global         AS resultado,
    CASE
        WHEN r.resultado_global = 'PASS'
            THEN 'Las queries son equivalentes: mismas filas y mismos agregados'
        ELSE 'Se detectaron diferencias. Revisar los checks individuales abajo.'
    END AS detalle
FROM resumen r

UNION ALL

SELECT check_name, resultado, detalle FROM all_checks

UNION ALL

SELECT
    'DETALLE_FILA_SOLO_ORIGINAL' AS check_name,
    'INFO' AS resultado,
    CONCAT(
        'cod_suc_orden=', COALESCE(CAST(cod_suc_orden AS STRING), 'NULL'),
        ' | rut=', COALESCE(CAST(rut AS STRING), 'NULL'),
        ' | cuenta=', COALESCE(CAST(cuenta AS STRING), 'NULL'),
        ' | num_fact_o_nc=', COALESCE(CAST(num_fact_o_nc AS STRING), 'NULL'),
        ' | tipo_factura=', COALESCE(CAST(tipo_factura AS STRING), 'NULL'),
        ' | total=', COALESCE(CAST(total AS STRING), 'NULL')
    ) AS detalle
FROM filas_solo_original
LIMIT 20

UNION ALL

SELECT
    'DETALLE_FILA_SOLO_OPTIMIZADA' AS check_name,
    'INFO' AS resultado,
    CONCAT(
        'cod_suc_orden=', COALESCE(CAST(cod_suc_orden AS STRING), 'NULL'),
        ' | rut=', COALESCE(CAST(rut AS STRING), 'NULL'),
        ' | cuenta=', COALESCE(CAST(cuenta AS STRING), 'NULL'),
        ' | num_fact_o_nc=', COALESCE(CAST(num_fact_o_nc AS STRING), 'NULL'),
        ' | tipo_factura=', COALESCE(CAST(tipo_factura AS STRING), 'NULL'),
        ' | total=', COALESCE(CAST(total AS STRING), 'NULL')
    ) AS detalle
FROM filas_solo_optimized
LIMIT 20

UNION ALL

SELECT
    'DETALLE_AGG_DIFERENCIA' AS check_name,
    'INFO' AS resultado,
    CONCAT(
        'tipo_factura=', tipo_factura,
        ' | simultanea=', simultanea,
        ' | cnt(orig/opt)=', CAST(orig_cnt AS STRING), '/', CAST(opt_cnt AS STRING),
        ' | monto_compras(orig/opt)=', CAST(orig_monto_compras AS STRING), '/', CAST(opt_monto_compras AS STRING),
        ' | monto_ventas(orig/opt)=', CAST(orig_monto_ventas AS STRING), '/', CAST(opt_monto_ventas AS STRING),
        ' | comision(orig/opt)=', CAST(orig_comision AS STRING), '/', CAST(opt_comision AS STRING),
        ' | derechos(orig/opt)=', CAST(orig_derechos AS STRING), '/', CAST(opt_derechos AS STRING),
        ' | gastos(orig/opt)=', CAST(orig_gastos AS STRING), '/', CAST(opt_gastos AS STRING),
        ' | total(orig/opt)=', CAST(orig_total AS STRING), '/', CAST(opt_total AS STRING)
    ) AS detalle
FROM agg_mismatches
;
