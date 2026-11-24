CREATE OR REPLACE TRIGGER IT.AA_TA_LIN_PRE_APROBADO
  AFTER DELETE OR UPDATE
     ON it.TA_LIN_PRE_APROBADO
    FOR EACH ROW
DECLARE
  r_taudi TA_AUDITORIAS%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  r_taudi.tabla := 'TA_LIN_PRE_APROBADO';
  r_taudi.clave := :old.cod_pre_aprobado || '#' || :old.cod_persona;
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_taudi.detalle := pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_PRE_APROBADO', :old.COD_PRE_APROBADO, :new.COD_PRE_APROBADO );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_PRE_APROBADO', :old.cod_pre_aprobado, :new.cod_pre_aprobado );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_PLA_PRE_APROBADO', :old.cod_pla_pre_aprobado, :new.cod_pla_pre_aprobado);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_INI_OFERTA', :old.fec_ini_oferta, :new.fec_ini_oferta);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_FIN_OFERTA', :old.fec_fin_oferta, :new.fec_fin_oferta);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_USU_OFICIAL', :old.cod_usu_oficial, :new.cod_usu_oficial );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MON_LIN_PRE_APROBADO', :old.mon_lin_pre_aprobado, :new.mon_lin_pre_aprobado );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MON_LIN_SOLICITADA', :old.mon_lin_solicitada, :new.mon_lin_solicitada);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_RUB_ECONOMICO', :old.cod_rub_economico, :new.cod_rub_economico );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_SOLICITUD', :old.nro_solicitud, :new.nro_solicitud );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MOT_ESTADO', :old.mot_estado, :new.mot_estado );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CAN_VISITAS', :old.can_visitas, :new.can_visitas );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_CANAL', :old.cod_canal, :new.cod_canal );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );

  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( r_taudi );
EXCEPTION
  when others then
    dbms_output.put_line('Error: ' || sqlerrm);
    prt_ins_ta_auditoria( r_taudi );
END;
/

