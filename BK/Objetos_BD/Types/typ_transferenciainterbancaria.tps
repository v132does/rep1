CREATE OR REPLACE TYPE IT."TYP_TRANSFERENCIAINTERBANCARIA"                                          IS OBJECT
(
   error                   VARCHAR(1),
   nombreRespuesta         VARCHAR2(15),
   descripcionRespuesta    VARCHAR2(200),
   tipoMensaje             VARCHAR2(1),
   cantidadAutorizacion    NUMBER(3),
   fechaOperacion          VARCHAR2(10),
   numeroCuentaDebito      VARCHAR2(17),
   nombreCuentaDebito      VARCHAR2(100),
   monedaCuentaDebito      VARCHAR2(3),
   montoDebito             NUMBER(18,2),
   numeroCuentaCredito     VARCHAR2(20),
   nombreCuentaCredito     VARCHAR2(100),
   swiftEntidadCredito     VARCHAR2(20),
   nombreEntidadCredito    VARCHAR2(60),
   monedaCuentaCredito     VARCHAR2(3),
   montoCredito            NUMBER(18,2),
   cotizacion              NUMBER(18,2),
   numeroReferencia        NUMBER(15),
   nombre                  VARCHAR2(100),
   direccion               VARCHAR2(100),
   numeroDocumento         VARCHAR2(20),
   tipoDocumento           NUMBER(3),
   prioridad               VARCHAR(1),
   respuestaLimite         VARCHAR2(2),
   listaConsultaEntes      typ_listaConsultaEntes,
   listaConsultaDocumentos typ_listaConsultaDocumentos,
   cotizacionCredito       NUMBER(18,2),
   CONSTRUCTOR FUNCTION typ_transferenciaInterbancaria RETURN SELF AS result
)
/

