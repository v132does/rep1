CREATE OR REPLACE TRIGGER IT.AA_BA_MAN_DETALLES
  AFTER DELETE OR UPDATE
     ON BA_MAN_DETALLES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 18/04/2008 a las 15:43:27 Hs.
  */
  v_registro BA_AUDITORIAS%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS
BEGIN
  v_registro.tabla := 'BA_MAN_DETALLES';
  v_registro.clave := :old.cod_manual || '#' || :old.nro_orden;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DETALLE', :old.detalle, :new.detalle );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'RESPONSABLE', :old.responsable, :new.responsable );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ACTIVO', :old.activo, :new.activo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PROGRAMA', :old.cod_programa, :new.cod_programa );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'RESULTADO', :old.resultado, :new.resultado );

  -- Insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria( v_registro );
EXCEPTION
  when others then
    pae_cnf.pr_ins_ba_auditoria( v_registro );
END;
/

