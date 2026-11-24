CREATE OR REPLACE PROCEDURE IT.PRG_RCH_SOLICITUDES (P_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE,
                                                 P_COD_MODULO    IN PR_SOLICITUDES.COD_MODULO%TYPE) is
  
   v_cod_cau_sistema ge_causales.cod_causa%type := fug_obt_pardinamico('SCO_MUL_CAU_RECHAZO', p_cod_modulo);
   v_observacion     ta_solicitudes.observacion%type;
  
BEGIN
   v_observacion := '* ' || USER || '-' || to_char(pag_cal.fu_obt_fec_actual(p_cod_modulo), 'DD/MM/YYYY' ) || ' => ' || 'Rechazado Automáticamente (scoring multiproducto).';
   IF p_cod_modulo = 5 THEN
      BEGIN
         UPDATE ta_solicitudes
            SET cod_estado    = 'RCH',
                cod_causa     = v_cod_cau_sistema,
                observacion   = v_observacion
          WHERE nro_solicitud = p_nro_solicitud;
          IF sql%notfound THEN
             UPDATE ta_sol_lineas
                SET cod_estado    = 'RCH',
                    cod_causa     = v_cod_cau_sistema,
                    observacion   = v_observacion
              WHERE nro_solicitud = p_nro_solicitud;
          END IF;
      EXCEPTION
         WHEN others THEN
            null;
      END;
   ELSIF p_cod_modulo = 6 THEN
      BEGIN
         UPDATE pr_solicitudes
            SET estado        = 'R',
                cod_causa     = v_cod_cau_sistema,
                observaciones = v_observacion
          WHERE nro_solicitud = p_nro_solicitud;
      EXCEPTION
         WHEN others THEN
            null;
      END;
   END IF;
   
END PRG_RCH_SOLICITUDES;
/

