CREATE OR REPLACE FUNCTION IT.FUX_VAL_CCE_PRESTAMO
 (P_NRO_SOLICITUD IN CX_CTA_EXPORTACIONES.NRO_SOL_PRESTAMO%TYPE,
  P_FEC_VTO IN CX_CTA_EXPORTACIONES.FEC_VENCIMIENTO%TYPE,
  P_MONTO IN CX_CTA_EXPORTACIONES.SALDO%TYPE)
 RETURN VARCHAR2
 IS
v_res VARCHAR2(1):='N';
v_fec_vto date;
v_saldo number;
  --Verifica si la Propuesta de Préstamo coincide con valores de la CCE
  begin
    select 'S', fec_vencimiento, saldo
      into v_res, v_fec_vto, v_saldo
      from CX_CTA_EXPORTACIONES
     where nro_sol_prestamo = p_nro_solicitud;
     
    if v_fec_vto <> p_fec_vto or v_saldo <> p_monto then
       v_res := 'N';
    end if;

    return v_res;
  exception
     when no_data_found then -- no corresponde a una CCE
         return null;
     when others then
        raise_application_error(-20000,'Verif.CCE. '||sqlerrm);
  end;
/

