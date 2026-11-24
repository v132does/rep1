create or replace function it.fug_obt_contingencia(p_nro_cuenta in varchar2) return number is
  v_cod_modulo ge_cta_clientes.cod_modulo%type;
  v_cod_modalidad ge_cuentas.cod_modalidad%type;
  v_sal_contable ge_cuentas.sal_contable%type := 0;
  v_monto number(18,2) := 0;
  v_contingencia number(18,2) := 0;
begin
  -- Obtengo que tipo de cuenta es...
  Begin
    select cod_modulo, cod_modalidad, sal_contable 
      into v_cod_modulo, v_cod_modalidad, v_sal_contable
      from ge_cuentas
     where nro_cuenta = p_nro_cuenta;
  Exception
    When NO_DATA_FOUND then
        raise_application_error(-20000, 'Cuenta inexistente en GE_CUENTAS');
    When TOO_MANY_ROWS then
        raise_application_error(-20001, 'Cuenta duplicada en GE_CUENTAS');
    When OTHERS then
        raise_application_error(-20000, 'Error al buscar la cuenta en GE_CUENTAS '||p_nro_cuenta||' '||sqlerrm);        
  End;
  --
  If v_cod_modulo = 4 then -- Ctacte.
     select nvl(sum(nvl(monto,0)),0) into v_monto
       from cc_lin_sobregiros
      where nro_cuenta = p_nro_cuenta
        and estado = 'A';
     If v_sal_contable < 0 then
     	  v_contingencia := v_monto + v_sal_contable;
     	  if v_contingencia < 0 then
     	  	 v_contingencia := 0;
     	  end if;
     else
     	  v_contingencia := v_monto;
     end if;
  Elsif v_cod_modulo = 5 then -- Tarjetas
    select nvl(sum( (nvl(lin_cuotas,0)+nvl(lin_credito,0)) - (nvl(sal_facturar,0)+nvl(sal_financiado,0)+nvl(sal_facturado,0))) ,0) 
      into v_monto
      from ta_cta_tarjetas
     where nro_cuenta = p_nro_cuenta
       and estado != 'C';
    If v_monto < 0 then
       v_monto := 0;
    End if;
    v_contingencia := v_monto;
  end if;
  
  return(v_contingencia);
end fug_obt_contingencia;
/

