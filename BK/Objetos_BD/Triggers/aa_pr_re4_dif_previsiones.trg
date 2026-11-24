CREATE OR REPLACE TRIGGER IT.AA_PR_RE4_DIF_PREVISIONES
  AFTER DELETE OR UPDATE
     ON PR_RE4_DIF_PREVISIONES
    FOR EACH ROW
DECLARE
  r_paudi PR_AUDITORIAS%ROWTYPE; -- Registro de la tabla PR_AUDITORIAS
BEGIN
  r_paudi.tabla := 'PR_RE4_DIF_PREVISIONES';
  r_paudi.clave := to_char( :old.nro_cuenta);
  r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_paudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_paudi.tip_novedad := 'E';
  END IF;

  --- Registrar Detalle
	  r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'cod_persona', :old.cod_persona, :new.cod_persona);
    r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'nro_cuenta', :old.nro_cuenta, :new.nro_cuenta);    
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'mto_capital', :old.mto_capital, :new.mto_capital, 'M');
    
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'fec_ini_cta_nueva', :old.fec_ini_cta_nueva, :new.fec_ini_cta_nueva, 'F');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'fec_actualizacion', :old.fec_actualizacion, :new.fec_actualizacion, 'F');

	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'dia_atraso', :old.dia_atraso, :new.dia_atraso, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'can_mes_diferimiento', :old.can_mes_diferimiento, :new.can_mes_diferimiento, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'can_mes_diferido', :old.can_mes_diferido, :new.can_mes_diferido, 'N');

	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'mto_prevision', :old.mto_prevision, :new.mto_prevision, 'M');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'mto_pre_mon_original', :old.mto_pre_mon_original, :new.mto_pre_mon_original, 'M');

	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'mto_pre_diferido', :old.mto_pre_diferido, :new.mto_pre_diferido, 'M');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'mto_pre_dif_acumulado', :old.mto_pre_dif_acumulado, :new.mto_pre_dif_acumulado, 'M');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'por_pre_cta_madre', :old.por_pre_cta_madre, :new.por_pre_cta_madre, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'POR_PRE_CTA_HIJO', :old.POR_PRE_CTA_HIJO, :new.POR_PRE_CTA_HIJO, 'N');

	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'cat_aut_cta_madre', :old.cat_aut_cta_madre, :new.cat_aut_cta_madre, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'cat_ren_cta_madre', :old.cat_ren_cta_madre, :new.cat_ren_cta_madre, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'cat_ren_cta_hijo', :old.cat_ren_cta_hijo, :new.cat_ren_cta_hijo, 'N');

	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'cotizacion', :old.cotizacion, :new.cotizacion, 'N');
    r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'cod_mon_cta_madre', :old.cod_mon_cta_madre, :new.cod_mon_cta_madre);    
    r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'cod_mon_cta_hijo', :old.cod_mon_cta_hijo, :new.cod_mon_cta_hijo);    


	  --- Insertar tabla de auditoria
	  prp_ins_pr_auditoria(r_paudi);
EXCEPTION
   WHEN OTHERS THEN
	   prp_ins_pr_auditoria(r_paudi); -- para insertar hasta donde puede
END;
/

