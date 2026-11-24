create or replace procedure it.PRV_CAL_ATRASOS(p_nro_cuenta in varchar2 default null) is
  v_fec_actual ge_calendarios.fec_actual%type;
  cursor c1 is
     Select nro_cuenta, rowid registro
       from ov_cta_vencidas
      where (estado not in ('C' /*,'I' */) or fec_cam_estado = pag_cal.G_FEC_ACTUAL /*v_fec_actual*/)
        and nro_cuenta = nvl(p_nro_cuenta, nro_cuenta);

  v_max_atraso  pr_cta_prestamos.max_atraso%type := 0;
  v_dia_atraso  pr_cta_prestamos.dia_atraso%type := 0;
  v_pro_atraso  pr_cta_prestamos.pro_atraso%type := 0;

begin
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
  pag_cal.PR_OBT_DAT_CALENDAR(15);
  v_fec_actual := pag_cal.G_FEC_PROXIMA;
  
  --Si el proceso es del Inicio de dia toma la fecha actual - DYDMR-5273 --
  if FUG_OBT_PRO_CIE_ENCURSO = 10 then
     v_fec_actual := pag_cal.G_FEC_ACTUAL;
  end if;
  --Verifica si es ultimo dia habíl del mes y corre en el cierre - DYDMR-5273 --
  if pag_cal.g_fec_actual = pag_cal.g_ult_dia_mes_habil and FUG_OBT_PRO_CIE_ENCURSO = 11 then
     v_fec_actual := pag_cal.g_ult_dia_mes; 
  end if; 
  For r1 in c1 Loop
      SELECT round(MAX(NVL(fec_ult_movimiento, v_fec_actual) - fec_apertura)), -- Maximo
             round(AVG(decode(sign(round(NVL(fec_ult_movimiento, v_fec_actual) - fec_apertura)),-1,0,
             round(NVL(fec_ult_movimiento, v_fec_actual) - fec_apertura)))),
             round(v_fec_actual - nvl(MIN(decode(estado,'C', TO_DATE(NULL), fec_apertura)), v_fec_actual)) + nvl(max(dia_atr_inicial),0) -- Actual,
        INTO v_max_atraso, v_pro_atraso, v_dia_atraso
        FROM ov_cta_vencidas x
       WHERE fec_apertura <= v_fec_actual--DYDMR-6244 - 07/03/2017
         and nro_cuenta = r1.nro_cuenta;

      IF v_max_atraso < 0 THEN
         v_max_atraso := 0;
      END IF;
      IF v_pro_atraso < 0 THEN
         v_pro_atraso := 0;
      END IF;
      IF v_dia_atraso < 0 THEN
         v_dia_atraso := 0;
      END IF;

      update ov_cta_vencidas
         set dia_atraso = v_dia_atraso
       where rowid = r1.registro
         and nvl(dia_atraso,0) != nvl(v_dia_atraso,0) ;
  End Loop;
end PRV_CAL_ATRASOS;
/

