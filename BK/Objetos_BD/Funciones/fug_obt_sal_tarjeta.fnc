create or replace function it.FUG_OBT_SAL_TARJETA
  (P_NRO_CUENTA IN TA_CTA_TARJETAS.NRO_CUENTA%TYPE)
  Return number
  Is
  v_sal_credito number;
Begin
    SELECT (CASE WHEN t.estado != 'B' THEN
                (CASE WHEN NVL(t.sal_procesadora, 0) > (NVL(t.lin_credito, 0) + NVL(t.lin_cuotas, 0)) THEN 0
                      WHEN NVL(t.sal_procesadora, 0) <= 0 THEN (NVL(t.lin_credito, 0) + NVL(t.lin_cuotas, 0))
                      ELSE ((NVL(t.lin_credito, 0) + NVL(t.lin_cuotas, 0)) - NVL(t.sal_procesadora, 0))
                END)
             ELSE 0
           END) monto
    INTO v_sal_credito
    FROM ta_cta_tarjetas t
    Where t.nro_cuenta = p_nro_cuenta;
    Return(v_sal_credito);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_sal_credito := NULL;
      Return v_sal_credito;
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,SQLERRM||'ERROR. Al buscar saldo de la tarjeta. ');
end FUG_OBT_SAL_TARJETA;
/

