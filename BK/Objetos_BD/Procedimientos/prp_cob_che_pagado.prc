create or replace procedure it.prp_cob_che_pagado is

   --- Este procedimiento cobra los cheques en custodias cuyas cuotas ya fueron pagadas
   --- y no fueron pagadas con este cheque, es decir se pagaron x caja

   cursor c_cheques is
   select e.nro_cuenta, e.nro_cheque, e.cod_banco, e.monto,
          a.nro_referencia, a.cod_moneda, e.cta_libradora, e.rowid fila
     from cc_che_enviados e, ge_che_custodias a, pr_cuotas o
    where e.nro_cheque = a.nro_cheque
      and e.nro_cuenta = a.nro_referencia
      and a.nro_cuota = o.nro_cuota
      and e.nro_cuenta = o.nro_cuenta
      and e.estado = 'I' --- Ingresado para deposito
      and o.estado = 'N' --- Cuota cancelada
      and a.estado in ('D','R') --- Descontado por pago de cuota
    order by e.nro_cuenta, e.nro_cheque;

begin
   for reg in c_cheques loop
      begin
        --- Actualizar cheques enviados
        update cc_che_enviados
           set estado = 'C' -- Confirmar el cheque
         where rowid = reg.fila;
      exception
        when others then
          raise_application_error(-20000,'Actualizar cheques '||reg.nro_cheque||' '||reg.cta_libradora||' '||reg.nro_cuenta);
      end;
   end loop;
end prp_cob_che_pagado;
/

