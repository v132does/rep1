CREATE OR REPLACE PACKAGE IT.PAI_SGT IS
  v_tot_deuda   number(18);
  v_lugar       varchar2(4000);
  v_fec_proceso date := pag_cal.fu_obt_fec_actual(1);
  v_tipo_clie   ge_clientes.tipo%type;
  v_tip_destino ge_cla_operaciones.tip_destino%type;
  v_mon_local   ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
  v_mon_fuerte  ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_fuerte;
  v_mon_calculo ba_monedas.cod_moneda%type;
  v_cot_calculo ge_cotizaciones.val_conversion%type;
  v_dia_mora    ig_moras.dia_hasta%type;
  v_cod_periodo ig_parametros.cod_periodo%type := null;
  v_dias        ig_operaciones.dias%type;
  /* Proceso principal de categorización según la resolución 8. */
  PROCEDURE PR_GEN_DAT_OPERACIONES(P_TIPO_PROCESO IN VARCHAR2 default 'T');
  /* Procesar cuentas de operaciones vencidas. */
  --PROCEDURE PR_PRO_DAT_OPE_VENCIDAS;
  /* Generar resúmenes */
  PROCEDURE PR_GEN_RESUMENES;
  -- proceso que carga datos de los sub conceptos en forma dinamica
  PROCEDURE PR_GEN_SUB_CONCEPTOS;
  /*generación de los logros por oficial y cliente*/
  PROCEDURE PR_GEN_LOGROS;
  /*proceso que actualiza los logros en las tablas de metas*/
  PROCEDURE PR_ACT_MET_CON_LOGROS;
  /*proceso que reliza la liquidación de los periodos procesados*/
  PROCEDURE PR_GEN_LIQUIDACION;
  /*obtener previsiones generales*/
  FUNCTION FU_OBT_PREVISIONES(p_cod_periodo in number,
                              p_fec_desde   in date,
                              p_fec_hasta   in date,
                              P_COD_MONEDA  IN VARCHAR2) return number;
  /*obtener previsiones por unidad*/
  FUNCTION FU_OBT_PREVISIONES(p_cod_periodo in number,
                              p_fec_desde   in date,
                              p_fec_hasta   in date,
                              P_COD_UNIDAD  IN NUMBER,
                              P_COD_MONEDA  IN VARCHAR2) return number;
  /*obtener previsiones por oficial*/
  FUNCTION FU_OBT_PREVISIONES(p_cod_periodo in number,
                              p_fec_desde   in date,
                              p_fec_hasta   in date,
                              P_COD_UNIDAD  IN NUMBER,
                              P_COD_OFICIAL IN VARCHAR2,
                              P_COD_MONEDA  IN VARCHAR2) return number;
  /*obtener previsiones por cliente*/
  FUNCTION FU_OBT_PREVISIONES(p_cod_periodo in number,
                              p_fec_desde   in date,
                              p_fec_hasta   in date,
                              P_COD_UNIDAD  IN NUMBER,
                              P_COD_OFICIAL IN VARCHAR2,
                              P_COD_CLIENTE IN VARCHAR2,
                              P_COD_MONEDA  IN VARCHAR2) return number;
  /*obtener ingresos por servicios generales*/
  FUNCTION FU_OBT_SER_INGRESOS(p_cod_periodo in number,
                               p_fec_desde   in date,
                               p_fec_hasta   in date,
                               P_COD_MONEDA  IN VARCHAR2) return number;
  /*obtener ingresos por servicios por unidad*/
  FUNCTION FU_OBT_SER_INGRESOS(p_cod_periodo in number,
                               p_fec_desde   in date,
                               p_fec_hasta   in date,
                               P_COD_UNIDAD  IN NUMBER,
                               P_COD_MONEDA  IN VARCHAR2) return number;
  /*obtener ingresos por servicios por oficial*/
  FUNCTION FU_OBT_SER_INGRESOS(p_cod_periodo in number,
                               p_fec_desde   in date,
                               p_fec_hasta   in date,
                               P_COD_UNIDAD  IN NUMBER,
                               P_COD_OFICIAL IN VARCHAR2,
                               P_COD_MONEDA  IN VARCHAR2) return number;
  /*obtener ingresos por servicios por cliente*/
  FUNCTION FU_OBT_SER_INGRESOS(p_cod_periodo in number,
                               p_fec_desde   in date,
                               p_fec_hasta   in date,
                               P_COD_UNIDAD  IN NUMBER,
                               P_COD_OFICIAL IN VARCHAR2,
                               P_COD_CLIENTE IN VARCHAR2,
                               P_COD_MONEDA  IN VARCHAR2) return number;
  /*obtener costos por servicios generales*/
  FUNCTION FU_OBT_SER_COSTOS(p_cod_periodo in number,
                             p_fec_desde   in date,
                             p_fec_hasta   in date,
                             P_COD_MONEDA  IN VARCHAR2) return number;
  /*obtener costos por servicios por unidad*/
  FUNCTION FU_OBT_SER_COSTOS(p_cod_periodo in number,
                             p_fec_desde   in date,
                             p_fec_hasta   in date,
                             P_COD_UNIDAD  IN NUMBER,
                             P_COD_MONEDA  IN VARCHAR2) return number;
  /*obtener costos por servicios por oficial*/
  FUNCTION FU_OBT_SER_COSTOS(p_cod_periodo in number,
                             p_fec_desde   in date,
                             p_fec_hasta   in date,
                             P_COD_UNIDAD  IN NUMBER,
                             P_COD_OFICIAL IN VARCHAR2,
                             P_COD_MONEDA  IN VARCHAR2) return number;
  /*obtener costos por servicios por cliente*/
  FUNCTION FU_OBT_SER_COSTOS(p_cod_periodo in number,
                             p_fec_desde   in date,
                             p_fec_hasta   in date,
                             P_COD_UNIDAD  IN NUMBER,
                             P_COD_OFICIAL IN VARCHAR2,
                             P_COD_CLIENTE IN VARCHAR2,
                             P_COD_MONEDA  IN VARCHAR2) return number;
  /*obtener otros costos directos generales*/
  FUNCTION FU_OBT_OTR_COSTOS(p_cod_periodo in number,
                             p_fec_desde   in date,
                             p_fec_hasta   in date,
                             P_COD_MONEDA  IN VARCHAR2) return number;
  /*obtener otros costos directos por unidad*/
  FUNCTION FU_OBT_OTR_COSTOS(p_cod_periodo in number,
                             p_fec_desde   in date,
                             p_fec_hasta   in date,
                             P_COD_UNIDAD  IN NUMBER,
                             P_COD_MONEDA  IN VARCHAR2) return number;
  /*obtener otros costos directos por oficial*/
  FUNCTION FU_OBT_OTR_COSTOS(p_cod_periodo in number,
                             p_fec_desde   in date,
                             p_fec_hasta   in date,
                             P_COD_UNIDAD  IN NUMBER,
                             P_COD_OFICIAL IN VARCHAR2,
                             P_COD_MONEDA  IN VARCHAR2) return number;
  /*obtener otros costos directos por cliente*/
  FUNCTION FU_OBT_OTR_COSTOS(p_cod_periodo in number,
                             p_fec_desde   in date,
                             p_fec_hasta   in date,
                             P_COD_UNIDAD  IN NUMBER,
                             P_COD_OFICIAL IN VARCHAR2,
                             P_COD_CLIENTE IN VARCHAR2,
                             P_COD_MONEDA  IN VARCHAR2) return number;
  /*recuperar plazo*/
  FUNCTION FU_OBT_PLAZO(p_FEC_DESDE IN DATE, p_FEC_HASTA IN DATE)
    RETURN NUMBER;
  /*obtener devengado*/
  function fu_obt_devengado(p_nro_cuenta in varchar2,
                            p_cod_modulo in number) return number;
  /*recuperar el tipo de meta del parámetro*/
  FUNCTION FU_OBT_TIP_META(p_COD_PERIODO      IN NUMBER,
                           p_COD_CONCEPTO     IN NUMBER,
                           p_COD_SUB_CONCEPTO IN NUMBER) RETURN VARCHAR2;
  /*recuperar tasa encaje*/
  FUNCTION FU_OBT_TAS_ENCAJE(P_COD_MODULO    IN NUMBER,
                             P_COD_MODALIDAD IN NUMBER,
                             P_COD_MONEDA    IN VARCHAR2,
                             P_PLAZO         IN NUMBER) RETURN NUMBER;
  /*recuperar tasa interoficina*/
  FUNCTION FU_OBT_TAS_INTEROFICINA(p_PLAZO      IN NUMBER,
                                   P_COD_MONEDA IN VARCHAR2) RETURN NUMBER;
  /* Calculo del adicional automatico por superar todas las metas*/
  PROCEDURE pr_cal_adicional;
  -- Devuelve el total a cobrar por un usuario
  FUNCTION FU_OBT_TOT_A_COBRAR (p_cod_oficial in varchar2)
    RETURN NUMBER;

END PAI_SGT;
/

