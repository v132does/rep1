create or replace package it.pat_tgl is
  v_cod_mon_local       ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_pro_correcto        number := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'),
                                      0);
  v_pro_cor_pen         number := nvl(fug_obt_pardinamico('COD_MEN_PRO_PEN'),
                                      1);
  v_err_sql             number := nvl(fug_obt_pardinamico('COD_ERR_SQL'),
                                      999);
  v_cod_msg_exito       number := nvl(fug_obt_pardinamico('COD_MSG_EXITO'),
                                      200);
  v_ent_global          ah_tar_debitos.cod_ent_procesadora%type := fug_obt_pardinamico('COD_ENT_GLOBAL');
  v_cod_tar_deb_virtual ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('COD_TAR_DEB_VIRTUAL'),
                                                                   1);
  v_cod_tar_deb_fisica  ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('COD_TAR_DEB_FISICA'),
                                                                   0);

  /* procedimiento que habilita la tarjeta credito global */
  procedure pr_hab_tar_cre(p_nro_cta     in ta_cta_tarjetas.nro_cuenta%type,
                           p_cod_persona in ba_personas.cod_persona%type,
                           p_nro_tarjeta in ta_tarjetas.nro_tarjeta%type,
                           p_cod_error   out number,
                           p_men_error   out varchar2);

  /* procedimiento actualiza estado de la cuenta de la tarjeta credito global */
  procedure pr_act_cta_cre(p_nro_cta     in ta_cta_tarjetas.nro_cuenta%type,
                           p_cod_persona in ba_personas.cod_persona%type,
                           p_estado      in number,
                           p_cod_error   out number,
                           p_men_error   out varchar2);

  /* procedimiento actualiza estado de la tarjeta credito global */
  procedure pr_act_tar_cre(p_nro_cta     in ta_cta_tarjetas.nro_cuenta%type,
                           p_cod_persona in ba_personas.cod_persona%type,
                           p_nro_tarjeta in ta_tarjetas.nro_tarjeta%type,
                           p_estado      in number,
                           p_cod_error   out number,
                           p_men_error   out varchar2);

  -- llama al web service de acuerdo a la accion solicitada
  procedure pr_ws_conector(p_content     in varchar2, -- estructura jason
                           p_url         in varchar2, -- url para utilizar si es alta de cuenta o cambio estado
                           p_nro_cta     in varchar2, -- cuando es cambio de estado se requiere el nro de cuenta
                           p_cod_persona in varchar2, -- cod persona del cliente
                           p_accion      in varchar2, -- si es cambio de estado o alta
                           p_metodo      in varchar2, -- es el tipo de metodo PUT, POST, GET
                           p_cod_error   out number,
                           p_men_error   out varchar2);

