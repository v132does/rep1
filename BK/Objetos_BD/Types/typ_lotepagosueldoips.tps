CREATE OR REPLACE TYPE IT."TYP_LOTEPAGOSUELDOIPS"                                          IS object
(
  nroLote	 				 NUMBER(10),
  codEnte					 NUMBER(5),
  nombreArchivo			 VARCHAR2(60),  -- pago_salario_2019_01_01_1.txt ???
  hashArchivo				 VARCHAR2(64),
  nroCtaPagSalario       number(10),
  nroCtaOperativa        number(10),
  fechaAcreditacion      date,          -- yyyyMMdd 20190120
  fechaVencimiento       date,          -- yyyyMMdd
  totalDebito            NUMBER(18,2),    -- 999.000.000.000.000
  tipoAcreditacion       varchar2(1),   -- J/S/C Jubilados,Salarios,CajaPrestamo
  estado                 varchar2(1),   -- I, V, P, E
  tipoProceso            VARCHAR2(1),   -- V=verificacion, P=procesamiento
  comentarios            VARCHAR2(1000),
  cantAcreditacion		 NUMBER(2),
  cantconciliacion		 NUMBER(2),
  montoAcreditado			 NUMBER(18,2),
  fechaConciliacion		 date,
  fechaAcreditacionReal	 date,

  --pagos TYP_PAGOSSUELDOIPS, -- Lista de Datos de Acreditaciones
  CONSTRUCTOR FUNCTION TYP_LOTEPAGOSUELDOIPS RETURN SELF AS result
)
/

