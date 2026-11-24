CREATE OR REPLACE TYPE IT.typ_obtmovimientos_his                                          FORCE AS OBJECT
(
  fecha         DATE,
  hora          VARCHAR2(8),
  monto         NUMBER(18, 2),
  nrocuenta     VARCHAR2(15),
  nrodocumento  NUMBER(15),
  codtipmensaje VARCHAR2(3),
  concepto      VARCHAR2(100),
  tipmovimiento VARCHAR2(100),
  codmoneda     VARCHAR2(3),
  moneda        VARCHAR2(50),
  tipcuenta     varchar2(2),
  fecha_ge         DATE,
  hora_ge          VARCHAR2(8),
  cod_usuario_ge   VARCHAR2(10),
  nro_secuencia_ge NUMBER(3),
  CONSTRUCTOR FUNCTION typ_obtmovimientos_his RETURN SELF AS RESULT
)
--https://itti-digital.atlassian.net/browse/NVB-3811
/

