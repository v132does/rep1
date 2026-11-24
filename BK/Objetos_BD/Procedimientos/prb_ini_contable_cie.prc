create or replace procedure it.prb_ini_contable_cie is
-- orden de los procesos de inicio de dia
   v_estado ba_modulos.estado%type;
begin
   -- inicializo el estado del modulo
   begin
      select estado
        into v_estado
        from ba_modulos
       where cod_modulo = 2
         and estado = 1;
   exception
      when no_data_found then
         prb_act_est_ini_mod;
   end;
   -- transferencia de saldos contables consolidados por dia
   -- prb_tra_sal_diario_cie; -- ya se hace la transferencia en el cierre de ejercicio
   -- cambio de fecha de calendario
   prb_act_calendario;
   -- transferencia de asientos al historico
   prb_tra_asi_historico_cie;
   -- inicio mensual y anual
   prb_ini_mensual_cie;
   -- calculo de saldo de ayer y acumulado
   --if to_char(pag_cal.G_FEC_ACTUAL,'DDMM') = '0101' then
     -- Solo el primer dia del año no debe afectar el saldo promedio
     -- porque el ultimo asiento fue el asiento de cierre anual
      prb_gen_sal_ant_anual_cie;
   /*else
      prb_gen_sal_anterior;
   end if;*/

   prb_sum_sal_consolidados_ape;
   -- Abro el modulo contable
   prb_abr_contabilidad;
   -- Inicializo procesos de fin de dia
   prb_ini_pro_contab(320);
   ---
   --- Eliminando movimientos diarios
   --- Agregado p/ AF el 16/nov/07 -- ya no se eliminan los mov 3-11-2010 VC, Af se maneja igual que cualquier otro módulo
  /* delete ge_movimientos
   where  cod_modulo = 13;*/
   ---
end;
/

