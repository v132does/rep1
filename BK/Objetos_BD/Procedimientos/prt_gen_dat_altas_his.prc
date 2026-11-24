CREATE OR REPLACE PROCEDURE IT.PRT_GEN_DAT_ALTAS_HIS(P_COD_PROCESADORA IN VARCHAR2,
                                                  P_FECHA IN DATE,
                                                  P_HORA  IN VARCHAR2)
 IS
BEGIN
 --- inserción en cuentas ---------------------
 BEGIN
  insert into ta_env_cuentas
	(cod_procesadora, cod_banco, nro_doc_cod_procesadora, nro_doc_procesadora,nro_documento, tip_per_titular,
   cod_tip_doc_titular, pri_nom_titular, seg_nom_titular, pri_ape_titular, seg_ape_titular, raz_social,
   nom_comercial, cod_pai_titular, cod_sex_titular, fec_nac_titular, lug_nac_titular, ruc_titular,                    
   est_civ_titular, act_titular, dir_cor_titular, cod_tip_doc_nvo_titular, nro_doc_nvo_titular, sec_env_datos,
   nro_cuenta, cod_Afinidad, tip_cuenta, dir_recibo, direccion,localidad,dir_Ext_2,dir_ext_3,cod_departamento,
   cod_ciudad, cod_zona, telefono,nro_tel_movil, cod_sucursal, cta_vip, franqueo,seg_vida,cob_cargo,
   tip_costo, ret_extracto,cod_retencion,cau_retencion,cod_tip_cierre,emp_adherida,bcp_calificacion,
   situacion,cod_cli_entidad,nro_socio,bonos,tip_lin_normal,lin_Cre_normal,tip_lin_cuota, lin_cre_cuota,
   tas_personalizada,cod_Tasa,val_tasa,cod_tas_moratorio,val_tas_moratorio, cod_tas_compra,val_tas_compra,
   pag_min_personalizado,por_pag_minimo,pag_minimo,imp_pag_min_fijo,cod_for_pago,tip_cta_bancaria,
   cta_bancaria,tip_pago,val_cgf,tip_tasa,vip_fac_multiplicador,fac_vip,cobranding,nro_doc_codeudor,
   tip_per_codeudor,cod_tip_doc_codeudor,pri_nom_codeudor,seg_nom_codeudor,pri_ape_codeudor,
   seg_ape_codeudor,cod_sex_codeudor,fec_nac_codeudor,lug_nac_codeudor,est_civ_codeudor,
   act_codeudor,dir_cor_codeudor,nro_doc_oficial,tip_per_oficial,cod_tip_doc_oficial,pri_nom_oficial,
   seg_nom_oficial,pri_ape_oficial,seg_ape_oficial,cod_sex_oficial,fec_nac_oficial,
   lug_nac_oficial,est_civ_oficial,act_oficial,dir_cor_oficial,gas_no_aplicar,apl_impuesto,
   usu_Actualizacion,mot_nov_cuenta,cod_gas_financiero,cod_encargado,cod_mod_pago,tip_Comision,
   fec_novedad,tip_tarjeta,sec_alta,cod_movimiento,es_personalizado,fec_envio,hor_envio,estado,
   cod_modalidad,cod_moneda,nom_usuario,cod_persona,nro_solicitud,usu_insercion,fec_insercion,
   usu_modificacion,fec_modificacion)
   select 
   cod_procesadora, cod_banco, nro_doc_cod_procesadora, nro_doc_procesadora,nro_documento, tip_per_titular,
   cod_tip_doc_titular, pri_nom_titular, seg_nom_titular, pri_ape_titular, seg_ape_titular, raz_social,
   nom_comercial, cod_pai_titular, cod_sex_titular, fec_nac_titular, lug_nac_titular, ruc_titular,                    
   est_civ_titular, act_titular, dir_cor_titular, cod_tip_doc_nvo_titular, nro_doc_nvo_titular, sec_env_datos,
   nro_cuenta, cod_Afinidad, tip_cuenta, dir_recibo, direccion,localidad,dir_Ext_2,dir_ext_3,cod_departamento,
   cod_ciudad, cod_zona, telefono,nro_tel_movil, cod_sucursal, cta_vip, franqueo,seg_vida,cob_cargo,
   tip_costo, ret_extracto,cod_retencion,cau_retencion,cod_tip_cierre,emp_adherida,bcp_calificacion,
   situacion,cod_cli_entidad,nro_socio,bonos,tip_lin_normal,lin_Cre_normal,tip_lin_cuota, lin_cre_cuota,
   tas_personalizada,cod_Tasa,val_tasa,cod_tas_moratorio,val_tas_moratorio, cod_tas_compra,val_tas_compra,
   pag_min_personalizado,por_pag_minimo,pag_minimo,imp_pag_min_fijo,cod_for_pago,tip_cta_bancaria,
   cta_bancaria,tip_pago,val_cgf,tip_tasa,vip_fac_multiplicador,fac_vip,cobranding,nro_doc_codeudor,
   tip_per_codeudor,cod_tip_doc_codeudor,pri_nom_codeudor,seg_nom_codeudor,pri_ape_codeudor,
   seg_ape_codeudor,cod_sex_codeudor,fec_nac_codeudor,lug_nac_codeudor,est_civ_codeudor,
   act_codeudor,dir_cor_codeudor,nro_doc_oficial,tip_per_oficial,cod_tip_doc_oficial,pri_nom_oficial,
   seg_nom_oficial,pri_ape_oficial,seg_ape_oficial,cod_sex_oficial,fec_nac_oficial,
   lug_nac_oficial,est_civ_oficial,act_oficial,dir_cor_oficial,gas_no_aplicar,apl_impuesto,
   usu_Actualizacion,mot_nov_cuenta,cod_gas_financiero,cod_encargado,cod_mod_pago,tip_Comision,
   fec_novedad,tip_tarjeta,sec_alta,cod_movimiento,es_personalizado,fec_envio,hor_envio,estado,
   cod_modalidad,cod_moneda,nom_usuario,cod_persona,nro_solicitud,usu_insercion,fec_insercion,
   usu_modificacion,fec_modificacion
     from ta_env_cuentas_his h
    where h.cod_procesadora = P_COD_PROCESADORA
      and h.fec_envio       = P_FECHA
      and h.hor_envio       = p_hora;
 EXCEPTION
      when others then
        IF sqlcode <= -20000 THEN
          RAISE;
        ELSE
          RAISE_APPLICATION_ERROR( -20001,': insert de TA_ENV_TARJETAS ' || sqlerrm );
        END IF;
 END;

 --- inserción en tarjetas ---------------------
 BEGIN
    insert into ta_env_tarjetas
	  (cod_procesadora,nro_Tarjeta,nro_cuenta,nom_usuario,cod_persona,nro_documento,nro_doc_procesadora, 
	   dur_tarjeta,tip_Tarjeta,ven_tarjeta,cod_encargado,cla_tarjeta,cod_banco,cod_sucursal,
     cod_afinidad,fec_movimiento,sec_alta,cod_movimiento,nom_embozado,fec_envio,hor_envio,
     estado,nro_solicitud,cod_modalidad,sec_env_datos,usu_insercion,fec_insercion,usu_modificacion,
     fec_modificacion,tip_per_titular,cod_tip_doc_titular,pri_nom_titular,seg_nom_titular,
     pri_ape_titular,seg_ape_titular,cod_pai_titular,cod_sex_titular,fec_nac_titular,lug_nac_titular,
     est_civ_titular,act_titular,dir_cor_titular,tip_doc_nvo_titular,nro_doc_nvo_titular,tip_plastico,
     nom_plastico,adi_personalizado,nro_doc_promotor,cod_tip_doc_promotor,situacion,ren_automatica,
     orden_1,orden_2,tip_per_promotor,pri_nom_promotor,seg_nom_promotor,pri_ape_promotor,seg_ape_promotor,
     cod_Sex_promotor,fec_nac_promotor,lug_nac_promotor, est_civ_promotor,act_promotor,
     dir_cor_promotor,pla_contado,ope_pla_contado,imp_per_pla_contado,por_per_pla_contado,
     pla_ade_efectivo,ope_pla_ade_efectivo,imp_per_pla_ade_efectivo,por_per_ade_efectivo,
     pue_financiar,usu_actualizacion,emboza,nro_socio,mot_novedad)
	 select 
