CREATE OR REPLACE TRIGGER IT.AA_LC_DEVENGADOS
 AFTER DELETE OR UPDATE
 ON LC_DEVENGADOS
 FOR EACH ROW

DECLARE
r_laudi lc_auditorias%rowtype; -- Registro de la tabla LC_AUDITORIAS
BEGIN
   r_laudi.tabla := 'LC_DEVENGADOS';
   r_laudi.clave := :old.nro_cuenta||'#'||to_char(:old.fecha,'ddmmrrrr');
   r_laudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_laudi.tip_novedad := 'M';
   elsif deleting then
      r_laudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_laudi.detalle := pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'NRO_OPERACION',:old.nro_operacion,:new.nro_operacion,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'VAL_TASA',:old.val_tasa,:new.val_tasa,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'CAN_DIA_INTERES',:old.can_dia_interes,:new.can_dia_interes,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_INTERES',:old.mto_interes,:new.mto_interes,'M');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'SAL_ACUMULADO',:old.sal_acumulado,:new.sal_acumulado,'M');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_DEV_ANTERIOR',:old.mto_dev_anterior,:new.mto_dev_anterior,'M');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_DEV_ACUMULADO',:old.mto_dev_acumulado,:new.mto_dev_acumulado,'M');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_MAD_TRANSACCION',:old.cod_mad_transaccion,:new.cod_mad_transaccion,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_MAD_PADRE',:old.cod_mad_padre,:new.cod_mad_padre,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_OFI_ORIGEN',:old.cod_ofi_origen,:new.cod_ofi_origen,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'DESCUENTO',:old.descuento,:new.descuento);

   --- Insertar tabla de auditoria
   PRL_INS_LC_AUDITORIA(r_laudi);
END;
/

