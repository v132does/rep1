CREATE OR REPLACE TYPE IT."TYP_GEOLOCALIZACIONPRONET"                                          FORCE AS OBJECT
(
   codigoBocaPronet    NUMBER(3),      -- Código Interno asignado a la Boca de Cobro de Pronet
   latitud             VARCHAR2(50),   -- Latitud de la Boca de Pago
   longitud            VARCHAR2(50),   -- Longitud de la Boca de Pago
   direccion           VARCHAR2(150),  -- Direccion de la Boca de Pago
   descripcion         VARCHAR2(150),  -- Descripción que identifica a la Boca de Pago
   CONSTRUCTOR FUNCTION typ_geolocalizacionPronet RETURN SELF AS RESULT
)
/

