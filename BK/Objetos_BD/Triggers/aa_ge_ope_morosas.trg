CREATE OR REPLACE TRIGGER IT.AA_GE_OPE_MOROSAS
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_OPE_MOROSAS
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_OPE_MOROSAS';
   r_gaudi.clave := :old.nro_cuenta||'#'||:old.cod_persona;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODULO',:old.COD_MODULO,:new.COD_MODULO,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODALIDAD',:old.COD_MODALIDAD,:new.COD_MODALIDAD,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MONEDA',:old.COD_MONEDA,:new.COD_MONEDA);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_GARANTIA',:old.COD_GARANTIA,:new.COD_GARANTIA,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TOT_DEUDA',:old.TOT_DEUDA,:new.TOT_DEUDA,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TOT_DEU_CAPITAL',:old.TOT_DEU_CAPITAL,:new.TOT_DEU_CAPITAL,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TOT_DEU_INTERES',:old.TOT_DEU_INTERES,:new.TOT_DEU_INTERES,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'INT_MORA',:old.INT_MORA,:new.INT_MORA,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DIA_ATRASO',:old.DIA_ATRASO,:new.DIA_ATRASO,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ESTADO',:old.ESTADO,:new.ESTADO);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_ULT_PAGO',:old.FEC_ULT_PAGO,:new.FEC_ULT_PAGO,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MTO_CUO_VENCIDAS',:old.MTO_CUO_VENCIDAS,:new.MTO_CUO_VENCIDAS,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'INT_VENCIDO',:old.INT_VENCIDO,:new.INT_VENCIDO,'M');
 --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

