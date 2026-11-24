CREATE OR REPLACE PROCEDURE IT.PRA_CAP_CTA_VISTA
 (P_NRO_CUENTA IN VARCHAR2 := NULL
 ,P_INS_CAPITALIZACION IN VARCHAR2 := 'S'
 ,P_FEC_CAPITALIZACION IN DATE
 ,P_MTO_INTERES OUT NUMBER
 )
 IS
V_MTO_INTERES NUMBER(18, 2) := 0;
V_SAL_MINIMO AH_CTA_VISTAS.SAL_MINIMO%TYPE;
--_ACVIS AH_CTA_VISTAS%ROWTYPE;
V_TIPO GE_TASAS.TIPO%TYPE;
V_ANO_ACTUAL AH_SAL_MENSUALES.ANO%TYPE;
V_MES_ACTUAL AH_SAL_MENSUALES.MES%TYPE;
V_FEC_INICIAL DATE;
V_FEC_FINAL DATE;
V_FEC_ACTUAL DATE;
V_FEC_PROXIMA GE_CALENDARIOS.FEC_PROXIMA%TYPE;
V_FEC_VIGENCIA GE_TAS_FECHAS.FEC_VIGENCIA%TYPE;
V_SAL_ACU_DIARIO AH_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE;
V_HORA GE_MOVIMIENTOS.HORA%TYPE;
V_NRO_SECUENCIA GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE;
V_CAN_DIA_ACUMULADO AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE;
V_ULT_DIA_MES GE_CALENDARIOS.ULT_DIA_MES%TYPE;
V_TOT_INTERES NUMBER(18, 2) := 0;
V_REDONDEO NUMBER(5);
v_rowcount PLS_INTEGER := 0;
v_mensaje varchar2(3000);
v_tra_ah_modo    ge_par_dinamicos.val_parametro%TYPE:= NVL(fug_obt_pardinamico('PRA_CAP_CTA_PARALLEL'), 'NORMAL');
v_tam_fragmento  ge_par_dinamicos.val_parametro%TYPE:= NVL(fug_obt_pardinamico('PRA_CAP_CTA_TAM_FRAG'), '400');
v_job_cant       ge_par_dinamicos.val_parametro%TYPE:= NVL(fug_obt_pardinamico('PRA_CAP_CTA_JOB_CANT'), '6');
v_act_cta_vis_no_capitalizan ge_par_dinamicos.val_parametro%TYPE:= NVL(fug_obt_pardinamico('PRA_CTA_VIS_NO_CAP_PARALLEL'), 'SI');
v_tarea          VARCHAR2(128) := 'PRA_CAP_CTA_AH_PARALELO';
v_query_chunks   CLOB;
v_sql            CLOB;
v_divisor        NUMBER;
v_cant           NUMBER;
v_job_name VARCHAR2(30);
v_sql_stmt VARCHAR2(1000);
v_cant_registros number;
v_monto number;
v_resultado VARCHAR2(2) := 'NO';
v_can_user      number;

TYPE T_AH_CAPITALIZACIONES IS TABLE OF AH_CAPITALIZACIONES%ROWTYPE;
v_capitalizaciones T_AH_CAPITALIZACIONES := T_AH_CAPITALIZACIONES();
    
TYPE t_nro_cuenta_tab IS TABLE OF AH_CTA_VISTAS.NRO_CUENTA%TYPE;
TYPE t_sal_ult_capitalizacion_tab IS TABLE OF AH_CTA_VISTAS.SAL_ULT_CAPITALIZACION%TYPE;
TYPE t_sal_total_tab IS TABLE OF AH_CTA_VISTAS.SAL_TOTAL%TYPE;
TYPE t_ult_dia_mes_tab IS TABLE OF AH_CTA_VISTAS.FEC_ULT_CAPITALIZACION%TYPE;

v_nro_cuenta_tab t_nro_cuenta_tab;
v_sal_ult_capitalizacion_tab t_sal_ult_capitalizacion_tab;
v_sal_total_tab t_sal_total_tab;
v_ult_dia_mes_tab t_ult_dia_mes_tab;

    TYPE t_acvis IS RECORD (
        nro_cuenta            AH_CTA_VISTAS.nro_cuenta%TYPE,
        denominacion          AH_CTA_VISTAS.denominacion%TYPE,
        cod_modulo            AH_CTA_VISTAS.cod_modulo%TYPE,
        cod_modalidad         AH_CTA_VISTAS.cod_modalidad%TYPE,
        cod_oficina           AH_CTA_VISTAS.cod_oficina%TYPE,
        dig_verificador       AH_CTA_VISTAS.dig_verificador%TYPE,
        cod_moneda            AH_CTA_VISTAS.cod_moneda%TYPE,
        fre_extracto          AH_CTA_VISTAS.fre_extracto%TYPE,
        can_fir_requeridas    AH_CTA_VISTAS.can_fir_requeridas%TYPE,
        can_fir_registradas   AH_CTA_VISTAS.can_fir_registradas%TYPE,
        fec_apertura          AH_CTA_VISTAS.fec_apertura%TYPE,
        tip_capitalizacion    AH_CTA_VISTAS.tip_capitalizacion%TYPE,
        tas_personalizada     AH_CTA_VISTAS.tas_personalizada%TYPE,
        cod_tasa              AH_CTA_VISTAS.cod_tasa%TYPE,
        ret_personalizada     AH_CTA_VISTAS.ret_personalizada%TYPE,
        sal_minimo            AH_CTA_VISTAS.sal_minimo%TYPE,
        aut_pendiente         AH_CTA_VISTAS.aut_pendiente%TYPE,
        cod_usu_promotor      AH_CTA_VISTAS.cod_usu_promotor%TYPE,
        est_batch             AH_CTA_VISTAS.est_batch%TYPE,
        estado                AH_CTA_VISTAS.estado%TYPE,
        nro_folio             AH_CTA_VISTAS.nro_folio%TYPE,
        fec_ult_extracto      AH_CTA_VISTAS.fec_ult_extracto%TYPE,
        sal_ult_extracto      AH_CTA_VISTAS.sal_ult_extracto%TYPE,
        fec_cam_estado        AH_CTA_VISTAS.fec_cam_estado%TYPE,
        fec_ult_movimiento    AH_CTA_VISTAS.fec_ult_movimiento%TYPE,
        hor_ult_movimiento    AH_CTA_VISTAS.hor_ult_movimiento%TYPE,
        fec_ult_capitalizacion AH_CTA_VISTAS.fec_ult_capitalizacion%TYPE,
        sal_ult_capitalizacion AH_CTA_VISTAS.sal_ult_capitalizacion%TYPE,
        sal_ret_batch         AH_CTA_VISTAS.sal_ret_batch%TYPE,
        sal_retenido          AH_CTA_VISTAS.sal_retenido%TYPE,
        sal_blo_batch         AH_CTA_VISTAS.sal_blo_batch%TYPE,
        sal_bloqueado         AH_CTA_VISTAS.sal_bloqueado%TYPE,
        sal_tot_batch         AH_CTA_VISTAS.sal_tot_batch%TYPE,
        sal_total             AH_CTA_VISTAS.sal_total%TYPE,
        tra_prohibida         AH_CTA_VISTAS.tra_prohibida%TYPE,
        cta_combinada         AH_CTA_VISTAS.cta_combinada%TYPE,
        cod_sub_modalidad     AH_CTA_VISTAS.cod_sub_modalidad%TYPE
    );
    r_acvis t_acvis;
    /*Para parametros dinamicos*/
    v_ge_par_dinamicos typ_ge_par_dinamicos_tab;
   ----exception de ah_capitalizaciones
    v_errors EXCEPTION;
    PRAGMA EXCEPTION_INIT(v_errors, -24381); -- Código de error para errores en FORALL
    l_error_index NUMBER;
    l_error_message VARCHAR2(4000);
  --CIE-627
  v_usuario ba_usuarios.cod_usuario%type;
  --CIE-645
  TYPE typ_usu_secuencia IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
  v_usu_secuencia typ_usu_secuencia;
   TYPE t_usu_hor IS TABLE OF VARCHAR2(8) INDEX BY VARCHAR2(15);
   v_usu_hora t_usu_hor;

/* Calculo de Capitalizacion */
PROCEDURE LP_CAL_CAPITALIZAC
 (P_MTO_INTERES OUT NUMBER
 );

/* Calculo de Capitalizacion */
PROCEDURE LP_CAL_CAP_DEV_GRUPAL
 (P_MTO_INTERES OUT NUMBER
 );

/* Calcula Saldo promedio de Ahorro */
PROCEDURE LP_CAL_SAL_PROMEDIO
 (P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
 ,P_FEC_INICIAL IN DATE
 ,P_FEC_FIN IN DATE
 ,P_SAL_MINIMO IN NUMBER := 0
 ,P_SAL_PROMEDIO IN OUT NUMBER
 ,P_CAL_INTERES IN OUT VARCHAR2
 ,P_SAL_ACU_DIARIO OUT AH_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE
 ,P_CAN_DIA_ACUMULADO OUT AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 );

/* Calcula Saldo promedio de Ahorro */
PROCEDURE LP_CAL_SAL_PRO_DEV_GRUPAL
 (P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
 ,P_FEC_INICIAL IN DATE
 ,P_FEC_FIN IN DATE
 ,P_SAL_MINIMO IN NUMBER := 0
 ,P_SAL_PROMEDIO IN OUT NUMBER
 ,P_CAL_INTERES IN OUT VARCHAR2
 ,P_SAL_ACU_DIARIO OUT AH_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE
 ,P_CAN_DIA_ACUMULADO OUT AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 );

/* Calcula el Saldo Acumulado */
PROCEDURE LP_CAL_SAL_ACUMULADO
 (P_COD_MODULO IN GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN AH_CTA_VISTAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
 ,P_FEC_INICIAL IN DATE
 ,P_FEC_FINAL IN DATE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_SALDO IN OUT NUMBER
 ,P_SAL_PROMEDIO IN OUT AH_CAPITALIZACIONES.SAL_PROMEDIO%TYPE
 ,P_SAL_ACUMULADO IN OUT NUMBER
 ,P_CAN_DIA_ACUMULADO IN OUT AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 );

/* Calcula el Saldo Acumulado */
PROCEDURE LP_CAL_SAL_ACU_DEV_GRUPAL
 (P_COD_MODULO IN GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN AH_CTA_VISTAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
 ,P_FEC_INICIAL IN DATE
 ,P_FEC_FINAL IN DATE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_SALDO IN OUT NUMBER
 ,P_SAL_PROMEDIO IN OUT AH_CAPITALIZACIONES.SAL_PROMEDIO%TYPE
 ,P_SAL_ACUMULADO IN OUT NUMBER
 ,P_CAN_DIA_ACUMULADO IN OUT AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 );

/* Calcula Interes de Ahorro a la Vista */
PROCEDURE LP_CAL_INT_CTA_VISTA
 (RP_ACVIS IN OUT t_acvis--%ROWTYPE
 ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_FEC_INICIAL IN DATE
 ,P_FEC_FINAL IN DATE
 ,P_SALDO IN OUT AH_CTA_VISTAS.SAL_ULT_CAPITALIZACION%TYPE
 ,P_SAL_PROMEDIO IN NUMBER := 0
 ,P_SAL_ACU_DIARIO IN AH_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE
 ,P_CAN_DIA_ACUMULADO IN AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 ,P_MTO_INTERES OUT NUMBER
 );

/* Calcula Interes de Ahorro a la Vista */
PROCEDURE LP_CAL_INT_CTA_VIS_DEV_GRUPAL
 (RP_ACVIS IN OUT t_acvis--AH_CTA_VISTAS%ROWTYPE
 ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_FEC_INICIAL IN DATE
 ,P_FEC_FINAL IN DATE
 ,P_SALDO IN OUT AH_CTA_VISTAS.SAL_ULT_CAPITALIZACION%TYPE
 ,P_SAL_PROMEDIO IN NUMBER := 0
 ,P_SAL_ACU_DIARIO IN AH_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE
 ,P_CAN_DIA_ACUMULADO IN AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 ,P_MTO_INTERES OUT NUMBER
 );

/* Inserta registro en Capitalizaciones */
PROCEDURE LP_INS_CAPITALIZAC
 (RP_ACAPI IN AH_CAPITALIZACIONES%ROWTYPE
 );
/* Actualiza Saldo Ult. y Fec Ultima Capitalizacion en CTA_VISTAS */
PROCEDURE LP_ACT_SAL_FEC_CAPIT
 (P_MTO_INTERES IN NUMBER := 0
 );

/* Actualiza Saldo Ult. y Fec Ultima Capitalizacion Grupal */
PROCEDURE LP_ACT_SAL_FEC_CAP_GRUPAL
 (P_NRO_CUENTA IN VARCHAR2, P_MTO_INTERES IN NUMBER := 0
 );

/* Actualiza Saldo Acumulado Diario y Saldo Mensual en AH_SAL_MENSUALES */
PROCEDURE LP_ACT_SAL_MES_DIARI
 (P_MTO_INTERES IN NUMBER := 0
 );

/* Actualiza Saldo Acumulado Diario y Saldo Mensual en AH_SAL_MENSUALES Grupal*/
PROCEDURE LP_ACT_SAL_MES_DIA_GRUPAL
 (P_NRO_CUENTA IN VARCHAR2, P_MTO_INTERES IN NUMBER := 0
 );
 
 /* Funcion que retorna si es empleado*/
FUNCTION LF_ES_EMPLEADO(p_cod_persona varchar2) return varchar2;

/*RETORNA PARAMETRO DINAMICO*/
FUNCTION LF_OBT_PARDINAMICO
 (P_PARAMETRO IN GE_PAR_DINAMICOS.PARAMETRO%TYPE
 ,P_CACHED_DATA     IN typ_ge_par_dinamicos_tab
 ,P_COD_MODULO IN NUMBER DEFAULT NULL
 ,P_COD_MODALIDAD IN NUMBER DEFAULT NULL
 ,P_COD_MONEDA IN VARCHAR2 DEFAULT NULL
 ,P_COD_OFICINA IN NUMBER  DEFAULT NULL
 ,P_COD_SUB_MODALIDAD IN NUMBER DEFAULT NULL)
 RETURN VARCHAR2;
 
/*TASAS*/
PROCEDURE LP_TAS_SIG_VIGENCIA
 (P_COD_TASA IN GE_TASAS.COD_TASA%TYPE
 ,P_COD_MODULO IN GE_MODALIDADES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN GE_TAS_FECHAS.COD_OFICINA%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_FEC_INICIO IN GE_TAS_FECHAS.FEC_VIGENCIA%TYPE
 ,P_FEC_FINAL IN DATE
 ,P_FEC_VIGENCIA OUT GE_TAS_FECHAS.FEC_VIGENCIA%TYPE
 ,P_FIN_TASA IN OUT VARCHAR2
 ,P_COD_SUB_MODALIDAD IN AH_CTA_VISTAS.COD_SUB_MODALIDAD%TYPE
 );
PROCEDURE LP_OBT_VAL_TASA
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_MTO_TRANSACCION IN NUMBER default 0
 ,P_TAS_PERSONALIZADA IN GE_CUENTAS.TAS_PERSONALIZADA%TYPE
 ,P_COD_TASA IN OUT GE_TASAS.COD_TASA%TYPE
 ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_FEC_FINAL IN DATE
 ,P_VAL_TASA OUT GE_TAS_FECHAS.VAL_TASA%TYPE
 ,P_FEC_VIGENCIA OUT GE_TAS_FECHAS.FEC_VIGENCIA%TYPE
 ,P_TIP_VALOR OUT GE_TASAS.TIP_VALOR%TYPE
 ,P_TIPO OUT GE_TASAS.TIPO%TYPE
 ,P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE DEFAULT NULL
 ,P_COD_SUB_MODALIDAD OUT GE_CUENTAS.COD_SUB_MODALIDAD%TYPE);
