CREATE OR REPLACE TRIGGER IT.AA_GE_EMBARGOS_DET
 AFTER DELETE OR UPDATE
 ON GE_EMBARGOS_DET
 FOR EACH ROW

DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_EMBARGOS_DET';
   r_gaudi.clave := to_char(:old.cod_embargo)||'#'||:old.nro_cuenta;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COTIZACION',:old.cotizacion,:new.cotizacion,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MTO_EMBARGADO',:old.mto_embargado,:new.mto_embargado,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MTO_MON_CUENTA',:old.mto_mon_cuenta,:new.mto_mon_cuenta,'M');
   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

