-- =============================================================================
-- Query Original: Cierre Financiero Mes (empresa 00051)
-- =============================================================================
-- Tablas involucradas:
--   nsg_cierre_financiero_mes:          3,454,317 filas
--   nsg_habiles:                            8,189 filas
--   nsg_cierre_financiero_mes_simulada:    10,139 filas
--   nsg_parametros_cierre_contable:       107,101 filas
-- =============================================================================

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
        now() AS fecha_de_ejecucion,
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
            AND fecha_datos = replace((SELECT ultimo_habil FROM pro_business.nsgexp.nsg_habiles WHERE ultimo_calendario = '${fecha}' LIMIT 1), '-', '')
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
            AND fecha_datos = replace((SELECT ultimo_habil FROM pro_business.nsgexp.nsg_habiles WHERE ultimo_calendario = '${fecha}' LIMIT 1), '-', '')
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
      ON C.cuenta_contable = P.cod_cuenta;
