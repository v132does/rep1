create or replace function it.FUG_VER_VERIFICACION
                (p_cod_persona in varchar2) 
  return varchar2 is
  v_salida varchar2(1);
begin
  select decode(a.est_verificacion,'V','S','N')
    into v_salida
   from ba_personas a 
   where cod_persona = p_cod_persona;
  return(v_salida);
exception
  when others then
     raise_application_error(-20000,'FUG_VER_VERIFICACION '||sqlerrm);
end FUG_VER_VERIFICACION;
/

