CREATE OR REPLACE TRIGGER IT.AA_GE_PER_INHIBIDAS
  AFTER DELETE OR UPDATE
     ON GE_PER_INHIBIDAS
    FOR EACH ROW

DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 20/07/2005 a las 09:37:25 Hs.
  */
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_PER_INHIBIDAS';
  v_registro.clave := :old.cod_persona || '#' || to_char( :old.nro_orden);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CAUSA', :old.cod_causa, :new.cod_causa, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_INICIO', :old.fec_inicio, :new.fec_inicio, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ORIGEN', :old.origen, :new.origen );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_BANCO', :old.cod_banco, :new.cod_banco, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CTA_INHIBIDA', :old.nro_cta_inhibida, :new.nro_cta_inhibida );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_MULTA', :old.mto_multa, :new.mto_multa, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REFERENCIA', :old.referencia, :new.referencia );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DETALLE', :old.detalle, :new.detalle );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CAMPANA', :old.cod_campana, :new.cod_campana, 'N' );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/

