CREATE OR REPLACE TRIGGER IT.AA_GE_SEG_PAR_CUENTAS
 AFTER DELETE OR UPDATE
 ON GE_SEG_PAR_CUENTAS
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_SEG_PAR_CUENTA';
   r_gaudi.clave := to_char(:old.cod_seg_cliente)||'#'||to_char(:old.cod_modulo)||'#'||
   to_char(:old.cod_modalidad)||'#'||:old.cod_moneda;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_ENTE',:old.cod_ente,:new.cod_ente,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MIN_PACTADO',:old.min_pactado,:new.min_pactado,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_CAPITALIZACION',:old.tip_capitalizacion,:new.tip_capitalizacion,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_EXTRACTO',:old.tip_extracto,:new.tip_extracto);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_TASA',:old.cod_tasa,:new.cod_tasa,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'PLAZO',:old.plazo,:new.plazo,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_SUB_MODALIDAD',:old.cod_sub_modalidad,:new.cod_sub_modalidad,'N');

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

