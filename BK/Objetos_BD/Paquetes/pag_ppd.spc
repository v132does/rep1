create or replace package it.PAG_PPD is

  -- Author  : XPY5115
  -- Created : 27/03/2017 16:59:51
  -- Purpose : Interface que obtiene datos para nutricion de datos a la plantaforma PPD

  -- Public type declarations
  --type <TypeName> is <Datatype>;

  -- Public constant declarations
  g_directory         VARCHAR2(100) := fug_obt_pardinamico('DIR_BD_ARC_PPD'); -- 'PPD';
  g_ppd_svrip         VARCHAR2(100) := fug_obt_pardinamico('IP_SRV_FTP_PPD');
  g_ppd_svrport       VARCHAR2(100) := '21';
  g_ppd_user          VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_SVR_PPD');
  g_ppd_pass          VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_SVR_PPD');
  g_sha_folder        VARCHAR2(100) := fug_obt_pardinamico('SHA_FOL_FTP_PPD');  --'ramail\DYD\';


  -- Public variable declarations
  --<VariableName> <Datatype>;

  -- Public function and procedure declarations
  --function <FunctionName>(<Parameter> <Datatype>) return <Datatype>;
  -- proceso principal
  procedure pr_pro_gen_ext_mail;

  -- proc que genera archivo de cuentas
  procedure pr_gen_arc_cta_ext_mail;


  -- proc que genera archivo de movimientos
  procedure pr_gen_arc_mov_ext_mail;

  -- proc que genera archivo de calendario
  procedure pr_gen_fec_calendario;

  -- funcion que copia los archivos
  function fu_put_ftp_ramail(p_nom_archivo varchar2) return varchar2;

end PAG_PPD;
/

