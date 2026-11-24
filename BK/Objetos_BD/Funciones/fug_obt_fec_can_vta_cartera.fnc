CREATE OR REPLACE FUNCTION IT.fug_obt_fec_can_vta_cartera(p_nro_cuenta ge_sal_act_vta_cartera.nro_cuenta%type)
  RETURN DATE IS
  v_fec_cancelacion  date;
BEGIN
  SELECT s.fec_saldo
    INTO v_fec_cancelacion
    FROM ge_sal_act_vta_cartera s
   WHERE s.nro_cuenta = p_nro_cuenta
     AND s.fec_saldo = (SELECT MIN(fec_saldo)
                          FROM ge_sal_act_vta_cartera v
                         WHERE v.nro_cuenta = s.nro_cuenta
                           AND nvl(v.saldo, 0) = 0) --148
   UNION
  SELECT s.fec_saldo
    FROM ge_sal_act_vta_cartera s
   WHERE '0'||s.nro_cuenta = p_nro_cuenta
     AND s.fec_saldo = (SELECT MIN(fec_saldo)
                          FROM ge_sal_act_vta_cartera v
                         WHERE v.nro_cuenta = s.nro_cuenta
                           AND nvl(v.saldo, 0) = 0);
  RETURN v_fec_cancelacion;
EXCEPTION
  WHEN OTHERS THEN
    RETURN null;
END;
/

