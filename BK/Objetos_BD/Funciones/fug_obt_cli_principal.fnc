CREATE OR REPLACE FUNCTION IT.FUG_OBT_CLI_PRINCIPAL ( p_nro_cuenta in varchar2,
                                                   p_relacion varchar2 default null
                                                 )
return varchar2 is
  v_cod_cliente ge_cta_clientes.cod_persona%type;
  v_existe number(10) := 0;
begin
  /* Para COMEX en la mad. de C.C.E., el producto el principal para los cobros de cargos debería
     de ser el EXPORTADOR y no el principal, el principal es una entidad BANCARIA
  */
   select count(1)
    into v_existe
    from ge_cta_clientes
   where nro_cuenta = p_nro_cuenta
     and relacion   = nvl(p_relacion,'P');

  if v_existe > 0 then 
          select cod_persona
            into v_cod_cliente
            from ge_cta_clientes
           where nro_cuenta = p_nro_cuenta
             and relacion   = nvl(p_relacion,'P');
             return v_cod_cliente;
        
    else 
         select null  into v_cod_cliente from dual;  return v_cod_cliente;
   end if;
   
   exception

           when no_data_found then
              raise_Application_error(-20000,'Principal no definido para la Cuenta '||p_nro_cuenta);
           when too_many_rows then
              raise_Application_error(-20000,'Más de un Principal definido para la Cuenta');
           when others then
              raise_Application_error(-20000,'Obt.Principal de Cta. '||sqlerrm);
end;
/

