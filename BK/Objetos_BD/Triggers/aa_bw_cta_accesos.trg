CREATE OR REPLACE TRIGGER IT.AA_BW_CTA_ACCESOS
  AFTER DELETE OR UPDATE
     ON BW_CTA_ACCESOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2014 - IT Consultores
  || Generado el 05/08/2014 a las 17:34:45 Hs.
  */
  r_waudi BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  r_waudi.tabla := 'BW_CTA_ACCESOS';
  r_waudi.clave := :old.cod_persona || '#' || :old.cod_per_vinculo || '#' || :old.nro_cuenta;
  r_waudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_waudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_waudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_waudi.detalle := pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'TIP_ACCESO', :old.tip_acceso, :new.tip_acceso );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'VER_MOVIMIENTOS', :old.ver_movimientos, :new.ver_movimientos );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'ACTIVO', :old.activo, :new.activo );

  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( r_waudi );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( r_waudi );
END;
/

