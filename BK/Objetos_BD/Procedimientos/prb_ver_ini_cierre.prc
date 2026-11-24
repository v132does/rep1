create or replace procedure it.prb_ver_ini_cierre is
v_fec_contabilidad date := pag_cal.FU_OBT_FEC_ACTUAL(2);
v_fec_ctacte date := pag_cal.FU_OBT_FEC_ACTUAL(4);
v_est_mod_ctacte number(2);
v_est_mod_contabilidad number(2);
begin
  --Verificacion de Estado de Modulo--
  v_est_mod_contabilidad := PAE_CNF.FU_OBT_EST_MODULO(2); --Estado Modulo de Contabilidad--
  if v_est_mod_contabilidad <> 2 then --Control del modulo debe estar en 2=Abierto--
     RAISE_APPLICATION_ERROR(-20000,'Error. Modulo de Contabilidad no está Abierto.');
  end if;
  --Verificacion de fecha y estado del Modulo--
  if v_fec_contabilidad > v_fec_ctacte then
     RAISE_APPLICATION_ERROR(-20000,'Error. No puede ejecutar Cierre de Contabilidad Adelantado.');
  elsif v_fec_contabilidad = v_fec_ctacte then
     v_est_mod_ctacte := PAE_CNF.FU_OBT_EST_MODULO(4); --Estado Modulo de CtaCte--
     if v_est_mod_ctacte <> 4 then
        RAISE_APPLICATION_ERROR(-20000,'Error. Para ejecutar Cierre de Contabilidad, deben estar cerrados Ctas.Ctes. y Ahorros');
     end if;
  end if;
end prb_ver_ini_cierre;
/

