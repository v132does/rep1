CREATE OR REPLACE TRIGGER IT.ta_bw_otp_ref_medios
   AFTER UPDATE ON bw_otp_ref_medios
   FOR EACH ROW
DECLARE
   v_resultado         VARCHAR2(1) DEFAULT 0;
   v_estado            bw_otp_seriales.estado%TYPE;
   v_tipo              bw_otp_seriales.tipo%TYPE;
   v_cod_persona       bw_otp_seriales.cod_persona%TYPE;
   v_cod_per_vinculada bw_otp_seriales.cod_per_vinculada%TYPE;
BEGIN
   IF updating THEN
      IF :new.ref_medio <> :old.ref_medio AND :old.tipo = 'C' THEN
         SELECT a.estado, a.tipo, a.cod_persona, a.cod_per_vinculada
           INTO v_estado, v_tipo, v_cod_persona, v_cod_per_vinculada
           FROM bw_otp_seriales a
          WHERE a.nro_serial = :new.nro_serial;
         IF v_estado = 'A' AND v_tipo = 'V' THEN
            -- Elimina tareas del Workflow según Nro. de Serial del Token.
            paw_otp.pr_eli_tareas(:new.nro_serial);
            -- Actualiza el estado de la clave OTP a Entregado.
            v_resultado := paw_otp.fu_act_estado(v_cod_persona, v_cod_per_vinculada, v_tipo,
                                                 :new.nro_serial, 'N');
            IF v_resultado <> 0 THEN
               raise_application_error(-20000,
                                       ' No se ha podido actualizar el estado de token. - ' ||
                                        SQLERRM);
            END IF;
         END IF;
      END IF;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20001, ' en TA_BW_OTP_REF_MEDIOS ' || SQLERRM);
END;
/

