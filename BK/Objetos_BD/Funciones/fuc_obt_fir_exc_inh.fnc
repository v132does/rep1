create or replace function it.fuc_obt_fir_exc_inh(p_nro_cuenta in ge_cuentas.nro_cuenta%type)
  return varchar2 is
  v_inh_exc_cau_inh varchar2(1) := 'N';
  v_otr_cau_inhibicion varchar2(1) := 'N';
  v_cod_cau_exc_inh ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_CAU_EXC_INHIBIDO');
begin

  --Verificar si la cuenta tiene algun firmante inhibido por la Ley de Cheques
  begin
    select distinct 'S'
      into  v_inh_exc_cau_inh
      from ge_cuentas a, ge_cta_clientes b
     where a.nro_cuenta = b.nro_cuenta
       and a.nro_cuenta = p_nro_cuenta
       and exists (select 1
                     from ge_per_inhibidas x
                    where x.cod_persona = b.cod_persona
                      and x.estado = 'I'
                      and instr(','||v_cod_cau_exc_inh||',' ,  ','||x.cod_causa||',') > 0)
       and rownum = 1;
  exception
    when others then
       v_inh_exc_cau_inh:= 'N';
  end;

  begin
    select distinct 'S'
      into v_otr_cau_inhibicion
      from ge_cuentas a, ge_cta_clientes b
     where a.nro_cuenta = b.nro_cuenta
       and a.nro_cuenta = p_nro_cuenta
       and exists (select 1
                     from ge_per_inhibidas x
                    where x.cod_persona = b.cod_persona
                      and x.estado = 'I'
                      and instr(','||v_cod_cau_exc_inh||',' ,  ','||x.cod_causa||',') = 0
                       and x.cod_causa in(select m.cod_causa
                                            from ge_par_causales m, ge_causales c
                                           where m.cod_causa = c.cod_causa
                                             and c.tipo = 'I'
                                             and m.parametro = 'INH_LEY_CHEQUES'))

       and rownum = 1;
  exception
    when others then
      v_otr_cau_inhibicion := 'N';
  end;

  if nvl( v_inh_exc_cau_inh, 'N') = 'S' and nvl(v_otr_cau_inhibicion, 'N') = 'N' then
     return 'N';
  elsif nvl( v_inh_exc_cau_inh, 'N') = 'N' and nvl(v_otr_cau_inhibicion, 'N') = 'N' then
     return 'N';
  else
     return 'S';
  end if;
end fuc_obt_fir_exc_inh;
/

