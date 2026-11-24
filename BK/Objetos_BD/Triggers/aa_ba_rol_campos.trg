CREATE OR REPLACE TRIGGER IT.AA_BA_ROL_CAMPOS
  AFTER DELETE OR UPDATE
     ON ba_rol_campos
    FOR EACH ROW
DECLARE
  /*
  || Generado el 19/05/2014 a las 14:57 Hs.
  */
  v_registro GE_AUDITORIAS%ROWTYPE;
BEGIN
  v_registro.tabla := 'BA_ROL_CAMPOS';
  v_registro.clave := TO_CHAR( :old.cod_programa)||'#'||TO_CHAR(:old.cod_rol);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PROGRAMA', :old.cod_programa, :new.cod_programa );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ROL', :old.cod_rol, :new.cod_rol );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NOM_BLOQUE', :old.nom_bloque, :new.nom_bloque );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NOM_CAMPO', :old.nom_campo, :new.nom_campo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CONSULTA', :old.consulta, :new.consulta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'INSERTA', :old.inserta, :new.inserta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MODIFICA', :old.modifica, :new.modifica );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ELIMINA', :old.elimina, :new.elimina );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIPO_PERSONA', :old.tip_persona, :new.elimina );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/

