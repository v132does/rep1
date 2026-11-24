create or replace function it.fuc_ver_fir_inhibidos(p_nro_cuenta in ge_cuentas.nro_cuenta%type)
  return varchar2 is
  v_inhibido varchar2(1) := 'N';
begin
  --Verificar si la cuenta tiene algun firmante inhibido por la Ley de Cheques
  select 'S'
    into v_inhibido
    from ge_cuentas a, ge_cta_clientes b
   where a.nro_cuenta = b.nro_cuenta
     and a.nro_cuenta = p_nro_cuenta
     and exists (select 1
            from ge_per_inhibidas x
           where x.cod_persona = b.cod_persona
             and x.estado = 'I'
             and x.cod_causa in
                 (select m.cod_causa
                    from ge_par_causales m, ge_causales c
                   where m.cod_causa = c.cod_causa
                     and c.tipo = 'I'
                     and m.parametro = 'INH_LEY_CHEQUES'))
     and rownum = 1;
  return v_inhibido;
exception
  when no_data_found then
    v_inhibido := 'N';
    return v_inhibido;
end fuc_ver_fir_inhibidos;
/

