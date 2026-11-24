create or replace package it.PAM_DEP is

  -- Autor     : RPAVON
  -- Fecha     : 20/04/2018
  -- Finalidad : Agrupar Procedimientos y Funciones de DEPO

  --Variables Pre-Cargadas--
  g_bic_bcp_depo  varchar2(12) := fug_obt_bic_bcp_depo; --Produccion: BCPAPYPD / Desarrollo: ZYAFPYP0--
  g_bic_bcp_sipap varchar2(12) := fug_obt_bic_bcp_sipap; --Produccion: BCPAPYPR / Desarrollo: ZYAGPYP0--
  g_usu_xad_depo  constant ge_par_dinamicos.val_parametro%type := fug_obt_usu_xad_depo;
  g_usu_xad_sipap constant ge_par_dinamicos.val_parametro%type := fug_obt_usu_xad_sipap;

  g_pue_con_depo   constant number(4) := fug_obt_pardinamico('DEP_AUT_SCK_DIR_OPE'); --4454--
  g_err_dir_correo constant ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('DEP_AUT_DIR_ERR_OPE');
  g_gru_dir_correo constant ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('DEP_AUT_DIR_GRU_OPE');
  g_err_dir_mesa   constant ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('DEP_AUT_DIR_MES_OPE');
  g_gru_con_cierre constant ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('DEP_AUT_DIR_CIE_OPE');
  --SPI
 -- g_cta_ban_spi constant cc_cta_bancarias.nro_cta_bancaria%type := pas_spi.fu_obt_cta_ban_participante('GS'); --BBVASPI1PYG

  /* Obtener Valor de Parametros Especiales de DEPO */
  FUNCTION FU_OBT_PARAMETRO(P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE,
                            P_PARAMETRO  IN VARCHAR2,
                            P_FECHA      IN DATE default pag_cal.FU_OBT_FEC_ACTUAL(10))
    RETURN NUMBER;

  /* Calcula el Valor de monto recibido dentro de su unidad */
  FUNCTION FU_CAL_VAL_MTO_PISO(p_valor IN NUMBER) RETURN NUMBER;

FUNCTION FU_OBT_HOR_SEGUNDO(P_HORA IN GE_MOVIMIENTOS.HORA%TYPE, P_CAN_SEGUNDOS IN NUMBER) RETURN VARCHAR2;

FUNCTION FU_OBT_VAL_CAM_ESP(P_MEN_PROCESAR IN CLOB,
                            P_CAMPO IN SB_SNP_CAMPOS.CAMPO%TYPE) RETURN VARCHAR2;

  FUNCTION FU_OBT_EST_MOD_DEPO(P_COD_PERIODO IN NUMBER) RETURN VARCHAR2;

  FUNCTION FU_OBT_DAT_MONITOREO RETURN VARCHAR2;

  FUNCTION FU_OBT_VAL_SAL_SIPAP(P_COD_EJECUCION IN VARCHAR2) RETURN NUMBER;

  FUNCTION FU_PRO_MSJ_RECIBIDOS(P_MENSAJE IN LONG) RETURN VARCHAR2;

  FUNCTION FU_PRO_MT_RECIBIDO(P_TEXTO IN CLOB) return varchar2;

  FUNCTION FU_REG_MSJ_GENERICO(P_MENSAJE          IN CLOB,
                               P_IND_MSJ_RECIBIDO IN VARCHAR2 DEFAULT 'S',
                               P_ENV_MAIL         IN VARCHAR2 DEFAULT 'S')
    RETURN VARCHAR2;
  FUNCTION FU_OBT_CTA_BANCARIA(P_NRO_REFERENCIA IN VARCHAR2,
                               P_COD_MSJ        IN VARCHAR2) RETURN VARCHAR2;

  PROCEDURE PR_CAR_VAR_PARAMETROS;

PROCEDURE PR_PRO_CAM_MOD_FPD(P_COD_PERIODO IN NUMBER, P_ESTADO IN VARCHAR2);

  PROCEDURE PR_VAL_RES_REC_BCP(P_MENSAJE IN VARCHAR2, P_TIPO IN VARCHAR2);

  PROCEDURE PR_CON_SOL_PER_ACTIVO(P_COD_EJECUCION IN VARCHAR2 DEFAULT NULL);

  PROCEDURE PR_CON_INT_MSJ_TEXTO;

  PROCEDURE PR_OBT_SAL_CTA_SIPAP(P_COD_EJECUCION IN VARCHAR2 DEFAULT NULL);

  PROCEDURE PR_OBT_DAT_MSJ_ACTUAL(P_COD_MSJ_SWIFT   IN VARCHAR2,
                                  P_ESTADO          IN VARCHAR2,
                                  P_NRO_REF_CONTROL IN VARCHAR2,
                                  P_EXI_MSJ_ENVIADO OUT VARCHAR2,
                                  P_COD_EJECUCION   IN OUT VARCHAR2,
                                  P_NRO_ORDEN       OUT NUMBER,
                                  P_COD_MSJ_ENVIADO OUT VARCHAR2);

  PROCEDURE PR_CAL_BCP_DEPOSITO(P_COD_EJECUCION IN VARCHAR2);

  PROCEDURE PR_CAL_BCP_INTERES;

  PROCEDURE PR_GEN_OPE_BCP_COL(P_NRO_REFERENCIA IN VARCHAR2);

  PROCEDURE PR_INS_OPE_BCP_TMP;

  PROCEDURE PR_GEN_DAT_PEDIDO(P_TIPO IN VARCHAR2);

  PROCEDURE PR_GEN_PRE_DEPOSITO(P_VALOR          IN VARCHAR2,
                                P_NRO_REFERENCIA IN VARCHAR2);

  PROCEDURE PR_GEN_ENV_DEPOSITO(P_NRO_REFERENCIA IN VARCHAR2);

  PROCEDURE PR_GEN_CON_DEPOSITO(P_NRO_REFERENCIA IN VARCHAR2);

  PROCEDURE PR_GEN_MOV_APE_COL;

  PROCEDURE PR_GEN_MSJ_SWI_MT541(P_NRO_REFERENCIA OUT VARCHAR2);

