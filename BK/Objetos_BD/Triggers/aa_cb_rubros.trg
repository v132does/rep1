CREATE OR REPLACE TRIGGER IT.AA_CB_RUBROS
 AFTER DELETE OR UPDATE
 ON CB_RUBROS
 FOR EACH ROW


DECLARE
   r_baudi cb_auditorias%ROWTYPE; -- Registro de la tabla CB_AUDITORIAS
BEGIN
   r_baudi.tabla          := 'CB_RUBROS';
   r_baudi.clave          := :old.cod_rubro;
   r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   IF updating THEN
      r_baudi.tip_novedad := 'M';
   ELSIF deleting THEN
      r_baudi.tip_novedad := 'E';
   END IF;

   --- Registrar Detalle
   r_baudi.detalle := pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'DESCRIPCION', :old.descripcion,
                                               :new.descripcion);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda,
                                               :new.cod_moneda);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'COD_RUB_PADRE',
                                               :old.cod_rub_padre, :new.cod_rub_padre);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'ABREVIATURA', :old.abreviatura,
                                               :new.abreviatura);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'TIPO', :old.tipo, :new.tipo);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'NIVEL', :old.nivel, :new.nivel,
                                               'N');
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'NATURALEZA', :old.naturaleza,
                                               :new.naturaleza);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'DEDUCIBLE', :old.deducible,
                                               :new.deducible);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'IMPUTABLE', :old.imputable,
                                               :new.imputable);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'AJUSTABLE', :old.ajustable,
                                               :new.ajustable);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'ULT_NRO_MAYOR',
                                               :old.ult_nro_mayor, :new.ult_nro_mayor, 'N');
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'FEC_INICIO', :old.fec_inicio,
                                               :new.fec_inicio, 'F');
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'FEC_FIN', :old.fec_fin,
                                               :new.fec_fin, 'F');
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'COD_RUB_EXTERNO',
                                               :old.cod_rub_externo, :new.cod_rub_externo);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'COD_CONSOLIDACION',
                                               :old.cod_consolidacion, :new.cod_consolidacion);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'COD_GESTION', :old.cod_gestion,
                                               :new.cod_gestion);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'NRO_GRU_RUBRO',
                                               :old.nro_gru_rubro, :new.nro_gru_rubro, 'N');
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'TRANSITORIO', :old.transitorio,
                                               :new.transitorio);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'PLZ_MAXIMO', :old.plz_maximo,
                                               :new.plz_maximo, 'N');
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'AUTOMATICO', :old.automatico,
                                               :new.automatico);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'AFE_NATURALEZA',
                                               :old.afe_naturaleza, :new.afe_naturaleza);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'COD_AREA',
                                               :old.cod_area, :new.cod_area, 'N');

   --- Insertar tabla de auditoria
   prb_ins_cb_auditoria(r_baudi);
EXCEPTION
   WHEN OTHERS THEN
      prb_ins_cb_auditoria(r_baudi);
END;
/

