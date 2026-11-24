CREATE OR REPLACE TRIGGER IT.AA_BW_SOF_SERIALES
   AFTER DELETE OR UPDATE
   ON BW_SOF_SERIALES
   FOR EACH ROW
DECLARE
   r_gaudi BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'BW_SOF_SERIALES';
  r_gaudi.clave := :old.nro_serial;
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'nro_serial', :old.nro_serial, :new.nro_serial );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_DISPOSITIVO', :old.cod_dispositivo, :new.cod_dispositivo );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'CLA_ENCRIPTACION', :old.cla_encriptacion, :new.cla_encriptacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'VEC_INICIALIZACION', :old.vec_inicializacion, :new.vec_inicializacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_INSERCION', :old.fec_insercion, :new.fec_insercion, 'F' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'USU_INSERCION', :old.usu_insercion, :new.usu_insercion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_MODIFICACION', :old.fec_modificacion, :new.fec_modificacion, 'F' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'USU_MODIFICACION', :old.usu_modificacion, :new.usu_modificacion );

  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( r_gaudi );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( r_gaudi );
END;
/

