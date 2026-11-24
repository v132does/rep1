CREATE OR REPLACE TRIGGER IT.TA_PR_DEVENGADOS
 AFTER DELETE OR INSERT OR UPDATE of fecha
 ON PR_DEVENGADOS
 FOR EACH ROW
DECLARE
   v_dev_no_cobrado pr_devengados_his.dev_no_cobrado%type;
   v_dev_suspenso   pr_devengados_his.dev_suspenso%type;
   v_dev_ganancia   pr_devengados_his.dev_ganancia%type;
   v_fecha          ge_calendarios.fec_actual%type;
begin
   if updating and
      :old.fecha > :new.fecha then
      --- Cuando existe una reversion que no corresponda a la del dia.
      --- descontar del mes anterior o fecha anterior
      v_dev_no_cobrado := 0;
      v_dev_suspenso   := 0;
      v_dev_ganancia   := 0;
      if :old.tipo = 'N' then
         v_dev_no_cobrado := :old.mto_dev_actual;
         v_dev_ganancia   := :old.mto_dev_actual;
      else
         v_dev_suspenso   := :old.mto_dev_actual;
      end if;
      v_fecha := pag_cal.fu_obt_fec_actual(6);
      update pr_devengados_his
         set mto_interes    = nvl(mto_interes,0) - :old.mto_dev_actual,
             dev_no_cobrado = nvl(dev_no_cobrado,0) - v_dev_no_cobrado,
             dev_suspenso   = nvl(dev_suspenso,0) - v_dev_suspenso,
             dev_ganancia   = nvl(dev_ganancia,0) - v_dev_ganancia
       where nro_cuenta = :old.nro_cuenta
         and ano = to_number(to_char(v_fecha,'YYYY'))
         and mes = to_number(to_char(v_fecha,'MM'));
   end if;
end;
/
