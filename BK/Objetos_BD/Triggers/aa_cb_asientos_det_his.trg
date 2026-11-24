CREATE OR REPLACE TRIGGER IT."AA_CB_ASIENTOS_DET_HIS"
 AFTER DELETE OR UPDATE
 ON CB_ASIENTOS_DET_HIS
 FOR EACH ROW


DECLARE
r_baudi cb_auditorias%rowtype; -- Registro de la tabla CB_AUDITORIAS
BEGIN
   r_baudi.tabla := 'CB_ASIENTOS_DET_HIS';
   r_baudi.clave := to_char(:old.fecha,'ddmmrrrr')||'#'||to_char(:old.cod_oficina)||'#'||to_char(:old.nro_asiento)||'#'||to_char(:old.nro_linea);
   r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_baudi.tip_novedad := 'M';
   elsif deleting then
      r_baudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_baudi.detalle := pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_RUBRO',:old.cod_rubro,:new.cod_rubro);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'TIP_MOVIMIENTO',:old.tip_movimiento,:new.tip_movimiento);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'MTO_MON_RUBRO',:old.mto_mon_rubro,:new.mto_mon_rubro,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'MTO_MON_LOCAL',:old.mto_mon_local,:new.mto_mon_local,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'REFERENCIA',:old.referencia,:new.referencia);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'PROTEGIDO',:old.protegido,:new.protegido);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'ACTUALIZADO',:old.actualizado,:new.actualizado);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'VAL_COTIZACION',:old.val_cotizacion,:new.val_cotizacion,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'DISTRIBUIDO',:old.distribuido,:new.distribuido);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'REF_MOVIMIENTO',:old.ref_movimiento,:new.ref_movimiento,'N');

   --- Insertar tabla de auditoria
  PRB_INS_CB_AUDITORIA(r_baudi);
END;
/

