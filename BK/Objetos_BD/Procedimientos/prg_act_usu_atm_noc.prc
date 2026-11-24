create or replace procedure it.prg_act_usu_atm_noc is
  v_fecha date := pag_cal.FU_OBT_FEC_ACTUAL(1);
--Debe ser proceso 11 orden no se sabe--
begin
  --Actualiza el parámetro de Cantidad de Movimientos--
  prg_act_par_dinamico('COD_USU_ATM_ACTUAL',null,null,null,null,'ATM',null);
  prg_act_par_dinamico('CAN_USU_ATM_UTILIZADO',null,null,null,null,'1',null);
  
  --Elimina Registros del Log mayores a 30 dias de Antiguedad--
  if v_fecha = pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1) then
    delete from GE_LOG_ERR_HOR_USU_ATM x
     where (v_fecha - x.fecha) > 30; 
  end if;
  
end;
/

