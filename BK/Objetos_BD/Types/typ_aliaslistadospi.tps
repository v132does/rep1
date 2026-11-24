CREATE OR REPLACE TYPE IT."TYP_ALIASLISTADOSPI"                                          FORCE IS OBJECT
(
    cli_recordid        VARCHAR2(33),        --Identificador del Cliente en el módulo CAS
    tip_identificador   VARCHAR2(10),         --Tipo de Identificador del Alias.
    val_identificador   VARCHAR2(80),         --Valor de Identificador del Alias
    ali_recordid      VARCHAR2(33),           --Identificador del Alias en el módulo CAS
    cue_recordid VARCHAR2(33),                --Identificador de la Cuenta en el módulo CAS
    nro_cta_solicitante VARCHAR2(35),         --Número de cuenta del solicitante
    est_solicitud VARCHAR2(1),
  CONSTRUCTOR FUNCTION typ_aliaslistadospi RETURN SELF AS result
)
/

