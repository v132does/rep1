CREATE OR REPLACE FUNCTION IT.fuc_ver_per_pendiente(p_cod_persona VARCHAR2) RETURN BOOLEAN IS
   v_estado           ba_personas.est_verificacion%TYPE;
   v_cod_tip_circuito wf_circuitos.cod_tip_circuito%TYPE := fug_obt_pardinamico('COD_TIP_CIR_PERFIL');

BEGIN
   BEGIN
      SELECT DISTINCT estado
        INTO v_estado
        FROM wf_circuitos e
       WHERE e.cod_persona = p_cod_persona
         AND e.cod_tip_circuito = v_cod_tip_circuito
         AND estado = 'E'
         AND e.fec_inicio IN (SELECT MAX(fec_inicio)
                                FROM wf_circuitos s
                               WHERE s.cod_persona = e.cod_persona
                                 AND estado = 'E'
                                 AND s.cod_tip_circuito = v_cod_tip_circuito);
      RETURN TRUE;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN FALSE;
      WHEN too_many_rows THEN
         RETURN TRUE;
      WHEN OTHERS THEN
         RETURN FALSE;
   END;
END;
/

