CREATE OR REPLACE TRIGGER IT.AA_SB_CTA_GARANTIAS_NOV
  AFTER DELETE OR UPDATE
     ON IT.SB_CTA_GARANTIAS_NOV
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 21/07/2014 a las 09:56:49 Hs.
  */
  r_saudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  r_saudi.tabla := 'SB_CTA_GARANTIAS_NOV';
  r_saudi.clave := to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS') || '#' || :old.hora || '#' || to_char( :old.nro_garantia) || '#' || :old.nro_cuenta;
  r_saudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_saudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_saudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_saudi.detalle := pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'COD_GARANTIA', :old.cod_garantia, :new.cod_garantia, 'N' );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'MTO_APL_COMPUTABLE', :old.mto_apl_computable, :new.mto_apl_computable, 'M' );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( r_saudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( r_saudi );
END;
/

