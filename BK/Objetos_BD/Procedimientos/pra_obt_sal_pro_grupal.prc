CREATE OR REPLACE PROCEDURE IT.PRA_OBT_SAL_PRO_GRUPAL
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_FEC_INI IN DATE
 ,P_FEC_FIN IN DATE
 ,P_SAL_ACUMULADO IN OUT NUMBER
 ,P_SAL_PROMEDIO IN OUT NUMBER
 ,P_CAN_DIA_ACUMULADO IN OUT AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 )
 IS
V_FEC_ACTUAL DATE;
V_ANIO_ACTUAL AH_SAL_MENSUALES.ANO%TYPE;
V_MES_ACTUAL AH_SAL_MENSUALES.MES%TYPE;
V_SAL_ACU_DIARIO AH_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE;
V_CAN_DIA_ACUMULADO AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE;
g_lugar varchar2(250);
---Optimizar el codigo para que obtenga el saldo promedio
---de todas las cuentas cc, ah, pr, ta
---Pedido por Agustin, 16-04-2004
---Ver si se puede utilizar Parametros Diferenciados

CURSOR c_sal_pro_dev_grupal IS
   select sum(Nvl(fub_con_mon_a_moneda(d.cod_moneda,p.cod_moneda,nvl(k.sal_acu_diario,0),NULL,v_fec_actual),0)),
          max(nvl(k.can_dia_acumulado,0))
    from AH_DEV_GRU_CUENTAS x, ah_cta_vistas d, AH_SAL_MENSUALES k,
         (select distinct g.cod_persona, g.cod_grupo, f.cod_moneda
            from AH_DEV_GRU_CUENTAS g, ah_cta_vistas f
           where g.nro_cuenta = P_NRO_CUENTA  --Principal--
             and g.tipo = 'P'
             and f.nro_cuenta = g.nro_cuenta) p
    where x.cod_persona = p.cod_persona
      and x.cod_grupo = p.cod_grupo
      and x.nro_cuenta = d.nro_cuenta
      and k.nro_cuenta = x.nro_cuenta
      and k.ano = v_anio_actual
      and k.mes = v_mes_actual;

BEGIN
   g_lugar := 'Calcula_saldo_promedio_av';
   p_can_dia_acumulado:= 0;
   p_sal_acumulado := 0;
   p_sal_promedio := 0;
   v_fec_actual  := p_fec_ini;
   v_anio_actual := TO_NUMBER(TO_CHAR(p_fec_ini,'YYYY'));
   v_mes_actual := TO_NUMBER(TO_CHAR(p_fec_ini,'MM'));
   /* La fecha  actual se va incrementando en 1 mes. Mientras que sea menor que la fecha final
      recibida como parametros. Calcula el acumulado de saldo y el saldo promedio */
       WHILE TO_NUMBER(TO_CHAR(v_fec_actual,'YYYYMM')) <= TO_NUMBER(TO_CHAR(p_fec_fin,'YYYYMM')) LOOP
          IF c_sal_pro_dev_grupal%ISOPEN THEN
             CLOSE c_sal_pro_dev_grupal;
          END IF;
          OPEN c_sal_pro_dev_grupal;
             FETCH c_sal_pro_dev_grupal
             INTO v_sal_acu_diario, v_can_dia_acumulado;
             g_lugar := 'acumula saldo acumulado y cantidad de dias';
             p_sal_acumulado:= p_sal_acumulado + NVL(v_sal_acu_diario,0);
             p_can_dia_acumulado:= p_can_dia_acumulado + NVL(v_can_dia_acumulado,0);
             v_fec_actual:= ADD_MONTHS(v_fec_actual, 1);
             v_anio_actual := TO_NUMBER(TO_CHAR(v_fec_actual,'YYYY'));
             v_mes_actual := TO_NUMBER(TO_CHAR(v_fec_actual,'MM'));
       END LOOP;
       IF c_sal_pro_dev_grupal%ISOPEN THEN
          CLOSE c_sal_pro_dev_grupal;
       END IF;
   g_lugar := 'calcula saldo promedio';
   IF NVL(p_can_dia_acumulado,0) > 0 THEN
     p_sal_promedio := p_sal_acumulado / p_can_dia_acumulado;
   END IF;
EXCEPTION
  WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20022,SQLERRM||' -  '||g_lugar);
END;
/

