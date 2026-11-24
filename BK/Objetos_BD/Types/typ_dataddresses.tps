CREATE OR REPLACE TYPE IT."TYP_DATADDRESSES"                                          IS OBJECT
(
  idDireccion         varchar2(13),
  codPersona          varchar2(10),
  direccion           varchar2(205),
  ciudad              varchar2(35),
  idDpto              varchar2(3),
  nombreDpto          varchar2(35),
  idPais              varchar2(3),
  nombrePais          varchar2(35),
  idTipoDireccion     varchar2(1),
  nombreTipoDireccion varchar2(240),
  tipoPersona         varchar2(1),

   error                   VARCHAR2(1),   -- Indica si la respuesta es de error o no
   nombreRespuesta         VARCHAR2(15),  -- Codigo de respuesta
   descripcionRespuesta    VARCHAR2(200), -- Descripcion del codigo de respuesta
   
   CONSTRUCTOR FUNCTION TYP_DATADDRESSES RETURN SELF AS result
)
/

