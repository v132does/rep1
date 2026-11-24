CREATE OR REPLACE FUNCTION IT.FUG_GEN_ACC_CLAVE
(
   p_cod_persona IN VARCHAR2,
   p_estado      IN VARCHAR2,
   p_cod_perfil  IN VARCHAR2 DEFAULT NULL,
   p_clave       OUT VARCHAR2
) RETURN VARCHAR2 IS
   v_cla_gen VARCHAR2(10);
   v_clave   ge_clientes.clave%TYPE;
   error EXCEPTION;
BEGIN
   IF fue_val_vin_empresa(p_cod_persona) = 'S' OR
      (fue_val_vin_empresa(p_cod_persona) = 'N' AND fug_es_cliente(p_cod_persona) = 'S') THEN
      v_cla_gen := rpad(to_char(fue_obt_num_aleatorio), 9, '0');
      --v_clave   := pag_gen.fu_enc_pin(v_cla_gen);     
      v_clave := paw_bce.fu_enc_md5(v_cla_gen);
      UPDATE ge_clientes
         SET est_clave     = p_estado,
             fec_est_clave = sysdate,--pag_cal.fu_obt_fec_actual(1),
             can_intentos  = 0,
             clave         = v_clave,
             cod_perfil    = p_cod_perfil,
						 fec_ult_acceso = null
       WHERE cod_persona = p_cod_persona;
      IF SQL%NOTFOUND THEN
         RAISE error;
      END IF;
      INSERT INTO bw_cla_acciones
         (cod_persona, accion, tip_clave)
      VALUES
         (p_cod_persona, 'C', 'A');
      p_clave := v_cla_gen;
      RETURN 'S';
   ELSE
      raise_application_error(-20000, 'Persona no es Cliente o no posee Cuenta.');
   END IF;
EXCEPTION
   WHEN error THEN
      RETURN 'N';
   WHEN OTHERS THEN
      IF SQLCODE <= -20000 THEN
         RAISE;
      ELSE
         raise_application_error(-20000, 'Error en FUG_GEN_ACC_CLAVE. ' || SQLERRM);
      END IF;
END;
/

