CREATE OR REPLACE PACKAGE IT.PAG_EVO is

  -- Author  : Evolutivo Correctivo
  -- Created : 18/09/2013
  -- Purpose : Extraer datos de consultas a un txt, moverlos los archivos a un directorio compartido mediante FTP y enviar mail de aviso a usuario.
/* changelog:
     20120710:fjm: agregue el procedure prg_gen_mov_riegos
*/
-- Variables
  g_repository         VARCHAR2(100) := fug_obt_pardinamico('DIR_REP_FTP');
  g_envia_mail         VARCHAR2(100) := fug_obt_dir_correo;
  g_ip                 VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port               VARCHAR2(100) := fug_obt_pardinamico('PUERTO_FTP');
  g_user               VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  g_pass               VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  g_compartido         VARCHAR2(100) := '\\'||fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS')||'\';
  g_contabilidad       VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_CONTABILIDAD');
  g_amaral             VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_AMARAL');
  g_riesgos            VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_RIESGOS');
  g_finanzas           VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_FINANZAS');
  g_compras            VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_COMPRAS');
  g_sistemas           VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_SISTEMAS');
  g_extractos          VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_EXTRACTOS');
  g_balances           VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_BALANCES');
  g_infocidesa         VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_INF_CIDESA');
  g_operaciones        VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_OPERACIONES'); 
  g_conciliaciones     VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_TARJETAS');
  --RE DE-1172 --> ante la posibilidad de migracion de servidor.
  g_red_sucursales     ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('DIR_CARTERA_TOT_RED_SUCURSAL');
 
-- Funcion para obtener valores de GE_PAR_RA

FUNCTION fu_obt_valor_par
    (
    v_servicio IN varchar2 DEFAULT 'ALL',
    v_tabla    IN varchar2,
    v_campo    IN varchar2
    )
    RETURN  VARCHAR2;
-- Comparativo de Saldos ITGF Vs Bancard --
PROCEDURE pr_com_bancard;
-- Apuntes Manuales --
PROCEDURE pr_apu_manuales;
-- Previsiones Específicas Detallado y Query_10 --
PROCEDURE pr_ins_prev_det(p_fecha date default null);
PROCEDURE pr_previ_det(p_cod_proceso ge_procesos_det.cod_proceso%type default null,
                       p_nro_cuenta  ge_cuentas.nro_cuenta%type default null);
--Tiempos del cierre
PROCEDURE pr_tie_proc(p_cod_proceso ge_procesos_det.cod_proceso%type);
-- Impuestos al Valor Agregado 2
PROCEDURE pr_imp_va_dos;
--Cuentas asociadas a Entes de Pago Salario
PROCEDURE pr_cta_aso_pag_sal;
-- Funcion para obtener datos de Entes de pago de salarios
FUNCTION fu_cta_aso_pag_sal(p_nro_cuenta in varchar2, p_tipo in number)
  RETURN varchar2;
--Inventario de tasas reales mensuales
PROCEDURE pr_tas_reales;
-- Informe Detallado de envío de Encaje Legal al BCP (MT998)
PROCEDURE prs_snp_inf_enc_legal;
--Listado de depositos mayores a 10000USD para Cumplimiento Normativo
PROCEDURE pr_mov_dep_oficina;
--Listado de Operaciones Vigentes y Renovadas de Prestamos (Renovación,Re-financiación,Re-estructuración).
PROCEDURE pr_ope_renegociacion;
--Listado de asientos que no cuadran en el Pre-Cierre.
PROCEDURE pr_cua_pre_cierre;
-- Requerimiento: CNFDEEVO-30.
-- Fecha: 04/03/2016.
PROCEDURE pr_mov_uni_oficinas;
--Listado comparativo de saldos de prevision
PROCEDURE pr_com_prevision (p_tipo in char);
--Listado de datos de encaje antes de ser enviados al Sistema Sipap
procedure pr_snp_pre_enc_legal (p_fecha in sb_encajes_ml.fecha%type default null) ;

-- Requerimiento: CNFBPAFM-3.
/* Genera el Balance Proyectado. */
PROCEDURE pr_bal_sim_abi_suc(p_fecha in ge_calendarios.fec_actual%type);

END PAG_EVO;
/

