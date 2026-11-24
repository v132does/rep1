create or replace trigger it.aa_ge_cta_blo_creditos_det
 after delete or update
 on ge_cta_blo_creditos_det
 for each row

declare
r_gaudi ge_auditorias%rowtype; -- registro de la tabla ge_auditorias
begin
   r_gaudi.tabla := 'GE_CTA_BLO_CREDITOS_DET';
   r_gaudi.clave := :old.cod_blo_credito ||'#'||:old.cod_transaccion ||'#'||:old.cod_modulo ||'#'||:old.cod_modalidad ;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;
   --- registrar detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_BLO_CREDITO ',:old.cod_blo_credito ,:new.cod_blo_credito);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_TRANSACCION',:old.cod_transaccion ,:new.cod_transaccion );
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad);

    --- insertar tabla de auditoria
    prg_ins_ge_auditoria(r_gaudi);
end;
/
