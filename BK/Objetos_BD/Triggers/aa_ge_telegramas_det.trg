CREATE OR REPLACE TRIGGER IT.AA_GE_TELEGRAMAS_DET
  AFTER DELETE OR UPDATE
     ON GE_TELEGRAMAS_DET
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 21/07/2006 a las 17:49:09 Hs.
  */
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   v_registro.tabla := 'GE_TELEGRAMAS_DET';
   v_registro.clave := to_char(:old.cod_telegrama);
   v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      v_registro.tip_novedad := 'M';
   elsif deleting then
      v_registro.tip_novedad := 'E';
   end if;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CHEQUE', :old.nro_cheque, :new.nro_cheque, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FECHA', :old.fecha, :new.fecha, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'HORA', :old.hora, :new.hora );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/

