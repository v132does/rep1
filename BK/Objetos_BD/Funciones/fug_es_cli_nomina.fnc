create or replace function it.fug_es_cli_nomina (p_cod_persona ba_personas.cod_persona%type,
                                             p_nro_cuenta  ge_cta_clientes.nro_cuenta%type default null)
  return varchar2 is
  -- DE-1923 : Se comentan los códigos, porque no se encontró lógica en los mismos, para definir si un cliente es NOMINA. 
  --v_exi_ente      varchar2(1) := 'N';
  --v_no_exi_ente   varchar2(1) := 'S';
  v_nomina        varchar2(1) := 'N';
begin
--  OBS : Esta función se implementó con el pase : TBD-PPSL-4011 / CRO_2373, y relevando con los responsables, se decidió comentar dichos códigos.
  begin
    Select 'S'
      into v_nomina
      from ba_personas pe
     where pe.cod_persona = p_cod_persona
       and (exists
     (Select 1
              from ah_cta_vistas ah, ge_cta_clientes cl, ge_est_cuentas g
             where cl.nro_cuenta = ah.nro_cuenta
               and cl.cod_persona = pe.cod_persona
               and cl.cod_modulo = g.cod_modulo
               and cl.cod_modalidad = g.cod_modalidad
               and ah.estado = g.estado
               and g.activo = 'S'
               and cl.relacion = 'P'
               and ah.cod_ente is not null
               and (ah.nro_cuenta = p_nro_cuenta or p_nro_cuenta is null))
        or exists
     (Select 1
              from cc_cta_corrientes cc, ge_cta_clientes cl, ge_est_cuentas g
             where cc.nro_cuenta = cl.nro_cuenta
               and cl.cod_persona = pe.cod_persona
               and cl.cod_modulo = g.cod_modulo
               and cl.cod_modalidad = g.cod_modalidad
               and cc.estado = g.estado
               and g.activo = 'S'
               and cl.relacion = 'P'
               and cc.cod_ente is not null
               and (cc.nro_cuenta = p_nro_cuenta or p_nro_cuenta is null)));
  exception
    when too_many_rows then
      v_nomina := 'S'; ---Indica que SI existe ente en cuentas del cliente.
    when no_data_found then
      v_nomina := 'N'; --Indica que NO existe ente en cuentas del cliente.
    when others then
      v_nomina := 'N'; --Indica que NO existe ente en cuentas del cliente.
  end;
 return v_nomina;
  /*begin
    Select 'S'
      into v_no_exi_ente
      from ba_personas pe
     where pe.cod_persona = p_cod_persona
       and (exists
     (Select 1
              from ah_cta_vistas ah, ge_cta_clientes cl
             where cl.nro_cuenta = ah.nro_cuenta
               and cl.cod_persona = pe.cod_persona
               and cl.relacion = 'P'
               and ah.cod_ente is null
               and (ah.nro_cuenta = p_nro_cuenta or p_nro_cuenta is null))
        or exists
     (Select 1
              from cc_cta_corrientes cc, ge_cta_clientes cl
             where cc.nro_cuenta = cl.nro_cuenta
               and cl.cod_persona = pe.cod_persona
               and cl.relacion = 'P'
               and cc.cod_ente is null
               and (cc.nro_cuenta = p_nro_cuenta or p_nro_cuenta is null))
       or exists
      (Select 1
             from ge_cta_clientes e, ge_cuentas c, ge_est_cuentas g
            where e.nro_cuenta = c.nro_cuenta
              and e.cod_modulo = e.cod_modulo
              and e.cod_modalidad = c.cod_modalidad
              and c.cod_modulo = g.cod_modulo
              and c.cod_modalidad = g.cod_modalidad
              and c.estado = g.estado
              and e.cod_persona = pe.cod_persona
              and c.cod_modulo not in (5) -----Se excluyen las tarjetas
              and c.cod_modalidad not in (31,41)
              and g.activo = 'S'
              and e.relacion = 'P'
              and (e.nro_cuenta = p_nro_cuenta or p_nro_cuenta is null))
               );
  exception
    when too_many_rows then
      v_no_exi_ente := 'S'; ---Indica que SI existe ente en cuentas del cliente.
    when no_data_found then
      v_no_exi_ente := 'N'; --Indica que NO existe ente en cuentas del cliente.
    when others then
      v_no_exi_ente := 'N'; --Indica que NO existe ente en cuentas del cliente.
  end;
  if nvl(v_exi_ente,'N') = 'S' and nvl(v_no_exi_ente,'S') = 'N' then
    v_nomina := 'S';
    return v_nomina;
  elsif nvl(v_exi_ente,'N') = 'N' and nvl(v_no_exi_ente,'S') = 'N' then
   v_nomina := 'N';
   return v_nomina;
  elsif nvl(v_exi_ente,'N') = 'N' and nvl(v_no_exi_ente,'S') = 'S' then
   v_nomina := 'N';
   return v_nomina;
  elsif nvl(v_exi_ente,'N') = 'S' and nvl(v_no_exi_ente,'S') = 'S' then
   v_nomina := 'N';
   return v_nomina;
  end if;
exception
  when others then
    v_nomina := 'N'; --Indica que NO existe entr en cuentas del cliente o que el cliente no tiene cuenta
    return v_nomina;*/
end;
/

