create or replace function it.fug_ver_telegramas(p_nro_cuenta in varchar2, p_cod_cau_cancelacion in varchar2)
return varchar2 is
v_max_fecha date;
v_telegramas varchar2(100) := fug_obt_parcausales(p_cod_cau_cancelacion,'VER_TELEGRAMAS');
begin
 if v_telegramas is not null then
  select min(nvl(fec_entrega,sysdate+10) + nvl(fug_obt_parcausales(a.cod_causa, 'CAN_DIA_CAN_CTA'),0))
    into  v_max_fecha
    from ge_telegramas a
   where instr(','||ref_cuentas||',',','||p_nro_cuenta||',') > 0
     and instr(','||v_telegramas||',' ,  ','||a.cod_causa||',') > 0;
  if v_max_fecha is null then
  	--no existe en telegramas
     return 'S';
  elsif v_max_fecha <= pag_cal.FU_OBT_FEC_ACTUAL(1) then
     return 'S'; -- cumplio
  else
     return 'N'; -- no cumplio
  end if;
 else
    return 'S'; -- si cumplio
 end if;
exception
  when others then
     return 'N'; -- no cumple
end;
/

