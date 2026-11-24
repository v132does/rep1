CREATE OR REPLACE TYPE IT."TYP_TRANSFERENCIASPI"                                          FORCE IS OBJECT
(
    TIPO                      varchar2(30),
    DESCRIPCION_TIPO          varchar2(120), -- Transferencia entre cuentas, interbancarias o sipap
    NRO_REFERENCIA            varchar2(20), --mandatoryNúmero de Referencia de la Transferencia. Ej: 213804.
    NRO_CTA_SOLICITANTE       varchar2(35),-- Cuenta de Referencia de la Transferencia (puede ser de la Entidad si es Emitida o Externa si es Recibida).
    NOM_SOLICITANTE           varchar2(120),-- Nombre y Apellido del Solicitante.
    NRO_DOC_BENEFICIARIO      varchar2(20), -- Numero de Documento de Identidad del Beneficiario.
    NOM_BENEFICIARIO          varchar2(120), -- Nombre y Apellido del Beneficiario.
    NRO_CTA_BENEFICIARIO      varchar2(35), --Cuenta de Referencia de la Transferencia (puede ser de la Entidad si es Emitida o Externa si es Recibida).
    COD_SWI_PTE_BENEFICIARIO  varchar2(20), -- Código SWIFT (BIC) del Participante Beneficiario.
    COD_MONEDA                varchar2(3),--Codigo de Moneda.
    MONTO                     number(18,2),--default = 0, Monto de la Transferencia.
    COD_SWI_PTE_SOLICITANTE   varchar2(20), -- Código SWIFT (BIC) del Participante Solicitante.
    FEC_VALOR                 date, -- Fecha estimada de Pago.
    NRO_REF_EXTERNA           varchar2(33),
    HORA                      varchar2(15),
    concepto                  varchar2(140),
  CONSTRUCTOR FUNCTION typ_transferenciaSpi RETURN SELF AS result
)
/

