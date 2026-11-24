create or replace function it.fug_obt_paq_preferente(p_cod_persona in ba_personas.cod_persona%type,
                                                  p_nro_cuenta in ge_cta_clientes.nro_cuenta%type)
  return varchar2 is
  v_cod_paquete ge_paquetes.cod_paquete%type;
begin

    --Recibe el Código de la Persona y Retorna el Código del Paquete al cual esta Vinculado (Auque no sea titular)
    select distinct b.cod_paquete
      into v_cod_paquete
    from ge_cta_clientes a, ge_paq_clientes b, ge_paq_cuentas c, ge_paquetes p
   where b.cod_paquete = c.cod_paquete
     and b.cod_persona = c.cod_persona
     and c.cod_persona = a.cod_persona
     and c.nro_cuenta = a.nro_cuenta
     and b.cod_paquete= p.cod_paquete
     and a.cod_persona = p_cod_persona
     and a.nro_cuenta = p_nro_cuenta
     and p.cod_seg_preferente is not null
     and b.estado = 'N';
     
   return(v_cod_paquete);

exception
  when no_data_found then
    v_cod_paquete := null;
    return(v_cod_paquete);
end;
/

