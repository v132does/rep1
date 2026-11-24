create or replace function it.FUG_OBT_LIN_CRE_TARJETA
  (P_NRO_CUENTA IN TA_CTA_TARJETAS.NRO_CUENTA%TYPE)
  Return number
  Is
  v_lin_credito number;
Begin
    Select t.lin_credito
    Into v_lin_credito
    From ta_cta_tarjetas t
    Where t.nro_cuenta = p_nro_cuenta;
    Return(v_lin_credito);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_lin_credito := NULL;
      Return v_lin_credito;
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,SQLERRM||'ERROR. Al buscar linea de crédito de tarjeta. ');
end FUG_OBT_LIN_CRE_TARJETA;
/

