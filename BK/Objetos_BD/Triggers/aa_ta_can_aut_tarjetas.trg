CREATE OR REPLACE TRIGGER IT.AA_TA_CAN_AUT_TARJETAS
  AFTER DELETE OR UPDATE
     ON TA_CAN_AUT_TARJETAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 02/05/2014 a las 18:41:00 Hs.
  */
  v_registro TA_AUDITORIAS%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  v_registro.tabla := 'TA_CAN_AUT_TARJETAS';
  v_registro.clave := to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS') || '#' || :old.nro_cuenta;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DET_ERROR', :old.det_error, :new.det_error );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'HORA', :old.hora, :new.hora );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_TRA_PADRE', :old.cod_tra_padre, :new.cod_tra_padre, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MOD_PADRE', :old.cod_mod_padre, :new.cod_mod_padre, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MAD_PADRE', :old.cod_mad_padre, :new.cod_mad_padre, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'USU_ANULACION', :old.usu_anulacion, :new.usu_anulacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_ANULACION', :old.fec_anulacion, :new.fec_anulacion, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IND_MOV_ESPECIALES', :old.ind_mov_especiales, :new.ind_mov_especiales );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IND_NOV_EXONERACION', :old.ind_nov_exoneracion, :new.ind_nov_exoneracion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EST_ANTERIOR', :old.est_anterior, :new.est_anterior );

  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( v_registro );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( v_registro );
END;
/

