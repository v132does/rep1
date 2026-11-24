CREATE OR REPLACE PROCEDURE IT.PRA_ACT_SAL_MENSUAL
 IS

/* Codigo del Módulo, default 3 - Ahorro */
V_COD_MODULO AH_SAL_MENSUALES.COD_MODULO%TYPE := 3;
/* Fecha Actual de Calendarios */
V_FEC_ACTUAL GE_CALENDARIOS.FEC_ACTUAL%TYPE;
/* Fecha proxima del Modulo en Calendarios */
V_FEC_PROXIMA DATE;
/* Cant. de Dias Diferentes entre Meses */
V_CAN_DIA_DIF NUMBER;
/* Fecha Inicial de la Operación */
V_FEC_INICIAL DATE;
/* Cantidad de Dias */
V_CAN_DIAS NUMBER;
/* Mes de la Transacción */
V_MES_INICIAL AH_SAL_MENSUALES.MES%TYPE;
V_ANO_INICIAL AH_SAL_MENSUALES.ANO%TYPE;
V_MES_PROXIMO AH_SAL_MENSUALES.MES%TYPE;
V_ANO_PROXIMO AH_SAL_MENSUALES.ANO%TYPE;

/* Proceso de Cuentas Certificadas */
PROCEDURE LP_ACT_CTA_PLAZOS;
/* Proceso de Cuentas Certificadas */
PROCEDURE LP_ACT_CTA_CERTIFIC;
/* Actualiza /Inserta Saldos Mensuales */
PROCEDURE LP_ACT_SAL_MENSUAL;
/* Inserta registro en AH_SAL_MENSUALES */
PROCEDURE LP_INS_SAL_MENSUAL;
----------------------------
-- variables para cursores --
-----------------------------
   -- tipos de dato para colecciones ah_cta_vistas
   TYPE t_modulo IS TABLE OF ah_cta_vistas.cod_modulo%TYPE;
   TYPE t_modalidad IS TABLE OF ah_cta_vistas.cod_modalidad%TYPE;
   TYPE t_oficina IS TABLE OF ah_cta_vistas.cod_oficina%TYPE;
   TYPE t_nro_cuenta IS TABLE OF ah_cta_vistas.nro_cuenta%TYPE;
   TYPE t_moneda IS TABLE OF ah_cta_vistas.cod_moneda%TYPE;
   TYPE t_monto IS TABLE OF ah_cta_vistas.sal_total%TYPE;
   -- Colecciones para el BULK COLLECT
   v_cod_modulo_ah    t_modulo;
   v_cod_modalidad_ah t_modalidad;
   v_cod_oficina_ah   t_oficina;
   v_nro_cuenta_ah    t_nro_cuenta;
   v_cod_moneda_ah    t_moneda;
   v_monto_ah   t_monto;

CURSOR c_cta_vistas IS
   SELECT COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA,
          COD_MONEDA, nvl(sal_total,0) - nvl(sal_retenido,0) saldo
   FROM   AH_CTA_VISTAS
   WHERE  ESTADO NOT IN ('C','A','X');
   
   v_msj           varchar2(250);

/* Proceso de Cuentas Certificadas */
PROCEDURE LP_ACT_CTA_PLAZOS
 IS
----------------------------
-- variables para cursores --
-----------------------------
   -- tipos de dato para colecciones ah_cta_plazos
   TYPE t_modulo IS TABLE OF ah_cta_plazos.cod_modulo%TYPE;
   TYPE t_modalidad IS TABLE OF ah_cta_plazos.cod_modalidad%TYPE;
   TYPE t_oficina IS TABLE OF ah_cta_plazos.cod_oficina%TYPE;
   TYPE t_nro_cuenta IS TABLE OF ah_cta_plazos.nro_cuenta%TYPE;
   TYPE t_moneda IS TABLE OF ah_cta_plazos.cod_moneda%TYPE;
   TYPE t_monto IS TABLE OF ah_cta_plazos.sal_total%TYPE;
   -- Colecciones para el BULK COLLECT
   v_cod_modulo_ap    t_modulo;
   v_cod_modalidad_ap t_modalidad;
   v_cod_oficina_ap   t_oficina;
   v_nro_cuenta_ap    t_nro_cuenta;
   v_cod_moneda_ap    t_moneda;
   v_monto_ap         t_monto;

