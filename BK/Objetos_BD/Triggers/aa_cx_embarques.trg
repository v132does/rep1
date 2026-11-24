CREATE OR REPLACE TRIGGER IT.AA_CX_EMBARQUES
  AFTER DELETE OR UPDATE
     ON CX_EMBARQUES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 27/04/2009 a las 09:20:32 Hs.
  */
  v_registro CX_AUDITORIAS%ROWTYPE; -- Registro de la tabla CX_AUDITORIAS
BEGIN
  v_registro.tabla := 'CX_EMBARQUES';
  v_registro.clave := :old.nro_cuenta || '#' || to_char( :old.nro_embarque);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_COBRO', :old.tip_cobro, :new.tip_cobro );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_UTILIZADO', :old.mto_utilizado, :new.mto_utilizado, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SALDO', :old.saldo, :new.saldo, 'M' );

  -- Insertar tabla de auditoria
  prx_ins_cx_auditoria( v_registro );
EXCEPTION
  when others then
    prx_ins_cx_auditoria( v_registro );
END;
/

