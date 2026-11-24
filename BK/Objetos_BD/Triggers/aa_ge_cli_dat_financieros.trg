CREATE OR REPLACE TRIGGER IT.AA_GE_CLI_DAT_FINANCIEROS
  AFTER DELETE OR UPDATE
     ON GE_CLI_DAT_FINANCIEROS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 02/02/2010 a las 14:46:15 Hs.
  */
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_CLI_DAT_FINANCIEROS';
  v_registro.clave := :old.cod_persona;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FRE_MES_DINERO', :old.fre_mes_dinero, :new.fre_mes_dinero, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FRE_COM_EXTERIOR', :old.fre_com_exterior, :new.fre_com_exterior, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ACU_ANTERIOR', :old.acu_anterior, :new.acu_anterior, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ACU_ACTUAL', :old.acu_actual, :new.acu_actual, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_IMPORTACION', :old.tot_importacion, :new.tot_importacion, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_EXPORTACION', :old.tot_exportacion, :new.tot_exportacion, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_RIE_SISTEMA', :old.tot_rie_sistema, :new.tot_rie_sistema, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REL_PAS_ACTIVO', :old.rel_pas_activo, :new.rel_pas_activo, 'N' );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/

