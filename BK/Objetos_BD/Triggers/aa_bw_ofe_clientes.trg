CREATE OR REPLACE TRIGGER IT.AA_BW_OFE_CLIENTES
  AFTER DELETE OR UPDATE
     ON BW_OFE_CLIENTES
    FOR EACH ROW
DECLARE
 
  r_gaudi BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'BW_OFE_CLIENTES';
  r_gaudi.clave := :old.cod_persona||'#'||:old.producto;
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'CANTIDAD', :old.cantidad, :new.cantidad );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'INICIO', :old.inicio, :new.inicio );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'MENSAJE', :old.mensaje, :new.mensaje );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_INICIO', :old.fec_inicio, :new.fec_inicio, 'F' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_FIN', :old.fec_fin, :new.fec_fin, 'F' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'URL_IMAGEN', :old.url_imagen, :new.url_imagen );
 
  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( r_gaudi );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( r_gaudi );
END;
/

