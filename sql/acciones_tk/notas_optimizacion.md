# Notas de Optimización - Query NC (Notas de Crédito)

## Resumen de Optimizaciones Aplicadas

### Optimizaciones Globales (aplican a los 3 bloques UNION ALL)

| # | Optimización | Impacto |
|---|-------------|---------|
| 1 | **Eliminación de subconsultas wrapper** `(SELECT * FROM tabla)` → referencia directa con alias | Reduce nodos en plan de ejecución |
| 2 | **CTEs compartidas para PED y SUC** (pedt021 ~4.4M filas, tcdt050 ~686K filas) | Evita repetir 3 veces la misma subconsulta con filtro de partición |
| 3 | **LEFT JOIN → INNER JOIN** donde `WHERE columna IS NOT NULL` anulaba el LEFT implícitamente | Permite al optimizador elegir mejores estrategias (broadcast hash join) |
| 4 | **Operador unario negativo** `-valor` en lugar de `valor*(-1)` | Mayor legibilidad, marginalmente más eficiente |
| 5 | **Proyección mínima + partition pruning** en tablas grandes con `data_date_part = '${fecha}'` | Reduce I/O significativamente |

### Optimizaciones Específicas del Bloque 1 (NC MAN - NO simultánea)

| # | Optimización | Detalle |
|---|-------------|---------|
| 6 | **Reorden de JOINs**: INNER JOIN con tk2 movido antes de LEFT JOINs | Filtra filas tempranamente, reduce volumen en joins subsiguientes |

### Optimizaciones Específicas del Bloque 2 (NC MAN - SI simultánea)

| # | Optimización | Detalle |
|---|-------------|---------|
| 7 | **INNER JOIN tk1** movido antes de LEFT JOINs con filtro `fechaimpr IS NOT NULL` en ON | Reduce filas antes de procesar JOINs restantes |
| 8 | **Nota sobre `LIKE '%ANTICIPO%'`**: no admite pushdown ni índices; considerar columna derivada/flag si es recurrente | Mejora potencial futura |

### Optimizaciones Específicas del Bloque 3 (NC OP)

| # | Optimización | Detalle |
|---|-------------|---------|
| 9 | **CTE `tk3_prep`**: precalcula `CONCAT(TRIM(estado), TRIM(glosa1))` como `estado_glosa` | Eliminó 8+ repeticiones de la misma expresión; `IF(IN)` en vez de múltiples CASE/WHEN |
| 10 | **Eliminado LEFT JOIN a `subsch`** (~310K filas) | Ninguna columna de subsch se usaba en SELECT ni WHERE |
| 11 | **Eliminado LEFT JOIN a `tradch`** (~4.6M filas) en subconsulta t2 | Solo se usa `tradname` y `trad` de la tabla `trad`. tradch no aportaba columnas |
| 12 | **Simplificada subconsulta t2**: solo `SELECT tradname, trad FROM trad WHERE br='01'` | De 3 JOINs a tablas grandes → 1 sola tabla con filtro |
| 13 | **Simplificada lógica de `simultanea`**: `IF(TRIM(cond_liquidacion) IN ('CN','PM','PH'), 'NO', 'SI')` | De 4 ramas CASE a 1 expresión IF/IN |

## Impacto Estimado en Rendimiento

### Bloque 3 (mayor impacto):
- **Eliminación de tradch (~4.6M filas) y subsch (~310K filas)**: Ahorra ~2 shuffles/joins costosos
- **CTE tk3_prep con filtro br='01'**: Predicate pushdown directo al scan

### Todos los bloques:
- **CTEs compartidas PED/SUC**: Spark puede reutilizar el resultado materializado
- **INNER JOIN explícito**: Permite broadcast join si las tablas temporales son pequeñas

## Advertencia sobre Bloque 3 - subconsulta t2

La eliminación del LEFT JOIN a `tradch` podría cambiar resultados si existían **múltiples filas en tradch para un mismo trad** (lo cual causaría duplicados en la query original). Si esto es intencional, habría que restaurar ese JOIN. **Usar la query de verificación para confirmar equivalencia.**

## Archivos Entregados

- `query_optimizada.sql` - Query optimizada lista para ejecutar
- `query_verificacion.sql` - Query de verificación con original y optimizada embebidas
- `notas_optimizacion.md` - Este documento
