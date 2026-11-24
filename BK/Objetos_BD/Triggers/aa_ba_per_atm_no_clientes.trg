CREATE OR REPLACE TRIGGER IT.AA_BA_PER_ATM_NO_CLIENTES
  AFTER DELETE OR UPDATE
     ON "IT"."BA_PER_ATM_NO_CLIENTES"
    FOR EACH ROW
DECLARE
  v_registro ba_auditorias%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS

BEGIN
  v_registro.tabla := 'BA_PER_ATM_NO_CLIENTES';
  v_registro.clave := :old.nro_documento;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_DOCUMENTO', :old.NRO_DOCUMENTO, :new.NRO_DOCUMENTO );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_TIP_DOCUMENTO', :old.COD_TIP_DOCUMENTO, :new.COD_TIP_DOCUMENTO );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NOM_APE', :old.NOM_APE, :new.NOM_APE );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIRECCION', :old.DIRECCION, :new.DIRECCION );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TELEFONO', :old.TELEFONO, :new.TELEFONO );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EMAIL', :old.EMAIL, :new.EMAIL );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_ACTUALIZACION', :old.FEC_ACTUALIZACION, :new.FEC_ACTUALIZACION );

  -- Insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria( v_registro );
EXCEPTION
  when others then
    pae_cnf.pr_ins_ba_auditoria( v_registro );
END;
/

