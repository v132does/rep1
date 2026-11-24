CREATE OR REPLACE TRIGGER IT.AA_CC_SOBREGIROS_RES
  AFTER DELETE OR UPDATE
     ON CC_SOBREGIROS_RES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 26/06/2013 a las 15:31:47 Hs.
  */
  r_caudi AF_AUDITORIAS%ROWTYPE; -- Registro de la tabla AF_AUDITORIAS
BEGIN
  r_caudi.tabla := 'CC_SOBREGIROS_RES';
  r_caudi.clave := :old.nro_cuenta;
  r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_caudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_caudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_caudi.detalle := pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'CAN_DIAS', :old.can_dias, :new.can_dias, 'N' );
  r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'SIT_DEUDA', :old.sit_deuda, :new.sit_deuda );
  r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'CAN_DIA_SOBREGIRO', :old.can_dia_sobregiro, :new.can_dia_sobregiro, 'N' );
  r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'MAX_ATRASO', :old.max_atraso, :new.max_atraso, 'N' );
  r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'PRO_ATRASO', :old.pro_atraso, :new.pro_atraso, 'N' );
  r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'MTO_MORA', :old.mto_mora, :new.mto_mora, 'M' );
  r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'MTO_SOB_SUSPENSO', :old.mto_sob_suspenso, :new.mto_sob_suspenso, 'M' );

  -- Insertar tabla de auditoria
  prf_ins_af_auditoria( r_caudi );
EXCEPTION
  when others then
    prf_ins_af_auditoria( r_caudi );
END;
/

