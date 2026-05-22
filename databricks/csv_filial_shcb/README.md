# Carga CSV Base Filial → tabla paso_csv_filial_SHCB

## Descripción

Notebook de Databricks que lee el archivo `Base_Filial_yyyymmdd.csv` desde el volumen de Unity Catalog y lo carga en la tabla `paso_csv_filial_SHCB`.

## Ruta del archivo fuente

```
/Volumes/pro_app/essenneg/motor/Base_Filial_yyyymmdd.csv
```

## Estructura del CSV

El archivo está separado por tabulación (`\t`) con las siguientes columnas:

| Columna | Tipo | Descripción |
|---|---|---|
| Sociedad | STRING | Código de sociedad |
| Shareholder entity code | STRING | Código de entidad accionista |
| Name of the shareholder entity | STRING | Nombre de la entidad accionista |
| AMOUNT | DECIMAL(38,0) | Monto |
| Number of owned shares | DECIMAL(38,0) | Número de acciones propias |
| % of ownership per issuance | DECIMAL(10,2) | Porcentaje de propiedad por emisión |
| % of voting rights | DECIMAL(10,2) | Porcentaje de derechos de voto |
| BIxxxxx | STRING | Código BI |

## Parámetros

| Widget | Valor por defecto | Descripción |
|---|---|---|
| `fecha_proceso` | Fecha actual (`yyyymmdd`) | Fecha del archivo a procesar |

## Uso

1. Importar el notebook en Databricks.
2. (Opcional) Configurar el widget `fecha_proceso` con la fecha deseada.
3. Ejecutar todas las celdas.

La tabla `paso_csv_filial_SHCB` será creada o sobrescrita con los datos del CSV.
