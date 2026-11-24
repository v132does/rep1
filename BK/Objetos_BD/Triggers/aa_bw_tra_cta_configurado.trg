CREATE OR REPLACE TRIGGER IT.AA_BW_TRA_CTA_CONFIGURADO
  AFTER DELETE OR UPDATE
     ON BW_TRA_CTA_CONFIGURADO
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 05/11/2018 a las 15:28:26 Hs.
  */
  r_gaudi AF_AUDITORIAS%ROWTYPE; -- Registro de la tabla AF_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'BW_TRA_CTA_CONFIGURADO';
  r_gaudi.clave := :old.cod_persona;
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta );
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'USU_INSERCION', :old.usu_insercion, :new.usu_insercion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_INSERCION', :old.fec_insercion, :new.fec_insercion, 'F' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'USU_MODIFICACION', :old.usu_modificacion, :new.usu_modificacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_MODIFICACION', :old.fec_modificacion, :new.fec_modificacion, 'F' );

  -- Insertar tabla de auditoria
  prf_ins_af_auditoria( r_gaudi );
EXCEPTION
  when others then
    prf_ins_af_auditoria( r_gaudi );
END;
/

