create or replace package it.PAS_SNP is

  -- Autor     : FBOGADO, JGONZALEZ
  -- Creado    : 24/08/2011 05:50:08 p.m.
  -- Propósito : Gestionar envío/recepción de MTs para el Sistema Nacional de Pagos

  --Types--

  --Tipo de dato para cobro de servicios
  type t_tab_cob_servicio is table of ge_cob_servicios%rowtype INDEX BY binary_integer;

  --Tipo de dato para la mensajería
  type rg_msj is record
  (nro_referencia               ge_snp_transferencias.nro_referencia%type
  ,nro_lote                     ge_snp_transferencias.nro_lote%type
  ,nro_sec_lote                 ge_snp_transferencias.nro_sec_lote%type
  ,cod_modulo                   ge_snp_transferencias.cod_modulo%type
  ,cod_modalidad                ge_snp_transferencias.cod_modalidad%type
  ,cod_oficina                  ge_snp_transferencias.cod_oficina%type
  ,cod_msj_swift                ge_snp_transferencias.cod_msj_swift%type
  ,cod_tip_operacion            ge_snp_transferencias.cod_tip_operacion%type
  ,cod_sub_tip_operacion        ge_snp_transferencias.cod_sub_tip_operacion%type
  ,msj_swift                    ge_snp_transferencias.msj_swift%type
  ,fec_ingreso                  ge_snp_transferencias.fec_ingreso%type
  ,fec_recepcion                ge_snp_transferencias.fec_recepcion%type
  ,fec_valor                    ge_snp_transferencias.fec_valor%type
  ,fecha                        ge_snp_transferencias.fecha%type
  ,hora                         ge_snp_transferencias.hora%type
  ,cod_usuario                  ge_snp_transferencias.cod_usuario%type
  ,cod_moneda                   ge_snp_transferencias.cod_moneda%type
  ,monto                        ge_snp_transferencias.monto%type
  ,cod_per_solicitante          ge_snp_transferencias.cod_per_solicitante%type
  ,nom_solicitante              ge_snp_transferencias.nom_solicitante%type
  ,dir_solicitante              ge_snp_transferencias.dir_solicitante%type
  ,cod_tip_doc_solicitante      ge_snp_transferencias.cod_tip_doc_solicitante%type
  ,nro_doc_solicitante          ge_snp_transferencias.nro_doc_solicitante%type
  ,nro_cta_solicitante          ge_snp_transferencias.nro_cta_solicitante%type
  ,cod_swi_pte_solicitante      ge_snp_transferencias.cod_swi_pte_solicitante%type
  ,cod_swi_suc_solicitante      ge_snp_transferencias.cod_swi_suc_solicitante%type
  ,nro_cta_pte_solicitante      ge_snp_transferencias.nro_cta_pte_solicitante%type
  ,nro_cta_suc_pte_solicitante  ge_snp_transferencias.nro_cta_suc_pte_solicitante%type
  ,cod_per_beneficiario         ge_snp_transferencias.cod_per_beneficiario%type
  ,nom_beneficiario             ge_snp_transferencias.nom_beneficiario%type
  ,dir_beneficiario             ge_snp_transferencias.dir_beneficiario%type
  ,cod_tip_doc_beneficiario     ge_snp_transferencias.cod_tip_doc_beneficiario%type
  ,nro_doc_beneficiario         ge_snp_transferencias.nro_doc_beneficiario%type
  ,nro_cta_beneficiario         ge_snp_transferencias.nro_cta_beneficiario%type
  ,cod_swi_pte_beneficiario     ge_snp_transferencias.cod_swi_pte_beneficiario%type
  ,cod_swi_suc_beneficiario     ge_snp_transferencias.cod_swi_suc_beneficiario%type
  ,nro_cta_pte_beneficiario     ge_snp_transferencias.nro_cta_pte_beneficiario%type
  ,nro_cta_suc_pte_beneficiario ge_snp_transferencias.nro_cta_suc_pte_beneficiario%type
  ,concepto                     ge_snp_transferencias.concepto%type
  ,observacion                  ge_snp_transferencias.observacion%type
  ,nro_ref_externa              ge_snp_transferencias.nro_ref_externa%type
  ,tip_cargo                    ge_snp_transferencias.tip_cargo%type
  ,mto_cargo                    ge_snp_transferencias.mto_cargo%type
  ,ind_valor                    ge_snp_transferencias.ind_valor%type
  ,situacion                    ge_snp_transferencias.situacion%type
  ,estado                       ge_snp_transferencias.estado%type
  ,tip_rechazo                  ge_snp_transferencias.tip_rechazo%type
  ,prioridad                    ge_snp_transferencias.prioridad%type
  ,nro_operacion                ge_snp_transferencias.nro_operacion%type
  ,tip_mensaje                  ge_snp_transferencias.tip_mensaje%type
  ,cod_usu_transaccion          ge_snp_transferencias.cod_usu_transaccion%type
  ,ref_oid                      ge_snp_transferencias.ref_oid%type
  ,imp_inf_hacienda             ge_snp_transferencias.imp_inf_hacienda%type
  ,error                        ge_snp_transferencias.error%type
  ,origen                       ge_snp_transferencias.origen%type
  ,plataforma                   ge_snp_transferencias.plataforma%type
  ,indemnizado                  ge_snp_transferencias.indemnizado%type
  ,cod_servicio                 ge_snp_transferencias.cod_servicio%type
  ,usu_insercion                ge_snp_transferencias.usu_insercion%type
  ,usu_modificacion             ge_snp_transferencias.usu_modificacion%type
  ,fec_insercion                VARCHAR2(25)
  ,ben_dir_correo               ge_snp_transferencias.ben_dir_correo%type
  ,cod_tra_padre                ge_snp_transferencias.cod_tra_padre%type
  ,nro_cta_pte_corresponsal     ge_snp_transferencias.nro_cta_pte_corresponsal%type
  ,nom_corresponsal             ge_snp_transferencias.nom_corresponsal%type
  ,cod_bco_corresponsal         ge_snp_transferencias.cod_bco_corresponsal%type
  ,nro_cta_pte_intermediario    ge_snp_transferencias.nro_cta_pte_intermediario%type
  ,dir_intermediario            ge_snp_transferencias.dir_intermediario%type
  ,cod_swi_pte_intermediario    ge_snp_transferencias.cod_swi_pte_intermediario%type
  ,nom_intermediario            ge_snp_transferencias.nom_intermediario%type
  ,cod_per_intermediario        ge_snp_transferencias.cod_per_intermediario%type
  ,cod_swi_pte_corresponsal     ge_snp_transferencias.cod_swi_pte_corresponsal%type
  );
  --Tipo de dato catastro
  type rg_cat is record
  (nro_orden                    sb_snp_catastros.nro_orden%type
  ,estado                       sb_snp_catastros.estado%type
  ,origen                       sb_snp_catastros.origen%type
  ,cod_mensaje                  sb_snp_catastros.cod_mensaje%type
  ,cod_moneda                   sb_snp_catastros.cod_moneda%type
  ,monto                        sb_snp_catastros.monto%type
  ,ind_mto_fijo                 sb_snp_catastros.ind_mto_fijo%type
  ,fec_vencimiento              sb_snp_catastros.fec_vencimiento%type
  ,dia_envio                    sb_snp_catastros.dia_envio%type
  ,cod_per_solicitante          sb_snp_catastros.cod_per_solicitante%type
  ,cod_tip_doc_solicitante      sb_snp_catastros.cod_tip_doc_solicitante%type
  ,nro_doc_solicitante          sb_snp_catastros.nro_doc_solicitante%type
  ,nro_doc_receptor             sb_snp_catastros.nro_doc_receptor%type
  ,cod_tip_per_solicitante      sb_snp_catastros.cod_tip_per_solicitante%type
  ,nom_solicitante              sb_snp_catastros.nom_solicitante%type
  ,dir_solicitante              sb_snp_catastros.dir_solicitante%type
  ,cod_swi_pte_solicitante      sb_snp_catastros.cod_swi_pte_solicitante%type
  ,nro_cta_pte_solicitante      sb_snp_catastros.nro_cta_pte_solicitante%type
  ,nro_cta_solicitante          sb_snp_catastros.nro_cta_solicitante%type
  ,cod_per_receptor             sb_snp_catastros.cod_per_receptor%type
  ,cod_tip_doc_receptor         sb_snp_catastros.cod_tip_doc_receptor%type
  ,cod_tip_per_receptor         sb_snp_catastros.cod_tip_per_receptor%type
  ,nom_receptor                 sb_snp_catastros.nom_receptor%type
  ,dir_receptor                 sb_snp_catastros.dir_receptor%type
  ,cod_swi_pte_receptor         sb_snp_catastros.cod_swi_pte_receptor%type
  ,nro_cta_pte_receptor         sb_snp_catastros.nro_cta_pte_receptor%type
  ,nro_cta_receptor             sb_snp_catastros.nro_cta_receptor%type
  ,usu_insercion                sb_snp_catastros.usu_insercion%type
  ,fec_insercion                sb_snp_catastros.fec_insercion%type
  ,usu_modificacion             sb_snp_catastros.usu_modificacion%type
  ,fec_modificacion             sb_snp_catastros.fec_modificacion%type
  ,nro_referencia               sb_snp_catastros.nro_referencia%type
  ,nro_ref_externa              sb_snp_catastros.nro_ref_externa%type
  ,fec_registro                 sb_snp_catastros.fec_registro%type
  ,titular_servicio             sb_snp_catastros.titular_servicio%type
  ,cod_servicio                 sb_snp_catastros.cod_servicio%type
  ,can_cuotas                   sb_snp_catastros.can_cuotas%type
  ,tip_rechazo                  sb_snp_catastros.tip_rechazo%type
  ,fec_recepcion                sb_snp_catastros.fec_recepcion%type);
