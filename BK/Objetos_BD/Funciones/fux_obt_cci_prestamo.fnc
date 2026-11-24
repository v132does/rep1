CREATE OR REPLACE FUNCTION IT.FUX_OBT_CCI_PRESTAMO
 (P_NRO_SOLICITUD IN CX_CTA_IMPORTACIONES.NRO_SOL_PRESTAMO%TYPE)
 RETURN VARCHAR2
 IS
v_nro_cci cx_cta_importaciones.nro_cuenta%type;
Begin
  --Obtiene la cci de la solicitud o préstamo
  begin
    select nro_cuenta
      into v_nro_cci
      from cx_cta_importaciones
     where nro_sol_prestamo = p_nro_solicitud;
  exception
     when no_data_found then
        --si no encuentra en cci busca en las cuotas
        select nro_cuenta
          into v_nro_cci
          from cx_cuotas
         where nro_sol_prestamo = p_nro_solicitud;
     when others then
        raise_application_error(-20000,'Recup.CCI. '||sqlerrm);
  end;
  return v_nro_cci;
exception
   when no_data_found then
      return null;
   when others then
      raise_application_error(-20000,'Recup.CCI. '||sqlerrm);
End;
/

