create or replace function it.ful_obt_nro_orden
return varchar2 is
begin
  if pae_cnf.G_HORA is null then
     pae_cnf.g_hora := to_char(sysdate,'HH24:MI:SS');
  else
     pae_cnf.g_hora := pag_gen.FU_OBT_SIG_SEGUNDO(pae_cnf.g_hora);
  end if;
  return pae_cnf.g_hora;
end;
/

