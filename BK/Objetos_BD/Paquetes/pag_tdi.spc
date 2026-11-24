create or replace package it.pag_tdi is

---//Objetivo del paquete: Contener todas las funciones y Procedimientos sobre Tasas Depósitos Internos
--//Tasas Interpoladas


procedure pr_act_tas_interpolada;
                         
procedure pr_ins_ge_tas_interpolada (p_fec_vig_anterior date,
                                     p_sig_fec_vigencia date);
                                     
procedure pr_ins_tas_pro_ponderada;                                     
                                     
procedure pr_cal_tas_pro_ponderada (p_nro_cuenta    in     ge_cuentas.nro_cuenta%type,
                                    p_cod_tasa      in     ge_cal_tas_pro_ponderada_tmp.cod_tasa%type,
                                    p_val_tas_tpp   in out ge_tas_rangos.val_tasa%type);

procedure pr_ins_ge_tas_rangos_tmp;


function fu_obt_val_tas_interpolada  
                        (p_cod_modulo in ba_modulos.cod_modulo%type
                         ,p_cod_modalidad in ge_modalidades.cod_modalidad%type
                         ,p_cod_sub_modalidad in number
                         ,p_cod_oficina in ba_oficinas.cod_oficina%type 
                         ,p_nro_cuenta in ge_cuentas.nro_cuenta%type 
                         ,p_cod_moneda in ba_monedas.cod_moneda%type
                         ,p_dia_interpolar in ge_tas_rangos.val_hasta%type
                         ,p_cod_tasa in ge_tas_rangos.cod_tasa%type
                         ,p_fec_fin in date
                         ,p_fec_vigencia in ge_tas_rangos.fec_vigencia%type
                         ,p_cod_persona in ba_personas.cod_persona%type default null
                         ,p_cod_ente  in ge_entes.cod_ente%type default null)
                         return number;                                                                      
                                     
end;
/

