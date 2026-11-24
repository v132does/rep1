CREATE OR REPLACE TRIGGER IT.AA_BW_CLI_DIGITALES
  AFTER DELETE OR UPDATE
     ON BW_CLI_DIGITALES
    FOR EACH ROW
DECLARE
   /*
   || Archivo creado por el Generador de Triggers de Auditoría
   || (c) 2005 - IT Consultores
   || Generado el 02/10/2007 a las 08:13:12 Hs.
   */
   v_registro BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
   v_registro.tabla          := 'AA_BW_CLI_DIGITALES';
   v_registro.clave          := :old.anho || '#' || :old.mes || '#' || :old.cod_persona;
   v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   IF updating THEN
      v_registro.tip_novedad := 'M';
   ELSIF deleting THEN
      v_registro.tip_novedad := 'E';
   END IF;

   -- Registrar Detalle
   v_registro.detalle := pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'FEC_ULT_ACC_MOB', :old.FEC_ULT_ACC_MOB, :new.FEC_ULT_ACC_MOB, 'F');
   v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'FEC_ULT_ACC_WEB', :old.FEC_ULT_ACC_WEB, :new.FEC_ULT_ACC_WEB, 'F');
   v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'FEC_ULT_ACC_MIC', :old.FEC_ULT_ACC_MIC, :new.FEC_ULT_ACC_MIC, 'F');
   v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'FEC_ULT_ACC_TAS', :old.FEC_ULT_ACC_TAS, :new.FEC_ULT_ACC_TAS, 'F');
   v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'FEC_ULT_ACC_IVR', :old.FEC_ULT_ACC_IVR, :new.FEC_ULT_ACC_IVR, 'F');
   v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'FEC_ULT_ACC_ATM', :old.FEC_ULT_ACC_ATM, :new.FEC_ULT_ACC_ATM, 'F');

   -- Insertar tabla de auditoria
   prw_ins_bw_auditoria(v_registro);
EXCEPTION
   WHEN OTHERS THEN
      prw_ins_bw_auditoria(v_registro);
END;
/

