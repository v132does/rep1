CREATE OR REPLACE FUNCTION IT.FUA_OBT_VAR_TASA(P_NRO_CUENTA IN VARCHAR2)
/* Retorna la variacion de la tasa a mas o menos con respecto a la pizarra */
RETURN NUMBER IS
V_COD_MODULO NUMBER(6);
V_COD_MODALIDAD NUMBER(6);
V_COD_MONEDA VARCHAR2(04);
V_MONTO      NUMBER(18,2);
V_DIA_PLAZO      NUMBER(9);
V_VAL_TASA   NUMBER;
V_VARIACION  NUMBER := 0;
v_piz_tasa_min number;
v_piz_tasa_max number;
v_piz_tasa_actual number;
v_piz_tasa_tae number;
v_tip_capitalizacion number(3);
BEGIN
   SELECT A.COD_MODULO, A.COD_MODALIDAD, A.COD_MONEDA, A.MTO_APERTURA, 1 PLAZO, A.TIP_CAPITALIZACION,
          fug_obt_val_tasa(A.COD_MODULO, A.COD_MODALIDAD, A.COD_OFICINA, A.NRO_CUENTA,
                           A.COD_MONEDA, A.MTO_APERTURA, A.TAS_PERSONALIZADA, A.COD_TASA, NULL, SYSDATE)
     INTO V_COD_MODULO, V_COD_MODALIDAD, V_COD_MONEDA, V_MONTO, V_DIA_PLAZO, V_TIP_CAPITALIZACION,V_VAL_TASA
     FROM AH_CTA_VISTAS A
    WHERE A.NRO_CUENTA = P_NRO_CUENTA;

	 pap_pre.pr_obt_tas_pizarra(v_cod_modulo, v_cod_modalidad, v_cod_moneda,
	                            v_dia_plazo, v_monto, v_tip_capitalizacion,
	                            v_piz_tasa_min,
	                            v_piz_tasa_max,
	                            v_piz_tasa_actual,
	                            v_piz_tasa_tae);
 	 If nvl(v_piz_tasa_min,0) = 0 and nvl(v_piz_tasa_max,0) = 0 and nvl(v_piz_tasa_actual,0) = 0then
	 	  raise_application_error(-20000,'Debe definir la pizarra para este tipo de Ahorros ');
	 else
   		 IF NOT v_val_tasa BETWEEN v_piz_tasa_min and v_piz_tasa_max then
          -- esta fuera de rango, veo si es mas o menos  
          if v_val_tasa > v_piz_tasa_max then
             v_variacion := v_val_tasa - v_piz_tasa_max;
          else
             v_variacion := v_piz_tasa_min - v_val_tasa;
          end if;       
       end if;
   end if;   
   RETURN V_VARIACION;
END;
/

