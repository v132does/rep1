CREATE OR REPLACE TRIGGER IT.AA_GE_SEG_PAR_CTA_TAS
 AFTER DELETE OR UPDATE
 ON GE_SEG_PAR_CTA_TAS
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_SEG_PAR_CTA_TAS';
   r_gaudi.clave := to_char(:old.cod_tasa)||'#'||to_char(:old.cod_seg_cliente)||'#'||
   to_char(:old.cod_modulo)||'#'||to_char(:old.cod_modalidad)||'#'||:old.cod_moneda;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VALOR',:old.valor,:new.valor,'M');
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_SUB_MODALIDAD',:old.cod_sub_modalidad,:new.cod_sub_modalidad,'N');

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

