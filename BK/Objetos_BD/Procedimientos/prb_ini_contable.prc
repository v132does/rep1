create or replace procedure it.prb_ini_contable is
-- orden de los procesos de inicio de dia
begin
   --prb_cop_respaldo_ini;
   pag_cal.PR_OBT_DAT_CALENDAR(2);
   -- Verifico que el dia contable a iniciar este cerrado en ITGF.
   if pag_cal.g_fec_proxima > fue_obt_fec_calendar(1) then
      raise_application_error(-20000,' No se puede realizar Inicio Contable ya que el modulo principal no se encuentra habilitado.');
   end if;
   -- inicializo el estado del modulo
   prb_act_est_ini_mod;
   -- transferencia de saldos contables consolidados por dia
   prb_tra_sal_diario;
   -- cambio de fecha de calendario
   prb_act_calendario;
   -- transferencia de asientos al historico
   prb_tra_asi_historico;
   -- inicio mensual y anual
   prb_ini_mensual;
   -- calculo de saldo de ayer y acumulado
   if to_char(pag_cal.G_FEC_ACTUAL,'DDMM') = '0101' then
     -- Solo el primer dia del año no debe afectar el saldo promedio
     -- porque el ultimo asiento fue el asiento de cierre anual
      prb_gen_sal_ant_anual;
   else
      prb_gen_sal_anterior;
   end if;

   prb_sum_sal_consolidados;
   -- Abro el modulo contable
   prb_abr_contabilidad;
   -- Inicializo procesos de fin de dia
   prb_ini_pro_contab(320);
   prb_ini_pro_contab(315);
   ---
end;
/
