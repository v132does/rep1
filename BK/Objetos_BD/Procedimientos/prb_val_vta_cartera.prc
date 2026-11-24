CREATE OR REPLACE PROCEDURE IT.PRB_VAL_VTA_CARTERA
IS
-- Variables.

v_existe      number;
v_fec_actual  ge_calendarios.fec_actual%type:=pag_cal.FU_OBT_FEC_ACTUAL(2);
v_fecha       ge_calendarios.fec_actual%type:= last_day(v_fec_actual);
v_ul_dia_habil ge_calendarios.fec_actual%type;  
BEGIN
  
   select count(1) 
      into v_existe
     from ge_sal_act_vta_cartera g
     where g.fec_saldo=v_fecha;

   
   pag_cal.pr_obt_dat_calendar(2);

   v_ul_dia_habil :=pag_cal.G_ULT_DIA_MES_HABIL;
   
   IF v_fec_actual = v_ul_dia_habil THEN
     IF v_existe = 0 THEN
      raise_application_error(-20000,'El proceso de Venta de cartera nro 135 aún no fue ejecutado, correr luego de restaurar la Contabilidad');
     END IF;
   END IF;
END;
/

