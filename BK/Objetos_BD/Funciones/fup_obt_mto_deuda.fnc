create or replace function it.FUP_OBT_MTO_DEUDA(P_NRO_CUENTA     IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL, --Número de Cuenta
                                                P_cod_ofi_origen IN GE_CUENTAS.Cod_Oficina%TYPE DEFAULT NULL,
                                                P_CUOTA_DESDE    IN PR_CUOTAS.NRO_CUOTA%TYPE DEFAULT 1, --cuota inicial
                                                P_CUOTA_HASTA    IN PR_CUOTAS.NRO_CUOTA%TYPE DEFAULT 999,
                                                P_FECHA          IN DATE,
                                                P_TIP_DEUDA      VARCHAR2,
                                                P_CANCELA        IN VARCHAR2 default 'C') --- cuota final
 return number is
  v_mto_atraso         number; -- monto de atraso en cuenta
  v_monto_cobrado      pr_cta_prestamos.sal_capital%type:=null;
  v_error              varchar2(1000);
  v_mensaje            varchar2(1000);
  v_tot_capital        pr_cta_prestamos.sal_capital%type;
  v_tot_interes        pr_cta_prestamos.sal_interes%type;
  v_tot_int_adelantado pr_cta_prestamos.sal_int_adelantado%type;
  v_tot_mora           pr_cta_prestamos.sal_interes%type;
  v_tot_mora_interes   pr_cta_prestamos.sal_interes%type;
  v_tot_mora_int_ade   pr_cta_prestamos.sal_interes%type;
  v_tot_punitorio      pr_cta_prestamos.sal_interes%type;
  v_tot_impuesto       pr_cta_prestamos.sal_interes%type;
  v_tot_cargo          pr_cta_prestamos.sal_capital%type;
  v_tot_cargo_iva      pr_cta_prestamos.sal_capital%type;
  v_tot_int_descontado pr_cuotas.sal_interes%TYPE;
  v_dia_mora           pr_cta_prestamos.dia_atraso%TYPE;
  -------------------
  v_tot_capital_t        pr_cta_prestamos.sal_capital%type;
  v_tot_interes_t        pr_cta_prestamos.sal_interes%type;
  v_tot_int_adelantado_t pr_cta_prestamos.sal_int_adelantado%type;
  v_tot_mora_t           pr_cta_prestamos.sal_interes%type;
  v_tot_mora_interes_t   pr_cta_prestamos.sal_interes%type;
  v_tot_mora_int_ade_t   pr_cta_prestamos.sal_interes%type;
  v_tot_punitorio_t      pr_cta_prestamos.sal_interes%type;
  v_tot_impuesto_t       pr_cta_prestamos.sal_interes%type;
  v_tot_cargo_t          pr_cta_prestamos.sal_capital%type;
  v_tot_cargo_iva_t      pr_cta_prestamos.sal_capital%type;
  v_tot_int_descontado_t pr_cuotas.sal_interes%TYPE;
  v_dia_mora_t           pr_cta_prestamos.dia_atraso%TYPE;
  -------------------
  v_cod_tra_padre      number := 359;
  v_renueva            varchar2(50);
  v_can_capital        varchar2(50);
  v_tip_operacion      varchar2(50);
  v_cod_modulo         pr_cta_prestamos.cod_modulo%type;
  v_cod_modalidad      pr_cta_prestamos.cod_modalidad%type;
  v_cod_oficina        pr_cta_prestamos.cod_oficina%type;
  v_cod_moneda         pr_cta_prestamos.cod_moneda%type;
  v_nro_solicitud      pr_cta_prestamos.nro_solicitud%type;
  v_tasa               number;
  v_redondeo           number;
  v_cob_iva            varchar2(1) := 'N';

  PRAGMA AUTONOMOUS_TRANSACTION;
