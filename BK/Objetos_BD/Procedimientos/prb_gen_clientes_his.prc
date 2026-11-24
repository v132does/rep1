CREATE OR REPLACE PROCEDURE IT.PRB_GEN_CLIENTES_HIS is
/** se modificó para que inserte fecha calendario y no sysdate - JS - 08/05/2012 **/
v_fec_calendario ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1); 
begin
  Insert into ge_clientes_his
         (fecha, cod_persona, cod_oficina, cat_riesgo, cod_gru_economico, exo_impuestos, cod_usu_oficial,
         cli_especial, residente, cod_sec_contable, cod_tip_deudor, cod_departamento, niv_cruzamiento,
         clave, est_clave, fec_est_clave, can_intentos, tipo, tot_deu_real, tot_deu_contingente,
         cat_subjetiva, tot_gar_computables, tot_prevision, tip_extracto, cod_usu_gestion, usu_insercion,
         fec_insercion, usu_modificacion, fec_modificacion, fec_ingreso, cod_seg_cliente, cli_confidencial,
         tot_deu_sistema, cat_automatica, cat_sistema, cat_renovaciones, cat_gru_economico, cat_anterior,
         fec_cat_anterior, fec_ult_clasif, cat_atraso, tip_clave, tot_deu_cod_sistema, tot_deu_codeudoria,
         tot_deu_con_sistema, ult_cat_riesgo, fec_ult_cat_sub, fec_ult_cat_3, cod_perfil, fec_ult_acceso, 
         cod_canal, val_comercial, fec_ult_cla_sistema, cod_seg_preferente, cod_seg_pre_anterior)
  Select v_fec_calendario, a.cod_persona, a.cod_oficina, a.cat_riesgo, a.cod_gru_economico, a.exo_impuestos, a.cod_usu_oficial,
         a.cli_especial, a.residente, a.cod_sec_contable, a.cod_tip_deudor, a.cod_departamento, a.niv_cruzamiento,
         a.clave, a.est_clave, a.fec_est_clave, a.can_intentos, a.tipo, a.tot_deu_real, a.tot_deu_contingente,
         a.cat_subjetiva, a.tot_gar_computables, a.tot_prevision, a.tip_extracto, a.cod_usu_gestion, a.usu_insercion,
         a.fec_insercion, a.usu_modificacion, a.fec_modificacion, a.fec_ingreso, a.cod_seg_cliente, a.cli_confidencial,
         a.tot_deu_sistema, a.cat_automatica, a.cat_sistema, a.cat_renovaciones, a.cat_gru_economico, a.cat_anterior,
         a.fec_cat_anterior, a.fec_ult_clasif, a.cat_atraso, a.tip_clave, a.tot_deu_cod_sistema, a.tot_deu_codeudoria,
         a.tot_deu_con_sistema, a.ult_cat_riesgo, a.fec_ult_cat_sub, a.fec_ult_cat_3, a.cod_perfil, a.fec_ult_acceso, 
         a.cod_canal, a.val_comercial, a.fec_ult_cla_sistema, a.cod_seg_preferente, a.cod_seg_pre_anterior
  from ge_clientes a;
   
  Exception
    when others then
    if sqlcode <= -20000 then
       raise;
    else
       raise_application_error(-20000, 'Error al insertar historico de clientes.' || sqlerrm);
    end if;
end PRB_GEN_CLIENTES_HIS;
/