v_msj varchar2(250);
V_HAB_DEV_GRUPAL GE_PAR_DINAMICOS.VAL_PARAMETRO%TYPE;
TYPE t_cta_vistas IS RECORD (
        nro_cuenta            AH_CTA_VISTAS.nro_cuenta%TYPE,
        denominacion          AH_CTA_VISTAS.denominacion%TYPE,
        cod_modulo            AH_CTA_VISTAS.cod_modulo%TYPE,
        cod_modalidad         AH_CTA_VISTAS.cod_modalidad%TYPE,
        cod_oficina           AH_CTA_VISTAS.cod_oficina%TYPE,
        dig_verificador       AH_CTA_VISTAS.dig_verificador%TYPE,
        cod_moneda            AH_CTA_VISTAS.cod_moneda%TYPE,
        fre_extracto          AH_CTA_VISTAS.fre_extracto%TYPE,
        can_fir_requeridas    AH_CTA_VISTAS.can_fir_requeridas%TYPE,
        can_fir_registradas   AH_CTA_VISTAS.can_fir_registradas%TYPE,
        fec_apertura          AH_CTA_VISTAS.fec_apertura%TYPE,
        tip_capitalizacion    AH_CTA_VISTAS.tip_capitalizacion%TYPE,
        tas_personalizada     AH_CTA_VISTAS.tas_personalizada%TYPE,
        cod_tasa              AH_CTA_VISTAS.cod_tasa%TYPE,
        ret_personalizada     AH_CTA_VISTAS.ret_personalizada%TYPE,
        sal_minimo            AH_CTA_VISTAS.sal_minimo%TYPE,
        aut_pendiente         AH_CTA_VISTAS.aut_pendiente%TYPE,
        cod_usu_promotor      AH_CTA_VISTAS.cod_usu_promotor%TYPE,
        est_batch             AH_CTA_VISTAS.est_batch%TYPE,
        estado                AH_CTA_VISTAS.estado%TYPE,
        nro_folio             AH_CTA_VISTAS.nro_folio%TYPE,
        fec_ult_extracto      AH_CTA_VISTAS.fec_ult_extracto%TYPE,
        sal_ult_extracto      AH_CTA_VISTAS.sal_ult_extracto%TYPE,
        fec_cam_estado        AH_CTA_VISTAS.fec_cam_estado%TYPE,
        fec_ult_movimiento    AH_CTA_VISTAS.fec_ult_movimiento%TYPE,
        hor_ult_movimiento    AH_CTA_VISTAS.hor_ult_movimiento%TYPE,
        fec_ult_capitalizacion AH_CTA_VISTAS.fec_ult_capitalizacion%TYPE,
        sal_ult_capitalizacion AH_CTA_VISTAS.sal_ult_capitalizacion%TYPE,
        sal_ret_batch         AH_CTA_VISTAS.sal_ret_batch%TYPE,
        sal_retenido          AH_CTA_VISTAS.sal_retenido%TYPE,
        sal_blo_batch         AH_CTA_VISTAS.sal_blo_batch%TYPE,
        sal_bloqueado         AH_CTA_VISTAS.sal_bloqueado%TYPE,
        sal_tot_batch         AH_CTA_VISTAS.sal_tot_batch%TYPE,
        sal_total             AH_CTA_VISTAS.sal_total%TYPE,
        tra_prohibida         AH_CTA_VISTAS.tra_prohibida%TYPE,
        cta_combinada         AH_CTA_VISTAS.cta_combinada%TYPE,
        cod_sub_modalidad     AH_CTA_VISTAS.cod_sub_modalidad%TYPE
    );
    TYPE t_cta_vistas_tab IS TABLE OF t_cta_vistas;
    
    l_cta_vistas t_cta_vistas_tab;
    v_limit PLS_INTEGER := 50000;  -- Ajusta el límite según el entorno
   ---------------------------------------------
   -- definicion de cursor para ciclo general --
   ---------------------------------------------
  CURSOR c_cta_vistas IS
    SELECT X.nro_cuenta, denominacion,X.cod_modulo,  X.cod_modalidad,
           X.cod_oficina,  dig_verificador,  cod_moneda,   fre_extracto,
           can_fir_requeridas, can_fir_registradas,  fec_apertura,  tip_capitalizacion,
           nvl(tas_personalizada,'N'), cod_tasa, ret_personalizada, sal_minimo,
           aut_pendiente, cod_usu_promotor, est_batch, estado,
           nro_folio, fec_ult_extracto, sal_ult_extracto, fec_cam_estado,
           fec_ult_movimiento, hor_ult_movimiento, fec_ult_capitalizacion, sal_ult_capitalizacion,
           sal_ret_batch, sal_retenido, sal_blo_batch, sal_bloqueado,
           sal_tot_batch, sal_total, tra_prohibida, cta_combinada, x.cod_sub_modalidad
    FROM  AH_CTA_VISTAS X, ah_cta_capitalizadas c
    WHERE  X.COD_MODULO = 3
    AND ESTADO NOT IN ('C','P','A','X')
    and x.nro_cuenta = c.nro_cuenta
    AND ((ESTADO <> 'T') OR (ESTADO = 'T' AND COD_MODALIDAD = 334 AND COD_SUB_MODALIDAD = 2 ))
    AND ((x.NRO_CUENTA = P_NRO_CUENTA)
       OR(P_NRO_CUENTA IS NULL AND MOD(v_mes_actual,TIP_CAPITALIZACION) = 0))
    AND (FEC_ULT_CAPITALIZACION is null
         OR FEC_ULT_CAPITALIZACION < v_fec_actual)
    AND P_INS_CAPITALIZACION = 'S'
    --Agregado Proyecto Dev. Grupal Cta Tran. Bancard - CORECTRB-19--
    AND ((V_HAB_DEV_GRUPAL = 'N') OR 
       (V_HAB_DEV_GRUPAL = 'S' AND NOT EXISTS (SELECT 1 FROM AH_DEV_GRU_CUENTAS Z WHERE Z.NRO_CUENTA = X.NRO_CUENTA)))
    AND not exists(select 1
                     from ah_capitalizaciones a
                    where a.fecha = V_ULT_DIA_MES
                      and a.nro_cuenta = x.nro_cuenta)
  ---SE AGREGA UNION PARA CONSULTAS DE MONTO INTERES---
   UNION ALL
       SELECT X.nro_cuenta, denominacion,X.cod_modulo,  X.cod_modalidad,
           X.cod_oficina,  dig_verificador,  cod_moneda,   fre_extracto,
           can_fir_requeridas, can_fir_registradas,  fec_apertura,  tip_capitalizacion,
           nvl(tas_personalizada,'N'), cod_tasa, ret_personalizada, sal_minimo,
           aut_pendiente, cod_usu_promotor, est_batch, estado,
           nro_folio, fec_ult_extracto, sal_ult_extracto, fec_cam_estado,
           fec_ult_movimiento, hor_ult_movimiento, fec_ult_capitalizacion, sal_ult_capitalizacion,
           sal_ret_batch, sal_retenido, sal_blo_batch, sal_bloqueado,
           sal_tot_batch, sal_total, tra_prohibida, cta_combinada, x.cod_sub_modalidad
    FROM  AH_CTA_VISTAS X
    WHERE  X.COD_MODULO = 3
    AND ESTADO NOT IN ('C','P','A','X')
    AND ((ESTADO <> 'T') OR (ESTADO = 'T' AND COD_MODALIDAD = 334 AND COD_SUB_MODALIDAD = 2 ))
    AND ((x.NRO_CUENTA = P_NRO_CUENTA)
       OR(P_NRO_CUENTA IS NULL AND MOD(v_mes_actual,TIP_CAPITALIZACION) = 0))
    AND (FEC_ULT_CAPITALIZACION is null
         OR FEC_ULT_CAPITALIZACION < v_fec_actual)
    AND P_INS_CAPITALIZACION = 'N'
    --Agregado Proyecto Dev. Grupal Cta Tran. Bancard - CORECTRB-19--
    AND ((V_HAB_DEV_GRUPAL = 'N') OR
       (V_HAB_DEV_GRUPAL = 'S' AND NOT EXISTS (SELECT 1 FROM AH_DEV_GRU_CUENTAS Z WHERE Z.NRO_CUENTA = X.NRO_CUENTA)))
    AND not exists(select 1
                     from ah_capitalizaciones a
                    where a.fecha = V_ULT_DIA_MES
                      and a.nro_cuenta = x.nro_cuenta);

CURSOR c_cta_vis_dev_grupal IS
   SELECT nro_cuenta, denominacion,cod_modulo,  cod_modalidad,
          cod_oficina,  dig_verificador,  cod_moneda,   fre_extracto,
          can_fir_requeridas, can_fir_registradas,  fec_apertura,  tip_capitalizacion,
          nvl(tas_personalizada,'N'), cod_tasa, ret_personalizada, 0, --sal_minimo, --Proyecto CORECTRB-19 / No tiene de saldo minimo--
          aut_pendiente, cod_usu_promotor, est_batch, estado,
          nro_folio, fec_ult_extracto, sal_ult_extracto, fec_cam_estado,
          fec_ult_movimiento, hor_ult_movimiento, fec_ult_capitalizacion, sal_ult_capitalizacion,
          sal_ret_batch, sal_retenido, sal_blo_batch, sal_bloqueado,
          sal_tot_batch, sal_total, tra_prohibida, cta_combinada
  FROM   AH_CTA_VISTAS X
  WHERE  COD_MODULO = 3
  AND ESTADO NOT IN ('C','P','A','X','T')
  AND ((NRO_CUENTA = P_NRO_CUENTA)
     OR(P_NRO_CUENTA IS NULL AND  MOD(v_mes_actual,TIP_CAPITALIZACION) = 0))
  AND (FEC_ULT_CAPITALIZACION is null
       OR FEC_ULT_CAPITALIZACION < v_fec_actual)
  --Agregado Proyecto Dev. Grupal Cta Tran. Bancard - CORECTRB-19--
  AND V_HAB_DEV_GRUPAL = 'S'
  AND EXISTS (SELECT 1
                FROM AH_DEV_GRU_CUENTAS Z
               WHERE Z.NRO_CUENTA = X.NRO_CUENTA
                 AND Z.TIPO = 'P')
  FOR UPDATE OF COD_MODULO;

/* Inserta datos en la Tabla GE_MOVIMIENTOS */
PROCEDURE LP_INS_GE_MOVIMIENTO (
    RP_GMOVI      IN GE_MOVIMIENTOS%ROWTYPE,
    P_ES_NOCTURNO IN CHAR := 'X'
) IS
    v_es_nocturno VARCHAR2(1);
    v_error       VARCHAR2(30);
    v_row         GE_MOVIMIENTOS%ROWTYPE;
BEGIN
    v_es_nocturno := NVL(p_es_nocturno, 'N');
    IF v_es_nocturno = 'X' THEN
        v_es_nocturno := 'N';
    END IF;

    -- Usamos una variable local para permitir modificaciones en el bloque de excepción
    v_row := RP_GMOVI;

    BEGIN
        <<intento_insercion>>
        IF v_es_nocturno = 'N' THEN
            v_error := 'GE_MOVIMIENTOS';
            INSERT /*+ APPEND_VALUES */ INTO ge_movimientos VALUES v_row;
        ELSE
            v_error := 'GE_MOVIMIENTOS_NOC';
            INSERT /*+ APPEND_VALUES */ INTO ge_movimientos_noc VALUES v_row;
        END IF;

    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            -- Manejo de la colisión: 
            -- Cambiamos el usuario al que está ejecutando la sesión (USER)
            v_row.cod_usuario    := USER; 
            
            BEGIN
                IF v_es_nocturno = 'N' THEN
                    INSERT /*+ APPEND_VALUES */ INTO ge_movimientos VALUES v_row;
                ELSE
                    INSERT /*+ APPEND_VALUES */ INTO ge_movimientos_noc VALUES v_row;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    -- Si falla por segunda vez, lanzamos el error detallado
                    RAISE;
            END;
    END;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000, 
            'Error crítico en ' || v_error || 
            ' | Intento: ' || v_row.fecha || '-' || v_row.hora || 
            '-' || v_row.cod_usuario || '-' || v_row.nro_secuencia ||
            ' | Mensaje: ' || SQLERRM);
END LP_INS_GE_MOVIMIENTO;

/* Calculo de Capitalizacion */
PROCEDURE LP_CAL_CAPITALIZAC
 (P_MTO_INTERES OUT NUMBER
 )
 IS

V_SAL_INICIAL AH_CTA_VISTAS.SAL_ULT_CAPITALIZACION%TYPE;

R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
V_VAL_TASA GE_TAS_FECHAS.VAL_TASA%TYPE;
V_MTO_INTERES NUMBER(18, 2) := 0;
V_SAL_PROMEDIO NUMBER(18, 2) := 0;
/* Indica si calcula interes (S/N) */
V_CAL_INTERES VARCHAR2(1) := 'N';

BEGIN
   --Obtiene Fecha Inicial
   IF r_acvis.fec_ult_capitalizacion IS NULL THEN
      v_fec_inicial:= r_acvis.fec_apertura;
   ELSE
      v_fec_inicial:= r_acvis.fec_ult_capitalizacion + 1;
   END IF;
   --Obtiene el Saldo Minimo
   IF r_acvis.sal_minimo IS NULL THEN
     --recuperar el saldo minimo del parametro
     DECLARE
      v_cod_persona varchar2(15) := fug_obt_cli_principal(r_acvis.NRO_CUENTA);
     BEGIN
        If lf_es_empleado(v_cod_persona) = 'S' then         
           v_sal_minimo := LF_OBT_PARDINAMICO('SAL_MIN_CAP_PAC_EMPLEADO',
                                              v_ge_par_dinamicos,
                                              r_acvis.COD_MODULO,
                                              r_acvis.COD_MODALIDAD,
                                              r_acvis.COD_MONEDA,
                                              r_acvis.COD_OFICINA);
        else
          v_sal_minimo := LF_OBT_PARDINAMICO('SAL_MIN_CAP_PACTADO',
                                              v_ge_par_dinamicos,
                                              r_acvis.COD_MODULO,
                                              r_acvis.COD_MODALIDAD,
                                              r_acvis.COD_MONEDA,
                                              r_acvis.COD_OFICINA);
        End if;

     END;
   ELSE
      v_sal_minimo := r_acvis.sal_minimo;
   END IF;
   --Inicializa el Saldo Inicial  y fecha final
   v_sal_inicial := r_acvis.sal_ult_capitalizacion;
   v_fec_final   := v_ult_dia_mes;
   --Obtiene el Saldo Promedio, Saldo Acumulado, Cant. Dias Acumulado
   lp_cal_sal_promedio(r_acvis.nro_cuenta,
                       v_fec_inicial,
                       v_fec_final,
                       v_sal_minimo,
                       --- OUT
                       v_sal_promedio,
                       v_cal_interes,
                       v_sal_acu_diario,
                       v_can_dia_acumulado);
   --Si tiene saldo promedio --
   --Calculo de Interes de Ahorro a la Vista
   lp_cal_int_cta_vista(r_acvis,609,--cod_transaccion
                        v_fec_inicial, v_fec_final,
                        v_sal_inicial, v_sal_promedio,
                        v_sal_acu_diario, v_can_dia_acumulado,
                        --- OUT
                        v_mto_interes);
   IF p_ins_capitalizacion = 'S' THEN
     --Prepara datos para insertar en GE_MOVIMIENTOS--
     IF v_mto_interes > 0 THEN
       
       v_usuario  := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');
       -- primera vez cada usuario es 0
       IF NOT v_usu_secuencia.EXISTS(v_usuario) THEN
         v_usu_secuencia(v_usuario) := 0;
         v_usu_hora(v_usuario) := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
       END IF;
              
       if v_usu_secuencia(v_usuario) = 999 then
         v_usu_hora(v_usuario) := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
         v_usu_secuencia(v_usuario) := 0;
       end if;
              
       -- para cada usuario voy aumentando la secuencia
       v_usu_secuencia(v_usuario) := v_usu_secuencia(v_usuario) + 1;
             
       r_gmovi.cod_usuario     := v_usuario;
       r_gmovi.hora            := v_usu_hora(v_usuario);
       r_gmovi.nro_secuencia   := v_usu_secuencia(v_usuario);
       r_gmovi.cod_oficina     := r_acvis.cod_oficina;
       r_gmovi.nro_cuenta      := r_acvis.nro_cuenta;
       r_gmovi.cod_moneda      := r_acvis.cod_moneda;
       r_gmovi.fec_valor       := v_fec_actual;
       r_gmovi.fecha           := v_fec_actual;
       r_gmovi.cod_mod_padre   := r_acvis.cod_modulo;
       r_gmovi.cod_mad_padre   := r_acvis.cod_modalidad;
       r_gmovi.cod_tra_padre   := 325;
       r_gmovi.cod_transaccion := 609;
       r_gmovi.monto           := v_mto_interes;
       r_gmovi.estado          := 'N';
       r_gmovi.cod_ofi_origen  := r_acvis.cod_oficina;
       r_gmovi.cod_tasa        := r_acvis.cod_tasa;
       r_gmovi.val_tasa        := v_val_tasa;
       r_gmovi.reversado       := 'N';
       r_gmovi.emi_aviso       := 'N';
       r_gmovi.protegido       := 'N';
       r_gmovi.cod_modulo      := r_acvis.cod_modulo;
       r_gmovi.cod_modalidad   := r_acvis.cod_modalidad;
       --Inserta en GE_MOVIMIENTOS
       --pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
       lp_ins_ge_movimiento(r_gmovi,'N');
             
       IF (v_tra_ah_modo != 'PARALLEL_EXECUTE') OR (p_nro_cuenta IS NOT NULL) THEN
         --Si el modo NO es paralelo O si es una cuenta específica (NOT NULL)
         --Actualiza Saldos y Fecha de Ultima Capitalizacion
         lp_act_sal_fec_capit(v_mto_interes);
       END IF;
       --Actualiza saldos del mes siguiente en Saldos Mensuales --
       -----------------------------------------------------------
       lp_act_sal_mes_diari(v_mto_interes);

     ELSE
       IF (v_tra_ah_modo != 'PARALLEL_EXECUTE') OR (p_nro_cuenta IS NOT NULL) THEN
         --Si el modo NO es paralelo O si es una cuenta específica (NOT NULL)
         ---- Tiene Valor de tasa 0 para pago ------------------
         lp_act_sal_fec_capit(v_mto_interes);
       END IF;
     END IF;
   END IF;
   --END IF;
   p_mto_interes := v_mto_interes;
END;

/* Calculo de Capitaliz. Dev. Grupal */
PROCEDURE LP_CAL_CAP_DEV_GRUPAL
 (P_MTO_INTERES OUT NUMBER
 )
 IS

V_SAL_INICIAL AH_CTA_VISTAS.SAL_ULT_CAPITALIZACION%TYPE;

