CREATE OR REPLACE TRIGGER IT.AA_MD_DEP_HORARIOS
  AFTER DELETE OR UPDATE
     ON MD_DEP_HORARIOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 19/06/2018 a las 16:33:48 Hs.
  */
  v_registro MD_AUDITORIAS%ROWTYPE; -- Registro de la tabla MD_AUDITORIAS
BEGIN
  v_registro.tabla := 'MD_DEP_HORARIOS';
  v_registro.clave := to_char( :old.cod_periodo);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FECHA', :old.fecha, :new.fecha, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'HOR_INICIO', :old.hor_inicio, :new.hor_inicio );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'HOR_FIN', :old.hor_fin, :new.hor_fin );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_HORARIO', :old.tip_horario, :new.tip_horario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DET_SQL', :old.det_sql, :new.det_sql );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'HOR_EJE_AUTOMATICA', :old.hor_eje_automatica, :new.hor_eje_automatica );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ERROR', :old.error, :new.error );

  -- Insertar tabla de auditoria
  prm_ins_md_auditoria( v_registro );
EXCEPTION
  when others then
    prm_ins_md_auditoria( v_registro );
END;
/