procedure pr_ws_conector(p_content     in varchar2, -- estructura jason
                           p_url         in varchar2, -- url para utilizar si es alta de cuenta o cambio estado
                           p_nro_cta     in varchar2, -- cuando es cambio de estado se requiere el nro de cuenta
                           p_cod_persona in varchar2, -- cod persona del cliente
                           p_accion      in varchar2, -- si es cambio de estado o alta
                           p_metodo      in varchar2, -- es el tipo de metodo PUT, POST, GET
                           p_cod_error   out number,
                           p_men_error   out varchar2,
                           p_nro_cupon   out number);
  -- genera el pin de 4 digitos para la tarjeta
  procedure pr_gen_pin(p_cod_persona in varchar2, -- cod persona del cliente
                       p_nro_pin     out varchar2, -- pin generado para el cliente
                       p_cod_error   out number,
                       p_men_error   out varchar2);

  -- actualiza pin de tarjeta de credito global
  procedure pr_act_pin_tar(p_nro_cta     in ta_cta_tarjetas.nro_cuenta%type,
                           p_cod_persona in ba_personas.cod_persona%type,
                           p_nro_tarjeta in ta_tarjetas.nro_tarjeta%type,
                           p_pin         in varchar2,
                           p_cod_error   out number,
                           p_men_error   out varchar2);
  --actualiza limite de tarjeta de credito
    procedure pr_act_lim_tar(p_nro_cta     in ta_cta_tarjetas.nro_cuenta%type,
                           p_cod_persona in ba_personas.cod_persona%type,
                           p_nro_tarjeta in ta_tarjetas.nro_tarjeta%type,
                           p_lim         in number,
                           p_cod_error   out number,
                           p_men_error   out varchar2);

  -- actualiza pago de tarjeta de credito global
  procedure pr_act_pag_tar(p_nro_cta   in ta_cta_tarjetas.nro_cuenta%type,
                           p_monto     in ta_cobros.monto%type,
                           p_fecha     in ta_cobros.fec_proceso%type,
                           p_hora      in ge_movimientos.hora%type,
                           p_usuario   in ge_movimientos.cod_usuario%type,
                           p_cod_error out number,
                           p_men_error out varchar2,
                           p_nro_cupon out number);
  -- Generacion JSON p/ llamada a pagos de TC GP
  procedure pr_jsn_pag_tar(p_nro_cta   in ta_cta_tarjetas.nro_cuenta%type,
                           p_monto     in ta_cobros.monto%type,
                           p_fecha     in ta_cobros.fec_proceso%type,
                           p_hora      in ge_movimientos.hora%type,
                           p_usuario   in ge_movimientos.cod_usuario%type,
                           p_cod_error out number,
                           p_men_error out varchar2,
                           p_nro_cupon out number);
  -- realiza el debito de la cuenta ahorro/cte para realizar el pago de la tarjeta credito
  procedure pr_pag_tar_cre(p_nro_cta     in ta_cta_tarjetas.nro_cuenta%type,
                           p_nro_tarjeta in ta_tarjetas.nro_tarjeta%type,
                           p_nro_cta_deb in ta_cta_tarjetas.nro_cuenta%type,
                           p_monto       in ta_cobros.monto%type,
                           p_cod_canal   in varchar2 default 'N',
                           p_cod_error   out number,
                           p_men_error   out varchar2);
  -- realiza el debito de la cuenta ahorro/cte para realizar el pago de la tarjeta credito,retorna nro y fecha generados
  procedure pr_pag_tar_cre_doc(p_nro_cta     in ta_cta_tarjetas.nro_cuenta%type,
                           p_nro_tarjeta in ta_tarjetas.nro_tarjeta%type,
                           p_nro_cta_deb in ta_cta_tarjetas.nro_cuenta%type,
                           p_monto       in ta_cobros.monto%type,
                           p_cod_canal   in varchar2 default 'N',
                           p_cod_error   out number,
                           p_men_error   out varchar2,
                           p_nro_documento out varchar2,
                           p_fec_mov      out varchar2);
  -- genera la solicitud de tarjeta
  procedure pr_gen_sol_tarjeta(p_cod_persona     in varchar2,
                               p_cod_moneda      in varchar2,
                               p_monto           in number,
                               p_cod_tip_tarjeta in varchar2,
                               p_nro_cta_debito  in varchar2 default null,
                               p_cod_error       out number,
                               p_men_error       out varchar2,
                               p_nro_solicitud   out number);

  procedure pr_obt_montos_tar(p_tip_tarjeta in varchar2,
                              p_mto_minimo  out number,
                              p_mto_maximo  out number,
                              p_cod_error   out number,
                              p_men_error   out varchar2);

  /**
  * Procedimiento para verificar si posee una cuenta credito global
  **/
  procedure pr_ver_cta_credito(p_cod_persona in varchar2,
                               p_existe      out varchar2,
                               p_cod_error   out number,
                               p_men_error   out varchar2);

  /**
  * Procedimiento para cargar y parsear los datos json de la tabla temporal
  **/
  procedure pr_par_json(p_dato            in varchar2,
                        p_cod_persona     in varchar2,
                        p_nro_cuenta      in varchar2,
                        p_nro_cta_global  out varchar2,
                        p_id_producto     out varchar2,
                        p_nro_cta         out varchar2,
                        p_nro_bin         out varchar2,
                        p_nro_tarjeta     out varchar2,
                        p_fec_vencimiento out varchar2,
                        p_tipo_tarjeta    out varchar2);

  /**
  * Procedimiento alta de cuenta para tarjeta debito y/o prepaga en global
  **/
  procedure pr_cre_cta_global(p_nro_cta     in ge_cta_clientes.nro_cuenta%type,
                              p_cod_persona in ge_cta_clientes.cod_persona%type default null,
                              p_cod_error   out number,
                              p_men_error   out varchar2);
  /**
    * Procedimiento alta de cuenta para tarjeta credito por producto
  **/
   procedure pr_cre_cta_cre_gp(p_nro_doc   in ba_personas.nro_documento%TYPE,
                                  p_tip_producto in varchar2,
                                  p_cod_error out number,
                                  p_men_error out varchar2);

   /**
  * Procedimiento alta de cuenta para tarjeta debito y/o prepaga por tipo de producto
  **/
  procedure pr_cre_cta_deb_gp(p_nro_cta     in ge_cta_clientes.nro_cuenta%type,
                              p_cod_persona in ge_cta_clientes.cod_persona%type default null,
                              p_tip_producto in varchar2 DEFAULT NULL,
                              p_cod_error   out number,
                              p_men_error   out varchar2);

  /**
  * Funcion que retorna si existe en el core una tarjeta debito/prepaga ya creada en global
  **/
  function fu_exi_tar_debpre(p_nro_cuenta  ah_tar_debitos.nro_cuenta%type,
                             p_cod_persona ah_tar_debitos.cod_persona%TYPE DEFAULT NULL)
    return varchar2;

  /**
  * Procedimiento alta/solicitud de tarjeta de debito y/o prepaga en el core
  **/
  procedure pr_alt_tar_debpre(p_nro_cta_global  in ah_tar_debitos.nro_cta_global%type,
                              p_id_producto     in ah_tar_debitos.id_producto%type,
                              p_nro_cta         in ah_tar_debitos.nro_cuenta%type,
                              p_nro_bin         in ah_tar_debitos.nro_bin%type,
                              p_nro_tarjeta     in ah_tar_debitos.nro_tarjeta%type,
                              p_fec_vencimiento in ah_tar_debitos.fec_vencimiento%type,
                              p_tip_tarjeta     in varchar2,
                              p_cod_error       out number,
                              p_men_error       out varchar2);
  /**
  * Procedimiento alta de registro de tarjeta de credito en el Core
  **/
    procedure pr_alt_tar_cre(p_nro_cuenta  in ta_tarjetas.nro_cuenta%type,
                              p_nro_tarjeta     in ta_tarjetas.nro_tarjeta%type,
                              p_cod_persona in ta_tarjetas.cod_persona%type,
                              p_fec_vencimiento in ta_tarjetas.fec_vencimiento%type,
                              p_nom_embozar in ta_tarjetas.nom_embozar%type,
                              p_id_producto in ta_tarjetas.id_producto%type,
                              p_cod_error       out number,
                              p_men_error       out varchar2);

  /**
  * Procedimiento actualiza estado de tarjeta de debito y prepaga
  **/
  procedure pr_act_tar_debpre(p_nro_cta     in ah_tar_debitos.nro_cuenta%type,
                              p_cod_persona in ah_tar_debitos.cod_persona%type,
                              p_nro_tarjeta in ah_tar_debitos.nro_tarjeta%type,
                              p_estado      in ah_tar_debitos.cod_est_solicitud%type,
                              p_cod_error   out number,
                              p_men_error   out varchar2);

  /**
  * Procedimiento para bloquear/desbloquear tarjetas debito/prepaga
  **/
  procedure pr_blo_tar_debpre(p_nro_cuenta  in ah_tar_debitos.nro_cuenta%type,
                              p_nro_tarjeta in ah_tar_debitos.nro_tarjeta%type,
                              p_ind_estado  in varchar2,
                              p_cod_error   out number,
                              p_men_error   out varchar2);

  /**
  * Procedimiento para actualizar estado de la tarjeta
  **/
  procedure pr_act_est_tarjeta(p_nro_cuenta  in ah_tar_debitos.nro_cuenta%type,
                               p_nro_tarjeta in ah_tar_debitos.nro_tarjeta%type,
                               p_estado      in varchar2,
                               p_cod_error   out number,
                               p_men_error   out varchar2);

    procedure pr_act_est_tar_cre(p_nro_cuenta  in ah_tar_debitos.nro_cuenta%type,
                               p_nro_tarjeta in ah_tar_debitos.nro_tarjeta%type,
                               p_estado      in number,
                               p_cod_error   out number,
                               p_men_error   out varchar2);

  procedure pr_baj_tr_causa(p_nro_tarjeta         in ah_tar_debitos.nro_tarjeta%type,
                            p_nro_cuenta          in ah_tar_debitos.nro_cuenta%type,
                            p_motivo              in varchar2,
                            p_tip_tarjeta         in ah_tar_debitos.tip_tar_debito%type,
                            p_nro_tar_deb_virtual out varchar2,
                            p_cod_transaccion     out varchar2,
                            p_fec_transaccion     out varchar2,
                            p_cod_error           out number,
                            p_men_error           out varchar2);
  /**
  * Procedimiento para cancelar tarjeta
  **/
  procedure pr_can_tar_debpre(p_nro_cuenta   in ah_tar_debitos.nro_cuenta%type,
                              p_nro_tarjeta  in ah_tar_debitos.nro_tarjeta%type,
                              p_motivo       in ah_tar_debitos.motivo%type,
                              p_cod_error    out number,
                              p_men_error    out varchar2,
                              p_est_anterior out varchar2);

  /* procedimiento para bloqueo automatico en el proceso de cierre*/
  PROCEDURE pr_blo_aut_tar_debpre;

  /**
  * Procedimiento para reemplazar/reimprimir tarjeta de debito.
  **/
  procedure pr_tar_reimprimir(p_nro_cuenta      in ah_tar_debitos.nro_cuenta%type,
                              p_nro_tarjeta     in ah_tar_debitos.nro_tarjeta%type,
                              p_nro_bin         in ah_tar_debitos.nro_bin%type,
                              p_fec_vencimiento in ah_tar_debitos.fec_vencimiento%type,
                              p_tip_tarjeta     in ah_tar_debitos.tip_tar_debito%type,
                              p_cod_error       out number,
                              p_men_error       out varchar2);
  /**
  * Procedimiento para reemplazar/reimprimir tarjeta de debito.
  **/
  procedure pr_ser_reimprimir(p_nro_cta     in ta_cta_tarjetas.nro_cuenta%type,
                              p_nro_tarjeta in ah_tar_debitos.nro_tarjeta%type,
                              p_tip_tarjeta     in ah_tar_debitos.tip_tar_debito%type,
                              p_cod_error       out number,
                              p_men_error       out varchar2);

  /*
  ** Procedimiento que realiza las operaciones abm de estado p/ viajes al exterior
  */
  procedure pr_tar_avi_exterior(p_cod_viaje       in ta_avi_via_exterior.cod_viaje%type,
                                p_tip_adicional   in ta_avi_via_exterior.tip_adicional%type default null,
                                p_nro_cuenta      in ta_avi_via_exterior.nro_cuenta%type default null,
                                p_fec_vig_inicial in ta_avi_via_exterior.fec_vig_inicial%type default null,
                                p_fec_vig_final   in ta_avi_via_exterior.fec_vig_final%type default null,
                                p_nro_tarjeta     in ta_avi_via_exterior.nro_tarjeta%type default null,
                                p_lis_cod_pais    in ta_avi_via_exterior.lis_cod_pais%type default null,
                                p_accion          in varchar2,
                                p_cod_error       out number,
                                p_men_error       out varchar2);

  /**
  * Procedimiento para alta de tarjeta de credito.
  **/
  procedure pr_alt_tar_credito(p_nro_cuenta      in ta_tar_global_tmp.nro_cuenta%type,
                               p_cod_persona     in ta_tar_global_tmp.cod_persona%type,
                               p_nro_tarjeta     in ta_tar_global_tmp.nro_tarjeta%type,
                               p_fec_vencimiento in ta_tar_global_tmp.fec_vencimiento%type,
                               p_tip_tarjeta     in ta_tar_global_tmp.tip_tarjeta%type,
                               p_cod_producto    in ta_tar_global_tmp.cod_producto%type,
                               p_cod_error       out number,
                               p_men_error       out varchar2);

  /**
  * Procedimiento para alta de tarjeta de credito desde solicitud.
  **/
  procedure pr_alt_tar_sol_credito(p_cod_persona   in ta_tar_global_tmp.cod_persona%type,
                                   P_nro_solicitud in ta_solicitudes.nro_solicitud%type,
                                   p_cod_error     out number,
                                   p_men_error     out varchar2);

  /**
   * Procedimiento para remplazo de tarjetas (debito/credito).
  **/
  procedure pr_tar_reemplazo(p_nro_cuenta      in ah_tar_debitos.nro_cta_global%type, --cta glp
                             p_cod_persona     in ah_tar_debitos.cod_persona%type,
                             p_nro_tarjeta     in ta_tar_global_tmp.nro_tarjeta%type,
                             p_fec_vencimiento in ah_tar_debitos.fec_vencimiento%type,
                             p_nro_sobre       in varchar2,
                             p_principal       in varchar2,
                             p_tip_tarjeta     in ta_tar_global_tmp.tip_tarjeta%type, --fisica/virtual
                             p_cod_error       out number,
                             p_men_error       out varchar2);


  /**
    * Procedimiento alta de cuenta para tarjeta credito virtual
  **/
  procedure pr_cre_tar_vir_global(p_nro_doc   in ba_personas.nro_documento%type,
                                  p_cod_error out number,
                                  p_men_error out varchar2);

  /**
    * Procedimiento vinculacion tD virtual a fisica
  **/
  procedure pr_vin_tar_deb_fisica(p_nro_cedula        in ba_personas.nro_documento%type,
                                  p_nro_sob_principal in VARCHAR2,
                                  p_cod_error         out number,
                                  p_men_error         out varchar2);
  /**
    * Procedimiento baja de tarjetas por cod_persona
  **/                                
 procedure pr_baj_tar_tmp(p_cod_persona   in ta_tarjetas.cod_persona%TYPE);

  /**
    * Procedimiento vinculacion tc virtual a fisica
  **/
  procedure pr_vin_tar_credito(p_nro_doc           in ba_personas.nro_documento%type,
                               p_nro_sob_principal in ta_imp_dat_embozados.nro_sob_pro_principal%type,
                               p_cod_error         out number,
                               p_men_error         out varchar2);

  /**
    * Procedimiento registro de solicitudes sobre tarjetas
  **/

    procedure pr_act_sol_tarjeta(p_tip_solicitud in ta_sol_global.tipo_solicitud%type,
                               p_nro_tarjeta   in ta_imp_dat_embozados.nro_sob_pro_principal%type,
                               p_nro_cuenta    in ta_imp_dat_embozados.nro_cuenta%type,
                               p_motivo        in ta_sol_global.motivo%type,
                               p_est_pin       in ta_sol_global.est_pin%type default null,
                               p_causa         in ta_sol_global.cod_causa%type default null,
                               p_cod_solicitud out varchar2,
                               p_cod_error     out number,
                               p_men_error     out varchar2);

  /*Procedimiento que cancela los avisos al exterior*/
  procedure pr_can_tar_avi_exterior(p_cod_viaje  in ta_avi_via_exterior.cod_viaje%type,
                                    p_nro_cuenta in ta_avi_via_exterior.nro_cuenta%type,
                                    p_cod_error  out number,
                                    p_men_error  out varchar2);

 /* --Alta viaje exterior tarjeta credito */
  procedure pr_alt_via_ext_cre(p_nro_cta         in ta_cta_tarjetas.nro_cuenta%type,
                               p_cod_persona     in ba_personas.cod_persona%type,
                               p_lis_cod_pais    in ta_avi_via_exterior.lis_cod_pais%type,
                               p_fec_vig_inicial in ta_avi_via_exterior.fec_vig_inicial%type,
                               p_fec_vig_final   in ta_avi_via_exterior.fec_vig_final%type,
                               p_cod_viaje       in ta_avi_via_exterior.cod_viaje%type,
                               p_cod_error       out number,
                               p_men_error       out varchar2);

  /* --Alta viaje exterior tarjeta debito */
  procedure pr_alt_via_ext_deb(p_nro_cta         in ta_cta_tarjetas.nro_cuenta%type,
                               p_cod_persona     in ba_personas.cod_persona%type,
                               p_lis_cod_pais    in ta_avi_via_exterior.lis_cod_pais%type,
                               p_fec_vig_inicial in ta_avi_via_exterior.fec_vig_inicial%type,
                               p_fec_vig_final   in ta_avi_via_exterior.fec_vig_final%type,
                               p_cod_viaje       in ta_avi_via_exterior.cod_viaje%type,
                               p_cod_error       out number,
                               p_men_error       out varchar2);
  /*Procedimiento que actualiza el estado de pagos */
  procedure prt_act_pag_gp(p_nro_cuenta   ta_cobros_gp.nro_cuenta%type,
                           p_fecha        ta_cobros_gp.fec_proceso%type,
                           p_hora         ta_cobros_gp.hora%type,
                           p_usuario      ta_cobros_gp.cod_usuario%type,
                           p_estado         ta_cobros_gp.est_envio%type,
                           p_cod_error    out number,
                           p_men_error    out varchar2,
                           p_nro_documento in ta_cobros_gp.nro_documento%type default null);
  /* procedimiento que actualiza estados en tablas */
  procedure pr_act_motivo(p_cod_persona in ba_personas.cod_persona%type,
                          p_nro_cuenta  in ta_cta_tarjetas.nro_cuenta%type,
                          p_nro_tarjeta in ta_tarjetas.nro_tarjeta%type,
                          p_motivo      in ta_sol_global.motivo%type,
                          p_cod_causa   in ta_sol_global.cod_causa%type,
                          p_tip_tarjeta in varchar2,
                          p_cod_error   out number,
                          p_men_error   out varchar2);
  /*Procedimiento que devuelve los datos de direccion/telefono/email para enviar a GP*/
  PROCEDURE pr_obt_dat_clientes (p_cod_persona IN ba_personas.cod_persona%TYPE,
                                 p_direccion OUT ba_direcciones.direccion%TYPE,
                                 p_numero OUT ba_direcciones.numero%TYPE,
                                 p_piso OUT ba_direcciones.piso%TYPE,
                                 p_departamento OUT ba_direcciones.departamento%TYPE,
                                 p_cod_postal OUT ba_direcciones.cod_postal%TYPE,
                                 p_barrio OUT ba_barrios.descripcion%TYPE,
                                 p_tel_particular OUT ba_telefonos.telefono%TYPE,
                                 p_tel_celular OUT ba_telefonos.telefono%TYPE,
                                 p_email OUT ba_personas.dir_correo%TYPE
                                 );
  /**
   * Procedimiento para realizar upgrade de TD clasica a black
  **/
  procedure pr_upg_deb_blk_gp(p_nro_cuenta     in ah_tar_debitos.nro_cta_global%type, --cta glp
                             p_id_producto     in ah_tar_debitos.id_producto%type,
                             p_nro_cta         in ah_tar_debitos.nro_cuenta%type,
                             p_nro_tarjeta     in ah_tar_debitos.nro_tarjeta%type,
                             p_fec_vencimiento in ah_tar_debitos.fec_vencimiento%type,
                             p_tip_tarjeta     in ah_tar_debitos.tip_tar_debito%type,
                             p_nro_sobre       in varchar2,
                             p_cod_error       out number,
                             p_men_error       out varchar2);
    /**
   * Procedimiento para realizar upgrade de TC clasica a black
  **/
  procedure pr_upg_cre_blk_gp(p_nro_cuenta     in ta_tarjetas.nro_cuenta%type, --cta glp
                             p_nro_tarjeta     in ta_tarjetas.nro_tarjeta%type,
                             p_fec_vencimiento in ta_tarjetas.fec_vencimiento%type,
                             p_nro_sobre       in varchar2,
                             p_cod_error       out number,
                             p_men_error       out varchar2);
  /*Procedimiento que actualiza los movimientos de las cuentas que realizan upgrade*/                           
  PROCEDURE pr_act_mov_upgrade(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE,
                               p_cod_persona IN ba_personas.cod_persona%TYPE,
                               p_cod_mad_anterior IN ge_cuentas.cod_modalidad%TYPE,
                               p_cod_mad_actual IN ge_cuentas.cod_modalidad%TYPE);
    /*Procedimiento para persistencia de datos al activar una tc*/
  procedure pr_ins_dat_tarjetas_gp(p_cod_persona     in ba_personas.cod_persona%type,
                                   p_nro_cuenta      in ta_tarjetas.nro_cuenta%type,
                                   p_nro_tarjeta     in ta_tarjetas.nro_tarjeta%type,
                                   p_fec_vencimiento in ta_tarjetas.fec_vencimiento%type,
                                   p_tip_embozado    in ta_tarjetas.tip_embozado%type,
                                   p_tip_producto    in varchar2,
                                   p_lin_credito     in ta_cta_tarjetas.lin_credito%type,
                                   p_embozado        in ta_tarjetas.nom_embozar%type,
                                   p_cod_moneda      in ta_cta_tarjetas.cod_moneda%type,
                                   p_nro_cta_ahorro  in ah_tar_debitos.nro_cuenta%type,
                                   p_plan_u          in varchar2,
                                   p_cod_error       out number,
                                   p_men_error       out varchar2); 
end pat_tgl;
/
