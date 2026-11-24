CREATE OR REPLACE TRIGGER IT.AA_WF_GRU_ROLES
  AFTER DELETE OR UPDATE
     ON WF_GRU_ROLES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 23/12/2013 a las 10:31:36 Hs.
  */
  r_gaudi WF_AUDITORIAS%ROWTYPE; -- Registro de la tabla WF_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'WF_GRU_ROLES';
  r_gaudi.clave := :old.cod_grupo || '#' || :old.cod_rol;
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'VE_OFICINAS', :old.ve_oficinas, :new.ve_oficinas );

  -- Insertar tabla de auditoria
  prw_ins_wf_auditoria( r_gaudi );
EXCEPTION
  when others then
    prw_ins_wf_auditoria( r_gaudi );
END;
/

