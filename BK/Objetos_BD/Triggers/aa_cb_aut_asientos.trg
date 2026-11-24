create or replace trigger it.aa_cb_aut_asientos
 after delete or update of fecha, cod_oficina, nro_asiento, cod_usuario, cod_modulo, cod_modalidad,
                           cod_usu_autoriza, confirmado, fec_autorizac
 on cb_aut_asientos
 for each row

declare
r_baudi cb_auditorias%rowtype; -- registro de la tabla cb_auditorias
begin
   --desopimi-21 - fase 2 - optimización pra_gen_asientos
   --- insertar tabla de auditoria
   --- para que no grabe auditoría si el proceso es un cierre
   if (updating or deleting) and (pae_cnf.g_programa <> 'GPPROFIN') then
     r_baudi.tabla := 'cb_aut_asientos';
     r_baudi.clave := to_char(:old.fecha,'ddmmrrrr')||'#'||
     to_char(:old.cod_oficina)||'#'||
     to_char(:old.nro_asiento);
     r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

     if updating then
        r_baudi.tip_novedad := 'M';
     elsif deleting then
        r_baudi.tip_novedad := 'E';
     end if;

     --- registrar detalle
      r_baudi.detalle := pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_USUARIO',:old.cod_usuario,:new.cod_usuario);
      r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
      r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
      r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
      r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'NRO_ASIENTO',:old.nro_asiento,:new.nro_asiento,'N');
      r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_USU_AUTORIZA',:old.cod_usu_autoriza,:new.cod_usu_autoriza);
      r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'CONFIRMADO',:old.confirmado,:new.confirmado);
      r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'FEC_AUTORIZAC',:old.fec_autorizac,:new.fec_autorizac,'N');
      prb_ins_cb_auditoria(r_baudi);
   end if;
end;
/
