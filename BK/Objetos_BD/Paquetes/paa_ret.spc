CREATE OR REPLACE PACKAGE IT.paa_ret IS

  --Variables Globales en
  g_cod_tas_inr ge_tasas.cod_tasa%type := 208;
  g_cod_tra_inr ge_transacciones.cod_transaccion%type := 9603;

  --Proceso insercion retenciones Ley 6380 - INR
  procedure pr_ins_ge_inr_retenciones(pg_dret     ge_inr_retenciones%rowtype,
                                      p_cod_error in out varchar2);

  --Proceso Generacion de Retenciones INR Ahorros
  procedure pr_gen_inr_ret_ahorros(p_fec_pago      ge_inr_retenciones.fec_pago%type default null,
                                   p_nro_secuencia in out ge_movimientos.Nro_Secuencia%type,
                                   p_mto_retencion in out ge_inr_retenciones.mto_retencion%type,
                                   p_nro_cuenta    ge_inr_retenciones.nro_cuenta%type default null,
                                   p_cod_modulo    ge_cuentas.cod_modulo%type default null,
                                   p_cod_modalidad ge_cuentas.cod_modalidad%type default null);

  --Proceso Generacion de Retenciones INR CDA
  procedure pr_gen_inr_ret_cda(p_fecha           ge_inr_retenciones.fec_pago%type,
                               p_nro_cuenta      ah_cta_certificados.nro_cuenta%type default null,
                               p_cod_tra_padre   ge_movimientos.cod_tra_padre%type,
                               p_cod_mod_padre   ge_movimientos.cod_mod_padre%type,
                               p_cod_mad_padre   ge_movimientos.cod_mad_padre%type,  
                               p_cod_transaccion ge_movimientos.cod_transaccion%type,
                               p_hora            ge_movimientos.hora%type default null,
                               p_nro_secuencia   in out ge_movimientos.nro_secuencia%type,
                               p_mto_retencion   in out ge_inr_retenciones.mto_retencion%type);

  
  ---Proceso de actualizacion 
  procedure pr_act_ge_inr_retenciones(pg_actret          ge_inr_retenciones%rowtype); 
 
  ---Funcion para obtener monto retencion CDA 
  function fu_obt_inr_ret_cda(p_nro_cuenta      ah_cta_certificados.nro_cuenta%type,
                              p_cod_modalidad   ah_cta_certificados.cod_modalidad%type,
                              p_serie           ah_cta_certificados.serie%type,
                              p_nro_certificado ah_cta_certificados.nro_certificado%type,
                              p_cod_moneda      ah_cta_certificados.cod_moneda%type,
                              p_nro_cupon       ah_cupones.nro_cupon%type,
                              p_fecha           ge_movimientos.fecha%type) return number;
    
  procedure pr_gen_notificaciones;

end;
/

