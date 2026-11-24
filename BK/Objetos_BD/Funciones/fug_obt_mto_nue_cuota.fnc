CREATE OR REPLACE FUNCTION IT.FUG_OBT_MTO_NUE_CUOTA
( p_nro_solicitud  IN pr_solicitudes.nro_solicitud%TYPE,
  p_cod_modulo     IN ba_modulos.cod_modulo%TYPE)
 RETURN NUMBER IS
   v_importe pr_solicitudes.monto%TYPE := 0;
Begin
If p_cod_modulo = 6 then
  BEGIN
     select nvl(mto_capital,0) + nvl(val_interes,0)
     into v_importe
     from pr_sol_cuotas
     where nro_solicitud = p_nro_solicitud
     and nro_cuota = 1;
     RETURN v_importe;
  EXCEPTION
     WHEN no_data_found THEN
        RETURN 0;
     WHEN OTHERS THEN
        raise_application_error(-20000, 'Error al obtener monto cuota prestamos en FUG_OBT_MTO_NUE_CUOTA. ' || SQLERRM);
  END;
Else If p_cod_modulo = 5 then 
  BEGIN
     select (nvl(monto,0)*10/100)
     into v_importe
     from ta_solicitudes
     where nro_solicitud = p_nro_solicitud
     union
     select (nvl(lin_credito,0)*10/100)
     from ta_sol_lineas
     where nro_solicitud = p_nro_solicitud;
     RETURN v_importe;
  EXCEPTION
     WHEN no_data_found THEN
        RETURN 0;
     WHEN OTHERS THEN
        raise_application_error(-20000, 'Error al obtener monto cuota tarjetas en FUG_OBT_MTO_NUE_CUOTA.' || SQLERRM);
  END;
End If;  
End If;
END fug_obt_mto_nue_cuota;
/

