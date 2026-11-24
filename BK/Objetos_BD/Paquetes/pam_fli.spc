create or replace package it.PAM_FLI is

  -- Autor     : RPAVON --
  -- Fecha     : 05/11/2018
  -- Finalidad : Agrupar Procedimientos y Funciones de DEPO

--Variables Pre-Cargadas--
g_bic_bcp_depo   varchar2(12)       := fug_obt_bic_bcp_depo;  --Produccion: BCPAPYPD / Desarrollo: ZYAFPYP0--
g_bic_bcp_sipap  varchar2(12)       := fug_obt_bic_bcp_sipap; --Produccion: BCPAPYPR / Desarrollo: ZYAGPYP0--
g_usu_xad_depo   constant ge_par_dinamicos.val_parametro%type := fug_obt_usu_xad_depo;
g_usu_xad_sipap  constant ge_par_dinamicos.val_parametro%type := fug_obt_usu_xad_sipap;

g_pue_con_depo   constant number(4) := fug_obt_pardinamico('DEP_AUT_SCK_DIR_OPE'); --4454--
g_err_dir_correo constant ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico( 'DEP_AUT_DIR_ERR_OPE' );
g_gru_dir_correo constant ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico( 'DEP_AUT_DIR_GRU_OPE' );
g_err_dir_mesa   constant ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico( 'DEP_AUT_DIR_MES_OPE' );
g_gru_con_cierre constant ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico( 'DEP_AUT_DIR_CIE_OPE' );

PROCEDURE PR_CAR_VAR_PARAMETROS;
/* Obtener Valor de Parametros Especiales de DEPO */
PROCEDURE PR_GEN_MSJ_SWI_MT549(P_NRO_REFERENCIA OUT VARCHAR2);
PROCEDURE PR_GEN_MSJ_SWI_MT524(P_IDE_INSTRUMENTO IN VARCHAR2, 
                               P_TIP_ACCION IN VARCHAR2,
                               P_CANTIDAD IN NUMBER, 
                               P_NRO_REFERENCIA OUT VARCHAR2);
PROCEDURE PR_GEN_MSJ_SWI_MT986(P_COD_MONEDA IN VARCHAR2, 
                               P_MTO_OPERACION IN NUMBER, P_NRO_REFERENCIA OUT VARCHAR2);
PROCEDURE PR_GEN_MSJ_SWI_MT595(P_IDE_INSTRUMENTO IN VARCHAR2, P_NRO_REFERENCIA OUT VARCHAR2);
PROCEDURE PR_GEN_MSJ_SWI_MT542(P_IDE_INSTRUMENTO IN VARCHAR2, 
                               P_COD_MONEDA IN VARCHAR2, 
                               P_MTO_OPERACION IN NUMBER, P_NRO_REFERENCIA OUT VARCHAR2);
end PAM_FLI;
/

