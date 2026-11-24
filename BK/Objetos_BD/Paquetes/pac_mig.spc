CREATE OR REPLACE PACKAGE IT.PAC_MIG IS
  ---------------------------------------------------------------------------
  -- Paquete utilizado para integraci¿n contable ITGF y BANTOTAL
  -- Fecha: 18/06/2021
  -- Autor: Gabriel Capo
  ---------------------------------------------------------------------------
  
  -- Variables
  g_repository         VARCHAR2(100) := fug_obt_pardinamico('DIR_REP_FTP');
  g_ip                 VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port               VARCHAR2(100) := fug_obt_pardinamico('PUERTO_FTP');
  g_user               VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  g_pass               VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  g_compartido         VARCHAR2(100) := '\\'||fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS')||'\';
  g_contabilidad       VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_CONTABILIDAD');


  function FU_OBT_RUB_PARSEADO(P_COD_RUBRO CB_RUBROS.COD_RUBRO%TYPE,
                                                   p_tipo      varchar2)
  return varchar2;
  
  function FU_OBT_RUB_BTW_MON(P_COD_RUBRO CB_RUBROS.COD_RUBRO%TYPE)
  return varchar2;
  
  function FU_OBT_RUB_BTW_INT(P_COD_RUBRO CB_RUBROS.COD_RUBRO%TYPE)
  return varchar2;
  
  function FU_OBT_RUB_BANTOTAL(P_COD_RUBRO CB_RUBROS.COD_RUBRO%TYPE)
  return varchar2;
  
  -- Balance Rubricado
PROCEDURE PR_XLSX_BALRUB(p_tipo varchar2 default 'H');

-- Balance Rubricado
PROCEDURE PR_ARC_BAL_BT(p_tipo varchar2 default 'H');

END PAC_MIG;
/

