CREATE OR REPLACE FUNCTION IT.fug_obt_sal_act_extractos(p_fec_extracto   IN DATE,
                                                        p_nro_cuenta     IN VARCHAR2,
                                                        p_hor_movimiento IN VARCHAR2,
                                                        p_fec_movimiento IN DATE,
                                                        p_mto_debito     IN NUMBER,
                                                        p_mto_credito    IN NUMBER
                                                        )
  RETURN NUMBER IS
  v_cont      NUMBER := 0;
  v_saldo_aux ge_ext_cli_cuentas.Sal_Actual%TYPE;
  cursor movi is
    SELECT mov.fec_movimiento,
           mov.hor_movimiento,
           mov.mto_debito,
           mov.mto_credito,
           cue.sal_anterior,
           cue.sal_actual,
           mov.concepto
      FROM ge_ext_clientes        cli,
           ge_ext_cli_cuentas     cue,
           ge_ext_cli_movimientos mov,
           ba_personas            pers ,
           gv_movimientos m, 
           ge_transacciones c
     where pers.cod_persona = cli.cod_persona
       AND cli.cod_persona = cue.cod_persona
       AND cli.cod_extracto = cue.cod_extracto
       AND cli.fre_extracto = cue.fre_extracto
       AND cli.fec_extracto = cue.fec_extracto
       AND cli.cod_persona = mov.cod_persona
       AND cue.fec_extracto = mov.fec_extracto
       AND cue.nro_cuenta = mov.nro_cuenta
       and      m.tipo = 'H'
       and      m.estado not in ('X', 'P', 'J')
       and      c.cod_modulo = m.cod_modulo
       and      c.cod_modalidad = m.cod_modalidad
       and      c.cod_transaccion = m.cod_transaccion
       and      c.ve_cliente = 'S'
       and      m.fecha=mov.fec_movimiento
       and      m.hora=mov.hor_movimiento
       and      m.nro_cuenta=cue.nro_cuenta
       and      m.nro_secuencia=mov.nro_secuencia
       and      not m.monto is null
       and      cue.fec_extracto = p_fec_extracto
       and      cue.nro_cuenta = p_nro_cuenta
     order by m.fec_insercion, mov.hor_movimiento ;
BEGIN
  v_cont := 1;
  for a in movi loop
    if v_cont = 1 then 
       v_saldo_aux := a.sal_anterior + a.mto_credito - a.mto_debito;
    else
      if a.mto_debito <0 then
       v_saldo_aux :=v_saldo_aux + a.mto_credito + abs(a.mto_debito);  
      else
       v_saldo_aux := v_saldo_aux + a.mto_credito - a.mto_debito;
       end if;
    end if;
    if p_fec_movimiento = a.fec_movimiento and p_hor_movimiento = a.hor_movimiento
      and p_mto_debito=a.mto_debito and p_mto_credito=a.mto_credito  then
      RETURN v_saldo_aux;
    end if;
    v_cont := v_cont + 1;
  end loop;
END;
/

