CREATE OR REPLACE TRIGGER IT.AA_GE_SNP_MENSAJES
  AFTER DELETE OR UPDATE
     ON IT.GE_SNP_MENSAJES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 02/11/2012 a las 17:29:10 Hs.
  */
  r_gaudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'GE_SNP_MENSAJES';
  r_gaudi.clave := :old.nro_referencia || '#' || :old.nro_ref_externa || '#' || :old.cod_msj_swift || '#' || to_char( :old.fec_valor, 'DD/MM/YYYY HH24:MI:SS');
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_REFERENCIA', :old.nro_referencia, :new.nro_referencia );  
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_REF_EXTERNA', :old.nro_ref_externa, :new.nro_ref_externa );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_MSJ_SWIFT', :old.cod_msj_swift, :new.cod_msj_swift );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'MSJ_SWIFT', :old.MSJ_SWIFT, :new.MSJ_SWIFT );   
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_MONEDA', :old.COD_MONEDA, :new.COD_MONEDA );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'ERROR', :old.error, :new.error );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_VALOR', :old.fec_valor, :new.fec_valor );   
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_RECEPCION', :old.fec_recepcion, :new.fec_recepcion, 'F' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'SITUACION', :old.situacion, :new.situacion);  
  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( r_gaudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( r_gaudi );
END;
/

