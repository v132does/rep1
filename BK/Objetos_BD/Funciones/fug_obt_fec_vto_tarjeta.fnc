create or replace function it.FUG_OBT_FEC_VTO_TARJETA
  (P_NRO_CUENTA IN TA_CTA_TARJETAS.NRO_CUENTA%TYPE,
   P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
  Return date
  Is
  v_fec_vencimiento date;
Begin
    SELECT t.fec_vencimiento
    INTO v_fec_vencimiento
    FROM ta_tarjetas t
    Where t.nro_cuenta = p_nro_cuenta
    And t.cod_persona = p_cod_persona
    And rownum = 1;
    Return(v_fec_vencimiento);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_fec_vencimiento := NULL;
      Return v_fec_vencimiento;
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,SQLERRM||'ERROR. Al buscar fecha vencimiento de la tarjeta. ');
end FUG_OBT_FEC_VTO_TARJETA;
/

