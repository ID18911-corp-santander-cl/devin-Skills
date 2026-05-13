# Optimización Query Cierre Financiero Mes (Spark SQL)

## Archivos

| Archivo | Descripción |
|---------|-------------|
| `query_original.sql` | Query original sin modificaciones |
| `query_optimizada.sql` | Query optimizada con todas las mejoras aplicadas |
| `query_verificacion.sql` | Query para comprobar equivalencia entre original y optimizada |

## Tablas involucradas

| Tabla | Filas |
|-------|-------|
| `pro_business.nsgexp.nsg_cierre_financiero_mes` | 3,454,317 |
| `pro_business.nsgexp.nsg_habiles` | 8,189 |
| `pro_business.nsgexp.nsg_cierre_financiero_mes_simulada` | 10,139 |
| `pro_business.nsgexp.nsg_parametros_cierre_contable` | 107,101 |

## Optimizaciones aplicadas

### 1. CTE `fecha_habil` — Subconsulta repetida eliminada
La subconsulta `SELECT ultimo_habil FROM nsg_habiles WHERE ultimo_calendario = '${fecha}' LIMIT 1` se ejecutaba **2 veces** (una por cada rama del UNION ALL). Ahora se ejecuta **una sola vez** como CTE, y además aplica `REPLACE('-', '')` dentro del CTE para evitar repetir la función.

### 2. Orden de filtros WHERE — Partition pruning
Los filtros de partición (`data_date_part`, `empresa`) se colocan **primero** en las cláusulas WHERE para aprovechar partition pruning en la tabla de 3.4M filas. Esto permite al motor (Spark/Hive/Trino) eliminar particiones enteras sin leerlas.

**Orden optimizado:**
1. `data_date_part` — columna de partición (partition pruning)
2. `empresa` — filtro de igualdad altamente selectivo
3. `origen_part` — filtro de partición secundario
4. `fecha_datos` — filtro con resultado del CTE
5. `sdo_acum_peso != 0` — filtro de desigualdad (menos selectivo, va al final)

### 3. CTE `parametros` — Materialización del subquery de parámetros
La subconsulta de `nsg_parametros_cierre_contable` (107K filas) filtrada por `cod_empresa = '00051'` se materializa como CTE una sola vez.

### 4. BROADCAST hint — Join optimizado
La tabla de parámetros filtrada (pocos miles de filas) se marca con `/*+ BROADCAST(parametros) */` para que Spark la replique en cada executor y evite el shuffle sort-merge join de la tabla principal.

### 5. IF → CASE WHEN — SQL estándar
`if(moneda = 'UF', 'CLF', moneda)` reemplazado por `CASE WHEN moneda = 'UF' THEN 'CLF' ELSE moneda END` para mayor portabilidad entre motores SQL.

### 6. Transformaciones movidas al SELECT final
`CAST(ROUND(sdo_acum_peso, 0) AS BIGINT)` y el literal `'BI00051'` se aplican una sola vez en el SELECT final en lugar de duplicarse en ambas ramas del UNION ALL.

### 7. Subquery anidado → CTE `cierre`
El subquery inline `C` se reemplaza por el CTE `cierre`, mejorando legibilidad y permitiendo al optimizador materializar el resultado.

## Query de verificación

La query de verificación (`query_verificacion.sql`) compara original vs optimizada mediante **3 técnicas complementarias**:

1. **Conteo de filas**: Verifica que ambas queries retornen la misma cantidad de filas
2. **EXCEPT bidireccional**: Detecta filas presentes en una query pero no en la otra
3. **Checksum MD5**: Genera un hash por fila y luego un checksum agregado ordenado para detectar diferencias incluso con filas duplicadas

> **Nota**: Se excluye `fecha_de_ejecucion` de la comparación ya que `NOW()` genera valores diferentes entre ejecuciones.

El resultado final muestra un **veredicto** claro: `EQUIVALENTES` o `DIFERENTES`.
