CREATE OR REPLACE TRIGGER IT.AA_BA_LOG_PER_GEN_OFE
  AFTER DELETE OR UPDATE
     ON "IT"."BA_LOG_PER_GEN_OFE"
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditorka
  || (c) 2005 - IT Consultores
  || Generado el 22/03/2022 a las 18:24:09 Hs.
  */
  v_registro BA_AUDITORIAS%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS
BEGIN
  v_registro.tabla := 'BA_LOG_PER_GEN_OFE';
  v_registro.clave := to_char( :old.cod_registro);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ERROR', :old.cod_error, :new.cod_error, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MSJ_ERROR', :old.msj_error, :new.msj_error );

  -- Insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria( v_registro );
EXCEPTION
  when others then
  pae_cnf.pr_ins_ba_auditoria( v_registro );
END;
/

