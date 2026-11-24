CREATE OR REPLACE TRIGGER IT.AA_CC_CTA_CAJEROS
  AFTER DELETE OR UPDATE
     ON CC_CTA_CAJEROS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 03/10/2006 a las 18:22:38 Hs.
  */
  v_registro CC_AUDITORIAS%ROWTYPE; -- Registro de la tabla CC_AUDITORIAS
BEGIN
  v_registro.tabla := 'CC_CTA_CAJEROS';
  v_registro.clave := to_char( :old.cod_oficina) || '#' || to_char( :old.nro_caja);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CTA_CHEQUE', :old.nro_cta_cheque, :new.nro_cta_cheque );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_RUBRO', :old.cod_rubro, :new.cod_rubro );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CAJ_EXTERNO', :old.nro_caj_externo, :new.nro_caj_externo, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ENT_PORTAVALOR', :old.cod_ent_portavalor, :new.cod_ent_portavalor);
  -- Insertar tabla de auditoria
  prc_ins_cc_auditoria( v_registro );
EXCEPTION
  when others then
    prc_ins_cc_auditoria( v_registro );
END;
/