--Tipo de dato para los datos del participante
  type rg_pte is record
  (cod_persona              ge_snp_transferencias.cod_per_solicitante%type
  ,nom_persona              ge_snp_transferencias.nom_solicitante%type
  ,cod_tip_doc_persona      ge_snp_transferencias.cod_tip_doc_solicitante%type
  ,nro_doc_persona          ge_snp_transferencias.nro_doc_solicitante%type
  ,dir_persona              ge_snp_transferencias.dir_solicitante%type
  ,ind_swi_propio           ge_snp_transferencias.ind_valor%type
  ,ind_hab_pte_hb           ge_snp_transferencias.ind_valor%type
  ,ind_val_fmt_msj_recibido ge_snp_transferencias.ind_valor%type
  );

  --Tipo para formatear el Tag72 para mensajes 202 (PHT)
  --Creado por TRFS-1187, corregido por TRFS-1366
  TYPE r_tag72_md IS RECORD (BILLETE varchar2(40), MONTO varchar(40));
  TYPE t_tag72_md IS TABLE OF r_tag72_md index by pls_integer;

  /*Manejo de Errores*/
  g_lugar               varchar2(250);
  g_msj_error           varchar2(1000);
  g_cod_error           number(3)   default 0;
  g_det_msj_error       ge_snp_transferencias.error%type := null;

  /*Excepciones*/
  ex_workflow           exception;
  ex_salir              exception;
  ex_horario            exception;

  /*Datos de la Operacion*/
  g_fec_actual          constant date   := pag_cal.fu_obt_fec_actual(1);
  g_cod_mon_local       varchar2(3)     := pag_gen.fu_obt_mon_local;
  g_cod_mon_iso_local   varchar2(3)     := 'PYG';
  --g_max_msj_lote        constant number := 15; -- Cantidad maxima de mensajes dentro de un lote.
  g_max_msj_lote        constant ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico( 'SNP_CANT_MAX_MSJ_LOTE' ); --DA-5476 MGF 26/09/2022
  g_err_dir_correo      constant ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico( 'SNP_ERR_DIR_CORREO' );
  g_gru_dir_correo      constant ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico( 'SNP_GRU_DIR_CORREO' );
  g_err_dir_tesoreria   constant ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico( 'SNP_ERR_DIR_TESORERIA' );
  g_usu_xadapter        constant ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico( 'SNP_USU_XADAPTER' );
  g_msj rg_msj;
  g_cat rg_cat;
  g_pte rg_pte;
  g_ref_invalida        boolean:=false;
  r_sb_snp_catastros    sb_snp_catastros%rowtype := null;
  g_tip_doc             sb_snp_catastros.cod_tip_doc_solicitante%type;
  g_documento           sb_snp_catastros.nro_doc_solicitante%type;
  g_cod_ser             sb_snp_catastros.cod_servicio%type;
  g_nro_referencia      ge_snp_mensajes.nro_referencia%type;
  /*Inicializa las variables de error*/
  procedure pr_ini_variables;

  /*Inicializa variables del tipo ROWTYPE*/
  procedure pr_ini_registros;

  /*Retorna la siguiente HORA de GE_MOVIMIENTOS*/
  function fu_ini_hora( p_fecha   in date default sysdate,
                        p_formato in varchar2 default 'HH24:MI:SS'
                      ) return varchar2;

  /*Adiciona datos a un texto*/
  procedure pr_set_texto ( p_texto     in out varchar2,
                           p_dato      in varchar2,
                           p_separador in varchar2 default ' '
                         );

  /*Recupera los datos de la mensajería*/
  procedure pr_obt_mensaje( p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                            p_ind_validar    in char default 'S'
                          );

  /*Recupera los datos del Participante*/
  procedure pr_obt_dat_participante( p_cod_swi_participante in     ge_snp_transferencias.cod_swi_pte_solicitante%type,
                                     rg_dat_pte             in out rg_pte
                                   );

  /*Invierte un mensaje RECIBIDO para operaciones de reversos*/
  procedure pr_gen_msj_invertido( rg_msj_ent in  pas_snp.rg_msj,
                                  rg_msj_sal out pas_snp.rg_msj
                                );

  /*Recupera el número de referencia interno de la mensajería ENVIADA o RECIBIDA para un MT900 ó MT910*/
  function fu_obt_nro_ref_interna( p_referencia       in ge_snp_transferencias.nro_ref_externa%type,
                                   p_cta_participante in ge_snp_transferencias.nro_cta_pte_solicitante%type,
                                   p_fec_valor        in ge_snp_transferencias.fec_valor%type default null
                                 ) return number;

  /*Retorna la descripción del tipo/subtipo de operación según el MT*/
  function fu_obt_des_tip_operacion( p_cod_swift         in ge_snp_transferencias.cod_msj_swift%type,
                                     p_tip_operacion     in ge_snp_transferencias.cod_tip_operacion%type,
                                     p_sub_tip_operacion in ge_snp_transferencias.cod_sub_tip_operacion%type default null
                                   ) return varchar2;

  /*Retorna la descripción del grupo de prioridades para los mensajes*/
  function fu_obt_des_prioridad ( p_tip_prioridad in varchar2 ) return varchar2;

  /*Retorna datos necesarios para la generación de movimientos para los MTs*/
  procedure pr_obt_par_mensajes( p_cod_swift         in  ge_snp_transferencias.cod_msj_swift%type,
                                 p_tip_operacion     in  ge_snp_transferencias.cod_tip_operacion%type,
                                 p_sub_tip_operacion in  ge_snp_transferencias.cod_sub_tip_operacion%type default null,
                                 p_ind_transaccion   in  varchar2 default 'E',
                                 p_cod_modulo        out ge_transacciones.cod_modulo%type,
                                 p_cod_modalidad     out ge_transacciones.cod_modalidad%type,
                                 p_cod_transaccion   out ge_transacciones.cod_transaccion%type
                               );

  /*Retorna la confirmación/rechazo de los MTs recibidos*/
  function fu_obt_msj_confirmacion( p_cod_swift       in  ge_snp_mensajes.cod_msj_swift%type,
                                    p_nro_ref_externa in  ge_snp_mensajes.nro_ref_externa%type,
                                    p_fec_valor       in  ge_snp_mensajes.fec_valor%type,
                                    p_ref_oid         out ge_snp_transferencias.ref_oid%type
                                  ) return varchar2;

  /*Retorna el tipo de movimiento dependiendo de la transacción*/
  function fu_obt_tip_mov_transaccion( p_cod_modulo      in ge_transacciones.cod_modulo%type,
                                       p_cod_modalidad   in ge_transacciones.cod_modalidad%type,
                                       p_cod_transaccion in ge_transacciones.cod_transaccion%type
                                     ) return varchar2;

  /*Obtiene la Cuenta registrada en ITGF según el Número de Cuenta registrado y formateado en los MTs RECIBIDOS */
  procedure pr_obt_cta_interna( p_nro_cuenta            in  ge_snp_transferencias.nro_cta_beneficiario%type,
                                p_tip_documento         in  ba_personas.cod_tip_documento%type,
                                p_nro_documento         in  ba_personas.nro_documento%type,
                                p_nro_cta_interno       out ge_cuentas.nro_cuenta%type,
                                p_cod_persona           out ba_personas.cod_persona%type
                              );

  /*Verifica que el número de tarjeta sea válido*/
  procedure pr_ver_nro_tarjeta( p_nro_tarjeta in  ge_snp_transferencias.nro_cta_beneficiario%type,
                                p_nro_cuenta  out ta_tarjetas.nro_cuenta%type
                              );

  /*Envía alertas al Cliente y al Oficial*/
  procedure pr_env_alerta( rg_msj_alerta in rg_msj,
                           p_tip_alerta  in varchar2 default 'C'
                         );

  /*Setea el indicador de envío de alertas al Cliente y al Oficial*/
  procedure pr_set_env_alerta( p_env_alerta varchar2 );

  /*Convierte un monto de una moneda a otra*/
  procedure pr_con_mon_a_moneda ( p_cod_mon_original in     ba_monedas.cod_moneda%type,
                                  p_cod_mon_destino  in     ba_monedas.cod_moneda%type,
                                  p_mto_mon_original in     number,
                                  p_mto_mon_destino  out    number,
                                  p_cot_mon_original in out number,
                                  p_cot_mon_destino  in out number
                                );

  /*Obtiene el concepto predefinido para movimientos, reversiones, etc*/
  function fu_obt_mov_concepto ( p_tipo       in varchar2 default 'M',
                                 p_origen     in ge_snp_transferencias.origen%type default 'I',
                                 p_referencia in ge_snp_transferencias.nro_ref_externa%type
                               ) return varchar2;

  /*Obtiene la denominación del Participante*/
  function fu_obt_des_participante( p_cod_swift in ge_bancos.cod_swift%type ) return varchar;

  /*Obtiene el indicador de BIC proporcionado por SWIFT o bien por el SIPAP, esto es para los cambios de letras en los TAGS, Ej. 50A ó 50D*/
  function fu_obt_ind_swi_propio( p_cod_swift in ge_bancos.cod_swift%type ) return boolean;

  /*Obtiene el Código Swift de la Entidad*/
  function fu_obt_cod_swi_participante( p_cod_persona in ba_personas.cod_persona%type ) return varchar;

  /*Obtiene la Cta. Física en BCP del participante según la moneda*/
  function fu_obt_cta_ban_participante( p_cod_swift  in ge_snp_transferencias.cod_swi_pte_solicitante%type,
                                        p_cod_moneda in ba_monedas.cod_moneda%type
                                      ) return varchar;

  /*Obtiene la Moneda de la Cta. Física en BCP */
  function fu_obt_mon_cta_participante ( p_nro_cta_participante in ge_snp_cta_bancos.nro_cta_bancaria%type,
                                         p_cod_moneda_cta_participante in ge_snp_patrocinador_cab.cod_moneda%type default null ) return varchar;

  /*Obtiene el estado actual del horario permitido para envio/recepcion de SWIFTs en BCP*/
  function fu_obt_est_horario ( p_cod_msj_swift     in ge_snp_transferencias.cod_msj_swift%type,
                                p_tip_operacion     in ge_snp_transferencias.cod_tip_operacion%type,
                                p_sub_tip_operacion in ge_snp_transferencias.cod_sub_tip_operacion%type
                              ) return varchar2;

  /* Cierra todos los períodos de la fecha actual en la tabla GE_SNP_HORARIOS */
  procedure pr_act_est_horario;

  /*Obtiene el siguiente número de referencia para el MT*/
  function fu_obt_sig_nro_referencia( p_fecha in ge_snp_transferencias.fecha%type default null ) return number;

  /*Obtiene el siguiente número de lote para el MT102*/
  function fu_obt_sig_nro_lote( p_fecha in ge_snp_transferencias.fecha%type default null ) return number;

  /*Verifica si la operación tiene mensajería duplicada*/
  function fu_ver_mov_duplicados( rg_msj_dup in rg_msj ) return number;

  /*Verifica si la operación tiene mensajería duplicada*/
  function fu_ver_mov_duplicados ( p_nro_referencia in ge_snp_transferencias.nro_referencia%type ) return number;

  /*Verifica si la operación RECIBIDA está duplicada*/
  function fu_ver_msj_duplicados ( p_nro_ref_externa in ge_snp_transferencias.nro_ref_externa%type,
                                   p_fec_valor       in ge_snp_transferencias.fec_valor%type
                                 ) return varchar2;

  /*Genera la cabecera del Mensaje a enviar*/
  function fu_obt_cab_msj_swift( p_nro_referencia in ge_snp_transferencias.nro_referencia%type ) return varchar;

  /*Procesa la cabecera del Mensaje recibido*/
  procedure pr_pro_cab_msj_swift( p_mensaje  in  long,
                                  rg_msj_rec out pas_snp.rg_msj
                                );

  /*Reemplaza G_SALTO por (*)asterisco antes de enviar la mensajería al socket*/
  function fu_con_mensaje ( p_msj in long ) return long;

  /*Envía la mensajería al socket*/
  procedure pr_gen_arc_swift( p_nro_referencia    in ge_snp_transferencias.nro_referencia%type,
                              p_val_movimientos   in varchar2 default 'S',
                              p_estado            in ge_snp_transferencias.estado%type default 'A'
                            );

  /*Envía la mensajería en LOTE al socket*/
  procedure pr_gen_arc_swi_lote ( p_msj_lote in long );

  /*Genera mensajeria parcial a partir del Movimiento*/
  procedure pr_gen_mov_snp ( p_hora           in  ge_movimientos.hora%type,
                             p_fecha          in  ge_movimientos.fecha%type,
                             p_cod_usuario    in  ge_movimientos.cod_usuario%type,
                             p_gen_workflow   in  varchar2 default 'S',
                             p_origen         in  ge_snp_transferencias.origen%type default 'I',
                             p_plataforma     in  ge_snp_transferencias.plataforma%type default 'X',
                             p_nro_ref_externa in  ge_snp_transferencias.nro_ref_externa%type default null,
                             p_ind_enviado     in  varchar2 default 'S',
                             p_cod_programa   out ba_programas.cod_programa%type,
                             p_nro_referencia out ge_snp_transferencias.nro_referencia%type,
                             p_cod_tra_padre   in  ge_snp_transferencias.cod_tra_padre%type default null
                           );

  /*Valida la cuenta bancaria del participante*/
  function fu_val_cta_ban_participante ( p_cod_swift            in ge_snp_transferencias.cod_swi_pte_solicitante%type,
                                         p_cod_moneda           in ba_monedas.cod_moneda%type,
                                         p_nro_cta_participante in ge_snp_cta_bancos.nro_cta_bancaria%type
                                       ) return varchar;

  /*Valida el dato ingresado contra ITGF*/
  function fu_val_dat_ingresado ( p_sql in varchar2 ) return boolean;

  /*Valida datos cargados contra la configuración realizada en la tabla GE_PAR_MENSAJES*/
  function fu_val_par_mensajes ( p_cod_swift         in ge_snp_transferencias.cod_msj_swift%type,
                                 p_tip_operacion     in ge_snp_transferencias.cod_tip_operacion%type,
                                 p_sub_tip_operacion in ge_snp_transferencias.cod_sub_tip_operacion%type default null
                               ) return boolean;

  /*Valida datos del perfil del cliente*/
  function fu_val_perfil ( rg_msj_perfil in pas_snp.rg_msj ) return boolean;

  /*Excluye de la cadena los caracteres no permitidos en la mensajería según SWIFT CHARACTER SET del CMA*/
  function fu_val_cadena ( p_cadena in varchar2 ) return varchar2;

  /*Expone de la cadena solamente los tipos de caracteres permitidos.*/
  function fu_val_cadena ( p_cadena in varchar2,
                           p_tipo   in varchar2
                         ) return varchar2;

  /*Valida que la fecha valor ingresada como parámetro no sobrepase los días hábiles permitidos en BCP.*/
  function fu_val_fec_valor ( p_fec_valor  in ge_snp_transferencias.fec_valor%type,
                              p_fec_actual in ge_snp_transferencias.fecha%type default null
                            ) return number;

  /*Obtiene la fecha en la cual se debería enviar la mensajería*/
  function fu_obt_fec_transferencia ( p_cod_msj_swift     in ge_snp_transferencias.cod_msj_swift%type,
                                      p_tip_operacion     in ge_snp_transferencias.cod_tip_operacion%type,
                                      p_sub_tip_operacion in ge_snp_transferencias.cod_sub_tip_operacion%type,
                                      p_fec_valor         in ge_calendarios.fec_actual%type
                                    ) return date;

  /*Obtiene la última fecha de intercambio de mensajes con BCP*/
  function fu_obt_fec_ult_operacion return date;

  /*Genera el movimiento de la operación a partir de la mensajería*/
  procedure pr_pro_principal( rg_msj_mov in out rg_msj );

  /*Genera el movimiento de transferencia a partir de la mensajería*/
  procedure pr_pro_transferencia( rg_msj_mov_tra in out rg_msj );

  /*Genera movimientos por Cobro de Cargos. Utilizado para Obtener datos desde la BD a los Formularios*/
  procedure pr_gen_mov_cargo( rg_msj_tra          in     pas_snp.rg_msj,
                              p_cta_cliente       in     ge_cuentas.nro_cuenta%type,
                              p_cta_interbancaria in     ge_cuentas.nro_cuenta%type,
                              p_mto_cliente       in     ge_movimientos.monto%type,
                              p_hora              in     ge_movimientos.hora%type,
                              p_nro_secuencia     in out ge_movimientos.nro_secuencia%type
                            );

  /*Genera movimientos por Cobro de Cargos*/
  procedure pr_gen_mov_cargo( rg_msj_tra           in     pas_snp.rg_msj,
                              rg_cta_cliente       in     pag_cta.rg_ctas,
                              rg_cta_interbancaria in     pag_cta.rg_ctas,
                              p_mto_cliente        in     ge_movimientos.monto%type,
                              p_hora               in     ge_movimientos.hora%type,
                              p_nro_secuencia      in out ge_movimientos.nro_secuencia%type
                            );

  /*Genera movimientos para indemnizar al Cliente por procesos de transferencias recibidos y atrasados*/
  procedure pr_gen_mov_indemnizacion( rg_cta_cliente  in     pag_cta.rg_ctas,
                                      rg_mensaje      in out pas_snp.rg_msj,
                                      p_mto_cliente   in     ge_movimientos.monto%type,
                                      p_hora          in     ge_movimientos.hora%type,
                                      p_nro_secuencia in out ge_movimientos.nro_secuencia%type
                                    );

  /*Genera y envía mensajería de Reverso para MTs ENVIADOS y RECIBIDOS mediante el mensaje ORIGINAL*/
  procedure pr_pro_msj_rechazado( rg_msj in out rg_msj );

  /*Envía mail por errores encontrados durante el proceso de REVERSION*/
  procedure pr_env_mail( p_dir_correo in ge_par_dinamicos.val_parametro%type,
                         p_tit_mail   in varchar2,
                         rg_msj_mail  in pas_snp.rg_msj,
                         p_det_error  in varchar2 default null
                       );

  /*Envía mail con adjunto*/
  procedure pr_env_mai_attachment( p_dir_correo  in ge_par_dinamicos.val_parametro%type,
                                   p_tit_mail    in varchar2,
                                   p_det_archivo in long,
                                   p_nom_archivo in varchar2
                                 );

  /*Envía mail de alertas para MT's Recibidos Alto Valor que aún no fueron procesados desde el WF*/
  procedure pr_gen_msj_alt_val_workflow( p_fec_valor in ge_snp_transferencias.fec_valor%type );

  /*Envía mail de alertas para MT's Recibidos Bajo Valor que aún no fueron procesados desde el WF*/
  procedure pr_gen_msj_baj_val_workflow( p_fec_valor in ge_snp_transferencias.fec_valor%type );

  /*Procesa valores para la insercion en GE_SNP_MENSAJES cuando no está esquematizado y envia mail*/
  FUNCTION fu_reg_msj_generico  ( p_mensaje          in clob,
                                  p_ind_msj_recibido in varchar2 default 'S',
                                  p_env_mail         in varchar2 default 'S'
                               ) return varchar2;

  /*Función que carga la mensajería recibida desde el Socket*/
  function fu_pro_msj_recibidos ( p_mensaje in clob ) return varchar2;

  /*Procesa la mensajería RECIBIDA (MT103)*/
  function fu_pro_msj_mt103( p_mensaje in long ) return varchar2;

  /* Formatea el Tag 72 para mensajes 202 PHT */
  FUNCTION  fu_formato_tag72(p_tag_72 varchar2) RETURN VARCHAR2;

  /*Procesa la mensajería RECIBIDA (MT202)*/
  function fu_pro_msj_mt202( p_mensaje in long ) return varchar2;

  /*Procesa la mensajería RECIBIDA (MT102)*/
  function fu_pro_msj_mt102( p_mensaje in long ) return varchar2;

  /*Función que procesa los MT900 y MT910 (Confirmación de Débito y Crédito)*/
  function fu_pro_msj_confirmacion( p_mensaje in long ) return varchar2;

  /*Retorna el monto formateado para SNP*/
  function fu_obt_mto_formato( p_monto          in ge_snp_transferencias.monto%type,
                               p_cod_moneda     in ge_snp_transferencias.cod_moneda%type,
                               p_ind_agr_moneda in varchar2 default 'S'
                             ) return varchar2;

  /*Procesa la mensajería RECIBIDA (MTn99)*/
  function fu_pro_msj_mtn99( p_mensaje in long ) return varchar2;

  /*Procesa la mensajería RECIBIDA (MTn96)*/
  function fu_pro_msj_mtn96( p_mensaje in long ) return varchar2;

  /*Procesa la recepción del MT986/PCLT, y envía el MTn99/SETACCOUNTLIMIT en Respuesta*/
  function fu_pro_msj_mt986( p_mensaje in long ) return varchar2;

  /* Se inserta datos en la tabla GE_SNP_TRANSFERENCIAS */
  procedure pr_ins_transferencias ( rg_msj_ins_tra in rg_msj );

  /*Obtiene la mensajería a ENVIAR (MT103)*/
  function fu_obt_msj_mt103( p_nro_referencia  in ge_snp_transferencias.nro_referencia%type,
                             p_val_movimientos in varchar2 default null
                           ) return varchar2;

  /*Obtiene la mensajería a ENVIAR (MT202)*/
  function fu_obt_msj_mt202( p_nro_referencia  in ge_snp_transferencias.nro_referencia%type,
                             p_val_movimientos in varchar2 default 'S'
                           ) return varchar2;

  /*Obtiene la mensajería a ENVIAR (MT102)*/
  procedure pr_obt_msj_mt102( p_fecha          in ge_snp_transferencias.fecha%type default null,
                              p_ver_cuenta     in varchar2 default 'N',
                              p_val_movimiento in varchar2 default 'S'
                            );

  /*Cancela un MT enviado de alto valor puesto en Cola de Espera*/
  procedure pr_obt_msj_mtn92( p_nro_referencia in ge_snp_transferencias.nro_referencia%type );

  /*Cambia la prioridad de un MT enviado de alto valor el cual se encuentra en Cola de Espera*/
  procedure pr_obt_msj_mtn95 ( p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                               p_tip_mensaje    in varchar2,
                               p_prioridad      in ge_snp_transferencias.prioridad%type default null
                             );

  /*Envia MT199 de Solicitud de Información*/
  procedure pr_obt_msj_mtn99( p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                              p_observacion    in varchar2
                            );

  /*Obtiene el registro G_MSJ que contiene los datos de GE_SNP_TRANSFERENCIAS*/
  function fu_obt_reg_transferencias return rg_msj;

  /*Obtiene el código de error del registro del paquete.*/
  function fu_obt_cod_error return number;

  /*Obtiene el mensaje de error contenido en el registro del paquete.*/
  function fu_obt_msj_error return varchar2;

  /*Obtiene un detalle de todos los errores encontrados durante la validación de MTs.*/
  function fu_obt_det_msj_error return varchar2;

  /*Inicia WORKFLOW*/
  procedure pr_ini_workflow ( rg_msj_ini_wfl in rg_msj );

  /*Cancela WORKFLOW abierto con relación a la transferencia*/
  procedure pr_can_workflow ( p_referencia in wf_circuitos.referencia%type );

  /*Verifica si existe WORKFLOW abierto*/
  function fu_ver_workflow ( p_referencia in wf_circuitos.referencia%type ) return boolean;

  /*Recupera el código de circuito de workflow dependiendo del origen E=Enviado, R=Recibido, C=Reversado*/
  function fu_obt_cod_tip_cir_workflow( p_cod_swift         in ge_snp_transferencias.cod_msj_swift%type,
                                        p_tip_circuito      in varchar2,
                                        p_tip_operacion     in ge_snp_transferencias.cod_tip_operacion%type,
                                        p_sub_tip_operacion in ge_snp_transferencias.cod_sub_tip_operacion%type default null,
                                        p_cod_tra_padre     in ge_snp_par_mensajes.cod_tra_padre%type default null
                                      ) return number;

  /*Envío de mensajería al WorkFlow*/
  procedure pr_reg_msj_workflow ( rg_msj_reg_wfl in rg_msj );

  /*Setea el estado, la situación y el error del SWIFT*/
  procedure pr_set_transferencias ( rg_msj_set_tra in rg_msj );

  /*Registra LOG de la mensajería*/
  procedure pr_reg_operacion( p_mensaje   in long,
                              p_respuesta in varchar2
                            );

  /*Validación del contenido del TAG registrado en la mensajería*/
  function fu_pro_val_tag( p_mensaje   in long,
                           p_tag       in varchar2,
                           p_limpia    in varchar2 default null,
                           p_posicion  in number default 1,
                           p_ubicacion in number default 1
                         ) return varchar2;

   --TRFS-1392
   /*Validación si el mensaje es una reversion a partir del tag (70 o 72)*/
   FUNCTION fu_pro_val_reversion( p_mensaje   in long,
                                  p_tag       in varchar2,
                                  p_posicion  in number default 1,
                                  p_ubicacion in number default 1
                                 ) return BOOLEAN;

  /*Proceso diario de Reversión automática de los movimientos Interbancarios sin Mensaje registrado*/
  procedure pr_rev_automatica( p_fec_actual in ge_snp_transferencias.fecha%type default null );

  /*Proceso diario de envío de SWIFTS a BCP, previa apertura de la fecha actual para el intercambio de información*/
  procedure pr_gen_men_automaticos( p_fec_valor     in ge_snp_transferencias.fec_valor%type default null,
                                    p_can_sin_fondo in varchar2 default 'N'
                                  );

  /*Proceso diario de reversión de todas las operaciones referentes a SNP y cancelación de la mensajería*/
  procedure pr_gen_rev_snp( p_fec_valor in ge_snp_transferencias.fec_valor%type default null );

  /*Proceso de reversion de operaciones con SWIFT asociado*/
  procedure pr_rev_ope_con_swift( p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                                  p_concepto       in ge_movimientos.concepto%type default null,
                                  p_estado         in ge_snp_transferencias.estado%type default 'C'
                                );

  /*Obtiene el cliente principal*/
  function fu_obt_cli_principal( p_nro_cuenta in ge_cuentas.nro_cuenta%type ) return varchar2;

  /*Obtiene la moneda de la Cta.*/
  function fu_obt_mon_cta( p_nro_cuenta in varchar2 ) return varchar2;

  /*Obtiene la dirección principal*/
  function fu_obt_dir_principal( p_cod_persona in ba_personas.cod_persona%type ) return varchar2;

  /*Obtiene el nro. de documento*/
  function fu_obt_nro_doc_persona( p_cod_persona in ba_personas.cod_persona%type ) return varchar2;

  /*Obtiene los datos del dominio*/
  function fu_obt_dat_referencias( p_dominio in ba_cod_referencias.dominio%type,
                                   p_valor   in ba_cod_referencias.val_minimo%type
                                 ) return boolean;
  /*Obtiene la Cta. Bancaria*/
  function fu_obt_cta_bancaria( p_nro_cuenta in cc_cta_bancarias.nro_cta_bancaria%type,
                                p_tip_cuenta in varchar2
                              ) return varchar2;

  /*Verifica si la Cta. pertenece o no a una INTERBANCARIA*/
  function fu_ver_cta_interbancaria ( p_nro_cuenta in ge_cuentas.nro_cuenta%type ) return boolean;

  /*Función que verifica si un MT fue enviado o no al BCP*/
  function fu_ver_mt_env_bcp ( p_nro_referencia in ge_snp_transferencias.nro_referencia%type ) return varchar2;

  /*Valida si la mensajería es ENVIADA o RECIBIDA*/
  function fu_val_es_enviado ( rg_msj_ver_env in pas_snp.rg_msj ) return boolean;

  /*Valida el segmento del cliente para la generación de Workflow */
  function fu_ver_seg_cliente ( p_cod_cliente in ge_clientes.cod_persona%type ) return varchar2 ;

  /*Validar y Confirmar el Contrato de Cambio*/
  procedure pr_obt_con_cambio ( p_nro_con_cambio  in out lc_ope_pendientes.nro_operacion%type, --Nro Contrato de Cambios (opcional)
                                p_con_confirma    in     varchar2 default 'N',                 --Confirma o válida contrato (S/N)
                                p_cta_debito      in     lc_ope_pendientes.cta_referencia%type,
                                p_cta_credito     in     lc_ope_pendientes.cta_referencia%type,
                                p_mto_operacion   in     lc_ope_pendientes.monto%type,
                                p_cod_mon_origen  in     lc_ope_pendientes.cod_moneda%type,    --Moneda Origen
                                p_cod_mon_destino in     lc_ope_pendientes.cod_moneda%type,    --Moneda Destino
                                p_cotizacion      in out lc_ope_pendientes.cotizacion%type,    --Cotización de Cambio
                                p_mto_debito      in out lc_ope_pendientes.monto%type,         --Monto del Contrato de Cambio
                                p_mto_credito     in out lc_ope_pendientes.monto%type          --Monto del Contrato de Cambio
                              );

  /*Proceso de Inicio de Día para Generar Movimientos por Transferencias Futuras de Tesoreria*/
  procedure pr_gen_mov_tesoreria( p_fec_valor in ge_snp_transferencias.fec_valor%type default null );

  /*Procedimiento de generación de mensajeria de cobros de IPS*/
  procedure pr_gen_tra_servicio ( p_cod_servicio in ge_cob_servicios.cod_servicio%type );

  /*Obtiene el salto configurado en ITGF es <CR+LF>*/
  function fu_obt_salto return varchar2;

  /*Obtiene el salto configurado en el SOCKET ES <*> */
  function fu_obt_sal_socket return varchar2;

  /*Formato de la máscara para importes */
  function fu_obt_mascara return varchar2;

  /*Obtiene el código de transacción padre para identificar movimientos de SNP*/
  function fu_obt_cod_tra_padre return number;

  /*Obtiene el código de módulo padre para identificar movimientos de SNP*/
  function fu_obt_cod_mod_padre return number;

  /*Obtiene el código de modalidad padre para identificar movimientos de SNP*/
  function fu_obt_cod_mad_padre return number;

  /*Obtiene el código de transacción hija para la generación de movimientos de cobro de cargos - SNP*/
  function fu_obt_cod_tra_cargo return number;

  /*Obtiene el código de transacción hija para identificar movimientos de indemnizacion de SNP*/
  function fu_obt_cod_tra_indemnizacion return number;

  /*Genera los movimientos para las cuentas Entidades Financieras del País */
  procedure pr_gen_mov_tar_conciliacion ( p_hora           ge_movimientos.hora%type,
                                          p_nro_secuencia  ge_movimientos.nro_secuencia%type,
                                          p_cod_ent_debito ge_entes.cod_ente%type,
                                          p_monto          ge_movimientos.monto%type,
                                          p_cod_moneda     ba_monedas.cod_moneda%type,
                                          p_tip_gru_servicio number
                                         );

  /*Obtiene el código de transacción hija para identificar movimientos de IVA de SNP*/
  function fu_obt_cod_tra_impuesto return number;

  /*Controla las transferencias duplicadas SNP e inserta en la tabla de logs*/
  procedure pr_ins_sb_snp_log_envios ( p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                                       p_accion         in varchar2,
                                       p_situacion      in ge_snp_transferencias.situacion%type default null,
                                       p_error          in ge_snp_transferencias.error%type default null );

  /*Obtiene el Nro. de refencia relacionada para los casos en que la referencia
  corresponde a un MTn95/STAT enviado.*/
  function fu_obt_nro_ref_relacionada( p_nro_referencia in ge_snp_mensajes.nro_referencia%type ) return number;

  /*Halla el BIC del Sistema X-ADAPTER*/
  FUNCTION fu_obt_bic_sistema return varchar2;

  /*Envia MT985 de Solicitud de Reportes de Estados y Saldos*/
  PROCEDURE pr_obt_msj_mt985( p_cod_tip_mensaje  in sb_snp_tip_mensajes.cod_mensaje%type,
                              p_nro_cta_bancaria in ge_snp_cta_bancos.nro_cta_bancaria%type,
                              p_cod_persona      in ba_personas.cod_persona%type );

  /*Envia MT920 de Solicitud de Extractos*/
  PROCEDURE pr_obt_msj_mt920( p_cod_tip_mensaje    in sb_snp_tip_mensajes.cod_mensaje%type,
                              p_nro_cta_bancaria   in ge_snp_cta_bancos.nro_cta_bancaria%type,
                              p_tip_rep_solicitado in number default null,
                              p_ind_debito         in varchar2 default null,
                              p_ind_credito        in varchar2 default null,
                              p_mto_debito         in ge_snp_transferencias.monto%type default 0,
                              p_mto_credito        in ge_snp_transferencias.monto%type default 0,
                              p_cod_moneda         in ge_snp_transferencias.cod_moneda%type );
