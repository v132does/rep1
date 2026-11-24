create or replace function it.ful_obt_cod_entidad (p_cod_persona in varchar2)
return varchar2 is

v_cod_entidad varchar2(10);
begin
  select substr(val_parametro,1,10)
    into v_cod_entidad
    from ge_par_entes
   where cod_ente in (83,78)--cambios y financieras
     and rownum =1;
   return v_cod_entidad;
exception
   when no_data_found then
      return 0;
   when others then
      raise_Application_error(-20000,'Obt.Entidad '||sqlerrm);
end;
/