--AH_CTA_PLAZOS
CURSOR c_cta_plazos  IS
   SELECT COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA,
          COD_MONEDA, decode(cod_modalidad, 38, capital, nvl(sal_total,0) - nvl(sal_retenido,0)) monto
   FROM   ah_cta_plazos
   WHERE  ESTADO NOT IN ('C','A','P', 'T');

   v_msj           varchar2(250);
BEGIN
   -- Inicio procesamiento saldo de la cuenta
   ------------------------------------------
   IF c_cta_plazos%ISOPEN THEN
      CLOSE c_cta_plazos;
   END IF;
   OPEN c_cta_plazos;
   LOOP
      FETCH c_cta_plazos BULK COLLECT 
      INTO v_cod_modulo_ap, v_cod_modalidad_ap, v_cod_oficina_ap,v_nro_cuenta_ap,
           v_cod_moneda_ap, v_monto_ap LIMIT 1000;
      EXIT WHEN v_cod_modulo_ap.COUNT = 0;
      FORALL i IN v_cod_modulo_ap.FIRST .. v_cod_modulo_ap.LAST --CIE-370               
               INSERT INTO ah_sal_mensuales_tmp
                  (cod_modulo, cod_modalidad, cod_oficina,
                   nro_cuenta, ano, mes, can_debitos, can_creditos, tot_debitos,
                   tot_creditos, can_che_devueltos, sal_ini_mes,
                   can_dia_acumulado, sal_acu_diario)
                   VALUES(v_cod_modulo_ap(i), v_cod_modalidad_ap(i), v_cod_oficina_ap(i),
                   v_nro_cuenta_ap(i), v_ano_inicial, v_mes_inicial,
                   0, 0, 0,
                   0, 0, 0,
                   v_can_dias, v_monto_ap(i));     
   END LOOP;--fin c_cta_plazos
   CLOSE c_cta_plazos; --NVB-3981
END;
/* Proceso de Cuentas Certificadas */
PROCEDURE LP_ACT_CTA_CERTIFIC
 IS

----------------------------
-- variables para cursores --
-----------------------------
   -- tipos de datos para colecciones ah_cta_certificados
   TYPE t_modulo IS TABLE OF ah_cta_certificados.cod_modulo%TYPE;
   TYPE t_modalidad IS TABLE OF ah_cta_certificados.cod_modalidad%TYPE;
   TYPE t_oficina IS TABLE OF ah_cta_certificados.cod_oficina%TYPE;
   TYPE t_nro_cuenta IS TABLE OF ah_cta_certificados.nro_cuenta%TYPE;
   TYPE t_moneda IS TABLE OF ah_cta_certificados.cod_moneda%TYPE;
   TYPE t_monto IS TABLE OF ah_cta_certificados.sal_total%TYPE;
   -- Colecciones para el BULK COLLECT
   v_cod_modulo_cda    t_modulo;
   v_cod_modalidad_cda t_modalidad;
   v_cod_oficina_cda   t_oficina;
   v_nro_cuenta_cda    t_nro_cuenta;
   v_cod_moneda_cda    t_moneda;
   v_monto_cda         t_monto;

CURSOR c_cta_certificados  IS
   SELECT COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA,
          COD_MONEDA, nvl(sal_total,0) - nvl(sal_retenido,0) saldo
   FROM   AH_CTA_CERTIFICADOS
   WHERE  ESTADO NOT IN ('C','A','P','T')
   AND usu_insercion !='MIGRAV';

