create or replace function it.fug_ver_fir_inhibidos(p_nro_cuenta in ge_cuentas.nro_cuenta%type)
  return varchar2 is
  v_inhibido varchar2(1) := 'N';
begin
  --Verificar si la cuenta tiene algun firmante inhibido por alguna causa.
  select distinct 'S'
    into v_inhibido
    from ge_cuentas a, ge_cta_clientes b
   where a.nro_cuenta = b.nro_cuenta
     and a.nro_cuenta = p_nro_cuenta
     and exists (select 1
            from ge_per_inhibidas x
           where x.cod_persona = b.cod_persona
             and x.estado = 'I')
     and rownum = 1;
  return v_inhibido;
exception
  when no_data_found then
    v_inhibido := 'N';
    return v_inhibido;
end fug_ver_fir_inhibidos;
/

