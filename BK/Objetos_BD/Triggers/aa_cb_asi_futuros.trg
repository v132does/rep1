CREATE OR REPLACE TRIGGER IT.AA_CB_ASI_FUTUROS
  --- Realizado por Ingrid Larraín - 07/10/2011 para que no se dispare por procesos automáticos
  AFTER DELETE OR UPDATE OF fecha, cod_oficina, nro_asiento, cod_usuario, cod_modulo, cod_modalidad, 
                            tot_control, reversado, ofi_integrada, confirmado, cod_ofi_origen, cod_cargo
     ON CB_ASI_FUTUROS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 03/01/2011 a las 16:57:48 Hs.
  */
  v_registro CB_AUDITORIAS%ROWTYPE; -- Registro de la tabla CB_AUDITORIAS
BEGIN
  v_registro.tabla := 'CB_ASI_FUTUROS';
  v_registro.clave := to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS') || '#' || to_char( :old.cod_oficina) || '#' || to_char( :old.nro_asiento);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_ASI_REAL', :old.nro_asi_real, :new.nro_asi_real, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_USUARIO', :old.cod_usuario, :new.cod_usuario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_CONTROL', :old.tot_control, :new.tot_control, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ACTUALIZADO', :old.actualizado, :new.actualizado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REVERSADO', :old.reversado, :new.reversado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OFI_INTEGRADA', :old.ofi_integrada, :new.ofi_integrada );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CONFIRMADO', :old.confirmado, :new.confirmado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFI_ORIGEN', :old.cod_ofi_origen, :new.cod_ofi_origen, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CARGO', :old.cod_cargo, :new.cod_cargo, 'N' );

  -- Insertar tabla de auditoria
  --- Para que no grabe auditoría si el proceso es un cierre
  IF updating or (deleting and pae_cnf.G_PROGRAMA <> 'GPPROFIN') THEN
     prb_ins_cb_auditoria( v_registro );
  END IF;
EXCEPTION
  when others then
    prb_ins_cb_auditoria( v_registro );
END;
/

