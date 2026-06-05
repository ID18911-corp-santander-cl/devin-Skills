# Code Structure

## Repositorio devin-Skills

```
devin-Skills/
├── README.md                    # Descripción general del repositorio
├── .devin/
│   └── skills/
│       ├── optimize-prompt.md           # Skill: optimización de prompts
│       └── generate-code-from-prompt.md # Skill: generación de código
└── docs/
    ├── CODE_STRUCTURE.md                # Este archivo
    └── subida_ficheros_front_filial_banco.md  # Doc técnica proceso Front
```

## Documentación Técnica

### subida_ficheros_front_filial_banco.md

Documentación del proceso "Subida de Ficheros por el Front Filial y Banco" para el Satélite 22 SHCB.

| Sección | Contenido |
|---------|-----------|
| Resumen Ejecutivo | Contexto y ficheros involucrados |
| Arquitectura del Flujo | Diagrama de carga end-to-end |
| Detalle por Notebook | Pipeline ETL de Filial y Banco |
| Validaciones Necesarias | Existencia, esquema, integridad, separador |
| Dependencias de Rutas | Mapa de ficheros → tablas de paso → tablas destino |
| Diferencias Front vs Motor | Comparativa de rutas y naming |
| Checklist de Habilitación | Pre-requisitos, modificaciones, testing, despliegue |
| Parametrización de Fuente | Ejemplo de código para selección front/motor |
| Seguridad y Auditoría | Permisos, trazabilidad, idempotencia |

### Notebooks referenciados (en otras ramas)

| Notebook | Rama | Función |
|----------|------|---------|
| `Carga_Satelite_Filiales.py` | `devin/1779991773-adaptar-esquema-satelite-22-shcb` | Carga Base_Filial.csv → `master_filiales_interfaz_satelite_22_shcb` |
| `Carga_Banco_SHCB.py` | `devin/1780075370-rename-tablas-banco-shcb` | Carga DCV.csv + Rutero_SHCB.csv → tablas Banco y satélite |
