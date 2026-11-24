CREATE OR REPLACE TRIGGER IT.AA_TA_CON_TRA_DIA_CAB_GP
  AFTER DELETE OR UPDATE
     ON IT.TA_CON_TRA_DIA_CAB_GP
    FOR EACH ROW
DECLARE
  r_taudi TA_AUDITORIAS%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  r_taudi.tabla := 'TA_CON_TRA_DIA_CAB_GP';
  r_taudi.clave := to_char(:old.nro_car_dia);
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_taudi.detalle := pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad, 'NRO_CAR_DIA', :old.nro_car_dia, :old.nro_car_dia);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_REGISTRO', :old.tip_registro, :new.tip_registro);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_ENTIDAD', :old.cod_entidad, :new.cod_entidad);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_ID_ARCHIVO', :old.cod_id_archivo, :new.cod_id_archivo);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DES_ARCHIVO', :old.des_archivo, :new.des_archivo);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_PROCESO', :old.fec_proceso, :new.fec_proceso);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FILLER', :old.filler, :new.filler);

  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( r_taudi );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( r_taudi );
END;
