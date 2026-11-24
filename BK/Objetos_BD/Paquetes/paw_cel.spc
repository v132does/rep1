create or replace package it.paw_cel is

  -- Author  : AGUSTIN MEZA
  -- Created : 11/11/2008 04:02:51 p.m.
  -- Purpose : Recibir y responder Operaciones de Celulares

  -- codigos de respuesta posibles
  v_cod_aprobado          varchar2(03) := '0';
  v_cod_cta_inexistente   varchar2(03) := '-1';
  v_cod_cta_duplicada     varchar2(03) := '-2';
  v_cod_cta_invalida      varchar2(03) := '-3';
  v_cod_sal_insuficiente  varchar2(03) := '-5';
  v_cod_sis_cierre        varchar2(03) := '-6';
  v_cod_cta_sin_mov       varchar2(03) := '-7';
  v_cod_sin_autorizacion  varchar2(03) := '-8';
  v_cod_tra_invalida      varchar2(03) := '-9';
  v_cod_tra_prohibida     varchar2(03) := '-10';
  v_cod_can_invalida      varchar2(03) := '-11';
  v_cod_cta_cancelada     varchar2(03) := '-12';
  v_cod_cta_bloqueada     varchar2(03) := '-13';
  v_dat_per_invalido      varchar2(03) := '-14';
  v_par_invalido          varchar2(03) := '-15';
  v_cta_duplicada         varchar2(03) := '-16';
  v_dat_cta_invalida      varchar2(03) := '-17';
  v_err_dat_conciliado    varchar2(03) := '-18';
  v_err_dat_res_servicio  varchar2(03) := '-19';
  v_cod_mto_invalido      varchar2(03) := '-21';
  v_cod_mov_ya_ingresado  varchar2(03) := '-34';
  v_cod_ope_no_permitida  varchar2(03) := '-35';
  v_cod_otr_error         varchar2(03) := '-99';
  --


  fin_por_error       exception;

  type ref_pedido is record(
    nro_ref_externo varchar2(50),
    nro_celular     varchar2(50),
    nro_movimiento  varchar2(50),
    tip_concepto    number(3),
    tip_movimiento  varchar2(1),
    monto           number(18,2)
  );

  type t_cur_pedidos is table of ref_pedido index by binary_integer;
  pedidos             t_cur_pedidos;
  v_can_pedidos       number(3) := 0;


  v_cod_usuario       varchar2(10) := user;  -- Codigo del usuario a grabar
  v_cod_ofi_origen    number(3) := fun_obt_ofi_matriz;   -- Oficina origen

  v_cod_mon_local     varchar2(3) := pag_gen.FU_OBT_MON_LOCAL;
  v_cod_persona       varchar2(15);  -- contiene el codigo de la persona
  v_nro_secuencia     number(3)    := 0;
  v_saldo             number(18,2) := null;
  v_sal_destino       number(18,2) := null;
  v_nro_cuenta        varchar2(20);
  --
  v_horario           varchar2(1)  := 'D'; -- Dia normal
  v_es_mov_noc        varchar2(1)  := 'N'; -- Graba S/N mov nocturnos
  v_es_cta_noc        varchar2(1)  := 'N'; -- Graba S/N ctas noctunas
  v_fec_actual        date         := pag_cal.fu_obt_fec_actual(9);          -- fecha de hoy
  v_fec_valor         date         := v_fec_actual;
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_lugar             varchar2(2000);
  --
  v_cod_respuesta     varchar2(03) := v_cod_aprobado;  -- respuesta 0=sin errores
  v_msj_respuesta     varchar2(1000) := ''; -- Mensaje de error de respuesta
  -- movimientos
  r_gmovi ge_movimientos%rowtype;
  --

  -- Funcion que registra un movimiento de debito/credito a una cuenta celular
  procedure pr_act_operacion(p_nro_operacion in number,     -- numero de operacion
                              p_tip_transaccion in varchar2,     -- puede ser: 1-Extraccion, 2-Deposito, 3-Compra 4-Transferencia
                              p_nro_ref_externo in varchar2, -- nro unico de identificacion de la cuenta
                              p_tip_movimiento in varchar2,  -- puede ser: d-debito o c-credito
                              p_monto in number,             -- Monto de la operacion
                              p_tip_concepto in varchar2,    -- Puede ser: 1-Cred.Comision, 2-Deb.Cargo, 3-Debito, 4-Credito
                              p_concepto     in varchar2);

  -- Funcion que registra el cambio de PIN
  function cambiarPin(p_nro_operacion   in number,
                      p_fec_transaccion in varchar2,
                      p_nro_ref_externo in varchar2,
                      p_nro_celular     in varchar2,
                      p_detalles        in varchar2) return varchar2;

  -- Funcion que retorna el saldo de una cuenta celular
  function consultarSaldo(p_nro_operacion   in number,
                          p_fec_transaccion in varchar2,
                          p_nro_ref_externo in varchar2,
                          p_nro_celular     in varchar2,
                          p_detalles        in varchar2) return varchar2;

  -- Funcion que procesa las operaciones enviadas desde el WebService
  function realizarOperacion(p_nro_operacion   in number,
                             p_fec_transaccion in varchar2,
                             p_nro_ref_externo in varchar2,
                             p_nro_celular     in varchar2,
                             p_tip_transaccion in varchar2,     -- puede ser: 1-Extraccion, 2-Deposito, 3-Compra 4-Transferencia
                             p_detalles        in varchar2)
    return varchar2;

  -- Funcion que retorna los ultimos tres movimientos de la cuenta
  function resumirMovimientos(p_nro_operacion   in number,
                              p_fec_transaccion in varchar2,
                              p_nro_ref_externo in varchar2,
                              p_nro_celular     in varchar2,
                              p_can_movimientos in number,
                              p_fec_movimiento  in varchar2,
                              p_detalles        in varchar2
                              ) return varchar2;

  -- Funcion que asocia la cuenta con el numero de Celular
  function asociarCuenta(p_nro_operacion   in number,
                         p_fec_transaccion in varchar2,
                         p_nro_ref_externo in varchar2,
                         p_nro_celular     in varchar2,
                         p_nro_cuenta       in varchar2,
                         p_tip_usuario     in varchar2
                         ) return varchar2;

  -- Funcion que inserta datos de la Persona, Cliente y Cuentas de Ahorro Vista.
  function crearCuenta(p_nro_operacion   in number,
                       p_fec_transaccion in varchar2,
                       p_nro_ref_externo in varchar2,
                       p_nro_celular     in varchar2,
                       p_tip_usuario     in varchar2,
                       p_pri_nombre      in varchar2,
                       p_seg_nombre      in varchar2 default null,
                       p_pri_apellido    in varchar2,
                       p_seg_apellido    in varchar2 default null,
                       p_nro_documento   in varchar2,
                       p_fec_nacimiento  in varchar2,
                       p_est_civil       in varchar2,
                       p_nro_ruc         in varchar2 default null,
                       p_direccion       in varchar2,
                       p_departamento    in varchar2 default null,
                       p_ciudad          in varchar2,
                       p_barrio          in varchar2 default null,
                       p_piso            in varchar2 default null,
                       p_cod_postal      in varchar2 default null,
                       p_sexo            in varchar2,
                       p_telefono        in varchar2,
                       p_detalles        in varchar2)
  return varchar2;
  -- Función que verifica si el registro fue conciliado o no
  function conciliado(p_nro_operacion   in number,   -- numero de operacion
                      p_tip_transaccion in varchar2, -- puede ser: 1-Extraccion, 2-Deposito, 3-Compra 4-Transferencia
                      p_nro_ref_externo in varchar2, -- nro unico de identificacion de la cuenta
                      p_tip_movimiento  in varchar2, -- puede ser: d-debito o c-credito
                      p_monto           in number,   -- Monto de la operacion
                      p_tip_concepto    in varchar2, -- Puede ser: 1-Cred.Comision, 2-Deb.Cargo, 3-Debito, 4-Credito
                      p_concepto        in varchar2)
  return varchar2;
  -- Reversión de Operaciones
  function revertirTransaccion(p_nro_operacion     in number,
                               p_fec_transaccion   in varchar2,
                               p_nro_ope_revertir  in number,
                               p_fec_tra_revertir  in varchar2,
                               p_tip_reversion     in number, -- 11-manual 12- automático
                               p_motivo            in varchar2,
                               p_detalles          in varchar2 default null)
  return varchar2;
  -- Actualiza código del Resumen Diario
  function procesarResumenDiario(p_nro_ope_grupo number default null,
                               p_fecha         date   default null)
  return varchar2;
  -- Actualiza el código de Conciliado
  function procesarConciliado(p_nro_ope_grupo number default null,
                              p_fecha         date   default null)
  return varchar2;
  -- Función que inserta registros en BW_RES_DIA_SERVICIOS
  function insertarResumenDiario(p_nro_grupo number,
                                p_nro_ref_externo varchar2,
                                p_nro_movil       varchar2,
                                p_tipo            varchar2, -- Tipo de Movimiento
                                p_monto           number,
                                p_tip_concepto    varchar2,
                                p_tip_transaccion varchar2,
                                p_nro_operacion   number,
                                p_fec_transaccion varchar2,
                                p_nro_movimiento  number)
  return varchar2;
  -- Función que elimina registros de BW_RES_DIA_SERVICIOS
  function eliminarResumenDiario(p_nro_grupo number)
  return varchar2;
  -- Función que inserta registros en BW_CON_SERVICIOS
  function insertarConciliado(p_nro_grupo number,
                             p_nro_ref_externo varchar2,
                             p_nro_movil       varchar2,
                             p_tipo            varchar2, -- Tipo de Movimiento
                             p_monto           number,
                             p_tip_concepto    varchar2,
                             p_tip_transaccion varchar2,
                             p_nro_operacion   number,
                             p_fec_transaccion varchar2,
                             p_nro_movimiento  number)
  return varchar2;
  -- Función que elimina registros de BW_CON_SERVICIOS
  function eliminarConciliado(p_nro_grupo number)
  return varchar2;
end paw_cel;
/

