create or replace package it.PAG_FIR is
    v_cod_sin_error number := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'),0);
    v_cod_err_sql number := nvl(fug_obt_pardinamico('COD_ERR_SQL'),999);
    v_pro_cor_pen number:= nvl(fug_obt_pardinamico('COD_MEN_PRO_PEN'),1);


    procedure pr_dis_documento(p_cod_documento in number,
                               p_tip_documento in varchar2,
                               p_nro_secuencia in number,
                               p_cod_beneficiario in varchar2);
                               
    procedure pr_obt_producto ( p_ind_producto varchar2,
                                p_cod_modulo out ba_modulos.cod_modulo%type,
                                p_cod_modalidad out ge_modalidades.cod_modalidad%type);

    procedure pr_val_sol_fir_cta (p_cod_persona bw_sol_fir_cuentas.cod_persona%type,
                                 p_cod_modulo bw_sol_fir_cuentas.cod_modulo%type,
                                 p_cod_modalidad bw_sol_fir_cuentas.cod_modalidad%type,
                                 p_ind_correcto out varchar,
                                 p_cod_error out number,
                                 p_men_error out varchar);

    procedure pr_ins_sol_firmantes (p_ind_producto varchar2,
                                    p_cod_persona bw_sol_fir_cuentas.cod_persona%type,
                                    p_nro_cedula bw_sol_fir_cuentas.nro_cedula%type,
                                    p_nro_telefono bw_sol_fir_cuentas.nro_telefono%type,
                                    p_dir_correo bw_sol_fir_cuentas.dir_correo%type,
                                    p_tip_vinculo bw_sol_fir_cuentas.cod_tip_vinculo%type,
                                    p_relacion bw_sol_fir_cuentas.relacion%type,
                                    p_cod_per_fir out bw_sol_fir_cuentas.cod_per_fir%type,
                                    p_cod_error out number, 
                                    p_men_error out varchar2);
    procedure pr_act_est_sol_fir (p_ind_producto varchar2,
                                  p_cod_persona bw_sol_fir_cuentas.cod_persona%type,
                                  p_cod_per_fir bw_sol_fir_cuentas.cod_per_fir%type,
                                  p_nro_ced_fir bw_sol_fir_cuentas.nro_cedula%type,
                                  p_estado bw_sol_fir_cuentas.est_firmante%type,
                                  p_cod_error out number, 
                                  p_men_error out varchar2);
    
   procedure pr_can_est_sol_fir;
   procedure pr_env_arc_fir_pen;
   
   PROCEDURE pr_ins_fir_cuentas (P_NRO_CUENTA GE_CTA_CLIENTES.NRO_CUENTA%TYPE,
                                 P_DIG_VERIFICADOR GE_CTA_CLIENTES.DIG_VERIFICADOR%TYPE,
                                 P_COD_OFICINA GE_CTA_CLIENTES.COD_OFICINA%TYPE,
                                 P_COD_PERSONA GE_CTA_CLIENTES.COD_PERSONA%TYPE,
                                 P_COD_MODULO GE_CTA_CLIENTES.COD_MODULO%TYPE,
                                 P_COD_MODALIDAD GE_CTA_CLIENTES.COD_MODALIDAD%TYPE, 
                                 P_TIE_SOL_FIRMANTES VARCHAR2,
                                 P_COD_ERROR OUT NUMBER,
                                 P_MEN_ERROR OUT VARCHAR2);
                                 
   procedure pr_gen_ext_req(p_cod_persona ba_personas.cod_persona%type,
                            p_nro_cuenta ge_cuentas.nro_cuenta%type,
                            p_cod_error out number,
                            p_men_error out varchar2);
                            
   procedure pr_act_tip_extracto(p_cod_persona  in ge_clientes.cod_persona%type,
                                  p_tip_extracto in ge_clientes.tip_extracto%type,
                                  p_cod_error    out number,
                                  p_men_error    out varchar2);
                                  
   procedure pr_val_sol_cta(p_cod_persona ge_cta_clientes.cod_persona%type,
                            p_cod_modulo ge_cta_clientes.cod_modulo%type,
                            p_cod_modalidad ge_cta_clientes.cod_modalidad%type,
                            p_ind_fir_correcto out varchar,
                            p_ind_doc_correcto out varchar);
                            
   procedure pr_can_est_sol_pen;
   
   PROCEDURE pr_aso_cant_firmas(p_cod_persona in ba_personas.cod_persona%TYPE,
                                p_cant_firmas in bw_rol_permisos.can_firmas%TYPE,
                                p_cod_error   out number,
                                p_mensaje     out varchar2);
   
   PROCEDURE pr_aso_firmas(p_nro_cuenta  in ah_cta_vistas.nro_cuenta%TYPE,
                           p_cod_persona in ba_personas.cod_persona%TYPE,
                           p_cod_error   out number,
                           p_mensaje     out varchar2);
                          
   procedure pr_alt_fir_cuentas(p_nro_cuenta in ah_cta_vistas.nro_cuenta%type,
                                p_cod_error   out number,
                                p_msj_error   out varchar2);
end PAG_FIR;
/

