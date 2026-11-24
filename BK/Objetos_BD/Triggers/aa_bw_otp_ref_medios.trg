CREATE OR REPLACE TRIGGER IT.aa_bw_otp_ref_medios
   AFTER DELETE OR UPDATE ON bw_otp_ref_medios
   FOR EACH ROW
DECLARE
   r_waudi bw_auditorias%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
   r_waudi.tabla          := 'BW_OTP_REF_MEDIOS';
   r_waudi.clave          := :old.nro_serial || '#' || :old.cod_persona || '#' || :old.ref_medio;
   r_waudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   IF updating THEN
      r_waudi.tip_novedad := 'M';
   ELSIF deleting THEN
      r_waudi.tip_novedad := 'E';
   END IF;

   -- Registrar Detalle
   r_waudi.detalle := pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'TIPO', :old.tipo, :new.tipo);

   -- Insertar tabla de auditoria
   prw_ins_bw_auditoria(r_waudi);
EXCEPTION
   WHEN OTHERS THEN
      prw_ins_bw_auditoria(r_waudi);
END;
/

