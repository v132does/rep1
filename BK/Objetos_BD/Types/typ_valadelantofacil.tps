CREATE OR REPLACE TYPE IT."TYP_VALADELANTOFACIL"                                          IS OBJECT
(
   error                   VARCHAR(1), --Error S ó N
   nombreRespuesta         VARCHAR2(15), --Nombre de la respuesta
   descripcionRespuesta    VARCHAR2(200), --Descripción de la respuesta
   montoLimite             NUMBER(19), --Monto límite a solicitar adelanto
CONSTRUCTOR FUNCTION typ_valadelantofacil RETURN SELF AS result
);
/

