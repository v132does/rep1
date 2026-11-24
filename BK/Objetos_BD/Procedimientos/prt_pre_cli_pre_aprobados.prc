create or replace procedure it.prt_pre_cli_pre_aprobados
is 

Begin
  ---Elimino los errores que quedaron pendientes de la ultima inserción (se deberían corregir la siguiente vez)
  delete ge_cli_aprobados_atm_tmp a
   where a.det_error is not null;
     
  --borro las tc pre aprobadas ya vencidas
  delete ge_cli_aprobados_atm_tmp a
   where a.fec_baja < pag_cal.FU_OBT_FEC_ACTUAL(5);     
  
end prt_pre_cli_pre_aprobados;
/

