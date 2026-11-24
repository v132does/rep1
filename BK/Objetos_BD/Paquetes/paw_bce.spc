CREATE OR REPLACE PACKAGE IT.PAW_BCE is

  -- Author  : AGUSTIN MEZA
  -- Created : 15/07/2005 03:47:41 p.m.
  -- Purpose : Responder las transacciones generadas a traves de la banca electronica

  -- Autor: Agustin Meza
  -- Creado: 17/sep/2007
  ---Proposito: Este es el nuevo paquete paw_bce, el cual es copia del original paw_bce, con el nombre
  -- temporal paw_bce porque el anterior aun debe permanecer activo por un tiempo
  -- variables generales recibidas
  p_clave        varchar2(32);  -- clave del cliente
  p_dato         varchar2(16);  -- Dato: nro de documento, cliente o cuenta
  p_tip_dato     varchar2(01);  -- Tipo: D-Nro.Doc, C-Cuenta, K-Cod.cliente
  -- datos de la caja
  v_tip_caja       varchar2(1);   -- Tipo de caja: A/S/H/T
  v_cod_usuario    varchar2(10);  -- Codigo del usuario a grabar
  v_cod_ofi_origen number(3);   -- Oficina del Autoservicio
  v_ult_cierre     date;
  v_ult_corte      date; 		-- BSEVOCORE-583

  -- variables
  v_cod_mon_local     varchar2(3) := pag_gen.FU_OBT_MON_LOCAL;
  v_nro_terminal      varchar2(3);   -- nro de terminal en el que se ingreso
  v_nro_operacion     varchar2(10);  -- nro unico de operacion generado por el cliente
  v_cod_operacion     varchar2(3);   -- codigo de la operacion recibida
  v_cod_persona       varchar2(15);  -- contiene el codigo de la persona
  v_clave           varchar2(32);   -- clave encriptada en la base
  v_cod_usu_oficial   varchar2(15);  -- codigo del oficial del cliente
  v_nom_completo      varchar2(100); -- nombre completo del cliente
  v_cod_respuesta     varchar2(03) := '000'; -- respuesta
  v_cam_clave         varchar2(1)  := 'N';   -- indica si el cliente debe cambiar clave
  v_nro_secuencia     number(3)    := 0;
  v_cod_per_empresa   varchar2(15);  -- Codigo de la persona empresa
  v_nom_empresa       varchar2(100); -- nombre de la empresa
  v_cod_perfil        varchar2(20);  -- codigo de perfil
  v_can_aut_requeridas number(5) := 0; -- cantidad de firmas requeridas
  v_permiso           varchar2(10);  -- contendra el permiso para la opcion que tnga el cliente
  v_tip_mensaje       varchar2(10);  -- guarda el tipo IAC
  --
  v_horario           varchar2(1)  := 'D'; -- Dia normal
  v_es_mov_noc        varchar2(1)  := 'N'; -- Graba S/N mov nocturnos
  v_es_cta_noc        varchar2(1)  := 'N'; -- Graba S/N ctas noctunas
  v_fec_actual        date         := pag_cal.fu_obt_fec_actual(9);          -- fecha de hoy
  v_fec_valor         date         := v_fec_actual;
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_lugar             varchar2(2000);
  v_max_lon_otp       number       := 15; -- máxima longitud para clave otp.

  -- movimientos
  r_gmovi ge_movimientos%rowtype;
  -- para controlar transacciones duplicadas, default 10 minutos
  v_min_transaccion   number := nvl(to_number(fug_obt_pardinamico('PAW_MIN_TRANSACCION')), 10);
  -- maximo numero de registros que se pueden importar por archivo
  v_max_imp_archivo   number := 1800;
  -- codigos de respuesta posibles
  v_cod_aprobado          varchar2(03) := '000';
  v_cod_cta_inexistente   varchar2(03) := '-01';
  v_cod_cta_duplicada     varchar2(03) := '-02';
  v_cod_pin_invalido      varchar2(03) := '-03';
  v_cod_pin_inexistente   varchar2(03) := '-04';
  v_cod_sal_insuficiente  varchar2(03) := '-05';
  v_cod_sis_cierre        varchar2(03) := '-06';
  v_cod_cta_sin_mov       varchar2(03) := '-07';
  v_cod_sin_autorizacion  varchar2(03) := '-08';
  v_cod_tra_invalida      varchar2(03) := '-09';
  v_cod_tra_prohibida     varchar2(03) := '-10';
  v_cod_can_invalida      varchar2(03) := '-11';
  v_cod_cta_cancelada     varchar2(03) := '-12';
  v_cod_cta_bloqueada     varchar2(03) := '-13';
  v_cod_cta_invalida      varchar2(03) := '-14';
  v_cod_pro_posterior     varchar2(03) := '-15';
  v_cod_pin_bloqueado     varchar2(03) := '-18';
  v_cod_pin_anulado       varchar2(03) := '-19';
  v_cod_tas_inhabilitado  varchar2(03) := '-20';
  v_cod_otr_error         varchar2(03) := '-99';
  -- nuevos
  v_cod_mto_invalido      varchar2(03) := '-21';
  v_cod_tot_invalido      varchar2(03) := '-22';
  v_cod_ped_duplicado     varchar2(03) := '-23';
  v_cod_pag_pendiente     varchar2(03) := '-24';
  v_cod_ser_inexistente   varchar2(03) := '-25';
  v_cod_dat_invalido      varchar2(03) := '-27';
  v_cod_sin_factura       varchar2(03) := '-30';
  v_cod_con_factura       varchar2(03) := '-31';
  v_cod_ope_no_permitida  varchar2(03) := '-35';
  -- datos de relacion de vinculo y perfil
  v_cod_vin_inexistente   varchar2(03) := '-32';
  v_cod_vin_vencido       varchar2(03) := '-33';
  ---
  v_cod_mov_ya_ingresado  varchar2(03) := '-34';
  v_cod_rec_por_DNA       varchar2(03) := '-55';
  v_cod_val_ticket_DNA    varchar2(03) := '-56';
  --
  v_cod_lim_exedido       varchar2(03) := '-36';
  v_cod_fec_invalida      varchar2(03) := '-37';
  v_cod_call_center       varchar2(03) := '-57';
  v_fec_exceso            varchar2(03) := '-58'; -- Fecha Excede el rango de los 60 Dias
  v_fec_invalida          varchar2(03) := '-59'; -- Rango de Fecha Invalida
  v_ref_invalida          varchar2(03) := '-60'; -- Nro de Referencia Transf. exterior invalida
  v_fec_rango_inicial     varchar2(03) := '-61';
  v_aviso_inexistente     varchar2(03) := '-62';
  v_err_pag_prov          varchar2(03) := '-63'; -- Error al Procesar Pago Proveedores
  v_con_cam_invalido      varchar2(03) := '-64'; -- Contrato de Cambio invalido
  v_hor_ope_invalida      varchar2(03) := '-65'; -- Hora de la Operacion Invalida
  v_err_comunicacion      varchar2(03) := '-66'; -- Error de Comunicacion con Socket BCP
  v_can_che_invalida      varchar2(03) := '-70'; --Cantidad de chequeras no valida
  v_cla_ope_invalida      varchar2(03) := '-71'; -- La clave de operaciones utilizada es invalida
  v_cla_ope_estado        varchar2(03) := '-72'; -- El estado de la clave no es estado activo
  v_cla_ope_intentos      varchar2(03) := '-73';
  v_cla_ope_cambiar       varchar2(03) := '-74';
  -- variables para límite global de operaciones
  v_cla_lim_excedido      varchar2(03) := '-75'; -- límite global excedido
  v_cla_lim_no_definido   varchar2(03) := '-76'; -- límite global no definido
  v_tok_invalido          varchar2(03) := '-77'; -- token inválido
  v_sol_cla_existe        varchar2(03) := '-78'; -- La solicitud ya existe
  v_cla_cambiar           varchar2(03) := '-79';
  v_cla_solicitar         varchar2(03) := '-80';
  v_can_cta_deb_invalida  varchar2(03) := '-81'; -- Cuenta a debitar debe ser solo una
  v_can_cta_cre_excedida  varchar2(03) := '-82'; -- Cantidad de cuentas credito excedida
  v_cam_cla_acceso        varchar2(03) := '-83'; -- Clave de acceso nueva o modificada, se debe cambiar
  v_fmt_arc_indefinido    varchar2(03) := '-86'; -- Formato de archivo no definido
  v_mon_dec_invalida      varchar2(03) := '-87'; -- Moneda no permite decimal
  v_cod_err_permitido     varchar2(03) := '-88'; -- Variable reservada para salarios y proveedores
  v_can_lim_excedido      varchar2(03) := '-89'; -- Límite de cantidad exedido
  v_err_snp               varchar2(03) := '-90'; -- Confirmación Invalida.
  v_cta_int_invalida      varchar2(03) := '-91'; -- Cuenta Interbancaria Invalida
  v_nro_tar_invalido      varchar2(03) := '-92'; -- Nro de Tarjeta Invalido - SNP
  v_can_lim_indefinido    varchar2(03) := '-93'; -- Límite de cantidad no definido
  v_cod_err_con_vasco     varchar2(03) := '-96'; -- Error conexion con Servidor VASCO OTP
  v_cod_err_con_socket    varchar2(03) := '-97'; -- Error conexion con Socket de conexion a VASCO
  v_cla_otp_inexistente   varchar2(03) := '-98'; -- No cuenta con clave OTP.
  v_cla_st_inexistente    varchar2(03) := '-99'; -- no tiene softoken


  v_err_ses_servicio      varchar2(03) := '005'; -- no se permite crear otra sesion para pago de servicio
  v_cod_tok_ine_vasco     varchar2(03) := '002'; -- Cuenta de usuario token no migrado al vasco
   --obtener el último Nro. de Hoja de Seguridad
   function fu_obt_nro_seguridad (p_cod_cliente       in varchar2,
                                  p_cod_per_vinculada in varchar2,
                                  p_tip_clave         in varchar2)
   return number;

  -- obtiene los datos de una registro segun formato de importacion de datos
  function fu_obt_dato(p_for_archivo in varchar2, p_nom_tabla in varchar2,
                     p_registro in varchar2,p_campo in varchar2)
  return varchar2;
  -- obtiene los datos de una registro segun formato de importacion de datos
  function fu_obt_dato_dev(p_for_archivo in varchar2, p_nom_tabla in varchar2,
                     p_registro in varchar2,p_campo in varchar2)
  return varchar2;

  -- funcion que encripta y devuelve el valor encriptado de una palabra en formato md5
  function fu_enc_md5(p_encripta varchar2) return varchar2;
  function fu_enc_sha1(p_encripta varchar2) return varchar2;

  -- procedimientos de control de datos recibidos
  procedure pr_val_caja;

  -- Identificacion del cliente. Devuelve datos del cliente
  procedure pr_val_clave(p_parametros in varchar2);

  -- función que valida que una clave (de acceso o transaccional) no se repita
  function fu_val_vul_claves(p_cod_persona in bw_ope_claves.cod_persona%type,
                             p_cla_nueva   in bw_ope_claves.clave%type)
    return varchar2;
  /*
    BWP-471 - glopez - Le agregue primero para que encripte en sha1
  */
  function fu_val_vul_cla(p_cod_persona in bw_ope_claves.cod_persona%type,
                             p_cla_nueva   in bw_ope_claves.clave%type)
    return number;
  -- procedimiento que valida una dirección ip
  procedure pr_val_dir_ip(p_ip in ge_par_dinamicos.val_parametro%type);

  -- procedimiento que valida un puerto tcp
  procedure pr_val_puerto(p_puerto in ge_par_dinamicos.val_parametro%type);

  -- procedimiento que valida una cuenta de aguinaldo
  procedure pr_ver_cta_aguinaldo(p_nro_cuenta    in ge_cuentas.nro_cuenta%type,
                                 p_traspaso      in varchar2,
                                 p_cod_error     in out number,
                                 p_mensaje       in out varchar2,
                                 p_longitud      in number);

  -- valida si la caja es homebanking
  function fu_caj_homebanking(p_nro_terminal in varchar2)
    return varchar2;

  -- devuelve el codigo del tipo de cuenta
  function fu_tip_cuenta(p_cod_modulo in number,
                         p_cod_modalidad in number)
    return char;
  -- retorna el saldo actual de una cuenta
  function fu_obt_sal_actual(p_cod_modulo    in number,
                             p_cod_modalidad in number,
                             p_nro_cuenta    in varchar2)
    return number;

  -- obtener cotizacion para operaciones via banca electronica
  function fu_obt_cotizacion
   (p_cod_moneda in ba_monedas.cod_moneda%type
   ,p_tipo       in varchar2  -- C-COMPRA o V-VENTA
   )
   return number;

  --
  function fu_act_est_clave(p_cod_persona        bw_ope_claves.cod_persona%TYPE,
                            p_cod_per_vinculada bw_ope_claves.cod_per_vinculada%TYPE,
                            p_tipo              varchar2,
                            p_est_clave         bw_ope_claves.est_clave%TYPE)
    return boolean;
  --Retorna si es vip
  function fu_es_vip(p_cod_persona in varchar2)
    return varchar2 ;

  -- informacion del cliente para ivr
  function fuw_obt_dat_cliente(p_documento in varchar2)
     return varchar2;

  function fuw_obt_ult_transacciones(p_num_cuenta in varchar2)
    return varchar2;

  --Crea o cambia una clave de transaccion o acceso
  function fu_gen_ope_clave (p_clave             in  varchar2,
                             p_cod_persona       in  varchar2,
                             p_cod_per_vinculada in  varchar2,
                             p_accion            in  varchar2,
                             p_tip_clave         in  varchar2,
                             p_cla_operacion     out varchar2,
                             p_nro_lote          in number default null)
    return varchar2;

  -- Valida una clave de transaccion
  function fu_val_ope_clave(p_clave             in varchar2,
                            p_cod_persona       in varchar2,
                            p_cod_per_vinculada in varchar2,
                            p_tip_clave         in varchar2)
    return number;

  -- valida la hora de cierre de pago a proveedores
  function fu_ver_hor_cie_proveedor(p_fec_pago in out date)
    return boolean;

  -- Función que indica si la operacion se puede realizar
  function fu_ver_operacion(p_nro_cuenta      in ge_cuentas.nro_cuenta%type,
                            p_monto           in ge_movimientos.monto%type,
                            p_cod_transaccion in ge_movimientos.cod_transaccion%type,
                            p_cod_tra_padre   in ge_movimientos.cod_tra_padre%type,
                            p_tip_movimiento  in varchar2)
    return varchar2;

  -- Función para saber si una cuenta es conjunta
  function fu_es_conjunta(p_nro_cuenta in varchar2)
    return varchar2;

  -- Función para saber que solicitar al autorizador (clave transaccional y/o token o nada).
  function fu_obt_aut_limite(p_cod_empresa   in bw_mov_pendientes.cod_per_principal%type,
                             p_nro_documento in bw_mov_pendientes.nro_documento%type,
                             p_cod_persona in bw_mov_pendientes.cod_per_principal%type DEFAULT NULL)
    return varchar2;

  -- Funcion para obtener el numero de tarjeta
  function fu_obt_nro_tarjeta(p_nro_cuenta      in ge_cuentas.nro_cuenta%type,
                              p_cod_persona     in ba_personas.cod_persona%type,
                              p_cod_per_empresa in ba_personas.cod_persona%type)
    return varchar2;

  -- Funcion para retornar la siguiente secuencia para sueldos HB
  function fu_obt_nro_sec_sueldo(p_cod_ente   in ge_pag_sueldos.cod_ente%type,
                                 p_fec_actual in ge_pag_sueldos.fec_envio%type) return number;

  -- actualizar fecha de pago a proveedores
  procedure pr_act_fec_pag_pendiente(p_nro_documento in bw_mov_pendientes.nro_documento%type,
                                     p_cod_persona   in bw_mov_pendientes.cod_per_principal%type,
                                     p_fec_pago      in bw_mov_pendientes.dato2%type);

  /* Función que valida que el código de persona del movimiento pendiente
     pertenezca a la persona que esta queriendo consultar el documento pendiente */
  function fu_val_per_pendiente(p_nro_documento in bw_mov_pendientes.nro_documento%type,
                                p_cod_persona   in ge_clientes.cod_persona%type)
    return varchar2;

  -- Verifica que una transacción igual no se haya realizado en los últimos minutos
  function fu_ver_transaccion(p_cod_transaccion IN ge_movimientos.cod_transaccion%TYPE,
                              p_cod_tra_padre   IN ge_movimientos.cod_tra_padre%TYPE,
                              p_nro_cuenta      IN ge_movimientos.nro_cuenta%TYPE,
                              p_monto           IN ge_movimientos.monto%TYPE)
    return varchar2;

  -- Verifica si ya existe el movimiento pendiente
  function fu_ver_mov_pendiente(p_cod_per_empresa in bw_mov_pendientes.cod_per_principal%type,
                                p_nro_cta_debito  in bw_mov_pendientes.nro_cuenta%type,
                                p_nro_cta_credito in bw_mov_pendientes.nro_cuenta%type,
                                p_monto           in bw_mov_pendientes.monto%type,
                                p_cod_tip_mensaje in bw_mov_pendientes.cod_tip_mensaje%type)
    return varchar2;

  -- Función que valida que el código de persona este vinculada a la empresa
  function fu_val_per_vinculada(p_cod_per_empresa in ge_clientes.cod_persona%type,
                                p_cod_persona     in ge_clientes.cod_persona%type)
    return varchar2;

  -- función para validacion de clave otp.
  function fu_obt_tok_validar(p_parametro         in varchar2,
                              p_cod_persona       in ba_personas.cod_persona%type,
                              p_cod_per_vinculada in ba_personas.cod_persona%type,
                              p_ini_cla_otp       in number,
                              p_modo              in varchar2)
    return varchar2;

  -- obtiene el total de límite máximo operativo por mensaje
  function fu_obt_limite(p_cod_tip_mensaje IN bw_tip_mensajes.cod_tip_mensaje%TYPE,
                         p_cod_persona     IN ba_personas.cod_persona%TYPE,
                         p_nro_cuenta      IN ge_cta_clientes.nro_cuenta%TYPE,
                         p_cod_moneda      IN ba_monedas.cod_moneda%TYPE,
                         p_cod_transaccion IN ge_movimientos.cod_transaccion%TYPE,
                         p_cod_tra_padre   IN ge_movimientos.cod_tra_padre%TYPE,
                         p_monto           IN ge_movimientos.monto%TYPE,
                         p_modo            IN VARCHAR2,
                         p_cod_ente        IN ge_entes.cod_ente%TYPE DEFAULT NULL,
                         p_session         IN bw_sesiones.nro_sesion%type DEFAULT NULL,
                         p_nro_ip          IN bw_sesiones.nro_ip%type DEFAULT NULL,
                         p_cantidad        IN NUMBER DEFAULT 1,
                         p_cod_per_vinculada IN ba_personas.cod_persona%TYPE DEFAULT NULL)
    return varchar2;

  --funcion para validar el principal de una cuenta
   function fu_val_cta_limite(p_nro_cuenta  IN ge_cuentas.nro_cuenta%TYPE,
                           p_tip_persona IN ba_personas.tipo%TYPE)
     return varchar2;

    Function fu_inh_lim_cliente(p_cod_cliente          IN ba_personas.cod_persona%TYPE,
                                p_cod_canal            IN VARCHAR2 DEFAULT NULL,
                                p_identificador_sesion IN VARCHAR2 DEFAULT NULL) return NUMBER;

  -- Transaccion de sincronizacion
  function fu_pro_operacion_000(p_parametros in varchar2)
    return varchar2;
  -- Identificacion del cliente. Devuelve datos del cliente
  function fu_pro_operacion_005(p_parametros in varchar2)
    return varchar2;
  -- Validacion de cuentas/tarjetas para depositos o pagos con o sin clave
  function fu_pro_operacion_010(p_parametros in varchar2)
    return varchar2;
  -- Devuelve las cuentas del cliente
  function fu_pro_operacion_011(p_parametros in varchar2,
                                p_ver_cuentas in varchar2 default null,
                                p_cod_moneda  in varchar2 default null,
                                p_tip_consulta in varchar2 default null)
    return clob;
  -- Confirmacion de depositos
  function fu_pro_operacion_015(p_parametros in varchar2)
    return varchar2;
  -- BSEVOCORE-583 Corte / Vaciamiento de Buzon del autoservicio
  function fu_pro_operacion_016(p_parametros in varchar2)
    return varchar2;
  -- Cierre del autoservicio
  function fu_pro_operacion_017(p_parametros in varchar2)
    return varchar2;
  -- Devuelve el saldo detallado de las cuentas
  function fu_pro_operacion_020(p_parametros in varchar2)
    return clob;
  -- 021 Movimientos por cuenta
  function fu_pro_operacion_021(p_parametros in varchar2)
    return clob;
  -- 022- Reimpresion de comprobantes
  function fu_pro_operacion_022(p_parametros in varchar2)
    return clob;

  -- 023-  confirmacion de autorizaciones pendientes
  function fu_pro_operacion_023(p_parametros in varchar2)
    return clob;

  -- 024- Consulta de autorizaciones pendientes
  function fu_pro_operacion_024(p_parametros in varchar2)
    return clob;

  -- 025- Impresion de Facturas
  function fu_pro_operacion_025(p_parametros in varchar2)
    return clob;

  -- 030-validacion o confirmacion de transferencia entre cuentas
  function fu_pro_operacion_030(p_parametros      in varchar2,
                                p_nro_cta_debito  in varchar2 default null,
                                p_monto           in number   default null,
                                p_nro_cta_credito in varchar2 default null,
                                p_modo            in varchar2 default null,
                                p_cotizacion      in number   default null,
                                p_mto_credito     in number   default null,
                                p_cot_credito     in number   default null,
                                p_nro_doc_credito in varchar2 default null,
                                p_concepto        in varchar2 default null)
  return varchar2;
  -- 031 - pago de prestamos
  function fu_pro_operacion_031(p_parametros in varchar2,
                              p_nro_cta_debito  in varchar2 default null,
                              p_monto           in number   default null,
                              p_nro_prestamo    in varchar2 default null,
                              p_modo            in varchar2 default null,
                              p_can_cuo_pagada  in number   default null)
    return clob;
  -- 032 - pago de tarjetas de credito
  function fu_pro_operacion_032(p_parametros in varchar2,
                              p_nro_cta_debito  in varchar2 default null,
                              p_monto           in number   default null,
                              p_nro_tarjeta     in varchar2 default null,
                              p_modo            in varchar2 default null)
    return clob;
  -- 033-validacion o confirmacion de Pago por Despachos aduaneros(Sofia)
  function fu_pro_operacion_033(p_parametros in varchar2,
                              p_nro_cta_debito  in varchar2 default null,
                              p_monto           in number   default null,
                              p_modo            in varchar2 default null,
                              p_msj_original    in varchar2 default null)
    return varchar2;
  -- 036  Transferencias Interbancarias (SNP)
  function fu_pro_operacion_036(p_parametros in varchar2,
                                p_modo            in varchar2 default null,
                                p_nro_referencia  in number   default null,
                                p_nro_cta_deb     in varchar2 default null,
                                p_mto_debito      in number   default null,
                                p_cot_debito      in number   default null,
                                p_nro_cta_cre     in varchar2 default null,
                                p_mto_credito     in number   default null,
                                p_cot_credito     in number   default null,
                                p_cod_mon_cre     in varchar2 default null,
                                p_fec_operacion   in date     default null)
    return clob;
  -- 037  Consulta de Transferencias Interbancarias (SNP)
  function fu_pro_operacion_037(p_parametros in varchar2)
    return clob;
  -- 038  Cancelación de Transferencias Interbancarias (SNP)
  function fu_pro_operacion_038(p_parametros in varchar2,
                                p_modo            in varchar2 default null,
                                p_nro_referencia  in number   default null)
    return clob;
  -- 039-validacion o confirmacion de transferencia entre cuentas de terceros
  function fu_pro_operacion_039(p_parametros      in varchar2,
                                p_nro_cta_debito  in varchar2 default null,
                                p_monto           in number   default null,
                                p_nro_cta_credito in varchar2 default null,
                                p_modo            in varchar2 default null,
                                p_cotizacion      in number   default null,
                                p_mto_credito     in number   default null,
                                p_cot_credito     in number   default null,
                                p_nro_doc_credito in varchar2 default null,
                                p_concepto        in varchar2 default null)
  return varchar2;

  -- 040  Consulta de cheques devueltos
  function fu_pro_operacion_040(p_parametros in varchar2)
    return clob;
  -- 041  Depositos a confirmar por cuenta
  function fu_pro_operacion_041(p_parametros in varchar2)
    return clob;
  -- Devuelve las cotizaciones de cuatro monedas
  function fu_pro_operacion_050(p_parametros in varchar2)
    return varchar2;
  -- solicitud de chequeras
  function fu_pro_operacion_060(p_parametros in varchar2,
                              p_nro_cta_cte   in varchar2 default null,
                              p_modo          in varchar2 default null,
                              p_tip_chequera  in varchar2 default null,
                              p_can_chequera  in number   default null,
                              p_ofi_retencion in number  default null)
    return clob;
   -- Consulta de Chequeras
  function fu_pro_operacion_061(p_parametros in varchar2)
    return clob;
   -- Consulta de Chequeras - Detalle de un Cheque
  function fu_pro_operacion_062(p_parametros in varchar2)
    return clob;
   -- Consulta de Chequeras - Detalle de Cheques
  function fu_pro_operacion_063(p_parametros in varchar2)
    return clob;
   -- Consulta de Chequeras - Detalle de una chequera
  function fu_pro_operacion_064(p_parametros in varchar2)
    return clob;

  -- control y actualizacion de pago de sueldos
  function fu_pro_operacion_070(p_parametros in clob)
    return clob;
  -- control y actualizacion de pago a proveedores
  function fu_pro_operacion_075(p_parametros in clob)
    return clob; -- OMM 10/05/2011
  -- cambio de clave del cliente
  function fu_pro_operacion_080(p_parametros in varchar2)
    return varchar2;
  -- Mensaje a la entidad
  function fu_pro_operacion_081(p_parametros in varchar2)
    return varchar2;
  -- Pago de Servicios
  function fu_pro_operacion_082(p_parametros in varchar2)
    return varchar2;
  -- Consulta de Cliente para Extracto
  function fu_pro_operacion_083(p_parametros in varchar2)
    return varchar2;

  -- 085 Extractos en formato texto para el IVR
  function fu_pro_operacion_085(p_parametros in varchar2)
    return clob;

  -- 086 Consulta de Transferencia al Exterior
  function fu_pro_operacion_086(p_parametros in varchar2)
    return clob;  -- OMM 07/01/2011


   -- Validacion de Session Pago de Servicios
  function fu_pro_operacion_087(p_parametros in varchar2)
    return varchar2; -- OMM 23/02/2011

  -- 095 Obtiene Calificación de Riesgo Crediticio del Cliente
  function fu_pro_operacion_095(p_parametros in varchar2)
    return varchar2; -- OMM 08/03/2011

  -- 099 Devuelve los avisos al cliente por Rango de Fechas
  function fu_pro_operacion_099(p_parametros in varchar2)
    return varchar2; -- OMM 08/03/2011

  -- 110 Devuelve el estado de la clave del cliente al IVR
  function fu_pro_operacion_110(p_parametros in varchar2)
    return varchar2;

  -- 111 Setea el estado de la clave del cliente a activo
  function fu_pro_operacion_111(p_parametros in varchar2)
    return varchar2;

  -- 112- Consultar linea de Sobregiro
  function fu_pro_operacion_112(p_parametros in varchar2)
    return varchar2;

  -- 113- Consultar saldo o ultimos movimientos de tarjeta
  function fu_pro_operacion_113(p_parametros in varchar2)
    return varchar2;

  -- 114- Adhesión Débito Automático para Préstamo o Tarjeta
  function fu_pro_operacion_114(p_parametros in varchar2)
    return varchar2;

  -- 115- Consulta de clientes con clave de acceso por CI
  function fu_pro_operacion_115(p_parametros in varchar2)
    return varchar2;

  -- 116- Consulta de próximos vencimientos de préstamos
  function fu_pro_operacion_116(p_parametros in varchar2)
    return varchar2;

  -- 117- Consulta de saldo de cuenta principal
  function fu_pro_operacion_117(p_parametros in varchar2)
    return varchar2;

  -- 213- Impresion de extractos de tarjetas
  function fu_pro_operacion_213(p_parametros in varchar2)
    return clob;

  -- 214- Transferencias con Operaciones de Cambio
  function fu_pro_operacion_214(p_parametros      in varchar2,
                                p_nro_cta_debito  in varchar2 default null,
                                p_monto           in number   default null,
                                p_nro_cta_credito in varchar2 default null,
                                p_modo            in varchar2 default null,
                                p_cotizacion      in number   default null,
                                p_mto_credito     in number   default null,
                                p_cot_credito     in number   default null,
                                p_nro_doc_credito in varchar2 default null,
                                p_concepto        in varchar2 default null,
                                p_nro_referencia  in number   default null)
  return varchar2;

  -- 219- Cambio de clave transaccional
  function fu_pro_operacion_219(p_parametros in varchar2)
    return varchar2;

  -- 220- Obtención de Códigos de Moneda
  function fu_pro_operacion_220(p_parametros in varchar2)
    return varchar2;

  -- 224- Verificación de estado de clave transaccional
  function fu_pro_operacion_224(p_parametros in varchar2)
    return varchar2;

  -- 225- Consulta de Histórico de Pago a Proveedores
  function fu_pro_operacion_225(p_parametros in varchar2)
    return clob;

end paw_bce;
/

