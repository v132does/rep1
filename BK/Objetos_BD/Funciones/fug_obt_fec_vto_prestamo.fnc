create or replace function it.FUG_OBT_FEC_VTO_PRESTAMO
  (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE)
  Return date
  Is
  v_fec_vencimiento date;
Begin
    Select fec_vencimiento
    Into v_fec_vencimiento
    From pr_cta_prestamos p
    Where p.nro_cuenta = p_nro_cuenta;
    Return(v_fec_vencimiento);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_fec_vencimiento := NULL;
      Return v_fec_vencimiento;
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,SQLERRM||'ERROR. Al buscar Fecha de vencimiento del Préstamo. ');
end FUG_OBT_FEC_VTO_PRESTAMO;
/

