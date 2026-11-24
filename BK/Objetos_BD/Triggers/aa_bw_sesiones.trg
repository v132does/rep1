CREATE OR REPLACE TRIGGER IT.AA_BW_SESIONES
  AFTER DELETE OR UPDATE
     ON BW_SESIONES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 03/12/2012 a las 10:49:07 Hs.
  */
  r_gaudi BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'BW_SESIONES';
  r_gaudi.clave := :old.cod_persona || '#' || :old.cod_per_vinculada;
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_SESION', :old.nro_sesion, :new.nro_sesion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_IP', :old.nro_ip, :new.nro_ip );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'HOR_INICIO', :old.hor_inicio, :new.hor_inicio );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_INICIO', :old.fec_inicio, :new.fec_inicio, 'F' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'CAN_OPERACIONES', :old.can_operaciones, :new.can_operaciones, 'N' );

  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( r_gaudi );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( r_gaudi );
END;
/

