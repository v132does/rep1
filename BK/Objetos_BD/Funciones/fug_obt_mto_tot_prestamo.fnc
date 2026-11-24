create or replace function it.FUG_OBT_MTO_TOT_PRESTAMO
  (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE)
  Return number 
  Is
  v_mon_tot_prestamo number;
Begin
    Select pag_gen.FU_CON_MON_A_MONEDA(p.cod_moneda,'GS',
                                       nvl(p.mto_capital,0)+(nvl(sum(nvl(c.mto_interes,0)),0)+ nvl(sum(nvl(c.mto_int_documentado,0)),0)))               
    Into v_mon_tot_prestamo
    From pr_cta_prestamos p, pr_cuotas c
    Where p.nro_cuenta = c.nro_cuenta
    And c.nro_cuota > 0
    And p.nro_cuenta = p_nro_cuenta
    Group by p.cod_moneda,'GS',p.mto_capital;
    Return(v_mon_tot_prestamo);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_mon_tot_prestamo := NULL;
      Return v_mon_tot_prestamo;
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,SQLERRM||'ERROR. Al buscar Monto Total del Préstamo. ');
end FUG_OBT_MTO_TOT_PRESTAMO;
/

