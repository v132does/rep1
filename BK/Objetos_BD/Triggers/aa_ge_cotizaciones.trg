CREATE OR REPLACE TRIGGER IT.AA_GE_COTIZACIONES
 AFTER DELETE OR UPDATE
 ON GE_COTIZACIONES
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_COTIZACIONES';
   r_gaudi.clave := :old.cod_moneda||'#'||to_char(:old.fecha,'ddmmrrrr');
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_CONVERSION',:old.val_conversion,:new.val_conversion,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_COMPRA',:old.val_compra,:new.val_compra,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_VENTA',:old.val_venta,:new.val_venta,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_VEN_CHEQUE',:old.val_ven_cheque,:new.val_ven_cheque,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_COM_CHEQUE',:old.val_com_cheque,:new.val_com_cheque,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_COM_ELECTRONICA',:old.val_com_electronica,:new.val_com_electronica,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_VEN_ELECTRONICA',:old.val_ven_electronica,:new.val_ven_electronica,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_COM_INTERBANCARIA',:old.val_com_interbancaria,:new.val_com_interbancaria,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_VEN_INTERBANCARIA',:old.val_ven_interbancaria,:new.val_ven_interbancaria,'N');

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

