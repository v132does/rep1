CREATE OR REPLACE TRIGGER IT.AA_BW_PAG_COD_SERVICIOS
  AFTER DELETE OR UPDATE
     ON BW_PAG_COD_SERVICIOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 03/12/2012 a las 10:49:49 Hs.
  */
  r_gaudi BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'BW_PAG_COD_SERVICIOS';
  r_gaudi.clave := :old.cod_servicio;
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_SERVICIO', :old.cod_servicio, :new.cod_servicio );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_PROVEEDOR', :old.cod_proveedor, :new.cod_proveedor );

  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( r_gaudi );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( r_gaudi );
END;
/

