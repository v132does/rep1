CREATE OR REPLACE TRIGGER IT.AA_LC_COT_OFICINAS
 AFTER DELETE OR UPDATE
 ON LC_COT_OFICINAS
 FOR EACH ROW



DECLARE
r_laudi lc_auditorias%rowtype; -- Registro de la tabla LC_AUDITORIAS
BEGIN
   r_laudi.tabla := 'LC_COT_OFICINAS';
   r_laudi.clave := to_char(:old.cod_oficina)||'#'||:old.cod_moneda||'#'||to_char(:old.fecha,'ddmmrrrr');
   r_laudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_laudi.tip_novedad := 'M';
   elsif deleting then
      r_laudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_laudi.detalle := pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'VAL_COMPRA',:old.val_compra,:new.val_compra,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'VAL_VENTA',:old.val_venta,:new.val_venta,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'VAL_VEN_CHEQUE',:old.val_ven_cheque,:new.val_ven_cheque,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'VAL_COM_CHEQUE',:old.val_com_cheque,:new.val_com_cheque,'N');
   --- Insertar tabla de auditoria
   PRL_INS_LC_AUDITORIA(r_laudi);
END;
/

