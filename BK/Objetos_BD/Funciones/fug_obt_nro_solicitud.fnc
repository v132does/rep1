create or replace function it.FUG_OBT_NRO_SOLICITUD
  (P_NRO_CUENTA IN TA_CTA_TARJETAS.NRO_CUENTA%TYPE,
   P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE)
  Return number
  Is
  v_nro_solicititud number;
Begin
    If p_cod_modulo = 5 then
       Begin
          Select nro_solicitud
          Into v_nro_solicititud
          From ta_cta_tarjetas
          Where nro_cuenta = p_nro_cuenta;
          Return(v_nro_solicititud);
          EXCEPTION
             WHEN NO_DATA_FOUND THEN
                v_nro_solicititud := NULL;
                Return v_nro_solicititud;
             WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20000,SQLERRM||'ERROR. Al buscar Nro. solicitud de la Cta. de tarjeta. ');
       End;
    Else If p_cod_modulo = 6 then
      Begin
         Select nro_solicitud
             Into v_nro_solicititud
             From pr_cta_prestamos
             Where nro_cuenta = p_nro_cuenta;
             Return(v_nro_solicititud);
             EXCEPTION
                WHEN NO_DATA_FOUND THEN
                   v_nro_solicititud := NULL;
                   Return v_nro_solicititud;
                WHEN OTHERS THEN
                   RAISE_APPLICATION_ERROR(-20000,SQLERRM||'ERROR. Al buscar Nro. solicitud de la Cta. de préstamos. ');
      End;             
    End If;
    End If;
end FUG_OBT_NRO_SOLICITUD;
/

