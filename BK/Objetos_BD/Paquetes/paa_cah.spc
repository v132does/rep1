create or replace package it.paa_cah is
  v_pro_correcto  number := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'), 0);
  v_err_sql       number := nvl(fug_obt_pardinamico('COD_ERR_SQL'), 999);
  v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;

  --Obtener tasa
  procedure pr_obt_tasa(p_cod_modulo    ba_modulos.cod_modulo%type,
                        p_cod_modalidad ge_modalidades.cod_modalidad%type,
                        p_cod_moneda    ba_monedas.cod_moneda%type,
                        p_cod_oficina   ah_cta_vistas.cod_oficina%type,
                        p_fec_apertura  ah_cta_vistas.fec_apertura%type,
                        p_tasa_actual   number,
                        P_cod_tasa      out ah_cta_vistas.cod_tasa%type);

  -- Generacion de Movimientos
  procedure pr_gen_movimientos(p_fecha           in ge_calendarios.fec_actual%type,
                               p_nro_secuencia   in ge_movimientos.nro_secuencia%type,
                               p_hora            in ge_movimientos.hora%type,
                               p_cod_tra_padre   in ge_transacciones.cod_transaccion%type,
                               p_cod_modulo      ge_movimientos.cod_modulo%type,
                               p_cod_modalidad   ge_movimientos.cod_modalidad%type,
                               p_nro_cuenta      ge_movimientos.nro_cuenta%type,
                               p_cod_moneda      ge_movimientos.cod_moneda%type,
                               p_cod_oficina     ge_movimientos.cod_oficina%type,
                               p_est_cuenta      ge_movimientos.est_cuenta%type,
                               p_cod_transaccion in ge_transacciones.cod_transaccion%type,
                               p_monto           in ge_movimientos.monto%type,
                               p_nro_documento   in ge_movimientos.nro_documento%type,
                               p_cod_causa       in ge_movimientos.cod_causa%type,
                               p_emi_aviso       in ge_movimientos.emi_aviso%type,
                               p_cod_tasa        in ge_movimientos.cod_tasa%type,
                               p_val_tasa        in ge_movimientos.val_tasa%type,
                               p_cod_error       out number,
                               p_men_error       out varchar2,
                               p_cod_usuario     in varchar2 default null,
                               p_concepto        in varchar2 default null);

  procedure pr_cre_cta_ahorro(p_cod_persona      ba_personas.cod_persona%type,
                              p_cod_moneda       ba_monedas.cod_moneda%type default v_cod_mon_local,
                              p_cod_modalidad ge_tas_fechas.cod_modalidad%type,
                              p_cod_sub_modalidad ge_tas_fechas.cod_sub_modalidad%type,
                              p_cod_error        out number,
                              p_men_error        out varchar2,
                              p_nro_cta_ahorro   out ge_cuentas.nro_cuenta%type);
 
  procedure pr_cre_cta_ahorro2(p_cod_persona       ba_personas.cod_persona%type,
                               p_cod_moneda        ba_monedas.cod_moneda%type default v_cod_mon_local,
                               p_cod_modalidad     ge_tas_fechas.cod_modalidad%type,
                               p_cod_sub_modalidad ge_tas_fechas.cod_sub_modalidad%type,
                               p_cta_billetera     ge_cta_dat_adicionales.val_parametro%type default 'N',
                               p_cod_error         out number,
                               p_men_error         out varchar2,
                               p_nro_cta_ahorro    out ge_cuentas.nro_cuenta%type);

  procedure pr_env_not_onb_productos(p_cod_persona   in ba_personas.cod_persona%type,
                                     p_nro_documento in ba_personas.nro_documento%type,
                                     p_tip_producto  in ba_tab_dat_adicionales.val_parametro%type,
                                     p_cod_error     out number,
                                     p_mensaje       out varchar2);
                         
end paa_cah;
/
