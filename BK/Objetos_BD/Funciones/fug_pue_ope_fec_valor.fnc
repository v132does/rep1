create or replace function it.FUG_PUE_OPE_FEC_VALOR
            (P_COD_USUARIO     IN BA_USU_ROLES.COD_USUARIO%TYPE,
             P_COD_MODULO      IN GE_TRANSACCIONES.COD_MODULO%TYPE,
             P_COD_MODALIDAD   IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE,
             P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
             P_FECHA           IN DATE default null,
             p_nro_cuenta      in ge_cuentas.nro_cuenta%type default null,
             p_cod_moneda      in ge_cuentas.cod_moneda%type default null,
             p_monto           in ge_cuentas.sal_contable%type default null)
  return varchar2 is
  v_puede varchar2(1);
  v_fecha date := pag_cal.fu_obt_fec_actual(nvl(p_cod_modulo,1));
  v_can_dias number;
  -- Verifico si el usuario puede operar con fecha valor con la transacción
  -- si fecha viene null valida que pueda operar
  -- si tiene fecha valida que pueda operar con esa fecha valor
begin
  begin
    Select 'S' 
      into v_puede
      from ba_usu_roles a,ge_tra_roles b
     where a.cod_rol = b.cod_rol
       and a.cod_usuario = p_cod_usuario
       and b.cod_transaccion = p_cod_transaccion
       and b.cod_modulo = p_cod_modulo
       and b.cod_modalidad = p_cod_modalidad
       and b.ope_fec_valor = 'S'
       and nvl(p_fecha, v_fecha) between (v_fecha -  b.can_dias) and v_fecha;
  exception
    when no_data_found then
      v_puede := 'N';
    when too_many_rows then
      v_puede := 'S';
    when others then
      v_puede := 'N';
  end;
  --verifica que la cuenta pueda operar
  if v_puede = 'S' then
    if p_nro_cuenta is not null then
      --recuperar datos de la cuenta
      pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
      if pag_cta.G_COD_ERROR <> 0 then
        raise_application_error(-20000,pag_cta.fu_obt_msj_error);
      end if;
      --verificari fecha de apertura
      if pag_cta.G_CTAS.fec_apertura > p_fecha then
        raise_application_error(-20000,'Fecha de Apertura de la Cuenta es menor a la Fecha Valor');
      end if;
      --verificar estado
      begin
        Select 'S'
          into v_puede
          from ge_est_cuentas c
         where c.cod_modulo = pag_cta.g_ctas.cod_modulo
           and c.cod_modalidad = pag_cta.g_ctas.cod_modalidad
           and c.estado = pag_cta.g_ctas.estado
           and c.activo = 'S';
      exception
        when no_data_found then
          raise_application_error(-20000,'Estado de la Cuenta no permite operar con Fecha Valor');
      end;
    end if;
  end if;
  return(v_puede);
end FUG_PUE_OPE_FEC_VALOR;
/

