CREATE OR REPLACE FUNCTION IT.FUX_OBT_CCE_PRESTAMO
 (P_NRO_SOLICITUD IN CX_CTA_EXPORTACIONES.NRO_SOL_PRESTAMO%TYPE)
 RETURN VARCHAR2
 IS
v_nro_CCE CX_CTA_EXPORTACIONES.nro_cta_prestamo%type;
Begin
  --Obtiene la CCE de la solicitud o préstamo
  begin
    select nro_cuenta
      into v_nro_CCE
      from CX_CTA_EXPORTACIONES
     where nro_sol_prestamo = p_nro_solicitud;
  exception
     when no_data_found then
         return null;
     when others then
        raise_application_error(-20000,'Recup.CCE. '||sqlerrm);
  end;
  return v_nro_CCE;
exception
   when no_data_found then
      return null;
   when others then
      raise_application_error(-20000,'Recup.CCE. '||sqlerrm);
End;
/

