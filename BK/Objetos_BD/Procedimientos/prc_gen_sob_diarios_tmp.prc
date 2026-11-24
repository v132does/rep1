CREATE OR REPLACE PROCEDURE IT.prc_gen_sob_diarios_tmp(nro_cuenta varchar2 default null)
IS
  --
  v_sal_inicial   number := null;
  v_sal_posterior number := null;
  v_cuenta        ge_cuentas.nro_cuenta%type := null;
  v_msj           varchar2(1000);
  v_actualiza     number(12);
  --
  CURSOR cuentas IS
    SELECT xmov.cod_persona, xmov.nro_cuenta, xmov.fec_movimiento, xmov.fec_valor, xmov.hor_movimiento hora,
       xmov.cod_modulo, xmov.cod_modalidad, xmov.cod_tra_padre, xcta.cod_moneda,
       nvl(xcta.sal_anterior,0) sal_anterior, xmov.mto_debito, xmov.mto_credito,
       xcta.sal_anterior sal_ini_mes, xcta.sal_actual sal_fin_mes, xmov.cod_ofi_origen
     FROM ge_ext_cli_cuentas xcta, ge_ext_cli_movimientos xmov
       WHERE xcta.cod_persona = xmov.cod_persona
         AND xcta.nro_cuenta = xmov.nro_cuenta
         AND to_char(xcta.fec_extracto,'mmyyyy') = to_char(add_months(pag_cal.FU_OBT_FEC_ACTUAL(4),-1),'mmyyyy')
         AND to_char(xmov.fec_extracto,'mmyyyy') = to_char(add_months(pag_cal.FU_OBT_FEC_ACTUAL(4),-1),'mmyyyy')
         AND not exists (select 1 from cc_cta_corrientes cc
                          where cc.cod_ente is not null
                            and cc.nro_cuenta = xmov.nro_cuenta)
     ORDER BY xmov.cod_persona, xmov.nro_cuenta, xmov.fec_movimiento, xmov.hor_movimiento;
    --
BEGIN
  --
  pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1;
  -- Elimino los registros cada vez que proceso.
  v_msj := null;
  sql_util.ejecute_dml('TRUNCATE TABLE CC_SOB_DIARIOS_TMP', v_msj);
  if v_msj is not null then
     RAISE_APPLICATION_ERROR(-20001, v_msj);
  end if;
  --
  v_actualiza := 0;
  --
  FOR c_cuentas IN cuentas
  LOOP
    --
    IF nvl(v_cuenta,'0') != c_cuentas.nro_cuenta THEN
      --
      v_cuenta        := c_cuentas.nro_cuenta;
      v_sal_inicial   := c_cuentas.sal_anterior;
      --
      v_sal_posterior := v_sal_inicial + c_cuentas.mto_credito - c_cuentas.mto_debito;
      --
    ELSE
      --
      v_cuenta        := c_cuentas.nro_cuenta;
      v_sal_inicial   := v_sal_posterior;
      --
      v_sal_posterior := v_sal_inicial + c_cuentas.mto_credito - c_cuentas.mto_debito;
      --
    END IF;
    --
    INSERT INTO cc_sob_diarios_tmp ( COD_PERSONA,
                                     NRO_CUENTA,
                                     FEC_MOVIMIENTO,
                                     FEC_VALOR,
                                     HORA,
                                     COD_MODULO,
                                     COD_MODALIDAD,
                                     COD_TRA_PADRE,
                                     COD_MONEDA,
                                     SAL_ANTERIOR,
                                     MTO_DEBITO,
                                     MTO_CREDITO,
                                     SAL_POSTERIOR,
                                     SAL_INI_MES,
                                     SAL_FIN_MES,
                                     COD_OFI_ORIGEN)
                           VALUES (
                                    c_cuentas.cod_persona,
                                    c_cuentas.nro_cuenta,
                                    c_cuentas.fec_movimiento,
                                    c_cuentas.fec_valor,
                                    c_cuentas.hora,
                                    c_cuentas.cod_modulo,
                                    c_cuentas.cod_modalidad,
                                    c_cuentas.cod_tra_padre,
                                    c_cuentas.cod_moneda,
                                    v_sal_inicial,
                                    c_cuentas.mto_debito,
                                    c_cuentas.mto_credito,
                                    v_sal_posterior,
                                    c_cuentas.sal_ini_mes,
                                    c_cuentas.sal_fin_mes,
                                    c_cuentas.cod_ofi_origen
                                  );
    --
    v_actualiza := v_actualiza + 1;
    -- Actualizo cada 1000 registros
    IF v_actualiza = 1000 THEN
      --
      COMMIT;
      --
      v_actualiza := 0;
      --
    END IF;
    --
  END LOOP;
  --
  COMMIT;
  --
END;
/

