create or replace function it.fup_exi_lin_sol_global(p_nro_linea in number, p_cod_persona in varchar2) return varchar2 is
  v_existe varchar2(1);
begin
  Select 'S'
    into v_existe
    from pr_gru_lin_aplicaciones pl
   where pl.nro_linea = p_nro_linea
     and pl.cod_persona = p_cod_persona
     and exists (Select 1
                   from pr_lineas pr
                  where pr.nro_linea = pl.nro_lin_individual
                  and pr.estado in ('A','B','P'));
  return(v_existe);
Exception
  When NO_DATA_FOUND then
       v_existe := 'N';
       Return v_existe;
  When TOO_MANY_ROWS then
       v_existe := 'S';
       Return v_existe;
  When OTHERS then
       raise_application_error(-20000, 'Error buscando lineas de aplicaciones');
end fup_exi_lin_sol_global;
/

