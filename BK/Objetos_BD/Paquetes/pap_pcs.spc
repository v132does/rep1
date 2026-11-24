CREATE OR REPLACE PACKAGE IT.pap_pcs IS
  procedure pr_obt_val_cuota(p_nro_solicitud       in pr_solicitudes.nro_solicitud%type default null,
                             p_cod_modalidad       in number,
                             p_cod_moneda          in varchar2,
                             p_monto               in number,
                             p_can_cuotas          in number,
                             p_mto_refuerzo        in number default 0,
                             p_can_cuo_refuerzo    in number default 0,
                             p_val_tasa            in number,
                             p_fec_inicio          in date,
                             p_fec_pri_vencimiento in date,
                             p_dias                in number default null,
                             p_exo_impuesto in varchar2 default 'N');

  procedure pr_obt_val_refuerzo(p_nro_solicitud in pr_sol_cuo_ref_tmp.nro_solicitud%type,
                                p_nro_cuota     in pr_sol_cuo_ref_tmp.nro_cuota%type,
                                p_mto_refuerzo  in out pr_sol_cuo_ref_tmp.val_int_original%type);

  procedure pr_gen_cal_cuo_refuerzo(p_nro_solicitud in pr_solicitudes.nro_solicitud%type,
                                    p_cod_modalidad in number,
                                    p_cod_moneda in varchar2,
                                    p_fec_inicio in date,
                                    p_exo_impuesto in varchar2 default 'N');

 function fu_obt_cal_cuo_ref_tmp 
          (p_nro_solicitud  in pr_solicitudes.nro_solicitud%type,
           p_nro_cuota  in pr_sol_cal_cuo_tmp.nro_cuota%type) return pr_sol_cal_cuo_tmp%rowtype;
           
 procedure pr_ins_val_refuerzo 
          (rg_cuoref pr_sol_cuo_ref_tmp%rowtype);       

 procedure pr_act_val_refuerzo (p_nro_solicitud number);

 procedure pr_eli_calculos_tmp;
                      
END pap_pcs;
/

