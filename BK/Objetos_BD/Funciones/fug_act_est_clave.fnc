CREATE OR REPLACE FUNCTION IT.FUG_ACT_EST_CLAVE
(
   p_cod_persona       bw_ope_claves.cod_persona%TYPE,
   p_cod_per_vinculada bw_ope_claves.cod_per_vinculada%TYPE,
   p_tipo              VARCHAR2
) RETURN BOOLEAN IS
   v_actualizo  BOOLEAN;
   v_fec_actual DATE := sysdate;--pag_cal.fu_obt_fec_actual(1);
   --p_tipo Tipo Clave. Valores: (T/Transaccional, A/Acceso)
BEGIN
   -- actualizar el valor del estado de la clave a IMPRESA.
   BEGIN
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
   END;
   v_actualizo := TRUE;
   IF p_tipo = 'T' THEN
      -- Se le llama desde el report GLCLAOPE
      IF p_cod_per_vinculada IS NULL THEN
         UPDATE bw_ope_claves
            SET est_clave         = 'I',
                fec_est_clave     = v_fec_actual,
                cla_impresa       = NULL,
                usu_impresion     = USER,
                fec_impresion     = v_fec_actual,
                cod_ofi_impresion = fug_obt_ofi_usuario(USER)
          WHERE cod_persona = p_cod_persona
            AND cod_per_vinculada IS NULL;
      ELSE
         UPDATE bw_ope_claves
            SET est_clave         = 'I',
                fec_est_clave     = v_fec_actual,
                cla_impresa       = NULL,
                usu_impresion     = USER,
                fec_impresion     = v_fec_actual,
                cod_ofi_impresion = fug_obt_ofi_usuario(USER)
          WHERE cod_persona = p_cod_persona
            AND cod_per_vinculada = p_cod_per_vinculada;
      END IF;
      IF SQL%NOTFOUND THEN
         v_actualizo := FALSE;
      END IF;
   ELSIF p_tipo = 'A' THEN
      -- Se le llama desde el report GLCLAVE
      UPDATE ge_clientes
         SET est_clave         = 'I',
             fec_est_clave     = v_fec_actual,
             usu_imp_clave     = USER,
             fec_imp_clave     = v_fec_actual,
             cod_ofi_imp_clave = fug_obt_ofi_usuario(USER),
						 fec_ult_acceso = null
       WHERE cod_persona = p_cod_persona;
      IF SQL%NOTFOUND THEN
         v_actualizo := FALSE;
      END IF;
   ELSE
      v_actualizo := FALSE;
   END IF;
   IF v_actualizo THEN
      COMMIT;
   ELSE
      ROLLBACK;
   END IF;
   RETURN(v_actualizo);
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error en FUG_ACT_EST_CLAVE. ' || SQLERRM);
END;
/

