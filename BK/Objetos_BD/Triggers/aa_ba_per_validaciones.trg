CREATE OR REPLACE TRIGGER IT.AA_BA_PER_VALIDACIONES
 AFTER DELETE OR UPDATE
 ON BA_PER_VALIDACIONES
 FOR EACH ROW


DECLARE
   r_gaudi ba_auditorias%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_gaudi.tabla          := 'BA_PER_VALIDACIONES';
   r_gaudi.clave          := :old.cod_persona;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   IF updating THEN
      r_gaudi.tip_novedad := 'M';
   ELSIF deleting THEN
      r_gaudi.tip_novedad := 'E';
   END IF;

   --- Registrar Detalle
   r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'COD_USU_VER_PERSONA',
                                               :old.cod_usu_ver_persona, :new.cod_usu_ver_persona);
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'FEC_VER_PERSONA',
                                               :old.fec_ver_persona, :new.fec_ver_persona, 'F');
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'EST_DAT_PERSONA',
                                               :old.est_dat_persona, :new.est_dat_persona);
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'COD_USU_VER_LABORAL',
                                               :old.cod_usu_ver_laboral, :new.cod_usu_ver_laboral);
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'FEC_VER_LABORAL',
                                               :old.fec_ver_laboral, :new.fec_ver_laboral, 'F');
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'EST_DAT_LABORAL',
                                               :old.est_dat_laboral, :new.est_dat_laboral);
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'COD_USU_VER_INGRESO',
                                               :old.cod_usu_ver_ingreso, :new.cod_usu_ver_ingreso);
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'FEC_VER_INGRESO',
                                               :old.fec_ver_ingreso, :new.fec_ver_ingreso, 'F');
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'EST_DAT_INGRESO',
                                               :old.est_dat_ingreso, :new.est_dat_ingreso);
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'COD_USU_VER_EGRESO',
                                               :old.cod_usu_ver_egreso, :new.cod_usu_ver_egreso);
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'FEC_VER_EGRESO',
                                               :old.fec_ver_egreso, :new.fec_ver_egreso, 'F');
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'EST_DAT_EGRESO',
                                               :old.est_dat_egreso, :new.est_dat_egreso);
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'COD_USU_VER_PROPIEDAD',
                                               :old.cod_usu_ver_propiedad, :new.cod_usu_ver_propiedad);
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'FEC_VER_PROPIEDAD',
                                               :old.fec_ver_propiedad, :new.fec_ver_propiedad, 'F');
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'EST_DAT_PROPIEDAD',
                                               :old.est_dat_propiedad, :new.est_dat_propiedad);
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'COD_USU_VER_GARANTIA',
                                               :old.cod_usu_ver_garantia, :new.cod_usu_ver_garantia);
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'FEC_VER_GARANTIA',
                                               :old.fec_ver_garantia, :new.fec_ver_garantia, 'F');
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'EST_DAT_GARANTIA',
                                               :old.est_dat_garantia, :new.est_dat_garantia);
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'COD_USU_VER_GLOBAL',
                                               :old.cod_usu_ver_global, :new.cod_usu_ver_global);
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'FEC_VER_GLOBAL',
                                               :old.fec_ver_global, :new.fec_ver_global, 'F');

   --- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_gaudi);
END;
/