cod_procesadora,nro_Tarjeta,nro_cuenta,nom_usuario,cod_persona,nro_documento,nro_doc_procesadora, 
	   dur_tarjeta,tip_Tarjeta,ven_tarjeta,cod_encargado,cla_tarjeta,cod_banco,cod_sucursal,
     cod_afinidad,fec_movimiento,sec_alta,cod_movimiento,nom_embozado,fec_envio,hor_envio,
     estado,nro_solicitud,cod_modalidad,sec_env_datos,usu_insercion,fec_insercion,usu_modificacion,
     fec_modificacion,tip_per_titular,cod_tip_doc_titular,pri_nom_titular,seg_nom_titular,
     pri_ape_titular,seg_ape_titular,cod_pai_titular,cod_sex_titular,fec_nac_titular,lug_nac_titular,
     est_civ_titular,act_titular,dir_cor_titular,tip_doc_nvo_titular,nro_doc_nvo_titular,tip_plastico,
     nom_plastico,adi_personalizado,nro_doc_promotor,cod_tip_doc_promotor,situacion,ren_automatica,
     orden_1,orden_2,tip_per_promotor,pri_nom_promotor,seg_nom_promotor,pri_ape_promotor,seg_ape_promotor,
     cod_Sex_promotor,fec_nac_promotor,lug_nac_promotor, est_civ_promotor,act_promotor,
     dir_cor_promotor,pla_contado,ope_pla_contado,imp_per_pla_contado,por_per_pla_contado,
     pla_ade_efectivo,ope_pla_ade_efectivo,imp_per_pla_ade_efectivo,por_per_ade_efectivo,
     pue_financiar,usu_actualizacion,emboza,nro_socio,mot_novedad
      from ta_env_tarjetas_his h
     where h.cod_procesadora = P_COD_PROCESADORA
           and h.fec_envio   = P_FECHA
           and h.hor_envio   = p_hora;
 EXCEPTION
      when others then
        IF sqlcode <= -20000 THEN
          RAISE;
        ELSE
          RAISE_APPLICATION_ERROR( -20002,': insert de TA_ENV_CUENTAS ' || sqlerrm );
        END IF;
 END;
END;
/

