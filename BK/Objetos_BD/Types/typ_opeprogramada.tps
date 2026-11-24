CREATE OR REPLACE TYPE IT."TYP_OPEPROGRAMADA"                                          FORCE is OBJECT
(
   error               VARCHAR2(1),
   nombreRespuesta     VARCHAR2(15),
   descripcionRespuesta VARCHAR2(200),
   numeroReferencia    NUMBER(18),
   frecuencia          VARCHAR2(1),
   fechaInicio         DATE,
   fechaFin            DATE,
   fechaSiguiente      DATE,
   fechaAnulacion      DATE,
   estado              VARCHAR2(1),
   concepto            VARCHAR2(60),
   monedaOperacion     VARCHAR2(3),
   montoOperacion      NUMBER(18,2),
   cuentaDebito        VARCHAR2(15),
   cuentaCredito       VARCHAR2(35),
   nombreCuentaCredito VARCHAR2(100),
   cantidadProgramada  NUMBER,
   cantidadRealizada   NUMBER,
   monedaDebito        VARCHAR2(3),
   monedaCredito       VARCHAR2(3),
   tipoOperacion       VARCHAR2(100),
   fechaInsercion      DATE,
   listaDetalles       typ_listaDetProgramada, 
  CONSTRUCTOR FUNCTION typ_opeProgramada RETURN SELF AS RESULT
)
/

