CREATE OR REPLACE TYPE IT."TYP_SEGUROPOLIZAS"                                          FORCE is OBJECT
(   
 --Indica si hubo error
 error                VARCHAR2(1),
 ---Nombre del mensaje
 nombreRespuesta      VARCHAR2(15), 
 -- Descripcion del mensaje 
 descripcionRespuesta VARCHAR2(200),
 --Codigo 
  codigo number,
--  producto
  producto VARCHAR2(100),
-- Descripcion del seguro
  seccion          VARCHAR2(50),
-- Descripcion especifica del seguro
  subSeccion      VARCHAR2(100),
-- Poliza
  nroPoliza         VARCHAR2(30),
-- Aseguradora
  ciaSeguros VARCHAR2(60),
-- fecha de inicio de vigencia de la poliza
  fecInicial DATE,
-- fecha de fin de vigencia de la poliza
  fecFinal DATE,
-- monto capital
  mtoCapital NUMBER(18,2),
-- cantidad de cuotas
  canCuota NUMBER(2),
-- Moneda en la cual se encuentra el seguro.
  codMoneda VARCHAR2(3),
-- Contador de registros
  cantidad NUMBER(2),
-- próximo vencimiento
  fecProxVencimiento DATE,
-- cantidad de cuotas atrasadas
  canCuotasAtrasadas NUMBER(2),
-- indica el tipo de movimiento
  tipMovimiento VARCHAR2(50),
-- indica si es un endoso en funcion a tipMovimiento
  tieneEndoso VARCHAR2(1),
-- indica si la poliza no fue anulada (N) o si cuenta con anulacion total (S) o parcial (P).
  tipAnulacion VARCHAR2(50),
-- determina si la poliza esta vigente (1), vencida(2) o anulada(3)
  situacion VARCHAR2(50),
-- monto cuota
  mtoCuota NUMBER(18,2),
-- Nombre completo del beneficiario de la poliza
  beneficiario varchar(100),
-- Indica si se trata de un pre-aprobado
  esPreaprobado varchar(1),
-- Indica si puede descargar el Archivo de la Poliza de Seguro
  generaPolizaWeb varchar2(1),
-- Codigo de Ente de la Aseguradora
  codEnte number(5),
-- Detalle de cuotas
  listaCuotas        TYP_LISTASEGUROSCUOTAS,
-- Tipo de seguro en caso de pre-aprobado, si es migrado -99
  codTipSeguro number(2),
-- determina el estado de la poliza
  estado VARCHAR2(1),
-- nombre legal del banco
  nombreEntidad VARCHAR2(120),

  CONSTRUCTOR FUNCTION TYP_SEGUROPOLIZAS RETURN SELF AS RESULT
)
/

