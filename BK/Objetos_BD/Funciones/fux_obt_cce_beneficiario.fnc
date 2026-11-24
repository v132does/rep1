CREATE OR REPLACE FUNCTION IT.FUX_OBT_CCE_BENEFICIARIO
(P_NRO_SOLICITUD IN CX_CTA_EXPORTACIONES.NRO_SOL_PRESTAMO%TYPE,
 P_NRO_CUENTA IN CX_CTA_EXPORTACIONES.NRO_CTA_PRESTAMO%TYPE default null)
 RETURN VARCHAR2
 IS
 v_cod_per_beneficiario CX_CTA_EXPORTACIONES.nro_cta_prestamo%type;
BEGIN 
   --Obtiene el código del beneficiario de la CCE.
   BEGIN
      SELECT  cod_per_beneficiario
        INTO  v_cod_per_beneficiario
        FROM  cx_cta_exportaciones
       WHERE (nro_sol_prestamo = p_nro_solicitud
          OR  nro_cta_prestamo = p_nro_cuenta);
   EXCEPTION
      WHEN no_data_found THEN
         IF p_nro_cuenta IS NULL AND p_nro_solicitud IS NOT NULL THEN -- BBVASOP-1541
            BEGIN
               SELECT cod_per_beneficiario
                 INTO v_cod_per_beneficiario
                 FROM cx_cta_exportaciones e, cx_cuotas c
                WHERE e.nro_cuenta = c.nro_cuenta
                  AND c.nro_sol_prestamo = p_nro_solicitud;
            EXCEPTION
               WHEN no_data_found THEN      
                  RETURN NULL;
               WHEN OTHERS THEN
                  raise_application_error(-20001,'Recup. Beneficiario CCE. '||sqlerrm);   
            END;      
         ELSE
            RETURN NULL;
         END IF;
      WHEN OTHERS THEN
         raise_application_error(-20000,'Recup. Beneficiario CCE. '||sqlerrm);
   END;
   RETURN v_cod_per_beneficiario;
END;
/

