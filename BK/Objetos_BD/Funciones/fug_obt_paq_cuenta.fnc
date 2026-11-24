create or replace function it.fug_obt_paq_cuenta(p_nro_cuenta ge_cuentas.nro_cuenta%type)
  return varchar2 is
  v_cod_paquete ge_paquetes.cod_paquete%type;
begin

  --Recibe el Nro. de Cuenta y Retorna el Código de Paquete al que pertenece (El paquete debe estar en estado N=Normal)

  select t.cod_paquete
    into v_cod_paquete
    from ge_paq_cuentas t, ge_paq_clientes c
   where t.cod_paquete = c.cod_paquete
     and t.cod_persona = c.cod_persona
     and t.nro_secuencia = c.nro_secuencia
     and t.nro_cuenta = p_nro_cuenta
     and c.estado = 'N';

   return(v_cod_paquete);

exception
  when others then
    v_cod_paquete := null;
    return(v_cod_paquete);
end;
/

