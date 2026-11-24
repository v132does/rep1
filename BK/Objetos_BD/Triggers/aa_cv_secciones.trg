CREATE OR REPLACE TRIGGER IT.AA_CV_SECCIONES
  AFTER DELETE OR UPDATE
     ON "IT"."CV_SECCIONES"
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 15/03/2016 a las 10:56:39 Hs.
  */
  v_registro CV_AUDITORIAS%ROWTYPE; -- Registro de la tabla CV_AUDITORIAS
BEGIN
  v_registro.tabla := 'CV_SECCIONES';
  v_registro.clave := to_char( :old.cod_seccion);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_HILERA', :old.cod_hilera, :new.cod_hilera, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_INCLUIDOS', :old.val_incluidos, :new.val_incluidos );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ABREVIATURA', :old.abreviatura, :new.abreviatura );

  -- Insertar tabla de auditoria
  prv_ins_cv_auditoria( v_registro );
EXCEPTION
  when others then
    prv_ins_cv_auditoria( v_registro );
END;
/

