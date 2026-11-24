create or replace function it.FUG_VER_EXO_IMPUESTO
  (p_cta_ori in GE_CUENTAS.NRO_CUENTA%TYPE, 
   p_cta_des in GE_CUENTAS.NRO_CUENTA%TYPE
  ) 
  return varchar2 
  is
  
	v_cod_cliente  ge_clientes.cod_persona%type;
	v_cod_cliente2 ge_clientes.cod_persona%type;
  v_tipo         ba_personas.tipo%type;
  v_tipo2        ba_personas.tipo%type;
  v_existe       varchar2(1) := 'N';
  
--Verificar si se va a cobrar el impuesto ley 125  
begin
  --Si son personas fisicas en ambas cuentas, y si existe alguna relacion entre ambas
  --no se cobra el impuesto. Pero si son juridicas tienen que ser principales en ambos
  --casos o de lo contrario si se cobra el impuesto

-- RI : 16/02/2010 : Se comenta el proceso, retorna siempre "N", esta ley ya no esta vigente   
/*  --Verificar si el cliente de la 1° cuenta es fisica o juridica
  select tipo,cli.cod_persona
    into v_tipo,v_cod_cliente
    from ge_cta_clientes cli,
         ba_personas per
   where cli.cod_persona = per.cod_persona
     and cli.nro_cuenta = p_cta_ori
     and relacion = 'P';
     
  --Verificar si el cliente de la 2° cuenta es fisica o juridica
  select tipo,cli.cod_persona
    into v_tipo2,v_cod_cliente2
    from ge_cta_clientes cli,
         ba_personas per
   where cli.cod_persona = per.cod_persona
     and cli.nro_cuenta = p_cta_des
     and relacion = 'P';
  
  If v_tipo <> v_tipo2 then
    return ('S');--Cuando son de dif. tipos, si cobra el impuesto
  elsif v_tipo = 'F' then --si ambos son fisicas
    begin
      select 'S'
        into v_existe
        from ge_cta_clientes cli
       where cli.nro_cuenta = p_cta_ori
         and cli.cod_persona in (select cod_persona
                                   from ge_cta_clientes cli2
                                  where cli2.nro_cuenta = p_cta_des);
                                    --ojo la cuenta des puede ser de préstamo también
    exception
      when no_data_found then
        v_existe := 'N';
      when too_many_rows then
        v_existe := 'S';
    end;
    If v_existe = 'S' then --Existe alguna relacion entre las ctas., no se cobra imp.
      return 'N';
    else
      return 'S';
    End if;
  elsif v_tipo = 'J' then --si ambos son juridicas
    If v_cod_cliente = v_cod_cliente2 then
      return ('N');  --No se cobra cuando son el mismo cliente en ambas ctas.
    else
      return ('S');
    End if;
  end if;
*/

Return 'N';
  
exception
  when others then
    raise_application_error(-20000,'FUG_VER_EXO_IMPUESTO '||sqlerrm); 
end FUG_VER_EXO_IMPUESTO;
/

