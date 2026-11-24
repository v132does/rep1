create or replace package it.PAS_CAS is
  -- (c) 2023 - ITTI DIGITAL
  -- Autores: César Armoa  - Patricia Sanchez
  -- Created : 17/05/2023
  -- Purpose : Gestionar envio y recepcion de datos para alta de alias (CAS)

 /*Variables Constantes*/
  g_fec_actual          constant date   := pag_cal.fu_obt_fec_actual(1);
   g_gru_dir_correo      constant ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico( 'SNP_GRU_DIR_CORREO' );

  /*Manejo de Errores*/
  g_lugar               varchar2(250);
  g_msj_error           varchar2(1000);
  g_cod_error           number(3)   default 0;

  /*EXCEPCIONES*/
   ex_salir              exception;

  /*para control de ms*/
  v_compilado constant varchar2(1) := 'S';

  /*procedure que utilizara el servcio para validar  si el paquete es valido*/
  procedure pr_paq_compilado ;

  /*Obtiene el código de error del registro del paquete.*/
  function fu_obt_cod_error return number;

  /*Obtiene el mensaje de error contenido en el registro del paquete.*/
  function fu_obt_msj_error return varchar2;

 /*Obtiene el tipo de persona .*/
  function fu_obt_tip_per(p_cod_persona in ba_personas.cod_persona%type) return varchar2;

  /*Inicializa las variables de error*/
  procedure pr_ini_variables;

   /*Obtiene el Código Swift de la Entidad*/
  function fu_obt_cod_swi_participante( p_cod_persona in ba_personas.cod_persona%type ) return varchar;

  /*Registra LOG de la mensajería*/
  procedure pr_reg_operacion( p_mensaje   in long,
                              p_respuesta in varchar2
                            );
  /*Obtiene el siguiente número de referencia para el MT*/
  function fu_obt_sig_ref_cas( p_fecha in ge_spi_con_cas.fecha%type default null ) return number;

  /*recupera cargo*/
  PROCEDURE pr_obt_cargo( p_cod_ofi_cta       in     ge_cuentas.cod_oficina%type
                          ,p_nro_cuenta        in     ge_cuentas.nro_cuenta%type
                          ,p_cod_moneda        in     ge_cuentas.cod_moneda%type
                          ,p_val_transaccion   in     ge_movimientos.monto%type
                          ,p_cod_modulo        in     ge_cuentas.cod_modulo%type
                          ,p_cod_modalidad     in     ge_cuentas.cod_modalidad%type
                          ,p_tas_personalizada in     ge_cuentas.tas_personalizada%type
                          ,p_cod_tra_cargo     in     ge_movimientos.cod_transaccion%type
                          ,p_cod_tas_cargo     in out ge_movimientos.cod_tasa%type
                          ,p_val_tas_cargo        out ge_movimientos.val_tasa%type
                          ,p_val_cargo            out ge_movimientos.val_tasa%type
                         );
 /*genera movimientos para cobro de alias*/
 PROCEDURE pr_gen_mov_cargo( p_referencia     in     ge_movimientos.referencia%type,
                            rg_cta_cliente    in     pag_cta.rg_ctas,
                            p_hora            in     ge_movimientos.hora%type,
                            p_nro_secuencia   in out ge_movimientos.nro_secuencia%type
                          );
 /*verifica el estado del modulo*/
 PROCEDURE pr_ver_horario(p_cod_modulo in ba_modulos.cod_modulo%type);

  /*procedimiento para insertar consulta de cas*/
  procedure pr_ins_consul_cas(p_tip_consulta      in ge_spi_con_cas.tip_consulta%type,
                              p_tip_identificador in ge_spi_con_cas.tip_identificador%type,
                              p_val_identificador in ge_spi_con_cas.val_identificador%type,
                              p_cod_persona       in ge_spi_con_cas.cod_persona%type default null,
                              p_nro_referencia   out GE_SPI_CON_CAS.NRO_REFERENCIA%type);
  /*funcion que genera cabecera para ms */
  function fu_obt_dat_Cab_concas(p_nro_referencia in ge_spi_con_cas.nro_referencia%type )return typ_obtdatcabconcas;

  /*procedure que se comunica con el ms*/
   procedure pr_obt_concas(p_dat_cab_cons_cas     out typ_obtdatcabconcas,
                            p_dat_cons_cas        out typ_ObtConsDatosCas,
                            p_dat_mensaje         out typ_mensajeria_spi );
   /*procedure que recibe respuesta de  ms*/
   procedure pr_pro_msj_rec_con_cas (p_res_concas in typ_ObtDatResCas,
                                     p_dat_mensaje out typ_mensajeria_spi);

   /*procedure que inserta datos cliente cas*/
  procedure pr_ins_clie_cas(p_dat_cons_cas in out typ_obtregclicas,
                            P_CANAL        in varchar2,
                            p_accion       in varchar2 default null);

  /*procedure que se comunica con el ms para dar de alta un cliente en cas*/
  procedure pr_obt_dat_cli_cas (p_dat_cab_cons_cas out typ_obtdatcabconcas,
                                p_dat_cons_cas     out typ_obtregclicas,
                                p_dat_mensaje      out typ_mensajeria_spi);
  /*procedure que RECIBE la respuesta de alta un cliente en cas*/
  procedure pr_pro_msj_rec_cli_cas (p_dat_cons_cas     in typ_ObtDatResCli,
                                    p_dat_mensaje      out typ_mensajeria_spi);

 /*procedure que inserta datos en una tabla para edicion */
  procedure pr_edi_clie_cas(p_dat_cons_cas in out typ_obtregclicas,
                            p_accion       in varchar2,
                            p_canal       in varchar2 default null);

  /*procedure que se comunica con el ms para dar editar, actualizar o eliminar un cliente en CAS*/
  procedure pr_obt_edi_cli_cas(p_dat_cab_cons_cas out typ_ObtdatCabconcas ,
                               p_dat_cons_cas     out typ_ObtEdiclicas,
                               p_dat_mensaje      out typ_mensajeria_spi);

 /*procedure que se comunica con el ms para recepcionar respuesta de Edicion, update o delete de cliente en CAS*/
 procedure pr_pro_msj_rec_edi_cas(p_dat_cons_cas     in typ_ObtEdiclicas,
                                  p_dat_mensaje      out typ_mensajeria_spi);

 procedure pr_ins_cta_cas(p_dat_cta_cas in out typ_insctacas,
                          P_CANAL        in varchar2,
                          p_accion       in varchar2 default null );

 procedure pr_obt_dat_cta_cas (p_dat_cab_cons_cas out typ_ObtdatCabconcas,
                               p_dat_cons_cas     out typ_ObtRegctacas,
                               p_dat_mensaje      out typ_mensajeria_spi);

 PROCEDURE pr_pro_msj_rec_cta_cas(p_res_cta_cas   in typ_ObtDatResCta,
                                  p_dat_mensaje   out typ_mensajeria_spi);

  procedure pr_edi_cta_cas(p_dat_cta_cas  in out typ_insctacas,
                           p_accion       in varchar2,
                            p_canal       in varchar2 default null );

  procedure pr_obt_dat_conf_cta_cas( p_dat_cab_cons_cas     out typ_ObtdatCabconcas,
                                     p_dat_cons_cas         out typ_ObtRegedictacas,
                                     p_dat_mensaje          out typ_mensajeria_spi);

  procedure pr_pro_msj_rec_edi_cta (p_dat_cons_cas in typ_ObtRegedictacas,
                                     p_dat_mensaje out typ_mensajeria_spi);

  procedure pr_ins_ali_cas(p_dat_ali_cas in out GE_SPI_ALI_CAS%ROWTYPE,
                           P_CANAL       in varchar2,
                           p_accion      in varchar2 default null  );

  procedure pr_obt_dat_ali_cas(p_dat_cab_cons_cas out typ_ObtdatCabconcas,
                                p_dat_cons_cas    out typ_ObtRegalicas,
                                p_dat_mensaje     out typ_mensajeria_spi);

  procedure pr_pro_msj_rec_ali_cas(p_dat_ali_cas    in typ_obtdatresali,
                                   p_dat_mensaje     out typ_mensajeria_spi);

  procedure pr_edi_ali_cas(p_dat_ali_cas in out GE_SPI_ALI_CAS%ROWTYPE,
                           p_accion      in varchar2,
                           p_canal       in varchar2 default null);

  procedure pr_obt_edi_ali_cas (p_dat_cab_cons_cas out typ_ObtdatCabconcas,
                                p_dat_ali_cas      out typ_obtedialicas,
                                p_dat_mensaje      out typ_mensajeria_spi);


 procedure pr_pro_msj_rec_edi_ali(p_dat_ali_cas   in typ_obtedialicas,
                                  p_dat_mensaje   out typ_mensajeria_spi);

end PAS_CAS;
/

