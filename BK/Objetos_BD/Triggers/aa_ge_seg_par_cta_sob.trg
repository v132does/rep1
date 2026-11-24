CREATE OR REPLACE TRIGGER IT.AA_GE_SEG_PAR_CTA_SOB
 AFTER DELETE OR UPDATE
 ON GE_SEG_PAR_CTA_SOB
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_SEG_PAR_CTA_SOB';
   r_gaudi.clave := to_char(:old.cod_seg_cliente)||'#'||to_char(:old.cod_modulo)||'#'||
   to_char(:old.cod_modalidad)||'#'||to_char(:old.plazo)||'#'||:old.tipo||'#'||:old.cod_moneda;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MONTO',:old.monto,:new.monto,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_TAS_INTERES',:old.val_tas_interes,:new.val_tas_interes,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DIA_TASA',:old.dia_tasa,:new.dia_tasa,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TAS_PREFERENCIAL',:old.tas_preferencial,:new.tas_preferencial,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DIA_SIN_COSTO',:old.dia_sin_costo,:new.dia_sin_costo,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_SUB_MODALIDAD',:old.cod_sub_modalidad,:new.cod_sub_modalidad,'N');

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

