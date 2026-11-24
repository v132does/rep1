CREATE OR REPLACE TRIGGER IT.AA_CB_RECIBOS
  AFTER DELETE OR UPDATE
     ON CB_RECIBOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 28/07/2016 a las 11:37:58 Hs.
  */
  v_registro CB_AUDITORIAS%ROWTYPE; -- Registro de la tabla CB_AUDITORIAS
BEGIN
  v_registro.tabla := 'CB_RECIBOS';
  v_registro.clave := to_char( :old.nro_recibo);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FECHA', :old.fecha, :new.fecha, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MOD_PADRE', :old.cod_mod_padre, :new.cod_mod_padre, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MAD_PADRE', :old.cod_mad_padre, :new.cod_mad_padre, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_TRA_PADRE', :old.cod_tra_padre, :new.cod_tra_padre, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COTIZACION', :old.cotizacion, :new.cotizacion, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ANULADO', :old.anulado, :new.anulado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IMPRESO', :old.impreso, :new.impreso );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_RECIBO', :old.tot_recibo, :new.tot_recibo, 'M' );

  -- Insertar tabla de auditoria
  prb_ins_cb_auditoria( v_registro );
EXCEPTION
  when others then
    prb_ins_cb_auditoria( v_registro );
END;
/

