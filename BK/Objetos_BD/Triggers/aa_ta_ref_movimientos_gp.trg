CREATE OR REPLACE TRIGGER IT.AA_TA_REF_MOVIMIENTOS_GP
  AFTER DELETE OR UPDATE
     ON "IT"."TA_REF_MOVIMIENTOS_GP"
    FOR EACH ROW
DECLARE
  r_taudi TA_AUDITORIAS%ROWTYPE;
BEGIN
  r_taudi.tabla := 'TA_REF_MOVIMIENTOS_GP';
  r_taudi.clave := to_char( :old.cod_referencia );
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_taudi.detalle := pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_REFERENCIA', :old.COD_REFERENCIA, :new.COD_REFERENCIA);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DESCRIPCION', :old.DESCRIPCION, :new.DESCRIPCION);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MODULO', :old.COD_MODULO, :new.COD_MODULO);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MODALIDAD', :old.COD_MODALIDAD, :new.COD_MODALIDAD);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_TRANSACCION', :old.COD_TRANSACCION, :new.COD_TRANSACCION);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'REF_ARCHIVO', :old.REF_ARCHIVO, :new.REF_ARCHIVO);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MODULO2', :old.COD_MODULO2, :new.COD_MODULO2);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MODALIDAD2', :old.COD_MODALIDAD2, :new.COD_MODALIDAD2);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_TRANSACCION2', :old.COD_TRANSACCION2, :new.COD_TRANSACCION2);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'PROCESA', :old.PROCESA, :new.PROCESA);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MODULO3', :old.COD_MODULO3, :new.COD_MODULO3);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MODALIDAD3', :old.COD_MODALIDAD3, :new.COD_MODALIDAD3);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_TRANSACCION3', :old.COD_TRANSACCION3, :new.COD_TRANSACCION3);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MODULO4', :old.COD_MODULO4, :new.COD_MODULO4);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MODALIDAD4', :old.COD_MODALIDAD4, :new.COD_MODALIDAD4);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_TRANSACCION4', :old.COD_TRANSACCION4, :new.COD_TRANSACCION4);

  prt_ins_ta_auditoria( r_taudi );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( r_taudi );
END;
/

