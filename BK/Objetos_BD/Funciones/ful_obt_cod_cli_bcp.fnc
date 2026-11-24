create or replace function it.ful_obt_cod_cli_bcp (p_cod_persona in varchar2)
return number is
v_cod_ente ge_par_entes.cod_ente%type;
begin
  select cod_ente
    into v_cod_ente
    from ge_par_entes
   where cod_ente in (83,78)--cambios y financieras
     and rownum =1;
   if v_cod_ente = 83 then 
      return 2;
   elsif v_cod_ente = 78 then
      return 8;
   else
      return 3;
   end if;
exception
   when no_data_found then
      return 0;
   when others then
      raise_Application_error(-20000,'Obt.Cli.BCP.'||sqlerrm);
end;
/

