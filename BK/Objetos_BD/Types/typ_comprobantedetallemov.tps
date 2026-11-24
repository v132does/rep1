CREATE OR REPLACE TYPE IT."TYP_COMPROBANTEDETALLEMOV"                                          FORCE                                        IS OBJECT
(
--Descripcion
   descripcion VARCHAR2(300),
--Nombre de la cuenta
   cuenta VARCHAR2(100),
--Codigo de la Moneda
   codMoneda VARCHAR2(16),
--Monto
   monto VARCHAR2(16),
--Numero de documento
   nroDocumento VARCHAR2(30),
   CONSTRUCTOR FUNCTION typ_comprobantedetallemov RETURN SELF AS result
)
/

