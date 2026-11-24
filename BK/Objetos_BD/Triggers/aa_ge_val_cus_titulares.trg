CREATE OR REPLACE TRIGGER IT.AA_GE_VAL_CUS_TITULARES
 AFTER DELETE OR UPDATE
 ON GE_VAL_CUS_TITULARES
 FOR EACH ROW


DECLARE
   r_gaudi ge_auditorias%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla          := 'GE_VAL_CUS_TITULARES';
   r_gaudi.clave          := to_char(:old.cod_val_custodia) || '#' || to_char(:old.cod_persona);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   IF updating THEN
      r_gaudi.tip_novedad := 'M';
   ELSIF deleting THEN
      r_gaudi.tip_novedad := 'E';
   END IF;

   --- Registrar Detalle
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'RELACION', :old.relacion,
                                               :new.relacion);

   --- Insertar tabla de auditoria
   prg_ins_ge_auditoria(r_gaudi);
END;
/

