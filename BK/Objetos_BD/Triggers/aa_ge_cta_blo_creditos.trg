create or replace trigger it.aa_ge_cta_blo_creditos
 after delete or update
 on ge_cta_blo_creditos
 for each row

declare
r_gaudi ge_auditorias%rowtype; -- registro de la tabla ge_auditorias
begin
   r_gaudi.tabla := 'GE_CTA_BLO_CREDITOS';
   r_gaudi.clave := :old.cod_blo_credito;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;
   --- registrar detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_CUENTA ',:old.nro_cuenta ,:new.nro_cuenta);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ESTADO',:old.estado ,:new.estado );
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'OBSERVACION',:old.observacion,:new.observacion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_GRU_TRANSACCION',:old.cod_gru_transaccion,:new.cod_gru_transaccion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_USU_BLOQUEO',:old.cod_usu_bloqueo,:new.cod_usu_bloqueo);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_BLOQUEO',:old.fec_bloqueo,:new.fec_bloqueo);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_USU_DESBLOQUEO',:old.cod_usu_desbloqueo,:new.cod_usu_desbloqueo);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_DESBLOQUEO',:old.fec_desbloqueo,:new.fec_desbloqueo);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_AREA',:old.cod_area,:new.cod_area);


    --- insertar tabla de auditoria
    prg_ins_ge_auditoria(r_gaudi);
end;
/
