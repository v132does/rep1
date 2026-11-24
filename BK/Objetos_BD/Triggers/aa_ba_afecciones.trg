CREATE OR REPLACE TRIGGER IT.AA_BA_AFECCIONES
 AFTER DELETE OR UPDATE
 ON BA_AFECCIONES
 FOR EACH ROW
DECLARE

  v_registro BA_AUDITORIAS%ROWTYPE; -- Registro de la tabla BA_AFECCIONES
BEGIN
  v_registro.tabla := 'BA_AFECCIONES';
  v_registro.clave := to_char( :old.cod_afeccion);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;
  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IND_DISCAPACITADO', :old.ind_discapacitado, :new.ind_discapacitado );
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  -- Insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria( v_registro );
EXCEPTION
  when others then
    pae_cnf.pr_ins_ba_auditoria( v_registro );
END;
/

