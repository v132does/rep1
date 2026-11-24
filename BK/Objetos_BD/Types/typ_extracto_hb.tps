CREATE OR REPLACE TYPE IT."TYP_EXTRACTO_HB"                                          force                                       as OBJECT
(
   error                 VARCHAR2(1),
   nombreRespuesta       VARCHAR2(15),
   descripcionRespuesta  VARCHAR2(200),
   codigoCliente         VARCHAR2(10),
   nombreCliente         VARCHAR2(120),
   nombreOficial         VARCHAR2(120),
   direccionCliente      VARCHAR2(150),
   telefonoCliente       VARCHAR2(41),
   cuentasCliente        typ_listaExtractoCuentas_hb,
   detallesMovimiento    typ_listaExtractoMovimientos_hb,
   retencionesCuenta     typ_listaExtractoRetenciones,
   resumenesCuenta       typ_listaExtractoResumenes,
   bloqueosCuenta        typ_listaExtractoBloqueos,
   fechaExtractoAnterior DATE,
   codigoSwiftBanco      VARCHAR2(20),
   codigoSwiftCuenta     VARCHAR2(20),
   codigoBanco           NUMBER(3),
   barrio                VARCHAR2(40),
   descripcion           VARCHAR2(100),
   calificacionRiesgo    VARCHAR2(15),
   fechaUltCalificacion  VARCHAR2(15),
   fechaExtracto         VARCHAR2(10),
   imagenLogo            VARCHAR2(120),
   nombreEntidad         VARCHAR2(120),
   CONSTRUCTOR FUNCTION typ_extracto_hb RETURN SELF AS result
)
/

