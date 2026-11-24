CREATE OR REPLACE TRIGGER IT.AA_GE_OFE_PAR_CUOTERO
  AFTER DELETE OR UPDATE
     ON "IT"."GE_OFE_PAR_CUOTERO"
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditor?a
  || (c) 2005 - IT Consultores
  || Generado el 22/03/2022 a las 18:01:42 Hs.
  */
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_OFE_PAR_CUOTERO';
  v_registro.clave := to_char( :old.mto_prestamo);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;
  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_CUOTA', :old.mto_cuota, :new.mto_cuota, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CAN_CUOTA', :old.can_cuota, :new.can_cuota, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/

