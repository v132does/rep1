CREATE OR REPLACE FUNCTION IT.fuc_ver_per_persona
(
   p_cod_persona VARCHAR2,
   p_accion      VARCHAR2 DEFAULT NULL
) RETURN VARCHAR2 IS
   v_resultado        VARCHAR2(250);
   v_estado           ba_personas.est_verificacion%type;
   v_fec_verificacion ba_personas.fec_verificacion%TYPE;
   v_fec_actual       DATE := pag_cal.fu_obt_fec_actual(1);
   v_cod_error        NUMBER := 0;
   v_cod_tip_circuito wf_circuitos.cod_tip_circuito%TYPE := fug_obt_pardinamico('COD_TIP_CIR_PERFIL');
   v_vigencia         ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('VIG_VER_PER_APERTURA'), 0);

   --
   v_cod_cir_perfil_pep wf_circuitos.cod_tip_circuito%TYPE := fug_obt_pardinamico('COD_CIR_PERFIL_PEP'); 
   v_usu_cumplimiento VARCHAR2(1) := fug_val_usu_roles(USER,'COD_ROL_PER_PERFIL');
BEGIN
   IF NVL(v_usu_cumplimiento,'N') = 'N' THEN
 -- Paso el codigo parametrizado para nuevo circuito
   IF UPPER(p_accion) = 'P' THEN
     v_cod_tip_circuito := v_cod_cir_perfil_pep;     
   END IF ;
   
   BEGIN
      SELECT DISTINCT estado
        INTO v_estado
        FROM wf_circuitos e
       WHERE e.cod_persona = p_cod_persona
         AND e.cod_tip_circuito = v_cod_tip_circuito
         AND e.fec_inicio IN (SELECT MAX(fec_inicio)
                                FROM wf_circuitos s
                               WHERE s.cod_persona = e.cod_persona
                                 AND s.cod_tip_circuito = v_cod_tip_circuito);
   EXCEPTION
      WHEN no_data_found THEN
         v_estado := NULL;
      WHEN too_many_rows THEN
         v_estado := NULL;
      WHEN OTHERS THEN
         v_estado := NULL;
   END;
   v_fec_verificacion := fue_per_dat_adicional(p_cod_persona, 'FEC_VER_PERFIL');
       IF v_estado = 'F' THEN
          if v_fec_verificacion is null then
            v_cod_error := paw_cir.fu_ini_circuito(v_cod_tip_circuito, p_cod_persona, p_cod_persona);
             UPDATE ba_per_dat_adicionales
                SET val_parametro = 'N'
              WHERE cod_persona = p_cod_persona
                AND parametro = 'EST_VER_PERFIL';
             v_resultado := 'Debe realizarse la Verificacion del Perfil de la Persona.';
          else
            IF (v_fec_actual > (v_fec_verificacion + v_vigencia))  OR
               p_accion = 'M'  OR p_accion = 'P' THEN
               v_cod_error := paw_cir.fu_ini_circuito(v_cod_tip_circuito, p_cod_persona, p_cod_persona);
               UPDATE ba_per_dat_adicionales
                  SET val_parametro = 'N'
                WHERE cod_persona = p_cod_persona
                  AND parametro = 'EST_VER_PERFIL';
               v_resultado := 'Debe realizarse la Verificacion del Perfil de la Persona.';
            ELSE
               v_resultado := 'S';
            END IF;
          end if;
       ELSIF v_estado IS NULL OR v_estado = 'C' THEN
         if v_fec_verificacion is null then
           v_cod_error := paw_cir.fu_ini_circuito(v_cod_tip_circuito, p_cod_persona, p_cod_persona);
             UPDATE ba_per_dat_adicionales
                SET val_parametro = 'N'
              WHERE cod_persona = p_cod_persona
                AND parametro = 'EST_VER_PERFIL';
             v_resultado := 'Debe realizarse la Verificacion del Perfil de la Persona.';
         else
           IF (v_fec_actual > (v_fec_verificacion + v_vigencia))  OR
               p_accion = 'M'  OR p_accion = 'P' THEN
            v_cod_error := paw_cir.fu_ini_circuito(v_cod_tip_circuito, p_cod_persona, p_cod_persona);
            UPDATE ba_per_dat_adicionales
               SET val_parametro = 'N'
             WHERE cod_persona = p_cod_persona
               AND parametro = 'EST_VER_PERFIL';
            v_resultado := 'Se ha generado Workflow para Aprobacion de Perfil.';
           ELSE
              v_resultado := 'S';
           END IF;
         end if;
       ELSE
          v_resultado := 'Debe realizarse la Verificacion del Perfil de la Persona.';
       END IF;
   END IF;
   RETURN v_resultado;
END;
/