PROCEDURE PR_GEN_MSJ_SWI_MT599(P_COD_PER_PARTICIPANTE IN VARCHAR2, P_MENSAJE IN VARCHAR2, P_NRO_REFERENCIA OUT VARCHAR2);

  PROCEDURE PR_GEN_MSJ_SWI_MT999(P_NRO_REFERENCIA OUT VARCHAR2);

  PROCEDURE PR_GEN_MSJ_SWI_MT920(P_NRO_REFERENCIA OUT VARCHAR2);

  PROCEDURE PR_GEN_MSJ_SWI_MT920_SPI(P_NRO_REFERENCIA OUT VARCHAR2);

  PROCEDURE PR_CON_ENV_AUTOMATICO(P_TIPO             IN VARCHAR2,
                                  P_NRO_REFERENCIA   IN VARCHAR2 DEFAULT NULL,
                                  P_HORA             IN VARCHAR2 DEFAULT NULL,
                                  P_COD_EJECUCION    IN VARCHAR2 DEFAULT NULL,
                                  P_NRO_ORDEN        IN NUMBER DEFAULT NULL,
                                  P_COD_MSJ_SWIFT    IN VARCHAR2 DEFAULT NULL,
                                  P_NRO_REF_RECIBIDO IN VARCHAR2 DEFAULT NULL,
                                  P_REF_CAMPO1       IN VARCHAR2 DEFAULT NULL,
                                  P_VAL_CAMPO1       IN VARCHAR2 DEFAULT NULL,
                                  P_REF_CAMPO2       IN VARCHAR2 DEFAULT NULL,
                                  P_VAL_CAMPO2       IN VARCHAR2 DEFAULT NULL,
                                  P_REF_CAMPO3       IN VARCHAR2 DEFAULT NULL,
                                  P_VAL_CAMPO3       IN VARCHAR2 DEFAULT NULL,
                                  P_REF_CAMPO4       IN VARCHAR2 DEFAULT NULL,
                                  P_VAL_CAMPO4       IN VARCHAR2 DEFAULT NULL);

  FUNCTION FU_PRO_MSJ_MTN99(P_MENSAJE IN LONG) RETURN VARCHAR2;

  FUNCTION FU_PRO_MSJ_MTN96(P_MENSAJE IN LONG) RETURN VARCHAR2;

  FUNCTION FU_PRO_MSJ_MT545(P_MENSAJE          IN CLOB,
                            P_IND_MSJ_RECIBIDO IN VARCHAR2 DEFAULT 'S',
                            P_ENV_MAIL         IN VARCHAR2 DEFAULT 'S')
    RETURN VARCHAR2;
  FUNCTION FU_PRO_MSJ_MT548(P_MENSAJE          IN CLOB,
                            P_IND_MSJ_RECIBIDO IN VARCHAR2 DEFAULT 'S',
                            P_ENV_MAIL         IN VARCHAR2 DEFAULT 'S')
    RETURN VARCHAR2;

  FUNCTION FU_PRO_MSJ_MT543(P_MENSAJE          IN CLOB,
                            P_IND_MSJ_RECIBIDO IN VARCHAR2 DEFAULT 'S',
                            P_ENV_MAIL         IN VARCHAR2 DEFAULT 'S')
    RETURN VARCHAR2;

  FUNCTION FU_PRO_MSJ_MT547(P_MENSAJE          IN CLOB,
                            P_IND_MSJ_RECIBIDO IN VARCHAR2 DEFAULT 'S',
                            P_ENV_MAIL         IN VARCHAR2 DEFAULT 'S')
    RETURN VARCHAR2;

  PROCEDURE PR_PRO_CAN_OPE_ENVIADO(P_NRO_REFERENCIA IN VARCHAR2);

PROCEDURE PR_VAL_APE_MOD_DEPO(p_des_periodo in varchar2, p_cod_per_actualizado in number);

  PROCEDURE PR_GEN_ARC_SWI_SERV(P_MENSAJE IN LONG);

  PROCEDURE PR_GEN_MOV_DES_COL(P_NRO_REFERENCIA IN VARCHAR2);

  PROCEDURE PR_GEN_SNP_MENSAJES(P_MENSAJE IN LONG);

  PROCEDURE PR_ENV_ARC_DEP_BCP(P_COD_EJECUCION IN VARCHAR2,
                               P_NRO_CTA       IN VARCHAR2 DEFAULT NULL);

  /* Genera Operacion Automatica de Facilidad Permanente de Depositos - (FPD)*/
  PROCEDURE PR_FPD_INI_OPE_AUT(P_CTA_ORIGEN VARCHAR2 DEFAULT NULL);

  /* Genera Operacion Automatica de Facilidad Permanente de Depositos - (FPD)*/
  PROCEDURE PR_FPD_REC_CON_AUT(P_NRO_REFERENCIA IN VARCHAR2);

end PAM_DEP;
/

