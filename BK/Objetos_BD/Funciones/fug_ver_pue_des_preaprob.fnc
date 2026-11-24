create or replace function it.fug_ver_pue_des_preaprob(p_nro_cuenta varchar2)
  return varchar2 is
  v_cod_modulo        ba_modulos.cod_modulo%type;
  v_cod_modalidad     ge_modalidades.cod_modalidad%type;
  v_cod_sub_modalidad ge_sub_modalidades.cod_sub_modalidad%type;
  v_cod_moneda        ba_monedas.cod_moneda%type;
  v_cod_oficina       ba_oficinas.cod_oficina%type;
  v_val_parametro     varchar2(1);
begin
  begin
    select a.cod_modulo, a.cod_modalidad, a.cod_sub_modalidad, a.cod_moneda, a.cod_oficina
      into v_cod_modulo, v_cod_modalidad, v_cod_sub_modalidad, v_cod_moneda, v_cod_oficina
      from ge_cuentas a
     where a.nro_cuenta = p_nro_cuenta;
  exception
    when others then
      return 'N';
  end;
  v_val_parametro := nvl(fug_obt_pardinamico('COD_MAD_BLO_DES_PREAPROB',
                                             v_cod_modulo,
                                             v_cod_modalidad,
                                             v_cod_moneda,
                                             v_cod_oficina,
                                             v_cod_sub_modalidad),
                         'N');
  if v_val_parametro = 'S' then
    return 'N';
  else
    return 'S';
  end if;
end;
/