procedure pr_gen_MT202_automatico(p_monto           in sb_snp_lim_depo.monto%type,
                                  p_cta_pte_solicitante in ge_snp_transferencias.nro_cta_pte_solicitante%type);

/*Procesa la mensajeria del Catastro - MT104.*/
procedure pr_pro_msj_catastro( p_mensaje in long,p_referencia varchar2,p_ref_externa varchar2);
/*Registro de persona*/
procedure pr_reg_persona( p_nombre in varchar2,p_nro_documento in varchar2,p_tipo in varchar2);
/*Obtiene la Cuenta registrada en ITGF segun el Numero de Cuenta registrado*/
procedure pr_obt_cta_catastro( p_nro_cuenta            in  ge_snp_transferencias.nro_cta_beneficiario%type,
                                p_tip_documento         in  ba_personas.cod_tip_documento%type,
                                p_nro_documento         in  ba_personas.nro_documento%type,
                                p_nro_cta_interno       out ge_cuentas.nro_cuenta%type,
                                p_cod_persona           out ba_personas.cod_persona%type,
                                p_cod_rechazo           out varchar2
                              );
/*Genera MT999 a enviar -Catastro.*/
procedure pr_obt_msj_catastro( p_nro_orden in sb_snp_catastros.nro_orden%type,
                                p_tip_accion     in varchar2,
                                p_tip_operacion  in varchar2,
                                p_cod_rechazo    in varchar2 default null);