R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
V_VAL_TASA GE_TAS_FECHAS.VAL_TASA%TYPE;
V_MTO_INTERES NUMBER(18, 2) := 0;
V_SAL_PROMEDIO NUMBER(18, 2) := 0;
/* Indica si calcula interes (S/N) */
V_CAL_INTERES VARCHAR2(1) := 'N';
---
V_MTO_INT_AUX NUMBER(18, 2) := 0;
v_cod_ofi_aux ah_cta_vistas.cod_oficina%type;
v_nro_cta_aux ah_cta_vistas.nro_cuenta%type;
v_cod_mon_aux ah_cta_vistas.cod_moneda%type;
v_can_reg_aux number(4);
v_acu_int_aux NUMBER(18, 2);
v_can_det_aux number(4);
v_for_dis_aux varchar2(1);

    --Cursor para Distribucion de Intereses--
    cursor c_dis_interes(p_nro_cuenta in varchar2, p_tot_interes in number, p_for_dis_interes in varchar2) is
        select nro_cuenta, cod_oficina, cod_moneda, tot_saldo, sal_cuenta, can_dias,
         round((sal_cuenta / tot_saldo),2) * 100 porcen, p_tot_interes tot_interes,
         -----
         case when p_for_dis_interes = 'D' then
              round((sal_cuenta / tot_saldo) * p_tot_interes,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',NULL,NULL,cod_moneda))
          else --C-Centralizado--
              case when tipo = 'P' then p_tot_interes else 0 end
          end mto_interes
          from
          (SELECT b.nro_cuenta, b.tipo, d.cod_oficina, d.cod_moneda, nn.tot_saldo,
                 sum(Nvl(fub_con_mon_a_moneda(d.cod_moneda,pp.cod_moneda,nvl(x.sal_acu_diario,0),NULL,v_fec_actual),0)) sal_cuenta,
                 max(nvl(x.can_dia_acumulado,0)) can_dias
             FROM AH_SAL_MENSUALES x, AH_DEV_GRU_CUENTAS b, ah_cta_vistas d,
             (SELECT sum(Nvl(fub_con_mon_a_moneda(d.cod_moneda,pp.cod_moneda,nvl(x.sal_acu_diario,0),NULL,v_fec_actual),0)) tot_saldo,
                 max(nvl(x.can_dia_acumulado,0)) can_dias
             FROM AH_SAL_MENSUALES x, AH_DEV_GRU_CUENTAS b, ah_cta_vistas d,
             (select distinct m.cod_persona, m.cod_grupo, l.cod_moneda
                         from ah_dev_gru_cuentas m, ah_cta_vistas l
                        where m.nro_cuenta = p_nro_cuenta
                          and m.tipo = 'P' --Principal--
                          and l.nro_cuenta = m.nro_cuenta) pp
             WHERE ANO = to_number(to_char(v_fec_actual,'yyyy'))
             AND MES = to_number(to_char(v_fec_actual,'mm'))
             --Proyecto Dev. Grupal Cta Tran. Bancard - CORECTRB-19--
             and b.cod_persona = pp.cod_persona
             and b.cod_grupo = pp.cod_grupo
             and b.nro_cuenta = x.nro_cuenta
             and d.nro_cuenta = b.nro_cuenta) nn,
             (select distinct m.cod_persona, m.cod_grupo, l.cod_moneda
                         from ah_dev_gru_cuentas m, ah_cta_vistas l
                        where m.nro_cuenta = p_nro_cuenta
                          and m.tipo = 'P' --Principal--
                          and l.nro_cuenta = m.nro_cuenta) pp
             WHERE x.ano(+) = to_number(to_char(v_fec_actual,'yyyy'))
               and x.mes(+) = to_number(to_char(v_fec_actual,'mm'))
               and b.cod_persona = pp.cod_persona
               and b.cod_grupo = pp.cod_grupo
               and b.nro_cuenta = x.nro_cuenta(+)
               and d.nro_cuenta = b.nro_cuenta
         group by b.nro_cuenta, b.tipo, d.cod_oficina, d.cod_moneda, nn.tot_saldo)
         --order by round((sal_cuenta / tot_saldo) * p_tot_interes,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',NULL,NULL,cod_moneda));
         order by case when p_for_dis_interes = 'D' then
              round((sal_cuenta / tot_saldo) * p_tot_interes,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',NULL,NULL,cod_moneda))
          else --C-Centralizado--
              case when tipo = 'P' then p_tot_interes else 0 end
          end;
  BEGIN
     --Obtiene Fecha Inicial
     IF r_acvis.fec_ult_capitalizacion IS NULL THEN
        v_fec_inicial:= r_acvis.fec_apertura;
     ELSE
        v_fec_inicial:= r_acvis.fec_ult_capitalizacion + 1;
     END IF;
     --Obtiene el Saldo Minimo
     IF r_acvis.sal_minimo IS NULL THEN
       --recuperar el saldo minimo del parametro
       DECLARE
          v_cod_persona varchar2(15) := fug_obt_cli_principal(r_acvis.NRO_CUENTA);
       BEGIN
          v_sal_minimo := FUG_OBT_SAL_MIN_PACTADO(r_acvis.COD_MONEDA, v_cod_persona, r_acvis.COD_MODULO,
                                                  r_acvis.COD_MODALIDAD, r_acvis.COD_OFICINA);
       END;
     ELSE
        v_sal_minimo := r_acvis.sal_minimo;
     END IF;
     --Inicializa el Saldo Inicial  y fecha final
     v_sal_inicial := r_acvis.sal_ult_capitalizacion;
     v_fec_final   := v_ult_dia_mes;
     --Obtiene el Saldo Promedio, Saldo Acumulado, Cant. Dias Acumulado
     lp_cal_sal_pro_dev_grupal(r_acvis.nro_cuenta,
                         v_fec_inicial,
                         v_fec_final,
                         v_sal_minimo,
                         --- OUT
                         v_sal_promedio,
                         v_cal_interes,
                         v_sal_acu_diario,
                         v_can_dia_acumulado);
     IF v_cal_interes = 'N' THEN
        --------  No tiene suficiente fondo disponible -------
        if p_ins_capitalizacion = 'S' then
           --Agregado Proyecto Dev. Grupal Cta Tran. Bancard - CORECTRB-19--
           UPDATE AH_CTA_VISTAS x
              SET x.fec_ult_capitalizacion = v_ult_dia_mes,
                  x.sal_ult_capitalizacion = nvl(x.sal_total,0)
            where exists (select 1
                            from ah_dev_gru_cuentas y
                           where y.nro_cuenta = x.nro_cuenta
                             and exists (select 1
                                           from ah_dev_gru_cuentas z
                                          where z.cod_persona = y.cod_persona
                                            and z.cod_grupo = y.cod_grupo
                                            and z.nro_cuenta = r_acvis.nro_cuenta));
        end if;
     ELSE
        --Si tiene saldo promedio --
        --Calculo de Interes de Ahorro a la Vista
        lp_cal_int_cta_vis_dev_grupal(r_acvis,609,--cod_transaccion
                             v_fec_inicial, v_fec_final,
                             v_sal_inicial, v_sal_promedio,
                             v_sal_acu_diario, v_can_dia_acumulado,
                             --- OUT
                             v_mto_interes);
        IF p_ins_capitalizacion = 'S' THEN
           --Si hay interes calculado genera distribucion porcentual--
           v_mto_int_aux := v_mto_interes;
           v_cod_ofi_aux := r_acvis.cod_oficina;
           v_nro_cta_aux := r_acvis.nro_cuenta;
           v_cod_mon_aux := r_acvis.cod_moneda;
           --v_can_reg_aux := c_dis_interes%rowcount;
           v_acu_int_aux := 0;
           v_can_det_aux := 0;
           v_for_dis_aux := nvl(FUA_OBT_FOR_DIS_GRUPAL(r_acvis.NRO_CUENTA),'C');
           v_can_reg_aux := 0;
           for dis in c_dis_interes(r_acvis.nro_cuenta, v_mto_int_aux, v_for_dis_aux) loop
               --Contar los Registros--
               v_can_reg_aux  := nvl(v_can_reg_aux,0)  + 1;
           end loop;
           for dis in c_dis_interes(r_acvis.nro_cuenta, v_mto_int_aux, v_for_dis_aux) loop
               v_can_det_aux := nvl(v_can_det_aux,0) + 1;
               --Carga variables con cursor de distribucion--
               r_acvis.cod_oficina := dis.cod_oficina;
               r_acvis.nro_cuenta := dis.nro_cuenta;
               r_acvis.cod_moneda := dis.cod_moneda;
               v_mto_interes := dis.mto_interes;
               if v_can_det_aux = v_can_reg_aux then
                  if (nvl(v_acu_int_aux,0) + nvl(dis.mto_interes,0)) <> nvl(dis.tot_interes,0) then
                    v_mto_interes := nvl(dis.tot_interes,0) - nvl(v_acu_int_aux,0);
                  end if;
               end if;
              IF v_mto_interes > 0 THEN
                 v_acu_int_aux := nvl(v_acu_int_aux,0) + nvl(v_mto_interes,0);
                 --------------------------------------------
                 v_usuario  := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');
                 
                  -- primera vez cada usuario es 0
                   IF NOT v_usu_secuencia.EXISTS(v_usuario) THEN
                       v_usu_secuencia(v_usuario) := 0;
                       v_usu_hora(v_usuario) := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
                   END IF;
                 
                 if v_usu_secuencia(v_usuario) = 999 then
                   v_usu_hora(v_usuario) := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
                   v_usu_secuencia(v_usuario) := 0;
                 end if;
                 
                 -- para cada usuario voy aumentando la secuencia
                 v_usu_secuencia(v_usuario) := v_usu_secuencia(v_usuario) + 1;
                 
                 r_gmovi.cod_usuario     := v_usuario;
                 r_gmovi.hora            := v_usu_hora(v_usuario);
                 r_gmovi.nro_secuencia   := v_usu_secuencia(v_usuario);
                 r_gmovi.cod_oficina     := r_acvis.cod_oficina;
                 r_gmovi.nro_cuenta      := r_acvis.nro_cuenta;
                 r_gmovi.cod_moneda      := r_acvis.cod_moneda;
                 r_gmovi.fec_valor       := v_fec_actual;
                 r_gmovi.fecha           := v_fec_actual;
                 r_gmovi.cod_mod_padre   := r_acvis.cod_modulo;
                 r_gmovi.cod_mad_padre   := r_acvis.cod_modalidad;
                 r_gmovi.cod_tra_padre   := 325;
                 r_gmovi.cod_transaccion := 609;
                 r_gmovi.monto           := v_mto_interes;
                 r_gmovi.estado          := 'N';
                 r_gmovi.cod_ofi_origen  := r_acvis.cod_oficina;
                 r_gmovi.cod_tasa        := r_acvis.cod_tasa;
                 r_gmovi.val_tasa        := v_val_tasa;
                 r_gmovi.reversado       := 'N';
                 r_gmovi.emi_aviso       := 'N';
                 r_gmovi.protegido       := 'N';
                 r_gmovi.cod_modulo      := r_acvis.cod_modulo;
                 r_gmovi.cod_modalidad   := r_acvis.cod_modalidad;
                 --Inserta en GE_MOVIMIENTOS
                 pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');

               --Actualiza Saldos y Fecha de Ultima Capitalizacion
               lp_act_sal_fec_cap_grupal(r_acvis.nro_cuenta, v_mto_interes);

               --Actualiza saldos del mes siguiente en Saldos Mensuales --
               -----------------------------------------------------------
               lp_act_sal_mes_dia_grupal(r_acvis.nro_cuenta, v_mto_interes);
            ELSE
              ---- Tiene Valor de tasa 0 para pago ------------------
              lp_act_sal_fec_cap_grupal(r_acvis.nro_cuenta,v_mto_interes);
            END IF;
         end loop;
         v_mto_interes := v_mto_int_aux;
         r_acvis.cod_oficina := v_cod_ofi_aux;
         r_acvis.nro_cuenta := v_nro_cta_aux;
         r_acvis.cod_moneda := v_cod_mon_aux;
      END IF;
   END IF;
   p_mto_interes := v_mto_interes;
END;

/* Calcula Saldo promedio de Ahorro */
PROCEDURE LP_CAL_SAL_PROMEDIO
 (P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
 ,P_FEC_INICIAL IN DATE
 ,P_FEC_FIN IN DATE
 ,P_SAL_MINIMO IN NUMBER := 0
 ,P_SAL_PROMEDIO IN OUT NUMBER
 ,P_CAL_INTERES IN OUT VARCHAR2
 ,P_SAL_ACU_DIARIO OUT AH_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE
 ,P_CAN_DIA_ACUMULADO OUT AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 )
 IS

V_MES_ACTUAL AH_SAL_MENSUALES.MES%TYPE;
V_ANO_ACTUAL AH_SAL_MENSUALES.ANO%TYPE;
V_FEC_ACTUAL DATE;
V_CAN_DIA_ACUMULADO AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE;
V_SAL_ACU_DIARIO AH_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE;
V_TOT_DIA_ACUMULADO AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE;
V_TOT_ACUMULADO NUMBER(18, 2) := 0;
--Declaracion del Cursor
CURSOR c_sal_mensuales IS
   SELECT NVL(SAL_ACU_DIARIO,0),
          NVL(CAN_DIA_ACUMULADO,0)
   FROM   AH_SAL_MENSUALES
   WHERE  NRO_CUENTA = p_nro_cuenta --v_nro_cuenta se toma en el proc. padre pra_capitalizaciones
   AND ANO = v_ano_actual
   AND MES = v_mes_actual;
BEGIN
   p_sal_promedio := 0;

   v_tot_acumulado:= 0;
   v_tot_dia_acumulado:= 0;
   p_cal_interes := 'N';

   v_fec_actual := p_fec_inicial; --p_fec_inicial se inicializa en lp_cal_capitalizac.

   v_ano_actual := TO_NUMBER(TO_CHAR(v_fec_actual,'YYYY'));
   v_mes_actual := TO_NUMBER(TO_CHAR(v_fec_actual,'MM'));
   ----------------------------------------------------------------
   -- la fecha  actual se va incrementando en 1 mes. Mientras
   -- que sea menor que la fecha final recibida como parametros
   -- calcula el acumulado de saldo, y al salir calcula el saldo
   -- promedio
   ----------------------------------------------------------------
   --p_fec_fin, se inicializa en el padre, pra_capitalizacion
   WHILE TO_NUMBER(TO_CHAR(v_fec_actual, 'YYYYMM')) <=
         TO_NUMBER(TO_CHAR(p_fec_fin, 'YYYYMM')) LOOP
      IF c_sal_mensuales%ISOPEN THEN
         CLOSE c_sal_mensuales;
      END IF;
      OPEN c_sal_mensuales;
      FETCH c_sal_mensuales INTO v_sal_acu_diario, v_can_dia_acumulado;
      -- acumula saldo acumulado y cantidad de dias --
      ------------------------------------------------
         v_tot_acumulado := v_tot_acumulado + nvl(v_sal_acu_diario,0);
         v_tot_dia_acumulado := v_tot_dia_acumulado + nvl(v_can_dia_acumulado,0);
         v_fec_actual   := ADD_MONTHS(v_fec_actual, 1);
         v_ano_actual := TO_NUMBER(TO_CHAR(v_fec_actual,'YYYY'));
         v_mes_actual := TO_NUMBER(TO_CHAR(v_fec_actual,'MM'));
        -- ve si el saldo promedio calculado es mayor o igual
        -- al saldo minimo pactado
        -----------------------------------------------------
        if v_can_dia_acumulado > 0 then
          p_sal_promedio := v_sal_acu_diario / v_can_dia_acumulado;
          IF p_sal_promedio >= p_sal_minimo THEN
             p_cal_interes := 'S';
          END IF;
        end if;
   END LOOP;
   -- calcula saldo promedio --
   ----------------------------
   p_sal_acu_diario := V_TOT_ACUMULADO;
   P_CAN_DIA_ACUMULADO := V_TOT_DIA_ACUMULADO;
   IF v_tot_dia_acumulado = 0 THEN
      p_cal_interes := 'N';
      p_sal_promedio := 0;
   ELSE
      p_sal_promedio := v_tot_acumulado / v_tot_dia_acumulado;
   END IF;
   IF c_sal_mensuales%ISOPEN THEN
      CLOSE c_sal_mensuales;
   END IF;
END;
/* Calcula Saldo promedio de Ahorro */
PROCEDURE LP_CAL_SAL_PRO_DEV_GRUPAL
 (P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
 ,P_FEC_INICIAL IN DATE
 ,P_FEC_FIN IN DATE
 ,P_SAL_MINIMO IN NUMBER := 0
 ,P_SAL_PROMEDIO IN OUT NUMBER
 ,P_CAL_INTERES IN OUT VARCHAR2
 ,P_SAL_ACU_DIARIO OUT AH_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE
 ,P_CAN_DIA_ACUMULADO OUT AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 )
 IS

V_MES_ACTUAL AH_SAL_MENSUALES.MES%TYPE;
V_ANO_ACTUAL AH_SAL_MENSUALES.ANO%TYPE;
V_FEC_ACTUAL DATE;
V_CAN_DIA_ACUMULADO AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE;
V_SAL_ACU_DIARIO AH_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE;
V_TOT_DIA_ACUMULADO AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE;
V_TOT_ACUMULADO NUMBER(18, 2) := 0;
--Declaracion del Cursor
CURSOR c_sal_men_dev_grupal IS
   SELECT sum(Nvl(fub_con_mon_a_moneda(d.cod_moneda,pp.cod_moneda,nvl(x.sal_acu_diario,0),NULL,v_fec_actual),0)),
       max(nvl(x.can_dia_acumulado,0))
   FROM AH_SAL_MENSUALES x, AH_DEV_GRU_CUENTAS b, ah_cta_vistas d,
   (select distinct m.cod_persona, m.cod_grupo, l.cod_moneda
            from ah_dev_gru_cuentas m, ah_cta_vistas l
           where m.nro_cuenta = P_NRO_CUENTA
             and m.tipo = 'P' --Principal--
             and l.nro_cuenta = m.nro_cuenta) pp
   WHERE ANO = v_ano_actual
   AND MES = v_mes_actual
   --Proyecto Dev. Grupal Cta Tran. Bancard - CORECTRB-19--
   and b.cod_persona = pp.cod_persona
   and b.cod_grupo = pp.cod_grupo
   and b.nro_cuenta = x.nro_cuenta
   and d.nro_cuenta = b.nro_cuenta;
BEGIN
   p_sal_promedio := 0;

   v_tot_acumulado:= 0;
   v_tot_dia_acumulado:= 0;
   p_cal_interes := 'N';

   v_fec_actual := p_fec_inicial; --p_fec_inicial se inicializa en lp_cal_capitalizac.

   v_ano_actual := TO_NUMBER(TO_CHAR(v_fec_actual,'YYYY'));
   v_mes_actual := TO_NUMBER(TO_CHAR(v_fec_actual,'MM'));
   ----------------------------------------------------------------
   -- la fecha  actual se va incrementando en 1 mes. Mientras
   -- que sea menor que la fecha final recibida como parametros
   -- calcula el acumulado de saldo, y al salir calcula el saldo
   -- promedio
   ----------------------------------------------------------------
   --p_fec_fin, se inicializa en el padre, pra_capitalizacion
   WHILE TO_NUMBER(TO_CHAR(v_fec_actual, 'YYYYMM')) <=
         TO_NUMBER(TO_CHAR(p_fec_fin, 'YYYYMM')) LOOP
      IF c_sal_men_dev_grupal%ISOPEN THEN
         CLOSE c_sal_men_dev_grupal;
      END IF;
      OPEN c_sal_men_dev_grupal;
      FETCH c_sal_men_dev_grupal INTO v_sal_acu_diario, v_can_dia_acumulado;
      -- acumula saldo acumulado y cantidad de dias --
      ------------------------------------------------
         v_tot_acumulado := v_tot_acumulado + nvl(v_sal_acu_diario,0);
         v_tot_dia_acumulado := v_tot_dia_acumulado + nvl(v_can_dia_acumulado,0);
         v_fec_actual   := ADD_MONTHS(v_fec_actual, 1);
         v_ano_actual := TO_NUMBER(TO_CHAR(v_fec_actual,'YYYY'));
         v_mes_actual := TO_NUMBER(TO_CHAR(v_fec_actual,'MM'));
        -- ve si el saldo promedio calculado es mayor o igual
        -- al saldo minimo pactado
        -----------------------------------------------------
        if v_can_dia_acumulado > 0 then
          p_sal_promedio := v_sal_acu_diario / v_can_dia_acumulado;
          IF p_sal_promedio >= p_sal_minimo THEN
             p_cal_interes := 'S';
          END IF;
        end if;
   END LOOP;
   -- calcula saldo promedio --
   ----------------------------
   p_sal_acu_diario := V_TOT_ACUMULADO;
   P_CAN_DIA_ACUMULADO := V_TOT_DIA_ACUMULADO;
   IF v_tot_dia_acumulado = 0 THEN
      p_cal_interes := 'N';
      p_sal_promedio := 0;
   ELSE
      p_sal_promedio := v_tot_acumulado / v_tot_dia_acumulado;
   END IF;
   IF c_sal_men_dev_grupal%ISOPEN THEN
      CLOSE c_sal_men_dev_grupal;
   END IF;
END;

/* Calcula el Saldo Acumulado */
PROCEDURE LP_CAL_SAL_ACUMULADO
 (P_COD_MODULO IN GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN AH_CTA_VISTAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
 ,P_FEC_INICIAL IN DATE
 ,P_FEC_FINAL IN DATE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_SALDO IN OUT NUMBER
 ,P_SAL_PROMEDIO IN OUT AH_CAPITALIZACIONES.SAL_PROMEDIO%TYPE
 ,P_SAL_ACUMULADO IN OUT NUMBER
 ,P_CAN_DIA_ACUMULADO IN OUT AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 )
 IS

V_COD_TRANSACCION GE_TRANSACCIONES.COD_TRANSACCION%TYPE;
V_TIP_DETALLE GE_TRANSACCIONES.TIPO%TYPE;
V_FEC_VALOR AH_MOVIMIENTOS_HIS.FEC_VALOR%TYPE;
V_MONTO AH_MOVIMIENTOS_HIS.MONTO%TYPE;
-------------------------------------------------------------------
--------- Acumula credito y debito que se encuentra en el  --------
--------- rango de fechas                                  --------
-------------------------------------------------------------------
CURSOR c_mov_historicos IS
   SELECT FEC_VALOR, MONTO, T.COD_TRANSACCION, FUG_OBT_TRA_TIPO(T.COD_TRANSACCION, TIPO, AFECTA) TIPO
     FROM GE_TRANSACCIONES T, AH_MOVIMIENTOS_HIS M
    WHERE T.COD_MODULO = p_cod_modulo
      AND T.COD_MODALIDAD = p_cod_modalidad
      AND M.NRO_CUENTA = p_nro_cuenta
      AND T.COD_TRANSACCION = M.COD_TRANSACCION
      AND T.COD_MODULO = M.COD_MODULO
      AND T.COD_MODALIDAD = M.COD_MODALIDAD
      AND FEC_VALOR >= p_fec_inicial
      AND FEC_VALOR <= p_fec_final
      AND TIPO IN ('C','D')
      AND AFECTA <> 'N'
      AND VE_CLIENTE = 'S'
 UNION ALL
    SELECT FEC_VALOR, MONTO, T.COD_TRANSACCION, FUG_OBT_TRA_TIPO(T.COD_TRANSACCION, TIPO, AFECTA) TIPO
      FROM GE_TRANSACCIONES T, GE_MOVIMIENTOS M
     WHERE T.COD_MODULO = p_cod_modulo
       AND T.COD_MODALIDAD = p_cod_modalidad
       AND M.NRO_CUENTA = p_nro_cuenta
       AND T.COD_TRANSACCION = M.COD_TRANSACCION
       AND T.COD_MODULO = M.COD_MODULO
       AND T.COD_MODALIDAD = M.COD_MODALIDAD
       AND FEC_VALOR >= p_fec_inicial
       AND FEC_VALOR <= p_fec_final
       AND TIPO IN ('C','D')
       AND VE_CLIENTE = 'S'
       AND AFECTA <> 'N'
    ORDER  BY 1;
BEGIN
    If p_fec_inicial = to_date('01'||to_char(p_fec_inicial, 'MMYYYY'), 'DDMMYYYY') and
       (p_fec_final = last_day(p_fec_final) or p_fec_final = PAA_DEV.G_FEC_PROXIMA - 1) Then
       --- Busca el saldo promedio ---
       pag_cta.PR_OBT_SAL_PROMEDIO (p_cod_modulo,
                                    p_cod_modalidad,
                                    p_cod_oficina,
                                    p_nro_cuenta,
                                    p_fec_inicial,
                                    p_fec_final,
                                    p_sal_acumulado,
                                    p_sal_promedio,
                                    p_can_dia_acumulado);
       -- Obtiene el Saldo Final por si tenga que utilizar para el proximo sub-periodo
       begin
         Select sal_ini_mes
           into p_saldo
           from ah_sal_mensuales
          where nro_cuenta = p_nro_cuenta
            and mes = to_number(to_char(add_months(p_fec_final,1), 'MM'))
            and ano = to_number(to_char(add_months(p_fec_final,1), 'YYYY'));
       exception
          when no_data_found then
             p_saldo := 0;
       end;
    Else
       p_can_dia_acumulado := p_fec_final - p_fec_inicial + 1;

       p_sal_acumulado := p_saldo; --Inicializa Acumulado al Saldo Inicial
       p_sal_acumulado := (NVL(p_sal_acumulado,0) * NVL(v_can_dia_acumulado,0));


       IF c_mov_historicos%ISOPEN THEN
          CLOSE c_mov_historicos;
       END IF;
       OPEN c_mov_historicos;
          LOOP
             FETCH c_mov_historicos
             INTO v_fec_valor, v_monto, v_cod_transaccion, v_tip_detalle;
             EXIT WHEN c_mov_historicos%NOTFOUND;
             if v_tip_detalle  = 'C'  THEN
                p_sal_acumulado := p_sal_acumulado + ((p_fec_final-v_fec_valor+1)*v_monto);
                p_saldo  := to_number(p_saldo) + v_monto;
             else
                p_sal_acumulado := p_sal_acumulado -((p_fec_final-v_fec_valor+1)*v_monto);
                p_saldo := p_saldo - v_monto;
             end if;
          END LOOP;
          CLOSE c_mov_historicos; 
          if p_can_dia_acumulado = 0 then
            p_sal_promedio := 0;
          else
            p_sal_promedio := p_sal_acumulado/ p_can_dia_acumulado;
          end if;
    End If;
END;
/* Calcula el Saldo Acumulado */
PROCEDURE LP_CAL_SAL_ACU_DEV_GRUPAL
 (P_COD_MODULO IN GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN AH_CTA_VISTAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
 ,P_FEC_INICIAL IN DATE
 ,P_FEC_FINAL IN DATE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_SALDO IN OUT NUMBER
 ,P_SAL_PROMEDIO IN OUT AH_CAPITALIZACIONES.SAL_PROMEDIO%TYPE
 ,P_SAL_ACUMULADO IN OUT NUMBER
 ,P_CAN_DIA_ACUMULADO IN OUT AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 )
 IS

V_COD_MON_LOCAL BA_MONEDAS.COD_MONEDA%TYPE;
V_COD_TRANSACCION GE_TRANSACCIONES.COD_TRANSACCION%TYPE;
V_TIP_DETALLE GE_TRANSACCIONES.TIPO%TYPE;
V_FEC_VALOR AH_MOVIMIENTOS_HIS.FEC_VALOR%TYPE;
V_MONTO AH_MOVIMIENTOS_HIS.MONTO%TYPE;
-------------------------------------------------------------------
--------- Acumula credito y debito que se encuentra en el  --------
--------- rango de fechas                                  --------
-------------------------------------------------------------------
CURSOR c_mov_historicos IS
   SELECT FEC_VALOR, fub_con_mon_a_moneda(d.cod_moneda,pp.cod_moneda,m.MONTO) monto,
          T.COD_TRANSACCION, FUG_OBT_TRA_TIPO(T.COD_TRANSACCION, T.TIPO, T.AFECTA) TIPO
     FROM GE_TRANSACCIONES T, AH_MOVIMIENTOS_HIS M, AH_DEV_GRU_CUENTAS B, AH_CTA_VISTAS D,
          --Proyecto Dev. Grupal Cta Tran. Bancard - CORECTRB-19--
          (select distinct m.cod_persona, m.cod_grupo, m.nro_cuenta, l.cod_moneda
            from ah_dev_gru_cuentas m, ah_cta_vistas l
           where m.nro_cuenta = P_NRO_CUENTA
             and m.tipo = 'P' --Principal--
             and l.nro_cuenta = m.nro_cuenta) pp          ---
    WHERE T.COD_MODULO = d.cod_modulo
      AND T.COD_MODALIDAD = d.cod_modalidad
      AND M.NRO_CUENTA = d.nro_cuenta
      AND T.COD_TRANSACCION = M.COD_TRANSACCION
      AND T.COD_MODULO = M.COD_MODULO
      AND T.COD_MODALIDAD = M.COD_MODALIDAD
      AND FEC_VALOR >= p_fec_inicial
      AND FEC_VALOR <= p_fec_final
      AND T.TIPO IN ('C','D')
      AND AFECTA <> 'N'
      AND VE_CLIENTE = 'S'
      --Proyecto Dev. Grupal Cta Tran. Bancard - CORECTRB-19--
      and b.cod_persona = pp.cod_persona
      and b.cod_grupo = pp.cod_grupo
      and b.nro_cuenta = d.nro_cuenta
 UNION ALL
    SELECT FEC_VALOR, fub_con_mon_a_moneda(d.cod_moneda,pp.cod_moneda,m.MONTO) monto,
          T.COD_TRANSACCION, FUG_OBT_TRA_TIPO(T.COD_TRANSACCION, T.TIPO, T.AFECTA) TIPO
     FROM GE_TRANSACCIONES T, GE_MOVIMIENTOS M, AH_DEV_GRU_CUENTAS B, AH_CTA_VISTAS D,
          --Proyecto Dev. Grupal Cta Tran. Bancard - CORECTRB-19--
          (select distinct m.cod_persona, m.cod_grupo, m.nro_cuenta, l.cod_moneda
            from ah_dev_gru_cuentas m, ah_cta_vistas l
           where m.nro_cuenta = P_NRO_CUENTA
             and m.tipo = 'P' --Principal--
             and l.nro_cuenta = m.nro_cuenta) pp          ---
    WHERE T.COD_MODULO = d.cod_modulo
      AND T.COD_MODALIDAD = d.cod_modalidad
      AND M.NRO_CUENTA = d.nro_cuenta
       AND T.COD_TRANSACCION = M.COD_TRANSACCION
       AND T.COD_MODULO = M.COD_MODULO
       AND T.COD_MODALIDAD = M.COD_MODALIDAD
       AND FEC_VALOR >= p_fec_inicial
       AND FEC_VALOR <= p_fec_final
       AND T.TIPO IN ('C','D')
       AND VE_CLIENTE = 'S'
       AND AFECTA <> 'N'
       --Proyecto Dev. Grupal Cta Tran. Bancard - CORECTRB-19--
      and b.cod_persona = pp.cod_persona
      and b.cod_grupo = pp.cod_grupo
      and b.nro_cuenta = d.nro_cuenta
    ORDER  BY 1;
BEGIN
    --Obtiene la moneda local
    v_cod_mon_local:= pag_gen.fu_obt_mon_local;
    If p_fec_inicial = to_date('01'||to_char(p_fec_inicial, 'MMYYYY'), 'DDMMYYYY') and
       (p_fec_final = last_day(p_fec_final) or p_fec_final = PAA_DEV.G_FEC_PROXIMA - 1) Then
       --- Busca el saldo promedio ---
       PRA_OBT_SAL_PRO_GRUPAL (p_nro_cuenta,
                                 p_fec_inicial,
                                 p_fec_final,
                                 p_sal_acumulado,
                                 p_sal_promedio,
                                 p_can_dia_acumulado);

       -- Obtiene el Saldo Final por si tenga que utilizar para el proximo sub-periodo
       begin
       --Proyecto Dev. Grupal Cta Tran. Bancard - CORECTRB-19--
         Select sum(nvl(fub_con_mon_a_moneda(d.cod_moneda,pp.cod_moneda,m.sal_ini_mes),0)) sal_ini_mes
           into p_saldo
           from ah_sal_mensuales M, AH_DEV_GRU_CUENTAS B, AH_CTA_VISTAS D,
           (select distinct m.cod_persona, m.cod_grupo, m.nro_cuenta, l.cod_moneda
            from ah_dev_gru_cuentas m, ah_cta_vistas l
           where m.nro_cuenta = P_NRO_CUENTA
             and m.tipo = 'P' --Principal--
             and l.nro_cuenta = m.nro_cuenta) pp
          where m.nro_cuenta = D.NRO_CUENTA
            and m.mes = to_number(to_char(add_months(p_fec_final,1), 'MM'))
            and m.ano = to_number(to_char(add_months(p_fec_final,1), 'YYYY'))
            ---
            and b.cod_persona = pp.cod_persona
            and b.cod_grupo = pp.cod_grupo
            and b.nro_cuenta = d.nro_cuenta;
       exception
          when no_data_found then
             p_saldo := 0;
       end;
    Else
       p_can_dia_acumulado := p_fec_final - p_fec_inicial + 1;

       p_sal_acumulado := p_saldo; --Inicializa Acumulado al Saldo Inicial
       p_sal_acumulado := (NVL(p_sal_acumulado,0) * NVL(v_can_dia_acumulado,0));


       IF c_mov_historicos%ISOPEN THEN
          CLOSE c_mov_historicos;
       END IF;
       OPEN c_mov_historicos;
          LOOP
             FETCH c_mov_historicos
             INTO v_fec_valor, v_monto, v_cod_transaccion, v_tip_detalle;
             EXIT WHEN c_mov_historicos%NOTFOUND;
             if v_tip_detalle  = 'C'  THEN
                p_sal_acumulado := p_sal_acumulado + ((p_fec_final-v_fec_valor+1)*v_monto);
                p_saldo  := to_number(p_saldo) + v_monto;
             else
                p_sal_acumulado := p_sal_acumulado -((p_fec_final-v_fec_valor+1)*v_monto);
                p_saldo := p_saldo - v_monto;
             end if;
          END LOOP;
          CLOSE c_mov_historicos; 
          if p_can_dia_acumulado = 0 then
            p_sal_promedio := 0;
          else
            p_sal_promedio := p_sal_acumulado/ p_can_dia_acumulado;
          end if;
    End If;
END;

/* Calcula Interes de Ahorro a la Vista */
PROCEDURE LP_CAL_INT_CTA_VISTA
 (RP_ACVIS IN OUT t_acvis--AH_CTA_VISTAS%ROWTYPE
 ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_FEC_INICIAL IN DATE
 ,P_FEC_FINAL IN DATE
 ,P_SALDO IN OUT AH_CTA_VISTAS.SAL_ULT_CAPITALIZACION%TYPE
 ,P_SAL_PROMEDIO IN NUMBER := 0
 ,P_SAL_ACU_DIARIO IN AH_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE
 ,P_CAN_DIA_ACUMULADO IN AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 ,P_MTO_INTERES OUT NUMBER
 )
 IS

V_MTO_INTERES NUMBER(18, 2) := 0;
V_MTO_INT_ACUMULADO NUMBER(18, 2) := 0;
V_FEC_VIGENCIA DATE;
V_FIN_TASA VARCHAR2(1) := 'N';
V_VAL_TASA GE_TAS_FECHAS.VAL_TASA%TYPE;
V_SIG_FEC_VIGENCIA DATE;
V_TIP_VALOR GE_TASAS.TIP_VALOR%TYPE;
R_ACAPI AH_CAPITALIZACIONES%ROWTYPE;
V_FEC_INICIAL DATE;
V_FEC_FINAL DATE;
V_CAN_DIA_ACUMULADO AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE;
V_SAL_ACUMULADO NUMBER(18, 2) := 0;
V_SAL_PROMEDIO NUMBER(18, 2) := 0;
V_TIPO GE_TASAS.TIPO%TYPE;
v_cod_tasa number(3);
BEGIN
   -- v_sal_disponible    := 0; --mientras tanto, ver donde se asigna el valor en el original,
   v_sal_acumulado     := 0;
   v_mto_int_acumulado := 0;
   v_fec_inicial       := p_fec_inicial;
   v_fec_final         := p_fec_final;
   v_fin_tasa          := 'N';
   ---
     -- Llamada a función de redondeo una sola vez, ya que el valor no cambia
   v_redondeo := LF_OBT_PARDINAMICO('VAL_RED_MON_EXTRANJERA',v_ge_par_dinamicos, rp_acvis.cod_modulo, rp_acvis.cod_modalidad, rp_acvis.cod_moneda);
   LOOP
      EXIT WHEN v_fin_tasa = 'S';
      -- Obtengo la sgte fecha de vigencia paa_cta.pr_tas_sig_vigencia---
      LP_TAS_SIG_VIGENCIA(rp_acvis.cod_tasa,3,31, rp_acvis.cod_oficina,
                                  rp_acvis.cod_moneda, rp_acvis.nro_cuenta,
                                  v_fec_inicial, p_fec_final,
                                  v_sig_fec_vigencia, v_fin_tasa, rp_acvis.cod_sub_modalidad);
         
      v_fec_final := v_sig_fec_vigencia-1;
      -- modificacion para Banco Regional
      if to_char(v_fec_final,'yyyymm') <> to_char(v_fec_inicial,'yyyymm') then
         v_fec_final := last_day(v_fec_inicial); -- ultimo dia del mes
         v_sig_fec_vigencia := v_fec_final + 1;
         v_fin_tasa := 'N';
      end if;
      -- calculo el promedio del sub-periodo
       lp_cal_sal_acumulado(3, --modulo
                            rp_acvis.cod_modalidad,
                            rp_acvis.cod_oficina,
                            rp_acvis.nro_cuenta,
                            v_fec_inicial,
                            v_fec_final,
                            rp_acvis.cod_moneda,
                            --- OUT
                            p_saldo,
                            v_sal_promedio,
                            v_sal_acumulado,
                            v_can_dia_acumulado);
      -- si hay sub periodo que calcular
      if v_can_dia_acumulado > 0  then
        v_cod_tasa := rp_acvis.cod_tasa;
          lp_obt_val_tasa  (rp_acvis.cod_modulo,  rp_acvis.cod_modalidad,
                                 rp_acvis.cod_oficina, rp_acvis.nro_cuenta,
                                 rp_acvis.cod_moneda,  v_sal_promedio,
                                 rp_acvis.tas_personalizada, v_cod_tasa,
                                 null,    v_fec_final,
                                 --- OUT ---
                                 v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo, null,
                                 RP_ACVIS.cod_sub_modalidad);
      end if;

      if v_can_dia_acumulado > 0 and (nvl(v_sal_acumulado,0)/nvl(v_can_dia_acumulado,0)) >= v_sal_minimo then
         -- tiene promedio en el mes para interes
         v_mto_interes :=  pag_gen.fu_cal_int_simple((v_sal_acumulado/v_can_dia_acumulado),
                                                      v_can_dia_acumulado,
                                                      v_val_tasa);
      else
         v_mto_interes := 0;
      end if;
      ----
      -- Redondeo del Interes.
      ---------------------------------------------------
      v_mto_interes := round(v_mto_interes,v_redondeo);
      if v_nro_secuencia is null then
        v_nro_secuencia := 2;
      end if;
      if p_ins_capitalizacion = 'S' THEN
          -- si debe capitalizar, genera mov. y reg. de la capitalizacion.
          -- Agregar los datos a la colección
            v_capitalizaciones.EXTEND;
            v_capitalizaciones(v_capitalizaciones.LAST).NRO_CUENTA         := rp_acvis.nro_cuenta;
            v_capitalizaciones(v_capitalizaciones.LAST).FECHA              := v_ult_dia_mes;
            v_capitalizaciones(v_capitalizaciones.LAST).COD_MODULO         := rp_acvis.cod_modulo;
            v_capitalizaciones(v_capitalizaciones.LAST).COD_MODALIDAD      := rp_acvis.cod_modalidad;
            v_capitalizaciones(v_capitalizaciones.LAST).COD_OFICINA        := rp_acvis.cod_oficina;
            v_capitalizaciones(v_capitalizaciones.LAST).COD_MONEDA         := rp_acvis.cod_moneda;
            v_capitalizaciones(v_capitalizaciones.LAST).FEC_INICIO         := v_fec_inicial;
            v_capitalizaciones(v_capitalizaciones.LAST).FEC_FIN            := v_fec_final;
            v_capitalizaciones(v_capitalizaciones.LAST).TIP_CAPITALIZACION := rp_acvis.tip_capitalizacion;
            v_capitalizaciones(v_capitalizaciones.LAST).COD_TASA           := rp_acvis.cod_tasa;
            v_capitalizaciones(v_capitalizaciones.LAST).VAL_TASA           := v_val_tasa;
            v_capitalizaciones(v_capitalizaciones.LAST).MTO_INTERES        := v_mto_interes;
            v_capitalizaciones(v_capitalizaciones.LAST).SAL_PROMEDIO       := v_sal_promedio;
            v_capitalizaciones(v_capitalizaciones.LAST).SAL_ACUMULADO      := v_sal_acumulado;
      end if;
      --Interes Acumulado
      v_mto_int_acumulado := v_mto_int_acumulado + v_mto_interes;
      -- v_tas_vigente := v_sig_val_tasa;
      v_fec_inicial := v_sig_fec_vigencia;
   END LOOP;
   --- Devolver monto para generar movimiento
   p_mto_interes := v_mto_int_acumulado;
END;

/* Calcula Interes de Ahorro a la Vista */
PROCEDURE LP_CAL_INT_CTA_VIS_DEV_GRUPAL
 (RP_ACVIS IN OUT t_acvis--AH_CTA_VISTAS%ROWTYPE
 ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_FEC_INICIAL IN DATE
 ,P_FEC_FINAL IN DATE
 ,P_SALDO IN OUT AH_CTA_VISTAS.SAL_ULT_CAPITALIZACION%TYPE
 ,P_SAL_PROMEDIO IN NUMBER := 0
 ,P_SAL_ACU_DIARIO IN AH_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE
 ,P_CAN_DIA_ACUMULADO IN AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 ,P_MTO_INTERES OUT NUMBER
 )
 IS

V_MTO_INTERES NUMBER(18, 2) := 0;
V_COD_MON_LOCAL BA_MONEDAS.COD_MONEDA%TYPE;
V_MTO_INT_ACUMULADO NUMBER(18, 2) := 0;
V_FEC_VIGENCIA DATE;
V_FIN_TASA VARCHAR2(1) := 'N';
V_VAL_TASA GE_TAS_FECHAS.VAL_TASA%TYPE;
V_SIG_FEC_VIGENCIA DATE;
V_TIP_VALOR GE_TASAS.TIP_VALOR%TYPE;
R_ACAPI AH_CAPITALIZACIONES%ROWTYPE;
V_FEC_INICIAL DATE;
V_FEC_FINAL DATE;
V_CAN_DIA_ACUMULADO AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE;
V_SAL_ACUMULADO NUMBER(18, 2) := 0;
V_SAL_PROMEDIO NUMBER(18, 2) := 0;
V_TIPO GE_TASAS.TIPO%TYPE;
BEGIN
   --Obtiene la moneda local
  -- v_cod_mon_local:= pag_gen.fu_obt_mon_local;
   -- v_sal_disponible    := 0; --mientras tanto, ver donde se asigna el valor en el original,
   v_sal_acumulado     := 0;
   v_mto_int_acumulado := 0;
   v_fec_inicial       := p_fec_inicial;
   v_fec_final         := p_fec_final;
   v_fin_tasa          := 'N';
   ---
   LOOP
      EXIT WHEN v_fin_tasa = 'S';
      -- Obtengo la sgte fecha de vigencia paa_cta.pr_tas_sig_vigencia---
       LP_TAS_SIG_VIGENCIA(rp_acvis.cod_tasa,3,31, rp_acvis.cod_oficina,
                                  rp_acvis.cod_moneda, rp_acvis.nro_cuenta,
                                  v_fec_inicial, p_fec_final,
                                  v_sig_fec_vigencia, v_fin_tasa, rp_acvis.cod_sub_modalidad);
      v_fec_final := v_sig_fec_vigencia-1;
      -- modificacion para Banco Regional
      if to_char(v_fec_final,'yyyymm') <> to_char(v_fec_inicial,'yyyymm') then
         v_fec_final := last_day(v_fec_inicial); -- ultimo dia del mes
         v_sig_fec_vigencia := v_fec_final + 1;
         v_fin_tasa := 'N';
      end if;
      -- calculo el promedio del sub-periodo
       lp_cal_sal_acu_dev_grupal(3, --modulo
                            rp_acvis.cod_modalidad,
                            rp_acvis.cod_oficina,
                            rp_acvis.nro_cuenta,
                            v_fec_inicial,
                            v_fec_final,
                            rp_acvis.cod_moneda,
                            --- OUT
                            p_saldo,
                            v_sal_promedio,
                            v_sal_acumulado,
                            v_can_dia_acumulado);
      -- si hay sub periodo que calcular
      if v_can_dia_acumulado > 0  then
         pag_gen.pr_obt_val_tasa(rp_acvis.cod_modulo,  rp_acvis.cod_modalidad,
                                 rp_acvis.cod_oficina, rp_acvis.nro_cuenta,
                                 rp_acvis.cod_moneda,  v_sal_promedio,
                                 rp_acvis.tas_personalizada, rp_acvis.cod_tasa,
                                 null,    v_fec_final,
                                 --- OUT ---
                                 v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
      end if;

      if v_can_dia_acumulado > 0 and (nvl(v_sal_acumulado,0)/nvl(v_can_dia_acumulado,0)) >= v_sal_minimo then
         -- tiene promedio en el mes para interes
         v_mto_interes :=  pag_gen.fu_cal_int_simple((v_sal_acumulado/v_can_dia_acumulado),
                                                      v_can_dia_acumulado,
                                                      v_val_tasa);
      else
         v_mto_interes := 0;
      end if;
      ----
      -- Redondeo del Interes.
      ---------------------------------------------------
      -- Si la Moneda de la Cuenta es igual a la Moneda Local
      v_redondeo := lf_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_ge_par_dinamicos,rp_acvis.cod_modulo, rp_acvis.cod_modalidad,rp_acvis.cod_moneda);
      v_mto_interes := round(v_mto_interes,v_redondeo);
      if p_ins_capitalizacion = 'S' THEN
       -- si debe capitalizar, genera mov. y reg. de la capitalizacion.
          r_acapi.NRO_CUENTA         := rp_acvis.nro_cuenta;
          r_acapi.FECHA              := v_ult_dia_mes;
          r_acapi.COD_MODULO         := rp_acvis.cod_modulo;
          r_acapi.COD_MODALIDAD      := rp_acvis.cod_modalidad;
          r_acapi.COD_OFICINA        := rp_acvis.cod_oficina;
          r_acapi.COD_MONEDA         := rp_acvis.cod_moneda;
          r_acapi.FEC_INICIO         := v_fec_inicial;
          r_acapi.FEC_FIN            := v_fec_final;
          r_acapi.TIP_CAPITALIZACION := rp_acvis.tip_capitalizacion;
          r_acapi.COD_TASA           := rp_acvis.cod_tasa;
          r_acapi.VAL_TASA           := v_val_tasa;
          r_acapi.MTO_INTERES        := v_mto_interes;
          r_acapi.SAL_PROMEDIO       := v_sal_promedio;
          r_acapi.SAL_ACUMULADO      := v_sal_acumulado;
          lp_ins_capitalizac(r_acapi);
      end if;
      --Interes Acumulado
      v_mto_int_acumulado := v_mto_int_acumulado + v_mto_interes;
      -- v_tas_vigente := v_sig_val_tasa;
      v_fec_inicial := v_sig_fec_vigencia;
   END LOOP;
   --- Devolver monto para generar movimiento
   p_mto_interes := v_mto_int_acumulado;
END;

/* Inserta registro en Capitalizaciones */
PROCEDURE LP_INS_CAPITALIZAC
(RP_ACAPI IN AH_CAPITALIZACIONES%ROWTYPE
 )
 IS
BEGIN
    INSERT INTO AH_CAPITALIZACIONES (COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA,
                                    COD_MONEDA, FECHA, FEC_INICIO, FEC_FIN,
                                    TIP_CAPITALIZACION, COD_TASA, VAL_TASA, MTO_INTERES,
                                    SAL_PROMEDIO, SAL_ACUMULADO)
   VALUES (rp_acapi.cod_modulo,rp_acapi.cod_modalidad, rp_acapi.cod_oficina, rp_acapi.nro_cuenta,
           rp_acapi.cod_moneda, rp_acapi.fecha,rp_acapi.fec_inicio, rp_acapi.fec_fin,
           rp_acapi.tip_capitalizacion, rp_acapi.cod_tasa, nvl(rp_acapi.val_tasa,0), rp_acapi.mto_interes,
           rp_acapi.sal_promedio, rp_acapi.sal_acumulado);
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'Error al insertar la CAPITALIZACION de la Cta '||rp_acapi.nro_cuenta||' - '||sqlerrm);
END;
/* Actualiza Saldo Ult. y Fec Ultima Capitalizacion en CTA_VISTAS */
PROCEDURE LP_ACT_SAL_FEC_CAPIT
 (P_MTO_INTERES IN NUMBER := 0
 )
 IS
   v_sal_total_actualizado NUMBER;
   v_sal_ult_capitalizacion_actualizada NUMBER;
BEGIN
   -- Agregar el registro a la colección
   -- Calcular los nuevos valores antes del UPDATE
   v_sal_total_actualizado := NVL(r_acvis.SAL_TOTAL, 0) + p_mto_interes;
   v_sal_ult_capitalizacion_actualizada := NVL(r_acvis.SAL_TOTAL, 0) + GREATEST(p_mto_interes, 0);                                       
   -- Actualizar en un solo bloque, ya que el cálculo es realizado previamente
                    v_nro_cuenta_tab.EXTEND;
                    v_sal_ult_capitalizacion_tab.EXTEND;
                    v_sal_total_tab.EXTEND;
                    v_ult_dia_mes_tab.EXTEND;

                    v_nro_cuenta_tab(v_nro_cuenta_tab.COUNT) := r_acvis.NRO_CUENTA;
                    v_sal_ult_capitalizacion_tab(v_sal_ult_capitalizacion_tab.COUNT) := v_sal_ult_capitalizacion_actualizada;
                    v_sal_total_tab(v_sal_total_tab.COUNT) := v_sal_total_actualizado;
                    v_ult_dia_mes_tab(v_ult_dia_mes_tab.COUNT) := v_ult_dia_mes;
END;

/* Actualiza Saldo Ult. y Fec Ultima Capitalizacion Grupal */
PROCEDURE LP_ACT_SAL_FEC_CAP_GRUPAL
 (P_NRO_CUENTA IN VARCHAR2, P_MTO_INTERES IN NUMBER := 0
 )
 IS
BEGIN
   if p_mto_interes > 0 then
      --Actualiza Saldos y Fecha de Ultima Capitalizacion
      UPDATE AH_CTA_VISTAS
         SET SAL_ULT_CAPITALIZACION = NVL(r_acvis.SAL_TOTAL,0) + NVL(p_mto_interes,0),
             SAL_TOTAL = NVL(SAL_TOTAL,0) + NVL(p_mto_interes,0),
             FEC_ULT_CAPITALIZACION = v_ult_dia_mes
       WHERE NRO_CUENTA = P_NRO_CUENTA;
   else
      UPDATE AH_CTA_VISTAS
         SET SAL_ULT_CAPITALIZACION = NVL(r_acvis.SAL_TOTAL,0),
             fec_ult_capitalizacion = v_ult_dia_mes
       WHERE  NRO_CUENTA = P_NRO_CUENTA;
   end if;
END;

/* Actualiza Saldo Acumulado Diario y Saldo Mensual en AH_SAL_MENSUALES */
PROCEDURE LP_ACT_SAL_MES_DIARI
 (P_MTO_INTERES IN NUMBER := 0
 )
 IS

V_SIG_FECHA DATE;
V_CAN_DIAS AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE;
V_DUMMY VARCHAR2(2);
V_SIG_ANO AH_SAL_MENSUALES.ANO%TYPE;
V_SIG_MES AH_SAL_MENSUALES.MES%TYPE;
--Definicion del Cursor
CURSOR c_sal_mensuales IS
   SELECT 'X'
     FROM AH_SAL_MENSUALES
    WHERE NRO_CUENTA = r_acvis.nro_cuenta AND
          ANO = v_sig_ano  AND
          MES = v_sig_mes
FOR UPDATE OF CAN_CREDITOS;
BEGIN
   v_sig_fecha := add_months(v_fec_actual,1);
   v_sig_ano := to_char(v_sig_fecha,'YYYY');
   v_sig_mes := to_char(v_sig_fecha, 'MM');
   IF c_sal_mensuales%ISOPEN THEN
      CLOSE c_sal_mensuales;
   END IF;
   OPEN c_sal_mensuales;
      FETCH c_sal_mensuales INTO v_dummy;
      IF c_sal_mensuales%FOUND THEN
         v_can_dias := TO_NUMBER(TO_CHAR(v_fec_proxima,'DD'))-1;
         UPDATE AH_SAL_MENSUALES
            SET SAL_ACU_DIARIO = NVL(SAL_ACU_DIARIO,0) + p_mto_interes * v_can_dias,
                SAL_INI_MES = NVL(SAL_INI_MES,0) + p_mto_interes
         WHERE CURRENT OF c_sal_mensuales;
        CLOSE c_sal_mensuales;
     ELSE
        CLOSE c_sal_mensuales;
     END IF;
END;

/* Actualiza Saldo Acumulado Diario y Saldo Mensual en AH_SAL_MENSUALES Grupal*/
PROCEDURE LP_ACT_SAL_MES_DIA_GRUPAL
 (P_NRO_CUENTA IN VARCHAR2, P_MTO_INTERES IN NUMBER := 0
 )
 IS

V_SIG_FECHA DATE;
V_CAN_DIAS AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE;
V_DUMMY VARCHAR2(2);
V_SIG_ANO AH_SAL_MENSUALES.ANO%TYPE;
V_SIG_MES AH_SAL_MENSUALES.MES%TYPE;
--Definicion del Cursor
CURSOR c_sal_mensuales IS
   SELECT 'X'
     FROM AH_SAL_MENSUALES
    WHERE NRO_CUENTA = P_NRO_CUENTA AND
          ANO = v_sig_ano  AND
          MES = v_sig_mes
FOR UPDATE OF CAN_CREDITOS;
BEGIN
   v_sig_fecha := add_months(v_fec_actual,1);
   v_sig_ano := to_char(v_sig_fecha,'YYYY');
   v_sig_mes := to_char(v_sig_fecha, 'MM');
   IF c_sal_mensuales%ISOPEN THEN
      CLOSE c_sal_mensuales;
   END IF;
   OPEN c_sal_mensuales;
      FETCH c_sal_mensuales INTO v_dummy;
      IF c_sal_mensuales%FOUND THEN
         v_can_dias := TO_NUMBER(TO_CHAR(v_fec_proxima,'DD'))-1;
         UPDATE AH_SAL_MENSUALES
            SET SAL_ACU_DIARIO = NVL(SAL_ACU_DIARIO,0) + p_mto_interes * v_can_dias,
                SAL_INI_MES = NVL(SAL_INI_MES,0) + p_mto_interes
         WHERE CURRENT OF c_sal_mensuales;
        CLOSE c_sal_mensuales;
     ELSE
        CLOSE c_sal_mensuales;
     END IF;
END;

FUNCTION LF_ES_EMPLEADO(p_cod_persona varchar2) return varchar2 is
  v_existe varchar2(1) := 'N';
  v_cod_segmento ge_clientes.cod_seg_cliente%type;
begin
     begin
       Select 'S'
         into v_existe
         from ba_usuarios
        where cod_persona = p_cod_persona
          and estado = 'A';
     exception
         When NO_DATA_FOUND Then
              v_existe := 'N';
         When TOO_MANY_ROWS Then
              v_existe := 'S';
     end;
     if v_existe = 'N' then
         select cod_seg_cliente
           into v_cod_segmento
           from ge_clientes
          where cod_persona = p_cod_persona;
        if v_cod_segmento = LF_OBT_PARDINAMICO('SEG_FUNCIONARIOS',v_ge_par_dinamicos) then -- funcionarios
           v_existe := 'S';
        else
           v_existe := 'N';
        end if;
     end if;
     Return v_existe;
Exception
     When NO_DATA_FOUND Then
          v_existe := 'N';
          return(v_existe);
     When others then
          v_existe := 'N';
          return(v_existe);
end;
/*FUNCTION LF_OBT_PARDINAMICO(
    P_PARAMETRO IN GE_PAR_DINAMICOS.PARAMETRO%TYPE,
    P_CACHED_DATA IN it.typ_ge_par_dinamicos_tab,
    P_COD_MODULO IN NUMBER DEFAULT NULL,
    P_COD_MODALIDAD IN NUMBER DEFAULT NULL,
    P_COD_MONEDA IN VARCHAR2 DEFAULT NULL,
    P_COD_OFICINA IN NUMBER DEFAULT NULL,
    P_COD_SUB_MODALIDAD IN NUMBER DEFAULT NULL
) RETURN VARCHAR2
IS
    v_val_parametro GE_PAR_DINAMICOS.VAL_PARAMETRO%TYPE;
cursor param is   
 SELECT val_parametro
    FROM TABLE(P_CACHED_DATA)
    WHERE parametro = P_PARAMETRO
      AND NVL(COD_MODULO, NVL(P_COD_MODULO, -1)) = NVL(P_COD_MODULO, -1)
      AND NVL(COD_MODALIDAD, NVL(P_COD_MODALIDAD, -1)) = NVL(P_COD_MODALIDAD, -1)
      AND NVL(COD_SUB_MODALIDAD, NVL(P_COD_SUB_MODALIDAD, -1)) = NVL(P_COD_SUB_MODALIDAD, -1)
      AND NVL(COD_OFICINA, NVL(P_COD_OFICINA, -1)) = NVL(P_COD_OFICINA, -1)
      AND NVL(COD_MONEDA, NVL(P_COD_MONEDA, 'x')) = NVL(P_COD_MONEDA, 'x')
     order by decode(cod_modulo,null,0,1) +
             decode(cod_modalidad,null,0,1) +
             decode(cod_sub_modalidad,null,0,1) +
             decode(cod_oficina,null,0,1) +
             decode(cod_moneda,null,0,1) desc;
  BEGIN
   open param;
   fetch param into v_val_parametro;
   if param%notfound then
      close param;
      raise no_data_found;
   else
      close param;
   end if;
   return v_val_parametro;
   exception
      when no_data_found then
         return null;
/*         raise_application_error(-20000,
         'No existe valor p/parametro '||p_parametro);*/
--END;

FUNCTION LF_OBT_PARDINAMICO(
    P_PARAMETRO IN GE_PAR_DINAMICOS.PARAMETRO%TYPE,
    P_CACHED_DATA IN typ_ge_par_dinamicos_tab,
    P_COD_MODULO IN NUMBER DEFAULT NULL,
    P_COD_MODALIDAD IN NUMBER DEFAULT NULL,
    P_COD_MONEDA IN VARCHAR2 DEFAULT NULL,
    P_COD_OFICINA IN NUMBER DEFAULT NULL,
    P_COD_SUB_MODALIDAD IN NUMBER DEFAULT NULL
)
 RETURN VARCHAR2
 IS
v_val_parametro ge_par_dinamicos.val_parametro%type;
begin 
  FOR i IN 1 .. P_CACHED_DATA.COUNT LOOP
            IF P_CACHED_DATA(i).parametro = P_PARAMETRO 
              AND NVL(P_CACHED_DATA(i).COD_MODULO,NVL(P_COD_MODULO,-1)) = NVL(P_COD_MODULO,-1)
              AND  NVL(P_CACHED_DATA(i).COD_MODALIDAD,NVL(P_COD_MODALIDAD,-1)) = NVL(P_COD_MODALIDAD,-1)
              AND  NVL(P_CACHED_DATA(i).COD_SUB_MODALIDAD,NVL(P_COD_SUB_MODALIDAD,-1)) = NVL(P_COD_SUB_MODALIDAD,-1)
              AND  NVL(P_CACHED_DATA(i).COD_OFICINA,NVL(P_COD_OFICINA,-1)) = NVL(P_COD_OFICINA,-1)
              AND  NVL(P_CACHED_DATA(i).COD_MONEDA,NVL(P_COD_MONEDA,'x')) = NVL(P_COD_MONEDA,'x') THEN
                v_val_parametro := P_CACHED_DATA(i).val_parametro;
                RETURN v_val_parametro;
                exit;
            END IF;
        END LOOP;
        if v_val_parametro is null then
         return null;
        end if;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    return null;--raise_application_error(-20000,'No existe parametro dinamico');
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error al buscar en ge_par_dinamicos '||SQLERRM);
END;
/**/
PROCEDURE LP_TAS_SIG_VIGENCIA
 (P_COD_TASA IN GE_TASAS.COD_TASA%TYPE
 ,P_COD_MODULO IN GE_MODALIDADES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN GE_TAS_FECHAS.COD_OFICINA%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_FEC_INICIO IN GE_TAS_FECHAS.FEC_VIGENCIA%TYPE
 ,P_FEC_FINAL IN DATE
 ,P_FEC_VIGENCIA OUT GE_TAS_FECHAS.FEC_VIGENCIA%TYPE
 ,P_FIN_TASA IN OUT VARCHAR2
 ,P_COD_SUB_MODALIDAD IN AH_CTA_VISTAS.COD_SUB_MODALIDAD%TYPE
 )
 IS
 v_tip_tasa ge_tasas.tipo%type;
 v_cod_ente          ge_tas_fechas.cod_ente%type;

BEGIN
/*Lee la menor fecha de tasa que sea mayor que la fecha de inicio en GE_TAS_FECHAS.
Si no encuentra es por que ya no volvio a cambiar*/
   P_FIN_TASA := 'N';
   --
   IF P_NRO_CUENTA IS NOT NULL THEN
        begin
           select ge.cod_ente 
             into v_cod_ente
             from ge_entes ge, ah_cta_vistas acv
            where ge.cod_ente = acv.cod_ente 
              and acv.nro_cuenta = p_nro_cuenta;
        exception
          when no_data_found then
            null;
          when others then
            null;
        end;
   ELSE
     v_cod_ente := NULL;
   END IF;
   --
   SELECT tipo
     INTO v_tip_tasa
     FROM GE_TASAS
    WHERE COD_TASA = P_COD_TASA;
   ---
   if v_tip_tasa = 'F' then
       -- tasas  por fecha
       SELECT MIN(fec_vigencia)
        INTO P_FEC_VIGENCIA
        FROM GE_TAS_FECHAS
       WHERE COD_TASA = P_COD_TASA
         AND FEC_VIGENCIA > P_FEC_INICIO
         AND ((COD_MODULO = P_COD_MODULO OR COD_MODULO IS NULL)
               AND (COD_MODALIDAD = P_COD_MODALIDAD OR COD_MODALIDAD IS NULL)
               AND (COD_SUB_MODALIDAD = P_COD_SUB_MODALIDAD OR COD_SUB_MODALIDAD IS NULL)
               AND (COD_OFICINA = P_COD_OFICINA OR COD_OFICINA IS NULL)
               AND (COD_ENTE = V_COD_ENTE OR COD_ENTE IS NULL)
               AND (COD_MONEDA = P_COD_MONEDA OR COD_MONEDA IS NULL)
               AND (NRO_CUENTA = P_NRO_CUENTA OR NRO_CUENTA IS NULL));
   elsif v_tip_tasa = 'V' then
       -- Tasas por rangos ------
       SELECT MIN(fec_vigencia)
         INTO P_FEC_VIGENCIA
         FROM GE_TAS_RANGOS
        WHERE COD_TASA = P_COD_TASA
          AND (COD_MODULO = P_COD_MODULO OR COD_MODULO IS NULL)
          AND (COD_MODALIDAD = P_COD_MODALIDAD OR COD_MODALIDAD IS NULL)
          AND (COD_SUB_MODALIDAD = P_COD_SUB_MODALIDAD OR COD_SUB_MODALIDAD IS NULL)
          AND (COD_OFICINA = p_cod_oficina OR COD_OFICINA IS NULL)
          AND (COD_ENTE = v_cod_ente OR COD_ENTE IS NULL)
          AND (COD_MONEDA = P_COD_MONEDA OR COD_MONEDA IS NULL)
          AND (NRO_CUENTA = P_NRO_CUENTA OR  NRO_CUENTA IS NULL)
          AND FEC_VIGENCIA > P_FEC_INICIO;
   else
       raise_application_error(-20000,'Tipo de Tasa '||v_tip_tasa||' no valido!!!');
   end if;
   IF P_FEC_VIGENCIA IS NULL THEN
       P_FIN_TASA := 'S';
       P_FEC_VIGENCIA := P_FEC_FINAL + 1;
   END IF;
END;
/* Obtiene el Valor de la tasa a aplicar */
PROCEDURE LP_OBT_VAL_TASA
  (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_MTO_TRANSACCION IN NUMBER default 0
 ,P_TAS_PERSONALIZADA IN GE_CUENTAS.TAS_PERSONALIZADA%TYPE
 ,P_COD_TASA IN OUT GE_TASAS.COD_TASA%TYPE
 ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_FEC_FINAL IN DATE
 ,P_VAL_TASA OUT GE_TAS_FECHAS.VAL_TASA%TYPE
 ,P_FEC_VIGENCIA OUT GE_TAS_FECHAS.FEC_VIGENCIA%TYPE
 ,P_TIP_VALOR OUT GE_TASAS.TIP_VALOR%TYPE
 ,P_TIPO OUT GE_TASAS.TIPO%TYPE
 ,P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE DEFAULT NULL
 ,P_COD_SUB_MODALIDAD OUT GE_CUENTAS.COD_SUB_MODALIDAD%TYPE)

 IS

  v_lugar                  VARCHAR2(250);
  v_fec_final              DATE;
  v_fec_vigencia           GE_TAS_FECHAS.FEC_VIGENCIA%TYPE;
  v_encontro_tas_pers      VARCHAR2(1) := 'N';
  v_cod_persona            BA_PERSONAS.COD_PERSONA%TYPE;
  v_tip_iva                BA_PERSONAS.TIP_IVA%TYPE;
  v_tas_personalizada      BA_PERSONAS.TAS_PERSONALIZADA%TYPE;
  v_spread                 GE_TAS_FECHAS.VAL_EXTENSION%TYPE;
  v_cod_sub_modalidad      GE_TAS_FECHAS.COD_SUB_MODALIDAD%TYPE := P_COD_SUB_MODALIDAD;
  v_val_tasa               GE_TAS_FECHAS.VAL_TASA%TYPE := -999;
  v_aux_val_min            GE_TAS_FECHAS.VAL_MINIMO%TYPE;   --Es una columna auxiliar donde se descargara los datos a nivel general, dependiendo del caso se utilizará o no este campo para retornar valores.
  v_aux_val_max            GE_TAS_FECHAS.VAL_MAXIMO%TYPE;   --Es una columna auxiliar donde se descargara los datos a nivel general, dependiendo del caso se utilizará o no este campo para retornar valores.
  v_aux_val_hasta          GE_TAS_RANGOS.VAL_HASTA%TYPE;    --Es una columna auxiliar donde se descargara los datos a nivel general, dependiendo del caso se utilizará o no este campo para retornar valores.
  v_redondeo               number(4);
  v_cod_ente               ge_entes.cod_ente%type;
  v_val_minimo             GE_TAS_FECHAS.VAL_MINIMO%TYPE;   
  v_val_maximo             GE_TAS_FECHAS.VAL_MAXIMO%TYPE;
  v_val_hasta         GE_TAS_RANGOS.VAL_HASTA%TYPE;

BEGIN
   v_lugar     := 'lp_obt_val_tasa';
   v_fec_final := p_fec_final;
   --
   IF P_NRO_CUENTA IS NOT NULL THEN
        BEGIN
                    SELECT ge.cod_ente
                      INTO v_cod_ente
                      FROM ge_entes ge
                      JOIN ah_cta_vistas acv ON ge.cod_ente = acv.cod_ente
                     WHERE acv.nro_cuenta = P_NRO_CUENTA;
                EXCEPTION
                    WHEN OTHERS THEN NULL;
                END;
    END IF;
      -- Recuperar el valor para el redondeo correspondiente
   v_redondeo := LF_OBT_PARDINAMICO('VAL_RED_MON_EXTRANJERA',v_ge_par_dinamicos,p_cod_modulo,p_cod_modalidad,p_cod_moneda);
   IF v_fec_final IS NULL THEN
      -- Recuperar la fecha del modulo desde donde se esta ejecutando
      v_fec_final := pag_cal.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   END IF;
   -- Recupera el codigo de tasa en el caso de fuere null de la tabla GE_TRANSACCIONES
   IF p_cod_tasa IS NULL AND p_cod_transaccion IS NOT NULL THEN
      BEGIN
         v_lugar := 'lp_obt_val_tasa: GE_TRANSACCIONES: Mad '||p_cod_modalidad||' Tra '||p_cod_transaccion;
         SELECT cod_tasa
           INTO p_cod_tasa
           FROM ge_transacciones
          WHERE cod_modulo      = p_cod_modulo
            AND cod_modalidad   = p_cod_modalidad
            AND cod_transaccion = p_cod_transaccion;
      EXCEPTION
            WHEN OTHERS THEN
             RAISE_APPLICATION_ERROR(-20001,v_lugar||' '||SQLERRM);
      END;
      IF p_cod_tasa IS NULL THEN
         p_val_tasa := 0;
         RETURN;
      END IF;
   END IF;
   -- Lee la Tabla de tasas para saber si es tarifa o porcentaje.
   BEGIN
     v_lugar := 'lp_obt_val_tasa: GE_TASAS';
     SELECT tip_valor, tipo
       INTO p_tip_valor, p_tipo
     FROM ge_tasas
     WHERE cod_tasa = p_cod_tasa;
   EXCEPTION
     WHEN OTHERS THEN
       --RAISE_APPLICATION_ERROR(-20002,' Tasa '||TO_CHAR(p_cod_tasa)||' '||p_cod_moneda||to_char(p_cod_oficina,'999')||' '||p_nro_cuenta||' '||v_lugar||' '||SQLERRM);
       v_val_tasa := null;
   END;
   -- buscar principal de cuenta y tipo de contribuyente, siempre q tenga cuenta y no venga de apertura(sin cta asignada)
   IF p_nro_cuenta is not null and p_nro_cuenta <> '999999999999999' THEN
       BEGIN
           select cod_persona
            into v_cod_persona
            from ge_cta_clientes
           where nro_cuenta = p_nro_cuenta
             and relacion   = 'P';
         exception
           when others then
             null;
        END;
   ELSIF p_cod_persona is not null THEN
     v_cod_persona := p_cod_persona; -- buscar x la persona, ya que no tiene cuenta
   END IF;
   IF p_nro_cuenta is not null and v_cod_sub_modalidad is null THEN
         begin
           select cod_sub_modalidad
           into v_cod_sub_modalidad
           from ge_cuentas
           where nro_cuenta = p_nro_cuenta;
        exception
         when others then
           null;
        end;
   END IF;
   ----------------
   IF v_cod_persona is not null THEN
      --v_tip_iva     := fue_obt_per_tip_iva(v_cod_persona);
 /*     Begin
    --Obtiene el tipo de contribuyente de la persona
        select tip_iva
        into v_tip_iva
        from ba_personas
        where cod_persona = v_cod_persona;
    exception
      when no_data_found then
       null;
   End;*/
      -- ver si la persona tiene personalización de tasas
      BEGIN
        v_lugar := 'lp_obt_val_tasa: Buscando Personalización de Tasas';
         select nvl(tas_personalizada,'N')
           into v_tas_personalizada
           from ba_personas
          where cod_persona = v_cod_persona;
      EXCEPTION
         when others then
            raise_application_error(-20003,' Persona '||v_cod_persona||' '||v_lugar||' '||SQLERRM);
      END;
   END IF;
   --DYDMR-5313 verificar sí solo tiene personalización de tasas por cuenta (ALV-NOV/2016)
   IF v_tas_personalizada <> 'S' and p_nro_cuenta is not null THEN 
      Begin
        v_lugar := 'lp_obt_val_tasa: Buscando Personalización de Cuentas';
        select nvl(c.tas_personalizada,'N')
          into v_tas_personalizada        
          from ge_cuentas c
         where c.nro_cuenta = p_nro_cuenta;
      Exception
        when others then
          raise_application_error(-20003,' Cuenta '||p_nro_cuenta||' '||v_lugar||' '||SQLERRM);
      End;
   END IF;
      
   /* Si la tasa es personalizada busca primero el valor de la tasa en GE_TAS_FECHAS o en GE_TAS_RANGOS
      ya sea por cuenta o por persona, si no encuentra valores para procesar se busca la personalizacion
      de la tasa a nivel GENERAL
   */
   IF (p_tas_personalizada = 'S' or v_tas_personalizada = 'S') THEN
      IF  p_tipo = 'F' THEN
          --buscar tasa personalizada x cuenta
          BEGIN
             v_lugar := 'lp_obt_val_tasa: GE_TAS_FECHAS (personalizado fijo x cuenta)';
             WITH MaxFecVigencia AS (
              SELECT MAX(fec_vigencia) AS max_fec_vigencia
              FROM ge_tas_fechas
              WHERE nro_cuenta = p_nro_cuenta
                AND cod_tasa = p_cod_tasa
                AND fec_vigencia <= v_fec_final)
            SELECT NVL(val_tasa, -999), fec_vigencia, val_minimo, val_maximo, val_extension
            INTO v_val_tasa, p_fec_vigencia, v_val_minimo, v_val_maximo, v_spread
            FROM ge_tas_fechas gtf
            JOIN MaxFecVigencia mfv
              ON gtf.fec_vigencia = mfv.max_fec_vigencia
            WHERE gtf.nro_cuenta = p_nro_cuenta
              AND gtf.cod_tasa = p_cod_tasa
              AND (cod_modulo = p_cod_modulo OR cod_modulo IS NULL)
              AND (cod_modalidad = p_cod_modalidad OR cod_modalidad IS NULL)
              AND (cod_sub_modalidad = v_cod_sub_modalidad OR cod_sub_modalidad IS NULL)
              AND (cod_oficina = p_cod_oficina OR cod_oficina IS NULL)
              AND (cod_ente = v_cod_ente OR cod_ente IS NULL);
             v_encontro_tas_pers := 'S';
          EXCEPTION
             WHEN NO_DATA_FOUND THEN
                   --buscar tasa personalizada x persona
                   v_lugar := 'lp_obt_val_tasa: GE_TAS_FECHAS (personalizado fijo x persona)';
                   begin
                     WITH MaxFecVigencia AS (
                      SELECT MAX(fec_vigencia) AS max_fec_vigencia
                      FROM ge_tas_fechas
                      WHERE cod_tasa = p_cod_tasa
                        AND cod_persona = v_cod_persona
                        AND fec_vigencia <= v_fec_final
                        AND (cod_modulo = p_cod_modulo OR cod_modulo IS NULL)
                        AND (cod_modalidad = p_cod_modalidad OR cod_modalidad IS NULL)
                        AND (cod_sub_modalidad = v_cod_sub_modalidad OR cod_sub_modalidad IS NULL)
                        AND (cod_oficina = p_cod_oficina OR cod_oficina IS NULL)
                        AND (cod_ente = v_cod_ente OR cod_ente IS NULL)
                        AND (cod_moneda = p_cod_moneda OR cod_moneda IS NULL)
                        AND nro_cuenta IS NULL
                  )
                      SELECT NVL(val_tasa, -999), fec_vigencia, val_minimo, val_maximo, val_extension
                      INTO v_val_tasa, p_fec_vigencia, v_val_minimo, v_val_maximo, v_spread
                      FROM ge_tas_fechas gtf
                      JOIN MaxFecVigencia mfv
                        ON gtf.fec_vigencia = mfv.max_fec_vigencia
                      WHERE gtf.cod_tasa = p_cod_tasa
                        AND gtf.cod_persona = v_cod_persona
                        AND (gtf.cod_modulo = p_cod_modulo OR gtf.cod_modulo IS NULL)
                        AND (gtf.cod_modalidad = p_cod_modalidad OR gtf.cod_modalidad IS NULL)
                        AND (gtf.cod_sub_modalidad = v_cod_sub_modalidad OR gtf.cod_sub_modalidad IS NULL)
                        AND (gtf.cod_oficina = p_cod_oficina OR gtf.cod_oficina IS NULL)
                        AND (gtf.cod_ente = v_cod_ente OR gtf.cod_ente IS NULL)
                        AND (gtf.cod_moneda = p_cod_moneda OR gtf.cod_moneda IS NULL)
                        AND gtf.nro_cuenta IS NULL;
                       v_encontro_tas_pers := 'S';
                   exception
                      when no_data_found then
                         v_encontro_tas_pers := 'N';
                      when others then
                         RAISE_APPLICATION_ERROR(-20004,' Tasa '||TO_CHAR(p_cod_tasa)||' '||
                                                        v_lugar||' - para Persona '||v_cod_persona||' '||SQLERRM);
                   end; --hasta aquí persona
             WHEN OTHERS THEN
                 RAISE_APPLICATION_ERROR(-20005,' Tasa '||TO_CHAR(p_cod_tasa)||' '||
                                                v_lugar||' - para '||p_cod_moneda||' '||v_fec_final||' '||SQLERRM);
          END;
       ELSIF p_tipo = 'V' THEN -- JG : 20/05/11 : Buscar personalizacion de tasa por rangos
            DECLARE CURSOR rango IS
               SELECT fec_vigencia, nvl(val_Tasa,-999), val_extension, val_hasta
                 FROM ge_tas_rangos
                WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
                  AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
                  AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                  AND nvl(cod_oficina,nvl(p_cod_oficina,-1))             = nvl(p_cod_oficina,-1)
                  AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
                  AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x')
                  AND nro_cuenta                                         = p_nro_cuenta
                  AND cod_tasa                                           = p_cod_tasa
                  AND val_hasta                                         >= NVL(p_mto_transaccion,0)
                  AND fec_vigencia                                      <= v_fec_final
               ORDER BY DECODE(COD_MODULO, NULL, 0, 1) +
                      DECODE(COD_MODALIDAD, NULL, 0, 1) +
                      DECODE(COD_SUB_MODALIDAD, NULL, 0, 1) DESC,
                      DECODE(NRO_CUENTA, NULL, 0, 1) DESC,
                      fec_vigencia DESC, val_hasta ASC;

            BEGIN
               v_lugar := 'lp_obt_val_tasa: GE_TAS_RANGOS (personalizado variable x cuenta)';
               IF rango%isopen THEN
                  CLOSE rango;
               END IF;
               OPEN rango;
                 FETCH rango INTO p_fec_vigencia, v_val_Tasa, v_spread, v_val_hasta;
                    IF RANGO%NOTFOUND THEN  -- si no encuentra por cuenta busca por persona
                      -- Buscar si esta personalizado por Persona
                      DECLARE CURSOR rango IS
                       SELECT fec_vigencia, nvl(val_Tasa,-999), val_extension, val_hasta
                         FROM ge_tas_rangos
                        WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
                          AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
                          AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                          AND nvl(cod_oficina,nvl(p_cod_oficina,-1))             = nvl(p_cod_oficina,-1)
                          AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
                          AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x')
                          AND nro_cuenta IS NULL
                          AND cod_tasa                                           = p_cod_tasa
                          and cod_persona                                        = v_cod_persona
                          AND val_hasta                                         >= NVL(p_mto_transaccion,0)
                          AND fec_vigencia                                      <= v_fec_final
                        ORDER BY DECODE(COD_MODULO, NULL, 0, 1) +
                                 DECODE(COD_MODALIDAD, NULL, 0, 1) +
                                 DECODE(COD_SUB_MODALIDAD, NULL, 0, 1) DESC,
                                 DECODE(COD_PERSONA,NULL,0,1) DESC,
                                 fec_vigencia DESC, val_hasta ASC;
                      BEGIN
                        v_lugar := 'lp_obt_val_tasa: GE_TAS_RANGOS (personalizado variable x persona)';
                        IF rango%isopen THEN
                          CLOSE rango;
                        END IF;
                        OPEN rango;
                          FETCH rango INTO p_fec_vigencia, v_val_tasa, v_spread, v_val_hasta;
                        IF RANGO%NOTFOUND THEN
                           v_encontro_tas_pers := 'N';
                        ELSE
                           v_encontro_tas_pers := 'S';
                        END IF;
                        CLOSE RANGO;
                      END;
                    ELSE
                      v_encontro_tas_pers := 'S';
                    END IF;
               CLOSE RANGO;
             END;
       END IF;
   END IF;
   -- Si es fija se busca el valor en GE_TAS_FECHAS a nivel GENERAL (GENERAL no tiene spread)
   IF p_tipo = 'F' and v_val_tasa = -999 THEN
      --si no encontró o tiene spread o no tiene val_tasa, busca la tasa base
      DECLARE CURSOR fijas IS
         SELECT nvl(val_tasa,0), fec_vigencia, val_minimo, val_maximo
           FROM ge_tas_fechas
          WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
            AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
            AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
            AND nvl(cod_oficina,nvl(p_cod_oficina,-1))             = nvl(p_cod_oficina,-1)
            AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
            AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x')
          --  and nvl(tip_iva,nvl(v_tip_iva,'x'))                    = nvl(v_tip_iva,'x')
            AND cod_tasa                                           = p_cod_tasa
            AND nro_cuenta  IS NULL
            and cod_persona IS NULL
            and fec_vigencia                                      <= v_fec_final
       ORDER BY DECODE(COD_MODULO, NULL, 0, 1) +
                DECODE(COD_MODALIDAD, NULL, 0, 1) +
                DECODE(COD_SUB_MODALIDAD, NULL, 0, 1) DESC, fec_vigencia DESC;

        BEGIN
           v_lugar := 'lp_obt_val_tasa: GE_TAS_FECHAS (gral)';
           IF fijas%isopen THEN
              CLOSE fijas;
           END IF;
           OPEN fijas;
              FETCH fijas INTO v_val_tasa, p_fec_vigencia, v_aux_val_min, v_aux_val_max;
           IF FIJAS%NOTFOUND THEN
              --No es un error propiamente, por eso se omite el SQLERRM (ORA-0000, Normal succesful completion)
              v_val_tasa := null;
           END IF;
           CLOSE FIJAS;
            --Si a nivel personalizado no se ha definido tampoco el val_minimo y el val_maximo,
            --se carga dichos valores del nivel general
           IF v_val_minimo IS NULL THEN
              v_val_minimo := v_aux_val_min;
           END IF;
           IF v_val_maximo IS NULL THEN
              v_val_maximo := v_aux_val_max;
           END IF;
        END;
   ELSIF p_tipo = 'V' and v_val_tasa = -999 THEN
      --si no encontró o tiene spread o no tiene val_tasa, busca la tasa base
      DECLARE CURSOR rango IS
         SELECT fec_vigencia, nvl(val_tasa,0), val_hasta
           FROM ge_tas_rangos
          WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
            AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
            AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
            AND nvl(cod_oficina,nvl(p_cod_oficina,-1))             = nvl(p_cod_oficina,-1)
            AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
            AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x')
            AND nro_cuenta  IS NULL
            and cod_persona IS NULL
            AND cod_tasa                                           = p_cod_tasa
            AND val_hasta                                         >= NVL(p_mto_transaccion,0)
            AND fec_vigencia                                      <= v_fec_final
       ORDER BY DECODE(COD_MODULO, NULL, 0, 1) +
                DECODE(COD_MODALIDAD, NULL, 0, 1) +
                DECODE(COD_SUB_MODALIDAD, NULL, 0, 1) DESC, fec_vigencia DESC, val_hasta ASC;

        BEGIN
           v_lugar := 'lp_obt_val_tasa: GE_TAS_RANGOS (gral. 01)';
           IF rango%isopen THEN
              CLOSE rango;
           END IF;
           OPEN rango;
              FETCH rango INTO p_fec_vigencia, v_val_tasa, v_aux_val_hasta;
           IF RANGO%NOTFOUND THEN
              --No es un error propiamente, por eso se omite el SQLERRM (ORA-0000, Normal succesful completion)
              --RAISE_APPLICATION_ERROR(-20008,'No se han recuperado datos para la Tasa '||TO_CHAR(p_cod_tasa)||' '||v_lugar||'- para '||p_cod_moneda||' '||p_mto_transaccion);
              v_val_tasa := null;
           END IF;
           CLOSE RANGO;
           --Si a nivel personalizado no se ha definido tampoco el val_hasta,
           --se carga el val_hasta del nivel general
           IF nvl(v_val_hasta,0) = 0 THEN
              v_val_hasta := nvl(v_aux_val_hasta, 0);
           END IF;
        END;
     END IF;
     IF v_val_tasa = -999 THEN
        v_lugar := 'lp_obt_val_tasa: despues de recuperar tasa a nivel gral.';
        --Si por algun motivo no ha ingresado en ninguno de los procedimientos
        --se debe tratar el v_val_tasa= -999, para el proceso.
        RAISE_APPLICATION_ERROR(-20009,'El valor para la Tasa ' || p_cod_tasa || ' no puede ser ' || TO_CHAR(v_val_tasa) || ' ' || v_lugar);
     END IF;
     p_val_tasa := nvl(v_val_tasa,0);
     IF v_spread IS NOT NULL THEN
       if nvl(p_tip_valor,'X') = 'P' then -- No se redondea para porcentaje. V.O. 05-02-14
         p_val_tasa := nvl(p_val_tasa,0) - (nvl(p_val_tasa,0) * (v_spread/100));
       else
         p_val_tasa := round(nvl(p_val_tasa,0) - (nvl(p_val_tasa,0) * (v_spread/100)),v_redondeo);
       end if;
     END IF;
END;


BEGIN
   --Recuperamos la cantidad de users con el dominio
   BEGIN
     SELECT COUNT(*)
       INTO v_can_user
       FROM ba_cod_referencias
      WHERE dominio = 'USU_MOV_CIERRE'
        AND abreviatura = 'MOVCIERRE';
   END;
   --Obtiene las Fechas necesarias--------------------------
   pag_cal.pr_obt_dat_calendar(3);
   v_fec_actual  := nvl(p_fec_capitalizacion,pag_cal.g_fec_actual);
   v_ult_dia_mes := pag_cal.g_ult_dia_mes;
   v_fec_proxima := pag_cal.g_fec_proxima;
   v_mes_actual  := TO_NUMBER(TO_CHAR(v_fec_actual,'MM'));
   v_ano_actual  := TO_NUMBER(TO_CHAR(v_fec_actual,'YYYY'));
   v_nro_secuencia := 0;
   DBMS_APPLICATION_INFO.SET_ACTION('PRA_CAP_CTA_VISTA');
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PRA_CAP_CTA_VISTA, Iniciando');
   
   ---------------------------------------------------------
   SELECT typ_ge_par_dinamicos(
             parametro,
             cod_modulo,
             cod_modalidad,
             cod_moneda,
             cod_oficina,
             cod_sub_modalidad,
             val_parametro
          )
    BULK COLLECT INTO v_ge_par_dinamicos
    FROM ge_par_dinamicos
    WHERE parametro IN ('DEV_GRU_HAB_DEV_GRUPAL',
                        'SAL_MIN_CAP_PAC_EMPLEADO',
                        'SAL_MIN_CAP_PACTADO',
                        'VAL_RED_MON_EXTRANJERA',
                        'SEG_FUNCIONARIOS')
    ORDER BY decode(cod_modulo, NULL, 0, 1) +
             decode(cod_modalidad, NULL, 0, 1) +
             decode(cod_sub_modalidad, NULL, 0, 1) +
             decode(cod_oficina, NULL, 0, 1) +
             decode(cod_moneda, NULL, 0, 1) DESC;
   V_HAB_DEV_GRUPAL := nvl(LF_OBT_PARDINAMICO('DEV_GRU_HAB_DEV_GRUPAL',v_ge_par_dinamicos),'N');
   
   if P_NRO_CUENTA is null then
     ---Obtenemos la cantidad de registros a procesar--------------------------------------
     SELECT count (0)
       INTO v_cant_registros
       FROM AH_CTA_VISTAS X, ah_cta_capitalizadas c
      WHERE X.COD_MODULO = 3
        AND ESTADO NOT IN ('C','P','A','X')
        AND x.nro_cuenta = c.nro_cuenta
        AND ((ESTADO <> 'T') OR (ESTADO = 'T' AND COD_MODALIDAD = 334 AND COD_SUB_MODALIDAD = 2 ))
        AND ((x.NRO_CUENTA = P_NRO_CUENTA)
           OR(P_NRO_CUENTA IS NULL AND MOD(v_mes_actual,TIP_CAPITALIZACION) = 0))
        AND (FEC_ULT_CAPITALIZACION is null
             OR FEC_ULT_CAPITALIZACION < v_fec_actual)
        AND ((V_HAB_DEV_GRUPAL = 'N') OR 
           (V_HAB_DEV_GRUPAL = 'S' AND NOT EXISTS (SELECT 1 FROM AH_DEV_GRU_CUENTAS Z WHERE Z.NRO_CUENTA = X.NRO_CUENTA)))
        AND not exists(select 1
                        from ah_capitalizaciones a
                        where a.fecha = V_ULT_DIA_MES
                          and a.nro_cuenta = x.nro_cuenta);
   end if;
   
                        
   ----Cuerpo principal----------------------------------------------------------------                     
   OPEN c_cta_vistas;
    LOOP
      FETCH c_cta_vistas BULK COLLECT INTO l_cta_vistas LIMIT v_limit;
        EXIT WHEN l_cta_vistas.COUNT = 0;     
          -- Limpiar las colecciones
   v_capitalizaciones := T_AH_CAPITALIZACIONES();
   v_nro_cuenta_tab := t_nro_cuenta_tab();
   v_sal_ult_capitalizacion_tab := t_sal_ult_capitalizacion_tab();
   v_sal_total_tab := t_sal_total_tab();
   v_ult_dia_mes_tab := t_ult_dia_mes_tab(); 
   ---------------------------------------------------------
   -- ciclo general, carga de las variables de cuentas------
   ---------------------------------------------------------
     FOR i IN 1 .. l_cta_vistas.COUNT LOOP
            r_acvis.nro_cuenta        := l_cta_vistas(i).nro_cuenta;
            r_acvis.denominacion      := l_cta_vistas(i).denominacion;
            r_acvis.cod_modulo        := l_cta_vistas(i).cod_modulo;
            r_acvis.cod_modalidad     := l_cta_vistas(i).cod_modalidad;
            r_acvis.cod_oficina       := l_cta_vistas(i).cod_oficina;
            r_acvis.dig_verificador   := l_cta_vistas(i).dig_verificador;
            r_acvis.cod_moneda        := l_cta_vistas(i).cod_moneda;
            r_acvis.fre_extracto      := l_cta_vistas(i).fre_extracto;
            r_acvis.can_fir_requeridas:= l_cta_vistas(i).can_fir_requeridas;
            r_acvis.can_fir_registradas:= l_cta_vistas(i).can_fir_registradas;
            r_acvis.fec_apertura      := l_cta_vistas(i).fec_apertura;
            r_acvis.tip_capitalizacion:=l_cta_vistas(i).tip_capitalizacion;
            r_acvis.tas_personalizada:= l_cta_vistas(i).tas_personalizada;
            r_acvis.cod_tasa          := l_cta_vistas(i).cod_tasa;
            r_acvis.ret_personalizada := l_cta_vistas(i).ret_personalizada;
            r_acvis.sal_minimo        :=l_cta_vistas(i).sal_minimo;
            r_acvis.aut_pendiente     :=l_cta_vistas(i).aut_pendiente;
            r_acvis.cod_usu_promotor  :=l_cta_vistas(i).cod_usu_promotor;
            r_acvis.est_batch         :=l_cta_vistas(i).est_batch;
            r_acvis.estado            :=l_cta_vistas(i).estado;
            r_acvis.nro_folio         :=l_cta_vistas(i).nro_folio;
            r_acvis.fec_ult_extracto  := l_cta_vistas(i).fec_ult_extracto;
            r_acvis.sal_ult_extracto  := l_cta_vistas(i).sal_ult_extracto;
            r_acvis.fec_cam_estado    :=l_cta_vistas(i).fec_cam_estado;
            r_acvis.fec_ult_movimiento:=l_cta_vistas(i).fec_ult_movimiento;
            r_acvis.hor_ult_movimiento:= l_cta_vistas(i).hor_ult_movimiento;
            r_acvis.fec_ult_capitalizacion:= l_cta_vistas(i).fec_ult_capitalizacion;
            r_acvis.sal_ult_capitalizacion:=l_cta_vistas(i).sal_ult_capitalizacion;
            r_acvis.sal_ret_batch     := l_cta_vistas(i).sal_ret_batch;
            r_acvis.sal_retenido      := l_cta_vistas(i).sal_retenido;
            r_acvis.sal_blo_batch     := l_cta_vistas(i).sal_blo_batch;
            r_acvis.sal_bloqueado     :=l_cta_vistas(i).sal_bloqueado;
            r_acvis.sal_tot_batch     :=l_cta_vistas(i).sal_tot_batch;
            r_acvis.sal_total         :=l_cta_vistas(i).sal_total;
            r_acvis.tra_prohibida     := l_cta_vistas(i).tra_prohibida;
            r_acvis.cta_combinada     :=l_cta_vistas(i).cta_combinada;
            lp_cal_capitalizac(v_mto_interes);
            v_rowcount := v_rowcount + 1;
            -- Solo entra aquí cada 10,000 registros
            IF MOD(v_rowcount, 10000) = 0 THEN
              v_mensaje := v_rowcount||' cuentas procesadas de '||v_cant_registros;
              DBMS_APPLICATION_INFO.SET_CLIENT_INFO(v_mensaje);
            END IF;
            v_tot_interes := NVL(v_tot_interes, 0) + v_mto_interes;
        END LOOP;
BEGIN
    v_mensaje := 'Ins AH_CAPITALIZACIONES. Total '|| v_rowcount ||' de '||v_cant_registros;
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO(v_mensaje);
    BEGIN
        -- Primera operación: Insertar en AH_CAPITALIZACIONES
        FORALL i IN v_capitalizaciones.FIRST .. v_capitalizaciones.LAST
            INSERT /*+ APPEND_VALUES */ INTO it.ah_capitalizaciones (COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA,
                                             COD_MONEDA, FECHA, FEC_INICIO, FEC_FIN,
                                             TIP_CAPITALIZACION, COD_TASA, VAL_TASA, MTO_INTERES,
                                             SAL_PROMEDIO, SAL_ACUMULADO)
            VALUES (v_capitalizaciones(i).COD_MODULO, v_capitalizaciones(i).COD_MODALIDAD, v_capitalizaciones(i).COD_OFICINA, v_capitalizaciones(i).NRO_CUENTA,
                    v_capitalizaciones(i).COD_MONEDA, v_capitalizaciones(i).FECHA, v_capitalizaciones(i).FEC_INICIO, v_capitalizaciones(i).FEC_FIN,
                    v_capitalizaciones(i).TIP_CAPITALIZACION, v_capitalizaciones(i).COD_TASA, NVL(v_capitalizaciones(i).VAL_TASA, 0), v_capitalizaciones(i).MTO_INTERES,
                    v_capitalizaciones(i).SAL_PROMEDIO, v_capitalizaciones(i).SAL_ACUMULADO);

    EXCEPTION
        WHEN OTHERS THEN
        --WHEN v_errors THEN
            FOR i IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
                l_error_index := SQL%BULK_EXCEPTIONS(i).ERROR_INDEX;
                l_error_message := --'Error al insertar en AH_CAPITALIZACIONES: índice ' || l_error_index ||
                                   ', NRO_CUENTA: ' || v_capitalizaciones(l_error_index).NRO_CUENTA ||
                                   ', Mensaje: ' || SQLERRM(SQL%BULK_EXCEPTIONS(i).ERROR_CODE);
                RAISE_APPLICATION_ERROR(-20001, l_error_message);
            END LOOP;
    END;

    -- Ejecuta si no es paralelo O si es una cuenta específica (not null)
    IF (v_tra_ah_modo != 'PARALLEL_EXECUTE') OR (p_nro_cuenta IS NOT NULL) THEN
      BEGIN
        -- Actualización masiva optimizada por PK
        FORALL i IN INDICES OF v_nro_cuenta_tab SAVE EXCEPTIONS
          UPDATE AH_CTA_VISTAS
          SET SAL_ULT_CAPITALIZACION = v_sal_ult_capitalizacion_tab(i),
              SAL_TOTAL              = v_sal_total_tab(i),
              FEC_ULT_CAPITALIZACION = v_ult_dia_mes_tab(i)
          WHERE NRO_CUENTA = v_nro_cuenta_tab(i);
      EXCEPTION
          WHEN v_errors THEN
            -- SQL%BULK_EXCEPTIONS captura errores de constraints o bloqueos (locks)
            FOR i IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
                l_error_index := SQL%BULK_EXCEPTIONS(i).ERROR_INDEX;
                l_error_message := 'Error en NRO_CUENTA: ' || v_nro_cuenta_tab(l_error_index) ||
                                   ' - ' || SQLERRM(-SQL%BULK_EXCEPTIONS(i).ERROR_CODE);
                RAISE_APPLICATION_ERROR(-20002, l_error_message);
            END LOOP;
      END;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20099, 'Error general en el proceso: ' || SQLERRM);
END;
  commit;-- se guarda cada 50.000 registros procesados
 END LOOP;
   
   -- Si el modo es paralelo Y el parámetro p_nro_cuenta es nulo (proceso masivo)
   IF (v_tra_ah_modo = 'PARALLEL_EXECUTE') AND (p_nro_cuenta IS NULL) THEN
      v_mensaje := 'Ejecutando DBMS_PARALLEL. Cuentas capitalizadas: '|| v_rowcount;
      DBMS_APPLICATION_INFO.SET_CLIENT_INFO(v_mensaje);

      -- Convertimos el parámetro dinámico a número
      v_divisor := TO_NUMBER(v_tam_fragmento);

      BEGIN
         -- Eliminar la tarea si ya existía de un intento previo
         DBMS_PARALLEL_EXECUTE.DROP_TASK(v_tarea);
      EXCEPTION
         WHEN DBMS_PARALLEL_EXECUTE.TASK_NOT_FOUND THEN
            NULL;
      END;

      -- Crear la tarea
      DBMS_PARALLEL_EXECUTE.create_task(v_tarea);

      -- Fragmentamos sobre la tabla MAESTRA (AH_CTA_VISTAS)
      DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_ROWID(
         task_name   => v_tarea,
         table_owner => 'IT',
         table_name  => 'AH_CTA_VISTAS',
         by_row      => FALSE, -- FALSE indica que dividirá por bloques físicos de OCI
         chunk_size  => v_divisor
      );

      v_sql := '
      DECLARE
         v_fecha_proc DATE := TO_DATE(''' || TO_CHAR(v_ult_dia_mes, 'YYYYMMDD') || ''', ''YYYYMMDD'');
      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 3;
         pae_cnf.G_PROGRAMA   := ''GPPROFIN'';

         MERGE INTO it.ah_cta_vistas e
         USING (
            SELECT c.nro_cuenta,
                   SUM(c.mto_interes) as total_interes,
                   MAX(c.fecha) as f_proc
              FROM it.ah_capitalizaciones c
             WHERE c.fecha = v_fecha_proc
               AND c.mto_interes > 0
               AND c.nro_cuenta IN (SELECT m.nro_cuenta
                                      FROM it.ah_cta_vistas m
                                     WHERE m.rowid BETWEEN :start_id AND :end_id)
             GROUP BY c.nro_cuenta
         ) h
         ON (e.nro_cuenta = h.nro_cuenta)
         WHEN MATCHED THEN
            UPDATE SET
               e.sal_ult_capitalizacion = e.sal_total + h.total_interes,
               e.sal_total              = e.sal_total + h.total_interes,
               e.fec_ult_capitalizacion = h.f_proc
            WHERE e.rowid BETWEEN :start_id AND :end_id
              AND (e.fec_ult_capitalizacion < h.f_proc OR e.fec_ult_capitalizacion IS NULL);
      END;';

     -- Ejecutar el DML en paralelo
     DBMS_PARALLEL_EXECUTE.RUN_TASK(
               task_name      => v_tarea,
               sql_stmt       => v_sql,
               language_flag  => DBMS_SQL.NATIVE,
               parallel_level => TO_NUMBER(v_job_cant)
      );
     
     --Verificar el estatus de la ejecucion
     IF DBMS_PARALLEL_EXECUTE.FINISHED != DBMS_PARALLEL_EXECUTE.TASK_STATUS(v_tarea) THEN
        raise_application_error(-20000, 'ERROR DBMS_PARALLEL_EXECUTE. Revisar Tarea: ' || v_tarea);
     END IF;
   END IF;
   
   --Verificamos si el parametro esta activo para el lanzamiento del proceso PRA_CTA_VIS_NO_CAPITALIZAN Y el parámetro p_nro_cuenta es nulo (proceso masivo)
   IF v_act_cta_vis_no_capitalizan = 'SI' AND (p_nro_cuenta IS NULL) THEN
     --Lanzamos en paralelo (job) el proceso para cuentas que no capitalizan
     --Buscamos si existe algún Job en ejecucion con ese prefijo 
     BEGIN
       SELECT 'SI'
         INTO v_resultado
         FROM dba_scheduler_running_jobs
        WHERE job_name LIKE 'JOB_CTA_NO_CAP_%'
          AND ROWNUM = 1;
     EXCEPTION
       WHEN OTHERS THEN
         v_resultado := 'NO';
     END;
     IF v_resultado = 'NO' THEN
       --Si no se esta ejecutando el job, lo creamos
       BEGIN
         -- Definimos un nombre único para el Job
         v_job_name := DBMS_SCHEDULER.GENERATE_JOB_NAME('JOB_CTA_NO_CAP_');
          
         -- Formateamos la fecha a string para que el Job la entienda correctamente
         v_sql_stmt := 'DECLARE l_monto NUMBER; BEGIN ' ||
                       'pre_ini_aplicacion; pae_cnf.g_cod_modulo := 3; pae_cnf.G_PROGRAMA := ''GPPROFIN'';'||
                       'IT.PRA_CTA_VIS_NO_CAPITALIZAN(' ||
                       'P_NRO_CUENTA => NULL, ' ||
                       'P_INS_CAPITALIZACION => ''S'', ' || 
                       'P_FEC_CAPITALIZACION => TO_DATE(''' || TO_CHAR(v_fec_actual, 'YYYY-MM-DD HH24:MI:SS') || ''', ''YYYY-MM-DD HH24:MI:SS''), ' ||
                       'P_MTO_INTERES => l_monto); ' ||
                       'END;';
                         
         DBMS_SCHEDULER.CREATE_JOB (
            job_name   => v_job_name,
            job_type   => 'PLSQL_BLOCK',
            job_action => v_sql_stmt,
            enabled    => TRUE, -- Lo habilitamos directamente
            auto_drop  => TRUE  
         );
       EXCEPTION
           WHEN OTHERS THEN
             RAISE_APPLICATION_ERROR(-20001, 'Error al crear el Job: ' || SQLERRM);
       END;
     END IF;
   END IF;
   
   IF V_HAB_DEV_GRUPAL = 'S' THEN
       --Ctas de Devengamiento Grupal--
       IF c_cta_vis_dev_grupal%ISOPEN THEN
          CLOSE c_cta_vis_dev_grupal;
       END IF;
       OPEN c_cta_vis_dev_grupal;
       ---------------------------------------------------------
       -- ciclo general, carga de las variables de cuentas------
       ---------------------------------------------------------
       LOOP

          FETCH c_cta_vis_dev_grupal
          INTO r_acvis.nro_cuenta, r_acvis.denominacion, r_acvis.cod_modulo, r_acvis.cod_modalidad,
               r_acvis.cod_oficina, r_acvis.dig_verificador, r_acvis.cod_moneda, r_acvis.fre_extracto,
               r_acvis.can_fir_requeridas, r_acvis.can_fir_registradas, r_acvis.fec_apertura, r_acvis.tip_capitalizacion,
               r_acvis.tas_personalizada, r_acvis.cod_tasa, r_acvis.ret_personalizada, r_acvis.sal_minimo,
               r_acvis.aut_pendiente, r_acvis.cod_usu_promotor, r_acvis.est_batch, r_acvis.estado,
               r_acvis.nro_folio, r_acvis.fec_ult_extracto, r_acvis.sal_ult_extracto, r_acvis.fec_cam_estado,
               r_acvis.fec_ult_movimiento, r_acvis.hor_ult_movimiento, r_acvis.fec_ult_capitalizacion, r_acvis.sal_ult_capitalizacion,
               r_acvis.sal_ret_batch, r_acvis.sal_retenido, r_acvis.sal_blo_batch, r_acvis.sal_bloqueado,
               r_acvis.sal_tot_batch, r_acvis.sal_total, r_acvis.tra_prohibida, r_acvis.cta_combinada;
          EXIT WHEN c_cta_vis_dev_grupal%NOTFOUND;
          --Calculo de la Capitalizacion de Ahorro a la Vista
          lp_cal_cap_dev_grupal(v_mto_interes);
          v_tot_interes := nvl(v_tot_interes,0) + v_mto_interes;
          commit;
       END LOOP;
       close c_cta_vis_dev_grupal; 
   END IF;
   ------
   p_mto_interes := v_tot_interes;
   -----------------------------------------------------
   --            fin ciclo general                    --
   -----------------------------------------------------
   /*IF c_cta_vistas%rowcount = 0 and p_nro_cuenta is null THEN
      v_msj := ' No encontre registros en AH_CTA_VISTAS';
      raise_application_error(-20000,v_msj);
   elsif c_cta_vistas%rowcount = 0 and p_nro_cuenta is not null THEN
      p_mto_interes := 0;
   END IF;
   close c_cta_vistas;         */
    ------
   DBMS_APPLICATION_INFO.SET_ACTION(NULL);
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
   --SDL6380INR-1 - Impuesto a la renta a no residentes - INR
   v_nro_secuencia := 0;
    -- Se retira el llamado al procedimiento @tcasco PBC-125 - FSOP-36667
    -- paa_ret.pr_gen_inr_ret_ahorros(v_fec_actual, v_nro_secuencia, v_mto_retencion, null, 3 , 31);
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,
      'ERROR.pra_capitalizacion '||SQLERRM);
END;
/
