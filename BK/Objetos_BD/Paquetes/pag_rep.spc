CREATE OR REPLACE PACKAGE IT.PAG_REP is

  -- Author  : Explotaci¿n de la producci¿n
  -- Created : 10/08/2015
  -- Purpose : Generaci¿n de Informes del cierre y porterior de cierre: Extraer datos de consultas a un txt, moverlos los archivos a un directorio compartido mediante FTP y enviar mail de aviso a usuario.
-- Variables
  g_repository         VARCHAR2(100) := fug_obt_pardinamico('DIR_REP_FTP');
  g_envia_mail         VARCHAR2(100) := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');
  g_ip                 VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port               VARCHAR2(100) := fug_obt_pardinamico('PUERTO_FTP');
  g_user               VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  g_pass               VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  g_compartido         VARCHAR2(100) := '\\'||fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS')||'\';
  g_contabilidad       VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_CONTABILIDAD');
  g_riesgos            VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_RIESGOS');
  g_finanzas           VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_FINANZAS');
  g_amaral             VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_AMARAL');
  g_compras            VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_COMPRAS');
  g_sistemas           VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_SISTEMAS');
  g_extractos          VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_EXTRACTOS');
  g_balances           VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_BALANCES');
  g_infoespana         VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_INFESPANA');
  g_infocidesa         VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_INF_CIDESA');
  g_operaciones        VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_OPERACIONES'); 
  g_conciliaciones     VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_TARJETAS');
 
-- Funcion para obtener valores de GE_PAR_RA
FUNCTION fu_obt_valor_par
    (
    v_servicio IN varchar2 DEFAULT 'ALL',
    v_tabla    IN varchar2,
    v_campo    IN varchar2
    )
    RETURN  VARCHAR2;

--Informes Complementarios de IVA - Cuadre por Modalidad
PROCEDURE prb_con_iva_cua_modalidad;
--Informes Complementarios de IVA - Cuadre por Movimientos
PROCEDURE prb_con_iva_cua_movimientos;
--Informes Complementarios de IVA - Detalle de Movimientos con descuadre
PROCEDURE prb_con_iva_det_movimientos;
--Informes Complementarios de IVA - Insercion y Generacion 
PROCEDURE prb_con_iva_complement;    
END PAG_REP;
/

