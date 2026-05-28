# devin-Skills
Skills de Devin

## Carga_Satelite_Fliliales.py

Notebook de Databricks que carga datos de filiales desde un archivo CSV hacia la tabla
`pro_business.essenexp.master_filiales_interfaz_satelite_22_shcb`.

### Esquema de la tabla destino

| # | Campo | Descripción |
|---|-------|-------------|
| 1 | `reporting_soc` | Sociedad (código) |
| 2 | `counterparty_soc` | Código de entidad accionista |
| 3 | `adjustment_code` | Código BI |
| 4 | `id_comb` | Literal `B03;MC23;PR18` |
| 5 | `amount` | Monto |
| 6 | `shcode` | Código de accionista |
| 7 | `shname` | Nombre del accionista |
| 8 | `isin` | Literal `000000000000` |
| 9 | `ic` | Literal `152` |
| 10 | `osha` | Número de acciones propias |
| 11 | `ownpi` | % propiedad por emisión |
| 12 | `votr` | % derechos de voto |
| 13 | `REPORTING_SOC\|COUNTERPARTY_SOC\|...\|VOTR` | Concatenación de los 12 campos anteriores separados por `\|` |
| 14 | `data_date_part` | Fecha de proceso (`yyyy-MM-dd`) |
| 15 | `fecha_de_ejecucion` | Timestamp de ejecución |
