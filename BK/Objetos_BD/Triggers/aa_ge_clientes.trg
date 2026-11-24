CREATE OR REPLACE TRIGGER IT.AA_GE_CLIENTES
 AFTER DELETE OR UPDATE
 ON GE_CLIENTES
 FOR EACH ROW




DECLARE
   r_eaudi ge_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'GE_CLIENTES';
   r_eaudi.clave := :old.cod_persona;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAT_RIESGO',:old.cat_riesgo,:new.cat_riesgo);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_GRU_ECONOMICO',:old.cod_gru_economico,:new.cod_gru_economico,'N');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'EXO_IMPUESTOS',:old.exo_impuestos,:new.exo_impuestos);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_USU_OFICIAL',:old.cod_usu_oficial,:new.cod_usu_oficial);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CLI_ESPECIAL',:old.cli_especial,:new.cli_especial);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'RESIDENTE',:old.residente,:new.residente);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_SEC_CONTABLE',:old.cod_sec_contable,:new.cod_sec_contable);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_TIP_DEUDOR',:old.cod_tip_deudor,:new.cod_tip_deudor,'N');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_DEPARTAMENTO',:old.cod_departamento,:new.cod_departamento,'N');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NIV_CRUZAMIENTO',:old.niv_cruzamiento,:new.niv_cruzamiento,'N');
    --Se quito la auditoria de la clave 27-11-2012 cbenitez
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'EST_CLAVE',:old.est_clave,:new.est_clave);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_EST_CLAVE',:old.fec_est_clave,:new.fec_est_clave,'F');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAN_INTENTOS',:old.can_intentos,:new.can_intentos,'N');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TIPO',:old.tipo,:new.tipo);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TOT_DEU_REAL',:old.tot_deu_real,:new.tot_deu_real,'M');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TOT_DEU_CONTINGENTE',:old.tot_deu_contingente,:new.tot_deu_contingente,'M');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAT_SUBJETIVA',:old.cat_subjetiva,:new.cat_subjetiva,'N');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TOT_GAR_COMPUTABLES',:old.tot_gar_computables,:new.tot_gar_computables,'M');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TOT_PREVISION',:old.tot_prevision,:new.tot_prevision,'M');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TIP_EXTRACTO',:old.tip_extracto,:new.tip_extracto);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_USU_GESTION',:old.cod_usu_gestion,:new.cod_usu_gestion);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_INGRESO',:old.fec_ingreso,:new.fec_ingreso,'F');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_SEG_CLIENTE',:old.cod_seg_cliente,:new.cod_seg_cliente,'N');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CLI_CONFIDENCIAL',:old.cli_confidencial,:new.cli_confidencial);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAT_AUTOMATICA',:old.cat_automatica,:new.cat_automatica,'N');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TOT_DEU_SISTEMA',:old.tot_deu_sistema,:new.tot_deu_sistema,'M');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAT_SISTEMA',:old.cat_sistema,:new.cat_sistema,'N');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAT_RENOVACIONES',:old.cat_renovaciones,:new.cat_renovaciones,'N');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAT_GRU_ECONOMICO',:old.cat_gru_economico,:new.cat_gru_economico,'N');

    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_CANAL',:old.cod_canal,:new.cod_canal);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'VAL_COMERCIAL',:old.val_comercial,:new.val_comercial);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_ULT_CLA_SISTEMA',:old.fec_ult_cla_sistema,:new.fec_ult_cla_sistema,'F');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_SEG_PREFERENTE',:old.cod_seg_preferente,:new.cod_seg_preferente,'N');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_SEG_PRE_ANTERIOR',:old.cod_seg_pre_anterior,:new.cod_seg_pre_anterior,'N');
		r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'USU_IMP_CLAVE',:old.usu_imp_clave,:new.usu_imp_clave);
		r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_OFI_IMP_CLAVE',:old.cod_ofi_imp_clave,:new.cod_ofi_imp_clave,'N');
		r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_IMP_CLAVE',:old.fec_imp_clave,:new.fec_imp_clave,'F');

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_eaudi);
   --- verifico si ciertos datos fueron modificados
/*
   if nvl(:new.cod_gru_economico,-1) <> nvl(:new.cod_gru_economico,-1) then
       -- se modifico el grupo economico, se envia mail al responsable
       -- envio mail al nuevo responsable
       it_mail.mail(fug_obt_dir_correo,
                    'itgf@itbank.com.py',
                    'Cambio de datos en el Cliente',
                    'El usuario '||user||' ha modificado los sgtes. datos del Cliente '||:new.cod_persona||chr(10)||
                    ' Grupo economico: '||to_char(:old.cod_gru_economico)||' - '||
                                          to_char(:new.cod_gru_economico));

   end if;
*/
END;
/

