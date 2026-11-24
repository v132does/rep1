CREATE OR REPLACE FUNCTION IT."PR_OBTENER_TIP_INTERES" (p_nro_cuenta varchar2, p_sol_ade_venc varchar2)
return varchar2
is
    v_sum_int_adelantado number(18,2);
    v_sum_int_vencido number(18,2);

begin
      /*Para verificar si el préstamo tiene intereses vencidos y adelantados mezclado*/

      --Se obtiene la suma de intereses adelantados y vencidos, del detalle de las cuotas
      select sum(mto_interes), sum(mto_int_documentado)
             into v_sum_int_vencido,v_sum_int_adelantado
             from it.pr_cuotas
             where nro_cuenta = p_nro_cuenta;

      --Si tiene, tanto intereses vencidos como adelantados
      --Se usa lo definido por Luis Almirón:
      if(v_sum_int_vencido > 0 and v_sum_int_adelantado > 0) then
          -- Se migra el préstamo como interés vencido
          return 'V';
      end if;

      return p_sol_ade_venc;
end;
/

