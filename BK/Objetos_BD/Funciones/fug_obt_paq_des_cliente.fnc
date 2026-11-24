create or replace function it.fug_obt_paq_des_cliente(p_cod_persona in ba_personas.cod_persona%type)
  return varchar2 is
  v_cod_paquete ge_paquetes.cod_paquete%type;
  v_des_paquete ge_paquetes.descripcion%type;
begin

    --Recibe el Código de la Persona y Retorna la Descripción del Paquete al cual esta Vinculado (Auque no sea titular)
    select distinct b.cod_paquete
      into v_cod_paquete
    from ge_cta_clientes a, ge_paq_clientes b, ge_paq_cuentas c
   where b.cod_paquete = c.cod_paquete
     and b.cod_persona = c.cod_persona
     and c.cod_persona = a.cod_persona
     and c.nro_cuenta = a.nro_cuenta
     and a.cod_persona = p_cod_persona
     and b.estado = 'N';

    select cod_paquete,descripcion
      into v_cod_paquete,v_des_paquete
      from ge_paquetes t
     where t.cod_paquete = v_cod_paquete;

   return(v_des_paquete);

exception
  when no_data_found then
    v_cod_paquete := null;
    v_des_paquete := null;
    return(v_des_paquete);
end;
/

