# devin-Skills
Skills de Devin

## Databricks Notebooks

### Carga CSV Base Filial → paso_csv_filial_SHCB

Notebook PySpark que lee el archivo `Base_Filial_yyyymmdd.csv` (separado por tabulación) desde `/Volumes/pro_app/essenneg/motor/` y lo carga en la tabla `paso_csv_filial_SHCB`.

- **Ubicación:** `databricks/csv_filial_shcb/load_csv_filial_shcb.py`
- **Parámetro:** `fecha_proceso` (widget, default: fecha actual en formato `yyyymmdd`)
- **Modo de escritura:** `overwrite`
- **Documentación detallada:** [`databricks/csv_filial_shcb/README.md`](databricks/csv_filial_shcb/README.md)

## Documentación

- [Referencia de API](docs/API_REFERENCE.md)
- [Estructura de código](docs/CODE_STRUCTURE.md)
