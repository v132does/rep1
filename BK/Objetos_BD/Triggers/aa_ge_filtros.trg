CREATE OR REPLACE TRIGGER IT.AA_GE_FILTROS
 AFTER DELETE OR UPDATE
 ON GE_FILTROS
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_FILTROS';
   r_gaudi.clave := :old.cod_campo;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_CAMPO',:old.tip_campo,:new.tip_campo);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'LON_CAMPO',:old.lon_campo,:new.lon_campo,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_DATO',:old.tip_dato,:new.tip_dato);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_MAX_PERMITIDO',:old.val_max_permitido,:new.val_max_permitido);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_MIN_PERMITIDO',:old.val_min_permitido,:new.val_min_permitido);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NOM_TAB_ASOCIADA',:old.nom_tab_asociada,:new.nom_tab_asociada);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NOM_REFERENCIA',:old.nom_referencia,:new.nom_referencia);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_ORDEN',:old.nro_orden,:new.nro_orden,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'OBSERVACION',:old.observacion,:new.observacion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIPO',:old.tipo,:new.tipo);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

