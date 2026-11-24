CREATE OR REPLACE TYPE IT."TYP_TELEFONO"                                          FORCE IS OBJECT
(
  telefono VARCHAR2(10),--Numero de Telefono
  area VARCHAR2(10),--Codigo de Area del Numero de Telefono
  interno VARCHAR2(5),--Numero de Interno
  tipoLinea VARCHAR2(1),--Tipo de Linea telefonica.
  tipo VARCHAR2(1),--Tipo de telefono (L=Laboral / P= Particular)
  principal VARCHAR2(1),--Indica si el telefono es default (S=SI / N=NO)
  codigoTelefono NUMBER(3),--Codigo de telefono.
  observacion VARCHAR2(1000),
  accion VARCHAR2(1),--Accion
  CONSTRUCTOR FUNCTION typ_telefono RETURN SELF AS result
)
/

