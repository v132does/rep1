CREATE OR REPLACE TRIGGER IT.AA_BU_BIE_GRUPOS
  AFTER DELETE OR UPDATE
     ON BU_BIE_GRUPOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 05/11/2010 a las 09:55:55 Hs.
  */
  v_registro BU_AUDITORIAS%ROWTYPE; -- Registro de la tabla BU_AUDITORIAS
BEGIN
  v_registro.tabla := 'BU_BIE_GRUPOS';
  v_registro.clave := :old.cod_persona || '#' || to_char( :old.cod_oficina) || '#' || to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS') || '#' || :old.forma || '#' || :old.cod_moneda;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_ADJUDICACION', :old.tot_adjudicacion, :new.tot_adjudicacion, 'M' );

  -- Insertar tabla de auditoria
  pru_ins_bu_auditoria( v_registro );
EXCEPTION
  when others then
    pru_ins_bu_auditoria( v_registro );
END;
/

