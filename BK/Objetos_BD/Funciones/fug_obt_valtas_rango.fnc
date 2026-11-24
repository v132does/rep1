CREATE OR REPLACE FUNCTION IT.FUG_OBT_VALTAS_RANGO
 (P_COD_TASA IN GE_TAS_RANGOS.COD_TASA%TYPE
 ,P_COD_MODULO IN GE_TAS_RANGOS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TAS_RANGOS.COD_MODALIDAD%TYPE
 ,P_COD_MONEDA IN GE_TAS_RANGOS.COD_MONEDA%TYPE
 ,P_COD_OFICINA IN GE_TAS_RANGOS.COD_OFICINA%TYPE
 ,P_VAL_HASTA IN GE_TAS_RANGOS.VAL_HASTA%TYPE
 ,P_FEC_VIGENCIA IN GE_TAS_RANGOS.FEC_VIGENCIA%TYPE
 )
 RETURN NUMBER
 IS
v_val_tasa ge_tas_rangos.val_tasa%type;
v_tas_personalizada varchar2(1) := 'N';
v_cod_transaccion ge_transacciones.cod_transaccion%type;

V_FEC_VIGENCIA DATE;
V_COD_TASA GE_TASAS.COD_TASA%TYPE;
V_TIP_VALOR GE_TASAS.TIP_VALOR%TYPE;
V_TIPO GE_TASAS.TIPO%TYPE;
V_NRO_CUENTA GE_CUENTAS.NRO_CUENTA%TYPE;

BEGIN
 V_COD_TASA := P_COD_TASA;
 V_FEC_VIGENCIA := P_FEC_VIGENCIA;
 PAG_GEN.PR_OBT_VAL_TASA(P_COD_MODULO,P_COD_MODALIDAD,P_COD_OFICINA,
                 V_NRO_CUENTA,  P_COD_MONEDA, P_VAL_HASTA, V_TAS_PERSONALIZADA,
                 V_COD_TASA,  V_COD_TRANSACCION, P_FEC_VIGENCIA, V_VAL_TASA,V_FEC_VIGENCIA,
                 V_TIP_VALOR, V_TIPO);
 RETURN V_VAL_TASA;

/*
   select val_tasa
   into v_val_tasa
   from ge_tas_rangos
   where cod_tasa = p_cod_tasa
   and nvl(nvl(cod_modulo, p_cod_modulo),-1) = nvl(p_cod_modulo,-1)
   and nvl(nvl(cod_modalidad,p_cod_modalidad),-1) = nvl(p_cod_modalidad, -1)
   and nvl(nvl(cod_moneda,p_cod_moneda),'x') = nvl(p_cod_moneda,'x')
   and nvl(nvl(cod_oficina,p_cod_oficina),-1) = nvl(p_cod_oficina,-1)
   and val_hasta >= p_val_hasta
   and fec_vigencia =
      (select max(fec_vigencia)
       from ge_tas_rangos
       where cod_tasa = p_cod_tasa
       and nvl(nvl(cod_modulo, p_cod_modulo),-1) = nvl(p_cod_modulo,-1)
       and nvl(nvl(cod_modalidad,p_cod_modalidad),-1) = nvl(p_cod_modalidad, -1)
       and nvl(nvl(cod_moneda,p_cod_moneda),'x') = nvl(p_cod_moneda,'x')
       and nvl(nvl(cod_oficina,p_cod_oficina),-1) = nvl(p_cod_oficina,-1)
       and val_hasta >= p_val_hasta
       and fec_vigencia <= p_fec_vigencia);
   RETURN v_val_tasa;
   */
exception
    when no_data_found then
      raise_application_error(-20000,
      'Tasa '||to_char(p_cod_tasa)||' no registrada por rango');
END;
/

