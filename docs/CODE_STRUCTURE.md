# Code Structure

## Repository Layout

```
devin-Skills/
├── .devin/
│   └── skills/
│       ├── optimize-prompt.md          # Skill: optimiza prompts siguiendo mejores prácticas
│       └── generate-code-from-prompt.md # Skill: genera código a partir de un prompt
├── databricks/
│   └── csv_filial_shcb/
│       ├── load_csv_filial_shcb.py     # Notebook: carga CSV Base_Filial a tabla paso_csv_filial_SHCB
│       └── README.md                   # Documentación del notebook
├── docs/
│   ├── API_REFERENCE.md                # Referencia de APIs y endpoints
│   └── CODE_STRUCTURE.md               # Este archivo
└── README.md
```

## Módulos

### databricks/csv_filial_shcb/

Notebook de Databricks para la carga del archivo `Base_Filial_yyyymmdd.csv` en la tabla `paso_csv_filial_SHCB`.

**Componentes:**

| Archivo | Descripción |
|---|---|
| `load_csv_filial_shcb.py` | Notebook PySpark que lee el CSV (tab-separated), valida los datos y escribe en la tabla destino |
| `README.md` | Instrucciones de uso, estructura del CSV y parámetros |

**Flujo del notebook:**

1. Recibe parámetro `fecha_proceso` (widget de Databricks, default: fecha actual)
2. Define esquema explícito con tipos `STRING` y `DECIMAL`
3. Lee el CSV desde `/Volumes/pro_app/essenneg/motor/Base_Filial_{fecha_proceso}.csv`
4. Ejecuta validaciones de nulos en columnas clave
5. Escribe en la tabla `paso_csv_filial_SHCB` con modo `overwrite`
6. Verifica la tabla resultante
