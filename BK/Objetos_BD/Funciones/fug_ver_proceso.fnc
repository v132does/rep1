create or replace function it.fug_ver_proceso return number is
  v_fec_may varchar2(1);
  v_mod_ab  varchar2(1);
begin
  if pag_cal.fu_obt_fec_actual(1) >= trunc(sysdate) then
    v_fec_may := 'S';
  end if;
  if pae_cnf.fu_obt_est_modulo(1) = 2 then
    v_mod_ab := 'S';
  end if;
  if nvl(v_fec_may, 'N') = 'S' and nvl(v_mod_ab, 'N') = 'S' then
    return 0;
  else
    return 1;
  end if;
exception
  when others then
    return 1;
end;
/

