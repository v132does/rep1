CREATE OR REPLACE TRIGGER IT.AA_GE_RET_CUENTAS
 AFTER DELETE OR UPDATE
 ON GE_RET_CUENTAS
 FOR EACH ROW


DECLARE
r_gaudi pr_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_RET_CUENTAS';
   r_gaudi.clave :=:old.nro_cuenta||'#'||to_char(:old.cod_retencion);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'CAN_DIA_RETENCION',:old.can_dia_retencion,:new.can_dia_retencion,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_VENCIMIENTO',:old.fec_vencimiento,:new.fec_vencimiento,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'OBSERVACIONES',:old.observaciones,:new.observaciones);
   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

