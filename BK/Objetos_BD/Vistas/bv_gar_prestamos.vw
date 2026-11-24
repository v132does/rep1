create or replace force view it.bv_gar_prestamos as
Select a.nro_cuenta,
       to_char(a.fec_inicio, 'ddmmyyyy') || a.nro_solicitud || rownum fec_ini_solicitud_sec,
       a.fec_inicio,
       a.nro_solicitud,
       fug_obt_cli_principal(a.nro_cuenta) cliente,
       fue_obt_nom_persona(fug_obt_cli_principal(a.nro_cuenta)) nombre,
       a.cod_modalidad,
       fug_obt_des_modal(a.cod_modulo, a.cod_modalidad) des_cuenta,
       a.cod_moneda,
       a.mto_capital,
       a.sal_interes,
       a.sal_capital + a.sal_interes deuda_total,
       a.cod_oficina,
       fue_obt_des_oficina(a.cod_oficina) des_oficina,
       a.nro_documento,
       a.fec_Insercion,
       a.fec_vencimiento,
       a.fec_vencimiento - a.fec_inicio plazo,
       a.can_cuotas,
       a.cod_canal,
       a.cod_campana,
       a.nro_cta_debito,
       a.cob_automatico cob_automatico,
       fug_obt_nom_cuenta(a.nro_cta_debito) a_nombre_de,
       a.val_tasa,
       a.usu_modificacion,
       fue_obt_nom_usuario(bp.cod_usu_promotor) cod_usuario,
       bp.cod_usu_promotor,
       a.cat_renovaciones,
       a.nro_cta_renovada,
       a.tipo,
       decode(a.tipo,'P','Plazo Fijo','D','Descto. de Documentos','A','Amortizable') Des_tipo,
       decode(a.tip_documento, 1, 'Vista', 2, 'Vencimiento') Tipo_documento,
       a.estado,
       decode(a.estado,'C','Vigente','V','Vencido','G','En Gestion','M','Moroso','I','Irrecuperable','N','Cancelado') Est_Cuenta,
       a.tip_interes,
       decode(a.tip_interes, 'A', 'Adelantado', 'V', 'Vencido') des_tip_interes,
       a.mto_lin_aplicado,
       a.fec_ren_tas_orig Prox_Reneg,
       case when a.nro_sol_renovada is null then 'N' when a.nro_sol_renovada is not null then 'S' end Renovado,
       a.tip_renovacion For_Renov,
       b.cod_garantia,
       c.descripcion,
       b.mto_aplicado,
       b.nro_garantia,
       cta_orig_pag_vista.val_parametro cta_orig_pag_vista,
       fecha_renovacion.val_parametro fecha_renovacion,
       fec_emi_pag_vista.val_parametro fec_emi_pag_vista,
       fec_vto_pag_vista.val_parametro fec_vto_pag_vista,
       nro_doc_pag_vista.val_parametro nro_doc_pag_vista,
       renovado_en_cta.val_parametro renovado_en_cta,
       g.cod_gru_economico as cod_gru_economico,
       gr.descripcion as nom_gru_economico,
       fug_obt_contingencia_cliente(g.cod_persona) as contingencia_cliente,
       fug_obt_activo_cliente(g.cod_persona) as activo_cliente,
       gr.tot_deu_real as deu_real_gru_economico,
       gr.tot_deu_contingente as tot_deu_contingente
  From ba_personas bp,
       pr_cta_prestamos a,
       pr_cta_garantias b,
       pr_gar_tipos c,
       ge_clientes g,
       ge_gru_economicos gr,
       (select x.nro_cuenta, x.parametro, x.val_parametro
          from ge_cta_dat_adicionales x
         where x.parametro = 'CTA_ORIG_PAG_VISTA') CTA_ORIG_PAG_VISTA,
       (select xx.nro_cuenta, xx.parametro, xx.val_parametro
          from ge_cta_dat_adicionales xx
         where xx.parametro = 'FECHA_RENOVACION') FECHA_RENOVACION,
       (select xxx.nro_cuenta, xxx.parametro, xxx.val_parametro
          from ge_cta_dat_adicionales xxx
         where xxx.parametro = 'FEC_EMI_PAG_VISTA') FEC_EMI_PAG_VISTA,
       (select y.nro_cuenta, y.parametro, y.val_parametro
          from ge_cta_dat_adicionales y
         where y.parametro = 'FEC_VTO_PAG_VISTA') FEC_VTO_PAG_VISTA,
       (select yy.nro_cuenta, yy.parametro, yy.val_parametro
          from ge_cta_dat_adicionales yy
         where yy.parametro = 'NRO_DOC_PAG_VISTA') NRO_DOC_PAG_VISTA,
       (select yyy.nro_cuenta, yyy.parametro, yyy.val_parametro
          from ge_cta_dat_adicionales yyy
         where yyy.parametro = 'RENOVADO_EN_CTA') RENOVADO_EN_CTA
 where b.nro_cuenta = a.nro_cuenta
   and bp.cod_persona = b.cod_persona
   and g.cod_persona = bp.cod_persona
   and gr.cod_gru_economico (+)= g.cod_gru_economico
   and CTA_ORIG_PAG_VISTA.Nro_Cuenta(+) = a.nro_cuenta
   and FECHA_RENOVACION.Nro_Cuenta(+) = a.nro_cuenta
   and FEC_EMI_PAG_VISTA.Nro_Cuenta(+) = a.nro_cuenta
   and FEC_VTO_PAG_VISTA.Nro_Cuenta(+) = a.nro_cuenta
   and NRO_DOC_PAG_VISTA.Nro_Cuenta(+) = a.nro_cuenta
   and RENOVADO_EN_CTA.Nro_Cuenta(+) = a.nro_cuenta
   and b.cod_garantia = c.cod_garantia
 order by 1;

