create or replace package it.paj_bce is

  -- Author  : AGUSTIN MEZA
  -- Created : 15/07/2005 03:47:41 p.m.
  -- Purpose : Responder las transacciones generadas a traves de la banca electronica

  -- variables generales recibidas
  p_clave        varchar2(10);  -- clave del cliente
  p_dato         varchar2(16);  -- Dato: nro de documento, cliente o cuenta
  p_tip_dato     varchar2(01);  -- Tipo: D-Nro.Doc, C-Cuenta, K-Cod.cliente
  -- datos de la caja
  v_tip_caja       varchar2(1);   -- Tipo de caja: A/S/H/T
  v_cod_usuario    varchar2(10);  -- Codigo del usuario a grabar
  v_cod_ofi_origen number(3);   -- Oficina del Autoservicio
  v_ult_cierre     date;

  -- variables
  v_cod_mon_local     varchar2(3) := pag_gen.FU_OBT_MON_LOCAL;
  v_nro_terminal      varchar2(3);   -- nro de terminal en el que se ingreso
  v_nro_operacion     varchar2(10);  -- nro unico de operacion generado por el cliente
  v_cod_operacion     varchar2(3);   -- codigo de la operacion recibida
  v_cod_persona       varchar2(15);  -- contiene el codigo de la persona
  v_cod_usu_oficial   varchar2(15);  -- codigo del oficial del cliente
  v_nom_completo      varchar2(100); -- nombre completo del cliente
  v_cod_respuesta     varchar2(03) := '000'; -- respuesta
  v_cam_clave         varchar2(1)  := 'N';   -- indica si el cliente debe cambiar clave
  v_nro_secuencia     number(3)    := 0;
  --
  v_horario           varchar2(1)  := 'D'; -- Dia normal
  v_es_mov_noc        varchar2(1)  := 'N'; -- Graba S/N mov nocturnos
  v_es_cta_noc        varchar2(1)  := 'N'; -- Graba S/N ctas noctunas
  v_fec_actual        date         := pag_cal.fu_obt_fec_actual(9);          -- fecha de hoy
  v_fec_valor         date         := v_fec_actual;
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual

  -- movimientos
  r_gmovi ge_movimientos%rowtype;

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
  v_cod_rec_por_DNA       varchar2(03) := '-55';

  -- procedimientos de control de datos recibidos
  procedure pr_val_caja;

  -- Identificacion del cliente. Devuelve datos del cliente
  procedure pr_val_clave(p_parametros in varchar2);

  -- devuelve el codigo del tipo de cuenta
  function fu_tip_cuenta(p_cod_modulo in number,
                         p_cod_modalidad in number)
    return char;
  -- retorna el saldo actual de una cuenta
  function fu_obt_sal_actual(p_cod_modulo    in number,
                             p_cod_modalidad in number,
                             p_nro_cuenta    in varchar2)
    return number;

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
  -- Cierre del autoservicio
  function fu_pro_operacion_017(p_parametros in varchar2)
    return varchar2;
  -- Devuelve el saldo detallado de las cuentas
  function fu_pro_operacion_020(p_parametros in varchar2)
    return clob;
  -- 021 Movimientos por cuenta
  function fu_pro_operacion_021(p_parametros in varchar2)
    return clob;
  -- 030-validacion o confirmacion de transferencia entre cuentas
  function fu_pro_operacion_030(p_parametros in varchar2)
    return varchar2;
  -- 031 - pago de prestamos
  function fu_pro_operacion_031(p_parametros in varchar2)
    return clob;
  -- 032 - pago de tarjetas de credito
  function fu_pro_operacion_032(p_parametros in varchar2)
    return clob;
  -- 033-validacion o confirmacion de Pago por Despachos aduaneros(Sofia)
  function fu_pro_operacion_033(p_parametros in varchar2)
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
  function fu_pro_operacion_060(p_parametros in varchar2)
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
  function fu_pro_operacion_070(p_parametros in varchar2)
    return clob;
  -- control y actualizacion de pago a proveedores
  function fu_pro_operacion_075(p_parametros in varchar2)
    return clob;
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
end paj_bce;
/

