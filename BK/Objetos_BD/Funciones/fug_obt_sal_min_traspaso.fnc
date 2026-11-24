CREATE OR REPLACE FUNCTION IT.FUG_OBT_SAL_MIN_TRASPASO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN INTEGER
 IS
v_cod_modulo      ge_cuentas.cod_modulo%type;
  v_cod_modalidad ge_cuentas.cod_modalidad%type;
  v_cod_oficina   ge_cuentas.cod_oficina%type;
  v_cod_moneda    ge_cuentas.cod_moneda%type;
  v_cod_persona   ge_cta_clientes.cod_persona%type;
  v_sal_minimo    cc_cta_combinadas.sal_minimo%type;
  v_cod_sub_modalidad ge_cuentas.cod_sub_modalidad%type;
Begin
  select cta.cod_modulo,cta.cod_modalidad,cta.cod_oficina,cta.cod_moneda,cli.cod_persona,cta.cod_sub_modalidad
    into v_cod_modulo,v_cod_modalidad,v_cod_oficina,v_cod_moneda,v_cod_persona,v_cod_sub_modalidad
    from ge_cuentas cta, ge_cta_clientes cli
   where cta.nro_cuenta = p_nro_cuenta
     and cli.relacion = 'P'
     and cta.nro_cuenta = cli.nro_cuenta;
  If FUG_ES_EMPLEADO(v_cod_persona) = 'S' then
	   v_sal_minimo := FUG_OBT_PARDINAMICO('SAL_MIN_TRA_EMPLEADO',v_cod_modulo,v_cod_modalidad,v_cod_moneda,v_cod_oficina,v_cod_sub_modalidad);
  else
     v_sal_minimo := FUG_OBT_PARDINAMICO('SAL_MIN_TRASPASO',v_cod_modulo,v_cod_modalidad,v_cod_moneda,v_cod_oficina,v_cod_sub_modalidad);
  End if;
  return v_sal_minimo;
exception
  when no_data_found then
    raise_application_error(-20000,'La cuenta no existe');
  when others then
  If sqlcode <= -20000 then
    raise;
  else
    raise_application_error(-20000,'Al obtener el saldo minimo de traspaso '||p_nro_cuenta||' '||sqlerrm);
  End if;
end;
/

