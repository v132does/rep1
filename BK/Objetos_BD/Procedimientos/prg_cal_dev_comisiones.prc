CREATE OR REPLACE PROCEDURE IT.PRG_CAL_DEV_COMISIONES
is
   v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(1);
   ---
   cursor rg_movi is
   select decode(b.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,b.monto,b.mto_equ_local) monto,
          b.fec_inicio, b.fec_vencimiento, b.fec_ult_proceso,
          b.mto_dev_anterior, b.mto_dev_actual, b.mto_dev_acumulado,
          b.estado, b.can_dia_actual, b.can_dia_anterior,
          b.cod_modulo, b.cod_mov_diferido, b.cod_moneda,
          c.estado est_cuenta
   from   ge_mov_diferidos b, ge_cuentas c
   where((b.mto_dev_acumulado < decode(b.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,b.monto,b.mto_equ_local)
   and    b.estado <> 'R') or (b.estado = 'R' and (b.mto_dev_acumulado <> b.mto_dev_actual))) 
   and    b.nro_cuenta = c.nro_cuenta
   and    b.fecha < v_fec_actual
   and    b.fec_inicio <= v_fec_actual -- agregado para cuentas migradas
   --- Reversar el devengado de la cancelación por de la cuenta
   --- Para las cuentas que reversaron su cancelación
   union
   select decode(b.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,b.monto,b.mto_equ_local) monto,
          b.fec_inicio, b.fec_vencimiento, b.fec_ult_proceso,
          b.mto_dev_anterior, b.mto_dev_actual, b.mto_dev_acumulado,
          b.estado, b.can_dia_actual, b.can_dia_anterior,
          b.cod_modulo, b.cod_mov_diferido, b.cod_moneda,
          c.estado est_cuenta
   from   ge_mov_diferidos b, ge_cuentas c
   where  b.mto_dev_acumulado >= decode(b.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,b.monto,b.mto_equ_local)
   and    b.nro_cuenta = c.nro_cuenta
   and    b.fec_vencimiento > v_fec_actual
   and    b.fecha < v_fec_actual
   and    b.fec_inicio <= v_fec_actual -- agregado para cuentas migradas
   and  ((c.estado <> 'C' and c.cod_modulo in (3,4,5,7,8,15))
      or (c.estado <> 'N' and c.cod_modulo in (6,10)));
   ---
   v_fec_calculo       date;
   v_can_dia_anterior  ge_mov_diferidos.can_dia_anterior%type;
   v_can_dia_actual    ge_mov_diferidos.can_dia_actual%type;
   v_mto_dev_anterior  ge_mov_diferidos.mto_dev_anterior%type;
   v_mto_dev_actual    ge_mov_diferidos.mto_dev_actual%type;
   v_mto_dev_acumulado ge_mov_diferidos.mto_dev_acumulado%type;
   v_can_tot_dias      number;
   v_estado            ge_mov_diferidos.estado%type;
begin
   begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
   for i in rg_movi loop
      if i.estado = 'N' then
         v_can_dia_anterior := i.can_dia_actual;
         v_mto_dev_anterior := i.mto_dev_actual;
         v_can_tot_dias     := ABS(i.fec_vencimiento - i.fec_inicio);--DYDMR-4953 - 14/09/2016
         v_can_dia_actual   := 0;
         v_mto_dev_actual := 0;
         --- Cuentas canceladas deben devengar totalmente
         if (i.est_cuenta = 'C' and i.cod_modulo in (3,4,5,7,8,15))
         or (i.est_cuenta = 'N' and i.cod_modulo in (6,10))
         or v_fec_actual > i.fec_vencimiento then
            v_fec_calculo := i.fec_vencimiento;
         else
            v_fec_calculo := v_fec_actual;
         end if;
         ---
         v_can_dia_actual := ABS(v_fec_calculo - nvl(i.fec_ult_proceso,i.fec_inicio));--DYDMR-4953 - 14/09/2016
			---
         if v_can_dia_actual > 0 
           --DYDMR-4953 - 14/09/2016
           -- Se agrega esta validacion para los registros que estan inconsistentes en fechas, 
           --donde la fecha de vencimiento es menor a la fecha de inicio
           OR (i.mto_dev_acumulado < i.monto and i.estado <> 'R')
             then
            v_mto_dev_actual := round(i.monto / v_can_tot_dias * v_can_dia_actual,0);
            -- Se verifica si corresponde a una reversión
            if i.mto_dev_acumulado >= i.monto and
               i.fec_vencimiento > v_fec_actual then
               i.mto_dev_acumulado := i.mto_dev_acumulado - i.mto_dev_actual;
               v_estado := 'C';
            else
               v_estado := 'N';
            end if;
            -- para redondear correctamente en el último devengado
            if (i.mto_dev_acumulado + v_mto_dev_actual) > i.monto
              --dydmr-4953 - 14/09/2016 
              -- Se agrega esta validación para que cancele la comision
              -- en caso que sea el ultimo cobro.
              or (v_fec_actual >= i.fec_vencimiento) then
               v_mto_dev_actual := i.monto - i.mto_dev_acumulado;
            end if;
            ---
            v_mto_dev_acumulado := i.mto_dev_acumulado + v_mto_dev_actual;
            ---
            update ge_mov_diferidos
            set    can_dia_anterior  = v_can_dia_anterior,
                   can_dia_actual    = v_can_dia_actual,
                   mto_dev_anterior  = v_mto_dev_anterior,
                   mto_dev_actual    = v_mto_dev_actual,
                   mto_dev_acumulado = v_mto_dev_acumulado,
                   estado            = v_estado,
                   fec_ult_proceso   = v_fec_actual
            where  cod_mov_diferido  = i.cod_mov_diferido;
         end if;
      elsif i.estado = 'R' then
         if i.monto > i.mto_dev_acumulado then
            update ge_mov_diferidos
            set    mto_dev_actual    = mto_dev_acumulado,
                   fec_ult_proceso   = v_fec_actual
            where  cod_mov_diferido  = i.cod_mov_diferido;
         end if;
      end if;
   end loop;
end;
/

