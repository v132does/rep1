create or replace procedure it.prp_pro_dat_seg_anual(p_tip_proceso in varchar2,
                                                  p_cod_ent_seguro in number default null,
                                                  p_cta_credito in varchar2 default null,
                                                  p_nro_solicitud in number default null,
                                                  p_cod_modalidad in number default null) is
  --Proyecto SDSEGVID-144--Seguro Anual de Consumo--
  v_pre_ind_mod_seg_anual ge_par_dinamicos.val_parametro%type;
  v_cod_rub_ganancia      cb_rubros.cod_rubro%type;
  v_cod_rub_cta_bancaria  cb_rubros.cod_rubro%type;
  v_tip_ente              ge_entes .tipo%type;
  v_tie_pag_seg_vid_anual ge_par_entes.val_parametro%type;

begin
  --Proyecto SDSEGVID-144--Seguro Anual de Consumo--
  if p_tip_proceso = 'I' then --Insertar ba_tab_dat_adicionales de la solicitud--
     v_pre_ind_mod_seg_anual := nvl(fug_obt_pardinamico('PRE_IND_MOD_SEG_ANUAL',6,p_cod_modalidad),'N');
     if nvl(v_pre_ind_mod_seg_anual,'N') = 'S' then
        insert into Ba_Tab_dat_Adicionales
        (TAB_RELACION, REFERENCIA, PARAMETRO, VAL_PARAMETRO)
        values
        ('PR_SOLICITUDES', p_nro_solicitud, 'PRE_PRO_CTA_SEG_ANUAL', 'S');
     end if;
  elsif p_tip_proceso = 'R' then --Reversion de cuentas de consumo pago anual--
     select decode(nvl(COUNT(*),0),0,'N','S')
       into v_tie_pag_seg_vid_anual
       from ba_tab_dat_adicionales t
      where t.tab_relacion = 'PR_SOLICITUDES'
        and t.parametro = 'PRE_PRO_CTA_SEG_ANUAL'
        and t.referencia = p_nro_solicitud
        and t.val_parametro = 'S';

     if nvl(v_tie_pag_seg_vid_anual,'N') = 'S' then
        --Proyecto SDSEGVID-144--Seguro Anual de Consumo--
        --Elimina datos de pr_cta_gas_seguros--
        delete from pr_cta_gas_seguros x
         where x.nro_solicitud = p_nro_solicitud;

        --Elimina datos de parametro por cuenta--
        delete from ba_tab_dat_adicionales t
         where t.tab_relacion = 'PR_SOLICITUDES'
           and t.parametro = 'PRE_PRO_CTA_SEG_ANUAL'
           and t.referencia = p_nro_solicitud
           and t.val_parametro = 'S';
    end if;
  end if;
end;
/

