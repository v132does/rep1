create or replace package it.paa_alc is
  v_pro_correcto  number := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'), 0);
  v_err_sql       number := nvl(fug_obt_pardinamico('COD_ERR_SQL'), 999);
  v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_pro_cor_pen   number := nvl(fug_obt_pardinamico('COD_MEN_PRO_PEN'), 1);
  V_COD_MOD_ALC   GE_MODALIDADES.COD_MODALIDAD%TYPE := fug_obt_pardinamico('AHO_COD_MAD_ALC');

  -- creacion de alcancia
  procedure pr_cre_cta_alcancia(p_nro_cta_relacion ge_cuentas.nro_cuenta%type,
                                p_nro_cta_alcancia out ge_cuentas.nro_cuenta%type,
                                p_cod_error        out number,
                                p_men_error        out varchar2);

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

  --Obtiene el nro de cuenta alcancia principal
  function fu_obt_alc_principal(p_cod_persona ba_personas.cod_persona%type)
    return varchar2;

  -- Transferencia entre Cuentas
  procedure pr_gen_tra_cuentas(p_nro_cta_remitente ge_cuentas.nro_cuenta%type,
                               p_nro_cta_destino   ge_cuentas.nro_cuenta%type,
                               p_monto             ge_movimientos.monto%type,
                               p_tip_proceso       varchar2 default 'N',
                               p_cod_canal         varchar2 default 'N',
                               p_tipo              varchar2 default null,
                               p_referencia        ge_movimientos.nro_documento%type default null,
                               p_nro_trans         out ge_movimientos.nro_documento%type,
                               p_hora              out ge_movimientos.hora%type,
                               p_fecha             out ge_movimientos.fecha%type,
                               p_cod_error         out number,
                               p_men_error         out varchar2);

  procedure pr_cre_cta_ahorro(p_cod_persona      ba_personas.cod_persona%type,
                              p_cod_moneda       ba_monedas.cod_moneda%type default v_cod_mon_local,
                              p_tip_proceso      varchar2 default 'C', -- o: onbording, -- c: convencional
                              p_cod_error        out number,
                              p_men_error        out varchar2,
                              p_nro_cta_ahorro   out ge_cuentas.nro_cuenta%type,
                              p_nro_cta_alcancia out ge_cuentas.nro_cuenta%type,
                              p_nro_tarjeta      out ah_tar_debitos.nro_tarjeta%type);

  procedure pr_tra_no_clientes(p_nro_cuenta       ah_cta_vistas.nro_cuenta%type,
                               p_monto            ah_cta_vistas.sal_total%type,
                               p_nom_beneficiario varchar2,
                               p_nro_tel_benef    varchar2,
                               p_concepto         ge_sol_tra_cuentas.concepto%type,
                               p_nro_trans        out number,
                               p_cod_error        out number,
                               p_men_error        out varchar2);

  procedure pr_can_tra_no_cli(p_nro_transf number,
                              p_nro_cuenta varchar2,
                              p_fecha      date,
                              p_cod_canal  varchar2 default 'N',
                              p_cod_error  out number,
                              p_men_error  out varchar2);

  procedure pr_tra_pen_ahorro(p_cod_persona varchar2,
                              p_nva_cta     varchar2,
                              p_cod_error   out number,
                              p_men_error   out varchar2);

  --Envia aviso de error en generacion de cuenta
  procedure pr_env_mai_error(p_asunto    varchar2,
                             p_texto     varchar2,
                             p_cod_error out number,
                             p_men_error out varchar2);

  procedure pr_ins_alt_producto(p_tipo          varchar2,
                                p_indicador     varchar2,
                                p_parametro     varchar2,
                                p_val_parametro varchar2,
                                p_cod_error     out number,
                                p_men_error     out varchar2);

  procedure pr_pro_fondeo(p_nro_documento in varchar2,
                          p_cod_error     out number,
                          p_men_error     out varchar2);
  procedure pr_env_not_onb_productos(p_cod_persona   in ba_personas.cod_persona%type,
                                     p_nro_documento in ba_personas.nro_documento%type,
                                     p_correo        in ba_tab_dat_adicionales.val_parametro%type,
                                     p_tip_producto  in ba_tab_dat_adicionales.val_parametro%type,
                                     p_cod_error     out number,
                                     p_mensaje       out varchar2);
  procedure pr_env_not_sms(p_nro_telefono in varchar2,
                           p_texto        in varchar2,
                           p_cod_error    out number,
                           p_men_error    out varchar2);

  /*Creación de proceso para activar cuenta caja de ahorro persona jurídica*/                        
  procedure pr_cre_cta_ah_juridica(p_cod_persona    in ba_personas.cod_persona%type,
                                  p_cod_moneda     in ba_monedas.cod_moneda%type default v_cod_mon_local,
                                  p_cod_onboarding in ba_onb_empresas.cod_onb_emp%type,
                                  p_cod_error      out number,
                                  p_men_error      out varchar2,
                                  p_nro_cta_ahorro out ge_cuentas.nro_cuenta%type);

 /*Creación de proceso para activar cuenta mipymes persona jurídica*/                                
  procedure pr_cre_cta_ah_juridica_mipymes(p_cod_persona    in ba_personas.cod_persona%type,
                                  p_cod_moneda     in ba_monedas.cod_moneda%type default v_cod_mon_local,
                                  p_cod_onboarding in ba_onb_empresas.cod_onb_emp%type,
                                  p_cod_error      out number,
                                  p_men_error      out varchar2,
                                  p_nro_cta_ahorro out ge_cuentas.nro_cuenta%type);                            
end paa_alc;
/
