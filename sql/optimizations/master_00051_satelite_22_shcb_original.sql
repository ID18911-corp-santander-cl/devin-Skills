-- ============================================================
-- QUERY ORIGINAL
-- Tabla: pro_app.conrepneg.master_00051_satelite_22_shcb
-- ============================================================

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
        ) AS `REPORTING_SOC|COUNTERPARTY_SOC|ADJUSTMENT_CODE|ID_COMB|AMOUNT|SHCODE|SHNAME|ISIN|IC|OSHA|OWNPI|VOTR`,
        data_date_part
    FROM pro_app.conrepneg.master_00051_satelite_22_shcb
    WHERE data_date_part = fecha_de_cierre;
