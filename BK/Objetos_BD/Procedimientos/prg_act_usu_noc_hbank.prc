create or replace procedure it.prg_act_usu_noc_hbank is
  --PCCDEEVO-1045 / Mejora PK usuario HBANK----
  v_fecha date := pag_cal.FU_OBT_FEC_ACTUAL(1);
begin
  --Actualiza el parámetro de Cantidad de Movimientos--
  prg_act_par_dinamico('COD_USU_ACT_HBANK',null,null,null,null,'HBANK',null);
  prg_act_par_dinamico('CAN_USU_UTI_HBANK',null,null,null,null,'1',null);
exception
  when others then
       null;
end;
/

