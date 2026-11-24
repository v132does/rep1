CREATE OR REPLACE TRIGGER IT.aa_cr_per_tip_operaciones
   AFTER DELETE OR UPDATE ON cr_per_tip_operaciones
   FOR EACH ROW

DECLARE
   r_raudi cr_auditorias%ROWTYPE; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla          := 'CR_PER_TIP_OPERACIONES';
   r_raudi.clave          := :old.cod_persona || '#' || to_char(:old.cod_modulo) || '#' || to_char (:old.cod_modalidad);
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   IF updating THEN
      r_raudi.tip_novedad := 'M';
   ELSIF deleting THEN
      r_raudi.tip_novedad := 'E';
   END IF;

   --- Registrar Detalle
   r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona);
   r_raudi.detalle := r_raudi.detalle || pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N');
   r_raudi.detalle := r_raudi.detalle || pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N');

   --- Insertar tabla de auditoria
   prr_ins_cr_auditoria(r_raudi);
END;
/

