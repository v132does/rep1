CREATE OR REPLACE TRIGGER IT.AA_GE_SNP_CTA_RESTRINGIDAS
  AFTER DELETE OR UPDATE
     ON it.GE_SNP_CTA_RESTRINGIDAS
    FOR EACH ROW

DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoria
  || (c) 2005 - IT Consultores
  || Generado el 29/12/2014 a las 10:06:19 Hs.
  */

  rg_raudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  rg_raudi.tabla := 'GE_SNP_CTA_RESTRINGIDAS';
  rg_raudi.clave := to_char( :old.nro_cuenta) || '#' || :old.cod_swi_entidad;
  rg_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    rg_raudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_raudi.tip_novedad := 'E';
  END IF;
  -- Registrar Detalle
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_SWI_ENTIDAD', :old.cod_swi_entidad, :new.cod_swi_entidad );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'ESTADO', :old.estado, :new.estado);
  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( rg_raudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( rg_raudi );
END;
/