begin
  -- Busco los datos de atrasos en las cuentas que tiene el client..
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  pap_pre.pr_obt_deu_prestamo(P_NRO_CUENTA,
                              P_FECHA,
                              P_CUOTA_DESDE,
                              P_CUOTA_HASTA,
                              P_cod_ofi_origen,
                              v_monto_cobrado,
                              v_error,
                              v_mensaje,
                              v_tot_capital,
                              v_tot_interes,
                              v_tot_int_adelantado,
                              v_tot_mora,
                              v_tot_mora_interes,
                              v_tot_mora_int_ade,
                              v_tot_punitorio,
                              v_tot_impuesto,
                              v_tot_cargo,
                              v_tot_cargo_iva,
                              v_tot_int_descontado,
                              v_dia_mora,
                              v_cod_tra_padre,
                              'C',--P_CANCELA,
                              v_renueva,
                              v_can_capital,
                              v_tip_operacion);
  rollback;

  -- Busco los datos de atrasos en las cuentas que tiene el cliente
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  pap_pre.pr_obt_deu_prestamo(P_NRO_CUENTA,
                              P_FECHA,
                              P_CUOTA_DESDE,
                              P_CUOTA_HASTA,
                              P_cod_ofi_origen,
                              v_monto_cobrado,
                              v_error,
                              v_mensaje,
                              v_tot_capital_t,
                              v_tot_interes_t,
                              v_tot_int_adelantado_t,
                              v_tot_mora_t,
                              v_tot_mora_interes_t,
                              v_tot_mora_int_ade_t,
                              v_tot_punitorio_t,
                              v_tot_impuesto_t,
                              v_tot_cargo_t,
                              v_tot_cargo_iva_t,
                              v_tot_int_descontado_t,
                              v_dia_mora_t,
                              v_cod_tra_padre,
                              'T',--P_CANCELA
                              v_renueva,
                              v_can_capital,
                              v_tip_operacion);
  rollback;


  If p_tip_deuda = 'IM' then
    v_mto_atraso := nvl(v_tot_impuesto, 0);

  elsif p_tip_deuda = 'CG' then
    v_mto_atraso := nvl(v_tot_cargo, 0);

  elsif p_tip_deuda = 'PU' then
    v_mto_atraso := nvl(v_tot_punitorio, 0);

  elsif p_tip_deuda = 'MI' then
    v_mto_atraso := nvl(v_tot_mora_interes, 0);

  elsif p_tip_deuda = 'MA' then
    v_mto_atraso := nvl(v_tot_mora_int_ade, 0);

  elsif p_tip_deuda = 'MO' then
    v_mto_atraso := nvl(v_tot_mora, 0);

  elsif p_tip_deuda = 'IA' then
    v_mto_atraso := nvl(v_tot_int_adelantado, 0);

  elsif p_tip_deuda = 'IN' then
    v_mto_atraso := nvl(v_tot_interes, 0) + nvl(v_tot_int_descontado, 0);

  elsif p_tip_deuda = 'CA' then
    v_mto_atraso := nvl(v_tot_capital_t, 0);

  elsif p_tip_deuda = 'CI' then
    v_mto_atraso := nvl(v_tot_cargo_iva, 0);

  elsif p_tip_deuda = 'DT' then

      Select t.cod_modulo, t.cod_modalidad, t.cod_oficina, t.cod_moneda, t.nro_solicitud
      into v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda, v_nro_solicitud
      from pr_cta_prestamos t
      where t.nro_cuenta = P_NRO_CUENTA;

      v_tasa := it.FUG_OBT_VAL_TASA(P_COD_MODULO => v_cod_modulo,
                                 P_COD_MODALIDAD => v_cod_modalidad,
                                 P_COD_OFICINA => v_cod_oficina,
                                 P_NRO_CUENTA => P_NRO_CUENTA,
                                 P_COD_MONEDA => v_cod_moneda,
                                 P_MTO_TRANSACCION => null,
                                 P_TAS_PERSONALIZADA => null,
                                 P_COD_TASA => null,
                                 P_COD_TRANSACCION => 1708,
                                 P_FEC_FINAL => P_FECHA);

    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                      v_cod_modulo,
                                      null,
                                      v_cod_moneda);
   Begin
       SELECT 'S'
         INTO v_cob_iva
         FROM pr_sol_cargos
        WHERE nro_solicitud = v_nro_solicitud
          AND cod_transaccion = 709;
   Exception
     when others then
       v_cob_iva := 'N';
   end;

     if v_cob_iva = 'N' then
        v_tasa := 0;
     end if;

      v_mto_atraso := round(nvl(v_tot_capital_t, 0) + nvl(v_tot_interes_t, 0) + nvl(v_tot_int_adelantado_t, 0) + nvl(v_tot_mora_t, 0) +
                      nvl(v_tot_mora_interes_t, 0) + nvl(v_tot_mora_int_ade_t, 0) + nvl(v_tot_punitorio_t, 0) +
                      nvl(v_tot_impuesto_t, 0) + nvl(v_tot_cargo_t, 0) - ((nvl(v_tot_int_descontado_t, 0)) * v_tasa/100)
                      ,v_redondeo) ;

  elsif p_tip_deuda = 'ID' then
    v_mto_atraso := nvl(v_tot_int_descontado_t, 0);
  elsif p_tip_deuda = 'IT' then
    v_mto_atraso := nvl(v_tot_interes_t, 0);
  End if;

  return nvl(v_mto_atraso, 0);

exception
  when others then
    raise_application_error(-20000,
                            'FUP_OBT_MTO_DEUDA Cuenta: ' || P_NRO_CUENTA || '-' ||
                            sqlerrm);
end;
/

