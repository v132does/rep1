CREATE OR REPLACE TRIGGER IT.AA_CR_RECLAMOS
  AFTER DELETE OR UPDATE
     ON CR_RECLAMOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 31/07/2014 a las 15:43:28 Hs.
  */
  r_raudi CR_AUDITORIAS%ROWTYPE; -- Registro de la tabla CR_AUDITORIAS
BEGIN
  r_raudi.tabla := 'CR_RECLAMOS';
  r_raudi.clave := to_char( :old.nro_reclamo);
  r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_raudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_raudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_raudi.detalle := pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  r_raudi.detalle := r_raudi.detalle || pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'TIP_RECLAMO', :old.tip_reclamo, :new.tip_reclamo );
  r_raudi.detalle := r_raudi.detalle || pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'FECHA', :old.fecha, :new.fecha, 'F' );
  r_raudi.detalle := r_raudi.detalle || pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'DETALLE', :old.detalle, :new.detalle );
  r_raudi.detalle := r_raudi.detalle || pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'FEC_SOLUCION', :old.fec_solucion, :new.fec_solucion, 'F' );
  r_raudi.detalle := r_raudi.detalle || pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );

  -- Insertar tabla de auditoria
  prr_ins_cr_auditoria( r_raudi );
EXCEPTION
  when others then
    prr_ins_cr_auditoria( r_raudi );
END;
/

