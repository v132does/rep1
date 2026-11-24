CREATE OR REPLACE TRIGGER IT.AA_BW_CLA_VAL_TIP_OPERACION
  AFTER DELETE OR UPDATE
     ON BW_CLA_VAL_TIP_OPERACION
    FOR EACH ROW
DECLARE

  r_waudi BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  r_waudi.tabla := 'BW_CLA_VAL_TIP_OPERACION';
  r_waudi.clave := :old.cod_tip_mensaje || '#' || :old.cod_tip_clave || '#' || :old.cod_tip_cla_sec || '#' || :old.tip_persona || '#' || :old.cod_persona;
  r_waudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_waudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_waudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_waudi.detalle := pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );       
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'COD_TIP_MENSAJE', :old.cod_tip_mensaje, :new.cod_tip_mensaje );  
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'COD_TIP_CLAVE', :old.cod_tip_clave, :new.cod_tip_clave );  
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'COD_TIP_CLA_SEC', :old.cod_tip_cla_sec, :new.cod_tip_cla_sec );  
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'TIP_PERSONA', :old.tip_persona, :new.tip_persona );       
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );    
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'USU_INSERCION', :old.usu_insercion , :new.usu_insercion );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'FEC_INSERCION', :old.fec_insercion , :new.fec_insercion , 'H' );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'USU_MODIFICACION', :old.usu_modificacion , :new.usu_modificacion );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'FEC_MODIFICACION', :old.fec_modificacion , :new.fec_modificacion , 'H' ); 
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'COD_USU_AUTORIZACION', :old.cod_usu_autorizacion, :new.cod_usu_autorizacion );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'FEC_USU_AUTORIZACION', :old.fec_usu_autorizacion, :new.fec_usu_autorizacion, 'F' ); 
    
  
  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( r_waudi );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( r_waudi );
END;
/

