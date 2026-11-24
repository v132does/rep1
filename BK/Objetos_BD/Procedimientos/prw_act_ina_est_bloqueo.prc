create or replace procedure it.PRW_ACT_INA_EST_BLOQUEO is
begin
  -- Cristhian Benitez
  -- Bloquea el acceso a clientes que no tienen transacciones en la banca electronica en los ultimos 3 meses
  -- El proceso se ejecuta al inicio de dia
  -- Hay que ejecutar 1 vez al dia

  update ge_clientes c
     set c.est_clave = 'B', c.can_intentos = 0
   where est_clave in ('N', 'A', 'M')
     and length(clave) > 10
     and cod_persona not in
         ( -- y no esta en los movimientos de los ultimos 3 meses
          select distinct cod_per_principal
             from bw_movimientos
            where fec_hora > add_months(sysdate, -3)
              and cod_respuesta = '000'
              );
exception
  when others then
     raise_application_error(-20000,'PRW_ACT_INA_EST_BLOQUEO '||sqlerrm);
end PRW_ACT_INA_EST_BLOQUEO;
/