BEGIN
   -- Inicio procesamiento saldo de la cuenta
   ------------------------------------------
   IF c_cta_certificados%ISOPEN THEN
      CLOSE c_cta_certificados;
   END IF;
   OPEN c_cta_certificados;
   LOOP
      FETCH c_cta_certificados BULK COLLECT
      INTO v_cod_modulo_cda, v_cod_modalidad_cda, v_cod_oficina_cda,v_nro_cuenta_cda,
        v_cod_moneda_cda, v_monto_cda LIMIT 1000;
      EXIT WHEN v_cod_modulo_cda.COUNT = 0;
       FORALL i IN v_cod_modulo_cda.FIRST .. v_cod_modulo_cda.LAST --CIE-370                 
               INSERT INTO ah_sal_mensuales_tmp
                  (cod_modulo, cod_modalidad, cod_oficina,
                   nro_cuenta, ano, mes, can_debitos, can_creditos, tot_debitos,
                   tot_creditos, can_che_devueltos, sal_ini_mes,
                   can_dia_acumulado, sal_acu_diario)
                   VALUES(v_cod_modulo_cda(i), v_cod_modalidad_cda(i), v_cod_oficina_cda(i),
                   v_nro_cuenta_cda(i), v_ano_inicial, v_mes_inicial,
                   0, 0, 0,
                   0, 0, 0,
                   v_can_dias, v_monto_cda(i));         
   END LOOP;--fin c_cta_certificados
   CLOSE c_cta_certificados; 
END;
/* Actualiza /Inserta Saldos Mensuales */
PROCEDURE LP_ACT_SAL_MENSUAL
 IS
BEGIN
--Ajuste realizado en CIE-370  
    MERGE INTO AH_SAL_MENSUALES a
      USING ah_sal_mensuales_tmp b
      ON    (a.nro_cuenta = b.nro_cuenta
         and a.mes = b.mes
         and a.ano = b.ano) 
      WHEN MATCHED THEN UPDATE 
           SET a.sal_acu_diario = a.sal_acu_diario + b.sal_acu_diario * v_can_dias,
               a.can_dia_acumulado = a.can_dia_acumulado + b.can_dia_acumulado,
               a.sal_fin_mes = decode(to_CHAR(v_fec_inicial,'MM'),v_mes_proximo,null,b.sal_acu_diario)
      WHEN NOT MATCHED THEN INSERT  
            (cod_modulo, cod_modalidad, cod_oficina,
             nro_cuenta, ano, mes, can_debitos, can_creditos, tot_debitos,
             tot_creditos, can_che_devueltos, sal_ini_mes,
             can_dia_acumulado, sal_acu_diario)
             VALUES(b.cod_modulo, b.cod_modalidad, b.cod_oficina,
             b.nro_cuenta, v_ano_inicial, v_mes_inicial,
             0, 0, 0,
             0, 0, 0,
             v_can_dias,  b.sal_acu_diario * v_can_dias);
END;
/* Inserta registro en AH_SAL_MENSUALES */
PROCEDURE LP_INS_SAL_MENSUAL 
 IS

BEGIN
--Ajuste realizado en CIE-370  
    MERGE INTO AH_SAL_MENSUALES a
      USING ah_sal_mensuales_tmp b
      ON    (a.nro_cuenta = b.nro_cuenta
         and a.mes = v_mes_proximo
         and a.ano = v_ano_proximo)       
      WHEN NOT MATCHED THEN 
        INSERT (cod_modulo, cod_modalidad, cod_oficina,
                nro_cuenta, ano, mes, can_debitos, can_creditos, tot_debitos,
                tot_creditos, can_che_devueltos, sal_ini_mes,
                can_dia_acumulado, sal_acu_diario)
                VALUES(b.cod_modulo, b.cod_modalidad, b.cod_oficina,
                 b.nro_cuenta,v_ano_proximo, v_mes_proximo,
                 0, 0, 0,
                 0, 0, b.sal_acu_diario,
                 v_can_dia_dif,  b.sal_acu_diario * v_can_dia_dif);
