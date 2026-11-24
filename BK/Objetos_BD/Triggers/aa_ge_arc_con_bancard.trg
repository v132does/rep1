CREATE OR REPLACE TRIGGER IT.AA_GE_ARC_CON_BANCARD
  AFTER DELETE OR UPDATE
     ON GE_ARC_CON_BANCARD
    FOR EACH ROW
DECLARE
  r_gaudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'GE_ARC_CON_BANCARD';
  r_gaudi.clave := to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS') || '#' || :old.hora || '#' || :old.cod_usuario || '#' || to_char( :old.nro_secuencia) || '#' || to_char( :old.nro_lote) || '#' || to_char( :old.nro_registro);
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  --------- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_DOCUMENTO', :old.nro_documento, :new.nro_documento, 'N' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_DOCUMENTO3', :old.nro_documento3, :new.nro_documento3, 'N' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'ENVIADO', :old.enviado, :new.enviado );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'REGISTRO', :old.registro, :new.registro );

  --- Insertar tabla de auditoria
  prg_ins_ge_auditoria( r_gaudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( r_gaudi );
END;
/