procedure pr_obt_dat_catastro(p_valor in varchar2, p_filtro in varchar2);
/*Obtiene el registro G_MSJ que contiene los datos de GE_SNP_TRANSFERENCIAS*/
function fu_obt_reg_catastros return rg_cat;
/*Procesa la mensajeria RECIBIDA - MT104.*/
function fu_pro_msj_mt104( p_mensaje in long) return varchar2;
/*Procesa Liquidacion de transferencias recibidas(MT104)*/
procedure pr_pro_rec_mt104 (p_nro_lote in ge_snp_transferencias.nro_lote%type default null);
function fu_pro_msj_mt198( p_mensaje in long ) return varchar2;
/*Genera MT de rechazo de instruccion dentro de un Batch*/
procedure pr_obt_msj_mt198( p_nro_referencia in ge_snp_transferencias.nro_referencia%type);
/*
Cancelacion automatica de solicitudes de alta y cancelacion de catastro
*/
procedure pr_can_aut_catastro;

--Bankitti
/*Genera movimiento Bancard */
PROCEDURE pr_gen_mov_bancard(p_hora           ge_movimientos.hora%type,
                               p_nro_secuencia  ge_movimientos.nro_secuencia%type,
                               p_cod_ent_debito ge_bancos.cod_banco%type,
                               p_monto          ge_movimientos.monto%type,
                               p_cod_moneda     ba_monedas.cod_moneda%type);
/*Generar mensaje de Pagos a Proveedores*/
procedure pr_gen_men_pag_proveedor( p_cod_ente in ge_entes.cod_ente%type,
                                      p_usuario  in ba_usuarios.cod_usuario%type,
                                      p_fec_pago date,
                                      p_nro_archivo ge_pag_proveedores.nro_archivo%type);
function fu_ver_cuenta(p_cta in varchar2) return varchar2;
/*Genera Swift Pago a Proveedores*/
procedure pr_gen_pro_swift( p_nro_referencia    in ge_snp_transferencias.nro_referencia%type,
                              p_val_movimientos   in varchar2 default 'S',
                              p_estado            in ge_snp_transferencias.estado%type default 'A'
                            );

FUNCTION fu_val_MTN96(p_texto in clob)
RETURN NUMBER;

end PAS_SNP;
/
