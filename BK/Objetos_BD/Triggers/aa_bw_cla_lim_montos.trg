CREATE OR REPLACE TRIGGER IT."AA_BW_CLA_LIM_MONTOS"
  AFTER DELETE OR UPDATE
     ON BW_CLA_LIM_MONTOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 10/04/2012 a las 14:24:40 Hs.
  */
  r_waudi BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  r_waudi.tabla := 'BW_CLA_LIM_MONTOS';
  r_waudi.clave := :old.cod_tip_mensaje || '#' || :old.cod_tip_clave || '#' || :old.tip_persona || '#' || :old.cod_moneda || '#' || :old.cod_persona || '#' || :old.nro_cuenta;
  r_waudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_waudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_waudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_waudi.detalle := pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'ACTIVO', :old.activo, :new.activo );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'MTO_MINIMO', :old.mto_minimo, :new.mto_minimo, 'M' );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'MTO_MAXIMO', :old.mto_maximo, :new.mto_maximo, 'M' );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'MTO_MAX_PERSONALIZACION', :old.mto_max_personalizacion, :new.mto_max_personalizacion, 'M' );	
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'COD_USU_AUTORIZACION', :old.cod_usu_autorizacion, :new.cod_usu_autorizacion );	       
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );                 -- DYDMR-987 CRO-JM-12/2014:
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'TIP_PERSONA', :old.tip_persona, :new.tip_persona );              -- DYDMR-987 CRO-JM-12/2014:
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'COD_TIP_MENSAJE', :old.cod_tip_mensaje, :new.cod_tip_mensaje );  -- DYDMR-987 CRO-JM-12/2014:
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'COD_TIP_CLAVE', :old.cod_tip_clave, :new.cod_tip_clave );			-- DYDMR-987 CRO-JM-12/2014:
    
	
  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( r_waudi );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( r_waudi );
END;
/

