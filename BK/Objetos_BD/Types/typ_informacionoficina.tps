CREATE OR REPLACE TYPE IT."TYP_INFORMACIONOFICINA"                                          IS OBJECT
(
--Codigo de la oficina
   codigoOficina VARCHAR2(3),
--Descripcion de la oficina
   descripcion VARCHAR2(35),
   CONSTRUCTOR FUNCTION typ_informacionOficina RETURN SELF AS result
)
/