END;
BEGIN
   DBMS_APPLICATION_INFO.SET_ACTION('PRA_ACT_SAL_MENSUAL'); --CIE-370  
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PRA_ACT_SAL_MENSUAL, Iniciando'); --CIE-370
   --Borra datos basura de la tabla ah_sal_mensuales_tmp
   EXECUTE IMMEDIATE 'truncate table ah_sal_mensuales_tmp'; 
   --Obtiene fecha actual y próxima;
   pag_cal.pr_obt_dat_calendar(v_cod_modulo);
   v_fec_actual  := pag_cal.g_fec_actual;
   v_fec_proxima := pag_cal.g_fec_proxima;
   ------------------------------------------
   -- Inicio procesamiento saldo de la cuenta
   ------------------------------------------
   IF c_cta_vistas%ISOPEN THEN
      CLOSE c_cta_vistas;
   END IF;
   --v_procesamiento := 'S' ;-- Procesamiento Saldo de la Cuenta
   v_fec_inicial := v_fec_actual;
   v_mes_inicial := TO_CHAR(v_fec_inicial,'MM');
   v_ano_inicial := TO_CHAR(v_fec_inicial,'YYYY');
   v_mes_proximo := TO_CHAR(v_fec_proxima,'MM') ;
   v_ano_proximo := TO_CHAR(v_fec_proxima,'YYYY');

   IF TO_CHAR(v_fec_inicial,'MM') <> v_mes_proximo THEN
      v_can_dias := LAST_DAY(v_fec_inicial)-v_fec_inicial+1;
      v_can_dia_dif := TO_NUMBER(TO_CHAR(v_fec_proxima,'DD'))-1;
   ELSE
      v_can_dias := v_fec_proxima - v_fec_inicial;
      v_can_dia_dif := 0;
   END IF;
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO('c_cta_vistas'); --CIE-370
   OPEN c_cta_vistas;
   LOOP 
      FETCH c_cta_vistas BULK COLLECT 
      INTO v_cod_modulo_ah, v_cod_modalidad_ah, v_cod_oficina_ah,
           v_nro_cuenta_ah, v_cod_moneda_ah, /*v_vsal_total, v_vsal_retenido*/ v_monto_ah LIMIT 1000;
      EXIT WHEN v_cod_modulo_ah.COUNT = 0;
       --insertar ahorros vistas          
       FORALL i IN v_cod_modulo_ah.FIRST .. v_cod_modulo_ah.LAST --CIE-370             
               INSERT INTO ah_sal_mensuales_tmp
                  (cod_modulo, cod_modalidad, cod_oficina,
                   nro_cuenta, ano, mes, can_debitos, can_creditos, tot_debitos,
                   tot_creditos, can_che_devueltos, sal_ini_mes,
                   can_dia_acumulado, sal_acu_diario)
                   VALUES(v_cod_modulo_ah(i), v_cod_modalidad_ah(i), v_cod_oficina_ah(i),
                   v_nro_cuenta_ah(i), v_ano_inicial, v_mes_inicial,
                   0, 0, 0,
                   0, 0, 0,
                   v_can_dias, v_monto_ah(i));         
    END LOOP;   
    CLOSE c_cta_vistas; 
   --- Acumular saldos para AH_CTA_CERTIFICADOS
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO('AH_CTA_CERTIFICADOS'); --CIE-370
   lp_act_cta_certific;
   --- Acumular saldos para AH_CTA_PLAZOS
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO('AH_CTA_PLAZOS'); --CIE-370
   lp_act_cta_plazos;
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO('LP_ACT_SAL_MENSUAL'); --CIE-370
   LP_ACT_SAL_MENSUAL;   
   IF TO_CHAR(v_fec_inicial,'MM') <> v_mes_proximo THEN
     DBMS_APPLICATION_INFO.SET_CLIENT_INFO('LP_INS_SAL_MENSUAL'); --CIE-370
     LP_INS_SAL_MENSUAL;    
   END IF;   
   -- Limpiar DBMS_APPLICATION_INFO
   DBMS_APPLICATION_INFO.SET_ACTION(NULL);
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
EXCEPTION  
  WHEN OTHERS THEN
   DBMS_APPLICATION_INFO.SET_ACTION(NULL);
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);    
   raise_application_error(-20000,'Error en el proceso'||sqlerrm);
END;
