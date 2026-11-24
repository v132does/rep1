CREATE OR REPLACE TRIGGER IT.AA_CR_SEGMENTOS
  AFTER DELETE OR UPDATE
     ON CR_SEGMENTOS
    FOR EACH ROW


DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 20/07/2005 a las 09:11:22 Hs.
  */
  v_registro CR_AUDITORIAS%ROWTYPE; -- Registro de la tabla CR_AUDITORIAS
BEGIN
  v_registro.tabla := 'CR_SEGMENTOS';
  v_registro.clave := :old.cod_segmento;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIPO', :old.tipo, :new.tipo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_USUARIO', :old.cod_usuario, :new.cod_usuario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ROLES', :old.roles, :new.roles );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'AFE_AGENDA', :old.afe_agenda, :new.afe_agenda );

  -- Insertar tabla de auditoria
  prr_ins_cr_auditoria( v_registro );
EXCEPTION
  when others then
    prr_ins_cr_auditoria( v_registro );
END;
/

