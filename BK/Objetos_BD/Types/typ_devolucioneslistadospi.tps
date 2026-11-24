CREATE OR REPLACE TYPE IT."TYP_DEVOLUCIONESLISTADOSPI"                                          FORCE IS OBJECT
(
    tipo_transferencia        varchar2(30),  --tipo de transferencia ( enviado o recibido )
    fecha_valor               date,          --Fecha valor
    tipo_operacion            Varchar2(60),     --cod_msj_swift ge_snp_par_mensajes
    nro_cta_solicitante       VARCHAR2(35),  --numero de cuenta  del solicitante.
    nom_solicitante           varchar2(120), -- nombre y apellido del solicitante.
    nro_cta_beneficiario      VARCHAR2(35),  --numero de cuenta  del beneficiario.
    nom_beneficiario          varchar2(120), -- nombre y apellido del beneficiario.
    monto                      number(18,2), --monto de la solicitud.
    estado                     varchar2(120),--estado de la solicitud
    nom_swi_pte_solicitante   VARCHAR2(140),
    nom_swi_pte_beneficiario  VARCHAR2(140),
    cod_moneda                varchar2(3),
    fecha_hora                date,
    nro_operacion             number(20),
    cod_operacion             varchar2(3),
  CONSTRUCTOR FUNCTION typ_devolucioneslistadospi RETURN SELF AS result
)
/

