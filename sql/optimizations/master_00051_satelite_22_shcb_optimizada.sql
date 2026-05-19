-- ============================================================
-- QUERY OPTIMIZADA (Spark SQL)
-- Tabla: pro_app.conrepneg.master_00051_satelite_22_shcb
-- ============================================================
--
-- Tecnicas de optimizacion aplicadas:
--
-- 1. ELIMINACION DE CAST REDUNDANTES: concat_ws realiza conversion
--    implicita de tipos no-string a string automaticamente. Los 4
--    CAST(... AS STRING) originales generaban nodos Cast innecesarios
--    en el plan fisico de Catalyst.
--
-- 2. PARTITION PRUNING ESTATICO: Se reemplaza la referencia a la
--    variable fecha_de_cierre por un literal string resuelto con
--    '${fecha_de_cierre}' (con comillas simples). Esto garantiza
--    que Spark resuelva la particion en tiempo de planificacion
--    (static partition pruning) en lugar de runtime (dynamic).
--
-- 3. PREDICATE PUSHDOWN: El filtro de igualdad sobre la columna
--    de particion data_date_part se traduce en partition pruning
--    a nivel filesystem. Spark solo lee los archivos del directorio
--    correspondiente a la particion filtrada.
--
-- 4. COLUMN PRUNING: Spark lee automaticamente solo las 12 columnas
--    referenciadas en SELECT. data_date_part como columna de particion
--    se deriva del path sin I/O adicional.
--
-- 5. MANTENIMIENTO DE concat_ws: Se mantiene concat_ws sobre concat
--    porque genera un unico nodo en Catalyst, maneja NULLs sin
--    propagacion (concat propaga NULL si cualquier argumento es NULL),
--    y requiere menos argumentos (13 vs 23 con concat + separadores).
--
-- 6. DESCARTE DE format_string(): Inferior por overhead de parseo
--    del patron de formato en cada fila y manejo inadecuado de NULLs.
--
-- Prerequisito: SET fecha_de_cierre = '2026-05-19'; (o la fecha correspondiente)
-- ============================================================

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
        ) AS `REPORTING_SOC|COUNTERPARTY_SOC|ADJUSTMENT_CODE|ID_COMB|AMOUNT|SHCODE|SHNAME|ISIN|IC|OSHA|OWNPI|VOTR`,
        data_date_part
    FROM pro_app.conrepneg.master_00051_satelite_22_shcb
    WHERE data_date_part = '${fecha_de_cierre}';


-- ============================================================
-- VERIFICACION DEL PLAN DE EJECUCION
-- Ejecutar para confirmar partition pruning y column pruning.
-- Buscar: PartitionFilters con valor literal, ReadSchema con
-- solo 12 columnas, sin Exchange/Sort innecesarios.
-- ============================================================

EXPLAIN FORMATTED
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
        ) AS `REPORTING_SOC|COUNTERPARTY_SOC|ADJUSTMENT_CODE|ID_COMB|AMOUNT|SHCODE|SHNAME|ISIN|IC|OSHA|OWNPI|VOTR`,
        data_date_part
    FROM pro_app.conrepneg.master_00051_satelite_22_shcb
    WHERE data_date_part = '${fecha_de_cierre}';
