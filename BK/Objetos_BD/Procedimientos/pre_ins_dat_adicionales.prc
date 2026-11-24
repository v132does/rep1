CREATE OR REPLACE PROCEDURE IT.pre_ins_dat_adicionales
(
   p_cod_persona IN ba_personas.cod_persona%TYPE,
   p_tip_accion  IN ba_personas.cod_persona%TYPE,
   p_cod_circuito  IN wf_circuitos.cod_circuito%TYPE DEFAULT NULL
) IS
   v_fec_actual    DATE := pag_cal.fu_obt_fec_actual(1);
   v_val_parametro ge_par_dinamicos.val_parametro%TYPE;
   v_novedad       VARCHAR2(1);
BEGIN
    --obtengo novedad
    BEGIN
      SELECT h.novedad
        INTO v_novedad
        FROM cr_per_tip_operaciones_his h
       WHERE h.cod_persona = p_cod_persona
         AND h.cod_circuito = p_cod_circuito
         AND h.estado = 'N';
    EXCEPTION
      WHEN OTHERS THEN
        v_novedad := NULL;
    END;
   IF p_tip_accion = 'A' THEN
      BEGIN
         --- Si no se actualizó desde el wmseguim por excepcion.
         SELECT val_parametro
           INTO v_val_parametro
           FROM ba_per_dat_adicionales
          WHERE cod_persona = p_cod_persona
            AND parametro = 'EST_VER_PERFIL'
            AND val_parametro = 'E'
            AND trunc(fec_modificacion) = to_char(v_fec_actual, 'dd/mm/yyyy');
      EXCEPTION
         WHEN no_data_found THEN
            UPDATE ba_per_dat_adicionales
               SET val_parametro = 'S'
             WHERE cod_persona = p_cod_persona
               AND parametro = 'EST_VER_PERFIL';
            IF SQL%NOTFOUND THEN
               INSERT INTO ba_per_dat_adicionales
                  (cod_persona, parametro, val_parametro)
               VALUES
                  (p_cod_persona, 'EST_VER_PERFIL', 'S');
            END IF;
            UPDATE ba_per_dat_adicionales
               SET val_parametro = to_char(v_fec_actual, 'dd/mm/yyyy')
             WHERE cod_persona = p_cod_persona
               AND parametro = 'FEC_VER_PERFIL';
            IF SQL%NOTFOUND THEN
               INSERT INTO ba_per_dat_adicionales
                  (cod_persona, parametro, val_parametro)
               VALUES
                  (p_cod_persona, 'FEC_VER_PERFIL', to_char(v_fec_actual, 'dd/mm/yyyy'));
            END IF;
            UPDATE ba_per_dat_adicionales
               SET val_parametro = USER
             WHERE cod_persona = p_cod_persona
               AND parametro = 'USU_VER_PERFIL';
            IF SQL%NOTFOUND THEN
               INSERT INTO ba_per_dat_adicionales
                  (cod_persona, parametro, val_parametro)
               VALUES
                  (p_cod_persona, 'USU_VER_PERFIL', USER);
            END IF;
      END;
      --Grabar datos en la tabla operaciones
      BEGIN    
        IF v_novedad = 'M' THEN
          UPDATE cr_per_tip_operaciones
             SET (cod_modulo,cod_modalidad,cod_moneda,mto_limite,fec_inicio,fec_vencimiento) =
                 (SELECT e.cod_modulo,e.cod_modalidad,e.cod_moneda,e.mto_limite,e.fec_inicio,e.fec_vencimiento
                    FROM cr_per_tip_operaciones_his e
                   WHERE e.cod_persona = p_cod_persona
                     AND e.estado = 'N'
                     AND e.cod_circuito = p_cod_circuito)                     
           WHERE cod_persona = p_cod_persona;
         
         ELSIF v_novedad = 'I' THEN
           INSERT INTO cr_per_tip_operaciones (cod_modulo,cod_modalidad,cod_moneda,mto_limite,fec_inicio,fec_vencimiento) 
           (SELECT e.cod_modulo,e.cod_modalidad,e.cod_moneda,e.mto_limite,e.fec_inicio,e.fec_vencimiento
                    FROM cr_per_tip_operaciones_his e
                   WHERE e.cod_persona = p_cod_persona
                     AND e.estado = 'N'
                     AND e.cod_circuito = p_cod_circuito);
         END IF;
         
         IF v_novedad IS NOT NULL THEN
            --actualizo el estado del historico
            UPDATE cr_per_tip_operaciones_his h
               SET h.estado = 'S'
             WHERE h.cod_persona = p_cod_persona
               AND h.cod_circuito = p_cod_circuito
               AND h.estado = 'N';
         END IF;
      END;
   ELSE
      UPDATE ba_per_dat_adicionales
         SET val_parametro = 'R'
       WHERE cod_persona = p_cod_persona
         AND parametro = 'EST_VER_PERFIL';
      IF SQL%NOTFOUND THEN
         INSERT INTO ba_per_dat_adicionales
            (cod_persona, parametro, val_parametro)
         VALUES
            (p_cod_persona, 'EST_VER_PERFIL', 'R');
      END IF;
      UPDATE ba_per_dat_adicionales
         SET val_parametro = to_char(v_fec_actual, 'dd/mm/yyyy')
       WHERE cod_persona = p_cod_persona
         AND parametro = 'FEC_VER_PERFIL';
      IF SQL%NOTFOUND THEN
         INSERT INTO ba_per_dat_adicionales
            (cod_persona, parametro, val_parametro)
         VALUES
            (p_cod_persona, 'FEC_VER_PERFIL', to_char(v_fec_actual, 'dd/mm/yyyy'));
      END IF;
      UPDATE ba_per_dat_adicionales
         SET val_parametro = USER
       WHERE cod_persona = p_cod_persona
         AND parametro = 'USU_VER_PERFIL';
      IF SQL%NOTFOUND THEN
         INSERT INTO ba_per_dat_adicionales
            (cod_persona, parametro, val_parametro)
         VALUES
            (p_cod_persona, 'USU_VER_PERFIL', USER);
      END IF;
      IF v_novedad IS NOT NULL THEN
        --actualizo el estado del historico
        UPDATE cr_per_tip_operaciones_his h
           SET h.estado = 'R'
         WHERE h.cod_persona = p_cod_persona
           AND h.cod_circuito = p_cod_circuito
           AND h.estado = 'N';
       END IF;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      NULL;
END;
/
