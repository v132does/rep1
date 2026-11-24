CREATE OR REPLACE TYPE IT."TYP_SOLITUDESLISTADOSPI"                                          FORCE                                          IS OBJECT
(
    tipo_transferencia        varchar2(30),  --tipo de transferencia ( enviado o recibido )
    fecha_valor               date,          --Fecha valor
    tipo_operacion            varchar2(120), --descripcion del tipo de mensaje-ge_snp_par_mensajes
    nro_cta_solicitante       VARCHAR2(35),  --numero de cuenta  del solicitante.
    nom_solicitante           varchar2(120), -- nombre y apellido del solicitante.
    nro_cta_beneficiario      VARCHAR2(35),  --numero de cuenta  del beneficiario.
    nom_beneficiario          varchar2(120), -- nombre y apellido del beneficiario.
    monto                     number(18,2), --monto de la solicitud.
    estado                    varchar2(120),--estado de la solicitud.
    cod_moneda                varchar2(3),   -- moneda de la solicitud.
  CONSTRUCTOR FUNCTION typ_SolitudesListadoSpi RETURN SELF AS result
)
/

