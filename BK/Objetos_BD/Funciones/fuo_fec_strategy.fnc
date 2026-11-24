create or replace function it.fuo_fec_strategy return date is
  v_fecha  date;
  v_estado ba_modulos.estado%type;
begin
  begin
    select a.estado
      into v_estado
      from ba_modulos a
     where a.cod_modulo = 1;
  end;
  if v_estado = 2 then
    v_fecha := pag_cal.fu_obt_fec_ant_hab(pag_cal.fu_obt_fec_actual(21),fun_obt_ofi_matriz,1);
  else
    v_fecha := pag_cal.fu_obt_fec_actual(21);
  end if;
  return v_fecha;
end;
/

