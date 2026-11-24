CREATE OR REPLACE TRIGGER IT.AA_SB_SNP_LIM_DEPO
  AFTER DELETE OR UPDATE
     ON SB_SNP_LIM_DEPO
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 25/06/2018 a las 15:01:30 Hs.
  */
  r_saudi SB_AUDITORIAS%ROWTYPE; -- Registro de la tabla SB_AUDITORIAS
BEGIN
  r_saudi.tabla := 'SB_SNP_LIM_DEPO';
  r_saudi.clave := :old.cod_moneda || '#' || to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS') || '#' || to_char( :old.monto);
  r_saudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_saudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_saudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_saudi.detalle := pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'TASA', :old.tasa, :new.tasa, 'M' );

  -- Insertar tabla de auditoria
  prs_ins_sb_auditoria( r_saudi );
EXCEPTION
  when others then
    prs_ins_sb_auditoria( r_saudi );
END;
/

