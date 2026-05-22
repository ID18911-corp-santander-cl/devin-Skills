-- =============================================================================
-- Script de creación de tabla: pro_app.essenneg.paso_csv_filial_SHCB
-- Databricks / Unity Catalog
-- =============================================================================

-- Crear schema si no existe
CREATE SCHEMA IF NOT EXISTS pro_app.essenneg;

-- Crear tabla
CREATE TABLE IF NOT EXISTS pro_app.essenneg.paso_csv_filial_SHCB (
    Sociedad                        STRING      COMMENT 'Código de sociedad',
    Shareholder_entity_code         STRING      COMMENT 'Código de entidad accionista',
    Name_of_the_shareholder_entity  STRING      COMMENT 'Nombre de la entidad accionista',
    AMOUNT                          DECIMAL(38,0) COMMENT 'Monto',
    Number_of_owned_shares          DECIMAL(38,0) COMMENT 'Número de acciones propias',
    Pct_ownership_per_issuance      DECIMAL(10,2) COMMENT 'Porcentaje de propiedad por emisión',
    Pct_voting_rights               DECIMAL(10,2) COMMENT 'Porcentaje de derechos de voto',
    BIxxxxx                         STRING      COMMENT 'Código BI'
)
USING DELTA
COMMENT 'Tabla de paso para carga de CSV Base_Filial con información de filiales y accionistas (SHCB)'
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact'   = 'true'
);
