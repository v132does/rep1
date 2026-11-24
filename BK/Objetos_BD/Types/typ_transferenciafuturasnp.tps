CREATE OR REPLACE TYPE IT."TYP_TRANSFERENCIAFUTURASNP"                                          FORCE IS OBJECT
(
-- Indica si es un mensaje de error
  error VARCHAR2(1),
-- Código de la respuesta
  nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
-- Cantida de Registros
  cantidadCuentas NUMBER(3),
-- Lista de resumen de cuentas
  listaTransferencias typ_listaTransferenciaSnp,
  CONSTRUCTOR FUNCTION typ_transferenciaFuturaSnp RETURN SELF AS result
)
/

