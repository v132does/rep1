CREATE OR REPLACE TRIGGER IT.AA_BW_CLA_LIM_CANTIDADES
  AFTER DELETE OR UPDATE
     ON BW_CLA_LIM_CANTIDADES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 10/04/2012 a las 14:24:40 Hs.
  */
  r_waudi BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  r_waudi.tabla := 'BW_CLA_LIM_CANTIDADES';
  r_waudi.clave := :old.cod_tip_mensaje || '#' || :old.tip_persona || '#' || :old.cod_persona || '#' || :old.nro_cuenta;
  r_waudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_waudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_waudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_waudi.detalle := pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'CAN_MAXIMA', :old.can_maxima, :new.can_maxima, 'M' );

  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( r_waudi );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( r_waudi );
END;
/

