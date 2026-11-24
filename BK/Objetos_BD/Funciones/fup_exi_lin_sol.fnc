create or replace function it.fup_exi_lin_sol(p_nro_linea in number, p_nro_sec_padre in number, p_nro_cuenta in varchar2) return varchar2 is
  v_existe varchar2(1);
begin
  Select 'S'
    into v_existe
    from pr_lin_aplicaciones
   where nro_linea = p_nro_linea
     and nro_sec_padre = p_nro_sec_padre
     and nro_cuenta = p_nro_cuenta;
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
end fup_exi_lin_sol;
/

