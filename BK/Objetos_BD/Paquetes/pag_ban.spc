create or replace package it.PAG_BAN is

  -- Author  : AMEZA - IT CONSULTORES SRL.
  -- Created : 21/01/2011 09:30 Hs

  /**Permite el manejo de las conexiones con el Socket conectado al Ws de Bancard,
     para consulta de Saldos en linea, Consulta de Extractos en linea, Consulta de
     ciclos de Extractos y consultas de Extractos por ciclo
  */

  g_servidor   VARCHAR2(20) := '62.12.248.13'; -- produccion
  --g_servidor   VARCHAR2(20) := '192.168.1.232'; -- produccion
  g_puerto     NUMBER(4)    := 4446;
  g_tie_espera NUMBER(4)  := NULL;

  g_lugar      varchar2(250);
  g_msj_error  varchar2(1000);
  g_cod_error  varchar(4) default '00';
  --
  g_can_tarjetas       number(6) := 0;
  g_can_movimientos    number := 0;
  g_can_ciclos         number := 0;
  -- detalle de tarjetas
  type ref_cur_tar is record(
      nroTarjeta   varchar2(19),
      tipoTarjeta   varchar2(1),
      nombreCliente   varchar2(50)
  );
  type t_cur_tarjetas is table of ref_cur_tar index by binary_integer;
  t_tarjetas t_cur_tarjetas;
  -- detalle de movimientos
  type ref_cur_mov is record(
     nroTarjeta   varchar2(19),
     tipoTransaccion   varchar2(1),
     FechaOperacion  date,
     FechaProceso date,
     NroCupon number(10),
     descripcion varchar2(50),
     importe number(18,2),
     impuesto number(18,2)
  );
  type t_cur_movimientos is table of ref_cur_mov index by binary_integer;
  t_movimientos t_cur_movimientos;
  -- detalle de ciclos
  type ref_cur_cic is record(
      fechaCierre   varchar2(10)
  );
  type t_cur_ciclos is table of ref_cur_cic index by binary_integer;
  t_ciclos t_cur_ciclos;

 /*1    METODO: pr_con_saldos PVP001
                Parametro: nro de tarjeta
                Retorno  : Varchar2 con todos los datos separados por #
 */
   PROCEDURE pr_con_saldos
      (p_nro_tarjeta in varchar2);

 /*2    METODO: pr_con_saldos PVP002
                Parametro: nro de tarjeta
                Retorno  : Varchar2 con todos los datos separados por #
 */
   PROCEDURE pr_ext_actual
      (p_nro_tarjeta in varchar2);

 /*3    METODO: pr_con_ciclos PVP003
                Parametro: nro de tarjeta
                Retorno  : Varchar2 con todos los datos separados por #
 */
   PROCEDURE pr_con_ciclos
      (p_nro_tarjeta in varchar2);

 /*4    METODO: pr_ext_anterior PVP004
                Parametro: nro de tarjeta

                Retorno  : Varchar2 con todos los datos separados por #
 */
   PROCEDURE pr_ext_anterior
      (p_nro_tarjeta in varchar2,
       p_fecha       in date);

 /*2    METODO: fu_mov_ext_actual PVP002
                Parametro: nro de tarjeta, orden de movimiento, cantidad de detalles
                Retorno  : Varchar2 detalle de los n movimientos segun 
                           p_orden - A primeros movimientos
                                     D ultimos movimientos
 */
   FUNCTION fu_mov_ext_actual(p_nro_tarjeta  in varchar2,
                              p_orden        in varchar2,
                              p_can_detalles in out number) 
    RETURN LONG;

  /* Obtiene el codigo de error del registro del paquete. */
  FUNCTION fu_obt_cod_error
   RETURN VARCHAR2;
  /* Obtener el lugar en el que quedo cargado el registro del paquete. */
  FUNCTION fu_obt_lugar
   RETURN VARCHAR2;
  /* Obtiene el mensaje de error contenido en el registro del paquete. */
  FUNCTION fu_obt_msj_error
   RETURN VARCHAR2;
  -- Retorna el dato recibido por orden
  FUNCTION fu_obt_dato(P_dato IN VARCHAR2, p_nro in number, p_tipo in varchar2 default 'X')
    RETURN VARCHAR2;
  -- Nombre del poseedor de la tarjeta
  FUNCTION fu_nom_cliente
    RETURN  VARCHAR2;
  -- Descripción de la marca de la tarjeta
  FUNCTION fu_Marca
    RETURN  VARCHAR2;
  -- Descripción de la clase de tarjeta
  FUNCTION fu_Clase
    RETURN  VARCHAR2;
  --  Descripción de la afinidad a la que pertenece la tarjeta
  FUNCTION fu_Afinidad
    RETURN  VARCHAR2;
  --  Descripción de la moneda de la tarjeta
  FUNCTION fu_Moneda
    RETURN  VARCHAR2;
  --  Línea de crédito de la tarjeta
  FUNCTION fu_Lin_credito
    RETURN  NUMBER;
  --  Saldo disponible para compras normales de la tarjeta de crédito
  FUNCTION fu_Dis_com_normal
    RETURN  NUMBER;
  --  Saldo disponible para compras en cuotas de la tarjeta de crédito
  FUNCTION fu_Dis_com_cuotas
    RETURN  NUMBER;
   --  Saldo disponible para Avances de Efectivo de la tarjeta de crédito
  FUNCTION fu_Dis_ava_fectivo
    RETURN  NUMBER;
  --  Saldo de la deuda por compras normales de la tarjeta de crédito
  FUNCTION fu_Deu_com_normal
    RETURN  NUMBER;
  --  Saldo de la deuda por compras en cuotas de la tarjeta de crédito
  FUNCTION fu_Deu_com_cuotas
    RETURN  NUMBER;
  -- Saldo de la deuda total de la tarjeta de crédito
  FUNCTION fu_Deu_total
    RETURN  NUMBER;
  -- Saldo de la deuda en mora de la tarjeta de crédito
  FUNCTION fu_Deu_mora
    RETURN  NUMBER;
  --  Monto del Pago Mínimo aún pendiente de la tarjeta de crédito
  FUNCTION fu_Pago_min_pendiente
    RETURN  NUMBER;
  -- Fecha del vencimiento del pago mínimo de la tarjeta de crédito,AAAAMMDD
  FUNCTION fu_Fec_ven_pag_minimo
    RETURN  DATE;
  -- Fecha del próximo cierre de la tarjeta de crédito, en formato AAAAMMDD
  FUNCTION fu_Fec_pro_cierre
    RETURN  DATE;
  -- Nro de Transaccion de Infonet
  FUNCTION fu_Nro_tra_infonet
    RETURN  NUMBER;
  --  Deuda anterior de la tarjeta
  FUNCTION fu_deu_cie_anterior
    RETURN  NUMBER;
  --  total de debitos del mes
  FUNCTION fu_tot_deb_mes
    RETURN  NUMBER;
  --  total de creditos del mes
  FUNCTION fu_tot_cre_mes
    RETURN  NUMBER;


end PAG_BAN;
/

