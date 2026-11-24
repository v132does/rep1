CREATE OR REPLACE PACKAGE IT.PAG_SER IS
  /************************ V A R I A B L E S    G L O B A L E S ************************/
  -- Variables para control de errores
  g_cod_error       NUMBER := 0;
  g_men_error       VARCHAR2(4000) := NULL;
  r_ctapre    pr_cta_prestamos%ROWTYPE;
  -- Fecha y hora para procesos de cobros de servicios
  g_fecha           DATE := pag_cal.fu_obt_fec_actual(1);
  g_hora            VARCHAR2(8) := to_char( sysdate, 'HH24:MI:SS' );
  -- Variables globales con los datos del servicio
  g_cod_modulo      GE_CUENTAS.COD_MODULO%TYPE;
  g_cod_modalidad   GE_CUENTAS.COD_MODALIDAD%TYPE;
  g_cod_oficina     GE_CUENTAS.COD_OFICINA%TYPE;
  g_nro_cuenta      GE_CUENTAS.NRO_CUENTA%TYPE;
  g_cod_moneda      GE_CUENTAS.COD_MONEDA%TYPE;
  g_cod_transaccion GE_TRANSACCIONES.COD_TRANSACCION%TYPE;
  g_for_referencia   ge_cob_ser_parametros.for_campo1%type;

    /************************ VARIABLES DEL PACKAGE ***************************************/
  v_horario           varchar2(1)  := 'D'; -- Dia normal
  v_es_mov_noc        varchar2(1)  := 'N'; -- Graba S/N mov nocturnos
  v_es_cta_noc        varchar2(1)  := 'N'; -- Graba S/N ctas noctunas
  v_fec_actual        date         := pag_cal.fu_obt_fec_actual(3);          -- fecha de hoy
  v_fec_valor         date         := v_fec_actual;
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_msj_respuesta varchar2(250);
  v_cod_respuesta number(2);
  v_cod_usuario       varchar2(10) := user;  -- Codigo del usuario a grabar
  v_nro_secuencia     number(3)    := 0;
  v_cod_mon_local     varchar2(3) := pag_gen.FU_OBT_MON_LOCAL;
  v_cod_servicio      VARCHAR2(5);
  v_cod_retorno       VARCHAR2(3) := '000';
  v_des_retorno       VARCHAR2(30) := 'OK';
  v_cod_error      NUMBER(3) := 0;
  -- codigos de respuesta posibles ProNet - Prestamos
  v_cod_aprobado         VARCHAR2(3) := '000';
  v_sin_datos            VARCHAR2(3) := '001';
  v_mon_incorrecta       VARCHAR2(3) := '002';
  v_imp_mayor            VARCHAR2(3) := '003';
  v_tra_incorrecta       VARCHAR2(3) := '004';
  v_tip_incorrecto       VARCHAR2(3) := '005';
  v_cta_incorrecta       VARCHAR2(3) := '006';
  v_cuo_cancelada        VARCHAR2(3) := '007';
  v_bco_incorrecto       VARCHAR2(3) := '008';
  v_cuo_inexistente      VARCHAR2(3) := '009';
  v_nro_cuo_incorrecto   VARCHAR2(3) := '010';
  v_usu_incorrecto       VARCHAR2(3) := '011';
  v_ord_incorrecto       VARCHAR2(3) := '012';
  v_cob_inexistente      VARCHAR2(3) := '013';
  v_che_existente        VARCHAR2(3) := '014';
  v_che_rel_cuota        VARCHAR2(3) := '015';
  v_che_detallado        VARCHAR2(3) := '016';
  v_error                VARCHAR2(3) := '017';
  v_cie_diario           VARCHAR2(3) := '018';
  v_mto_can_insuficiente VARCHAR2(3) := '019';
  v_err_mto_anulacion    VARCHAR2(3) := '020';
  v_err_cie_cancela      VARCHAR2(3) := '021';
  v_err_mto_minimo       VARCHAR2(3) := '022';
  v_ent_incorrecta       VARCHAR2(3) := '023';
  v_err_proceso          VARCHAR2(3) := '999';
  v_red_pago             VARCHAR2(2);
  v_mod_estado           ba_modulos.estado%TYPE;
 -- r_ctapre               pr_cta_prestamos%ROWTYPE;
  --v_cod_error            NUMBER(3) := 0;

  /***************************** P R O C E D I M I E N T O S ****************************/
  /*
  || PR_VER_SERVICIO
  || ===============
  || Verifica los datos del servicio a procesar.
  || Controla que las referencias ingresadas tengan el formato
  || adecuado para ser procesado y que cumpla con las reglas definidas
  || por el usuario en la tabla GE_COB_SER_PARAMETROS. También verifica
  || que las monedas de la cuenta del servicio y la cuenta de débito del
  || cliente sean iguales.
  || * PPalella ==> 02/08/2005
  */
  PROCEDURE pr_ver_servicio( p_cod_servicio IN  GE_COB_SERVICIOS.COD_SERVICIO%TYPE,
                             p_cta_debito   IN GE_COB_SERVICIOS.NRO_CTA_DEBITO%TYPE,
                             p_referencia1  IN  GE_COB_SERVICIOS.REFERENCIA1%TYPE,
                             p_referencia2  IN  GE_COB_SERVICIOS.REFERENCIA2%TYPE,
                             p_par_referencia1 out ge_cob_servicios.referencia1%type);


  /*
  || LP_VAL_REFERENCIA
  || =================
  || Procedimiento interno que verifica el formato de P_REFERENCIA con
  || los datos de formato recibidos en P_FORMATO, y de acuerdo a P_VALIDAR
  || para mostrar o no una alerta.
  || Los formatos se cargan en la tabla GE_COB_SER_PARAMETROS
  || * PPalella ==> 02/08/2005
  */
  PROCEDURE lp_val_referencia( p_val_ref IN GE_COB_SERVICIOS.REFERENCIA1%TYPE,
                               p_formato IN GE_COB_SER_PARAMETROS.FOR_CAMPO1%TYPE,
                               p_validar IN GE_COB_SER_PARAMETROS.VAL_CAMPO1%TYPE
                               );

  /*
  || LF_YA_FUE_GRABADO
  || =================
  || Verifica que el documento P_REFERENCIA, no haya sido ingresado ya en
  || el día de hoy para el servicio P_COD_SERVICIO.
  || P_TIPO es para diferenciar la REFERENCIA 1 o 2.
  || * PPalella ==> 02/08/2005
  */
  FUNCTION lf_ya_fue_grabado( p_cod_servicio IN GE_COB_SERVICIOS.COD_SERVICIO%TYPE,
                              p_referencia   IN GE_COB_SERVICIOS.REFERENCIA1%TYPE,
                              p_tipo         IN NUMBER
                              ) RETURN VARCHAR2;

  /*
  || Proceso que lee la tabla GE_COB_SERVICIOS_TMP y luego intenta procesar
  || cada registro. Si se producen errores los, estos son procesados en
  || cada procedimiento, y el regisro queda marcado como con error en
  || la tabla GE_COB_SERVICIOS_TMP
  || * PPalella ==> 02/08/2005
  */
  PROCEDURE pr_pro_servicio( p_cod_servicio IN GE_COB_SERVICIOS.COD_SERVICIO%TYPE );

  /*
  || PR_INS_COBRO
  || ============
  || Proceso que inserta el cobro del servicio.
  || Primero busca sel siguiente número de operación que le corresponde
  || de acuerdo al valor de P_OPERACIÓN (Los valores válidos son (D= Débito,
  || A= Débito Automático, C= Cobro en Caja). Luego obtiene los cargos
  || y el impuesto, de acuerdo al monto a cobrar y por último inserta
  || el cobro.
  || * PPalella ==> 02/08/2005
  */
  PROCEDURE pr_ins_cobro( p_reg         IN GE_COB_SERVICIOS%ROWTYPE,
                          p_transaccion IN NUMBER,
                          p_operacion   IN VARCHAR2
                          );

  /*
  || PR_PRO_DEBITO
  || =============
  || Proceso que debita el cobro del servicio a la cuenta del cliente y acredita
  || el importe a la cuenta del proveedor del servicio.
  || El proceso recibe toda la información necesaria para insertar en GE_COB_SERVICIOS
  || mediante el parámetro P_REG
  || * PPalella ==> 02/08/2005
  */
  PROCEDURE pr_pro_debito( p_reg IN GE_COB_SERVICIOS%ROWTYPE,
                           p_tipo IN VARCHAR2 DEFAULT 'I'
                           );

  /*
  || Proceso de débito automático.
  || el proceso busca todos los servicios que estén marcados como
  || Débito Automático [nvl( p.deb_automatico, 'N' ) = 'S'], y luego procesa
  || las cuentas asociadas a ese servicio, que estén autorizadas y cuya
  || frecuencia coincida con el día de hoy.
  || Si la cuenta está marcada como cuotas [tipo = 'P'], entonces procesa
  || las cuotas pendientes que aun no se hayan pagado y cuya fecha de
  || vencimiento sea igual al día de hoy
  || * PPalella ==> 02/08/2005
  */
  PROCEDURE pr_pro_deb_automatico;

  /*
  || Procedimiento que busca los datos del servicio y los carga en
  || las globales del paquete.
  || * PPalella ==> 02/08/2005
  */
  PROCEDURE pr_obt_servicio( p_cod_servicio IN  GE_COB_SER_PARAMETROS.COD_SERVICIO%TYPE );

  /*
  || Funcion utilizada para verificar si se produjeron errores
  ||  en los procesos
  || * PPalella ==> 02/08/2005
  */
  FUNCTION fu_obt_error( p_cod_error OUT VARCHAR2,
                         p_men_error OUT VARCHAR2
                         ) RETURN BOOLEAN;

  /* Función que retorna la moneda de la cuenta de crédito del servicio */
  FUNCTION fu_obt_mon_servicio
   RETURN varchar2;

  /* Procedimietno que iniciliza las variables de error */
  PROCEDURE pr_ini_variables;

   /*Procedimiento que verifica si hay datos pendientes de ser procesados*/
   --si existen devuelve S y
   --1: pendientes en ge_cob_servicios o
   --2: pendientes en ge_cob_servicios_tmp
   PROCEDURE pr_ver_cob_pendientes
   (p_cod_servicio IN  GE_COB_SER_PARAMETROS.COD_SERVICIO%TYPE,
    p_cod_usuario in ge_cob_servicios.cod_usuario%type,
    p_fecha in ge_cob_servicios.fecha%type,
    p_cod_oficina ge_cob_servicios.cod_ofi_origen%type,
    p_existe out varchar2,
    p_ind_archivo out number);

PROCEDURE pr_ver_dat_temporales
(p_cod_ente in ge_cob_ser_parametros.cod_servicio%type,
 p_error out varchar2,
 p_procesar in varchar2);

   /*Función que verifica si ya se procesaron cobros del servicio para la oficina*/
   FUNCTION fu_ver_cob_procesados
   (p_cod_servicio IN  GE_COB_SER_PARAMETROS.COD_SERVICIO%TYPE,
    p_cod_usuario in ge_cob_servicios.cod_usuario%type,
    p_fecha in ge_cob_servicios.fecha%type,
    p_cod_oficina ge_cob_servicios.cod_ofi_origen%type )
   RETURN BOOLEAN;

   /*Función que obtiene la cuenta de debito a partir de la referencia recibida */
   FUNCTION fu_obt_cta_debito
   (p_cod_servicio IN  GE_COB_SER_PARAMETROS.COD_SERVICIO%TYPE,
    p_referencia   in  ge_cob_ser_cuentas.referencia%type)
   RETURN VARCHAR2;

   /* función que verifica si la referencia es numérico de 15 para poder grabar en los movimientos */
   FUNCTION fu_ver_es_numerico
   (p_referencia in ge_cob_servicios.referencia1%type,
    p_formato IN GE_COB_SER_PARAMETROS.FOR_CAMPO1%TYPE)
   return boolean;

   /* Funcion que genera el movimiento de autorizacion de pago de serviocios */
   FUNCTION fu_aut_pago
      (p_sesion in varchar2,
       p_servicio IN number,
       p_cuenta in varchar2,
       p_fecha in varchar2,
       p_hora in varchar2,
       p_nro_tran varchar2,
       p_nro_lote varchar2,
       p_nro_ip varchar2,
       p_terminal varchar2,
       p_moneda number,
       p_imp_tran number,
       p_imp_comision number,
       p_imp_mora number,
       p_imp_interes number)
    return varchar2 ;

   -- obtiene la moneda del servicio
   FUNCTION fu_obt_ser_moneda(p_codigo IN NUMBER)
      RETURN VARCHAR2;

   -- obtiene datos para cuenta credito
   FUNCTION fu_obt_cta_credito(p_proveedor       IN NUMBER,
                               p_moneda          IN NUMBER,
                               p_nro_cta_credito OUT VARCHAR2,
                               p_cod_moneda      OUT VARCHAR2) RETURN NUMBER;


   -- obtiene la transaccion padre del proveedor de servicios
   FUNCTION fu_obt_tra_padre(p_proveedor IN NUMBER) RETURN NUMBER;

  /* Funcion que obtiene la deuda de prestamos por Servicios */
  FUNCTION fu_obt_deu_prestamo(p_nro_cuenta IN pr_cuotas.nro_cuenta%TYPE,
                               p_moneda     IN ba_monedas.cod_mon_bco_central%TYPE
                               -- p_cod_moneda      IN pr_cta_prestamos.cod_moneda%TYPE nr
                               -- p_tip_transaccion IN bw_pag_servicios.nro_transaccion%TYPE, nr
                               -- p_cod_servicio    IN bw_pag_servicios.cod_servicio%TYPE nr
                               -- ) RETURN LONG;
                               ) RETURN varchar2;

  /* Funcion que realiza el cobro de prestamos por Servicios */
  FUNCTION fu_cob_prestamo(p_nro_cuenta IN pr_cuotas.nro_cuenta%TYPE,
                           p_nro_cuota  IN pr_cuotas.nro_cuota%TYPE,
                           p_importe    IN pr_cuotas.mto_capital%TYPE,
                           p_cod_moneda IN NUMBER,
                           --p_cod_moneda      IN pr_cta_prestamos.cod_moneda%TYPE, --se comenta porque llega como 6900 nr
                           p_tip_pago        IN VARCHAR2,
                           p_nro_cheque      IN VARCHAR2,
                           p_cod_banco       IN VARCHAR2,
                           p_fec_cheque      IN DATE,
                           p_tip_transaccion IN bw_pag_servicios.nro_transaccion%TYPE,
                           p_cod_servicio    IN bw_pag_servicios.cod_servicio%TYPE,
                           p_cod_transaccion IN bw_pag_servicios.nro_transaccion%TYPE,
                           p_pto_cobranza    IN NUMBER default null,
                           p_nro_cuo_hasta   IN NUMBER default null)
    RETURN varchar2;

  /* Funcion que realiza la reversion de cobro de prestamos por Servicios */
  FUNCTION fu_rev_cob_prestamo(p_nro_cuenta IN pr_cuotas.nro_cuenta%TYPE,
                               p_nro_cuota  IN pr_cuotas.nro_cuota%TYPE,
                               p_importe    IN pr_cuotas.mto_capital%TYPE,
                               p_moneda     IN ba_monedas.cod_mon_bco_central%TYPE, --nr
                               -- p_cod_moneda      IN pr_cta_prestamos.cod_moneda%TYPE,
                               p_tip_transaccion IN bw_pag_servicios.nro_transaccion%TYPE,
                               p_cod_servicio    IN bw_pag_servicios.cod_servicio%TYPE,
                               p_cod_transaccion IN bw_pag_servicios.nro_transaccion%TYPE,
                               p_cod_tra_anular  IN bw_pag_servicios.nro_transaccion%TYPE,
                               p_pto_cobranza    IN bw_pag_servicios.pto_cobranza%TYPE default null

                               ) RETURN varchar2;

   FUNCTION fu_PagoServicios
      (p_cod_persona     IN VARCHAR2,
       p_cod_empresa     IN VARCHAR2,
       p_sesion          IN VARCHAR2,
       p_servicio        IN NUMBER,
       p_cuenta          IN VARCHAR2,
       p_nro_tran        VARCHAR2,
       p_nro_lote        VARCHAR2,
       p_nro_ip          VARCHAR2,
       p_terminal        VARCHAR2,
       p_moneda          NUMBER,
       p_imp_tran        NUMBER,
       p_imp_comision    NUMBER,
       p_imp_mora        NUMBER,
       p_imp_interes     NUMBER,
       p_cod_ws_servicio IN VARCHAR2,
       p_proveedor       IN NUMBER,
       p_mto_debito      IN NUMBER,
       p_cot_debito      IN NUMBER,
       p_cot_credito     IN NUMBER,
       p_nro_documento   IN NUMBER,
       p_ref_pago        IN VARCHAR2) RETURN NUMBER;

   FUNCTION fu_PagoServiciosReversa(p_cod_ws_servicio  IN VARCHAR2,
                                    p_mensajeRespuesta OUT VARCHAR2,
                                    p_horario          IN VARCHAR2 DEFAULT 'S') RETURN NUMBER;

    /* Funcion reversa el movimiento de pago de serviocios */
    FUNCTION fu_rev_pago
      (p_nro_lote in varchar2,
       p_nro_tran in varchar2,
       p_proceso in varchar2 default null)
     return varchar2 ;
  /*
  || Funcion interna que envia mail de reversion al cliente por
  || pago a la SET o pago de servicios
  */
  FUNCTION fu_env_mail_pag_servicios(p_cod_ws_servicio IN bw_pag_servicios.cod_ws_servicios%TYPE,
                         p_nro_cuenta      IN ge_cuentas.nro_cuenta%TYPE,
                         p_nro_boleta      IN ge_set_pagos.nro_boleta%TYPE,
                         p_fecha           IN DATE,
                         p_cierre          IN VARCHAR2,
                         p_nro_transaccion IN bw_pag_servicios.nro_transaccion%TYPE) RETURN NUMBER;

   /*
   Verifica el tiempo transcurrido para crear otra sesion en bw_sesiones
   para una persona fisica o juridica
   S - esta permitido crear una sesión
   N - no esta permitido crear una sesión
   */
   FUNCTION fu_val_ins_sesion(p_cod_persona     IN ba_personas.cod_persona%TYPE,
                              p_cod_per_empresa IN ba_personas.cod_persona%TYPE)
     RETURN VARCHAR2;

   /*
   Inserta una sesion para el pago de servicios en la banca electronica
   S - se creo una sesión
   N - no se creo la sesión
   */
   FUNCTION fu_ins_sesion(p_sesion            IN VARCHAR2,
                          p_nro_ip            IN VARCHAR2,
                          p_cod_persona       IN ba_personas.cod_persona%TYPE,
                          p_cod_per_empresa   IN ba_personas.cod_persona%TYPE,
                          p_cuenta            IN ge_cuentas.nro_cuenta%TYPE)
     RETURN VARCHAR2;

   fin_por_error       exception;

   /*Procedimiento que inserta las reversiones por cobro de servicios que no se procesaron
     por estar en cierre. SPI 2277. CB. 04/09/2013*/
   PROCEDURE pr_ins_rev_cobro( p_nro_lote        IN varchar2,
                               p_nro_transaccion IN varchar2);

   /*Procedimiento de Inicio de día que inseta las reversiones de cobro que no se pudieron
   realizar mientras el sistema estaba en cierre. SPI 2277. CB. 04/09/2013*/
   PROCEDURE pr_pro_rev_cobro;
   -- procedimiento para llamar al API para reintentar pagos inconclusos
   PROCEDURE pr_pro_reintento;

  -- cupones de cda vencidos de los clientes
  PROCEDURE pr_obt_cup_vencidos( p_nro_documento   IN ba_personas.nro_documento%type,
                                 p_serie           IN ah_cta_certificados.serie%type,
                                 p_nro_certificado IN ah_cta_certificados.nro_certificado%type,
                                 p_cod_moneda      IN ah_cta_certificados.cod_moneda%type,
                                 p_reg_firma       IN OUT ah_cta_certificados.reg_firma%type,
                                 p_imagen          IN OUT long,
                                 p_nro_cupon       IN OUT ah_cupones.nro_cupon%type,
                                 p_nro_cuenta_tit  IN OUT varchar2,
                                 p_beneficiario    IN OUT varchar2,
                                 p_moneda          IN OUT varchar2,
                                 p_monto           IN OUT ah_cupones.mto_interes%type,
                                 p_fecha_venc      IN OUT ah_cupones.fec_vencimiento%type,
                                 p_cod_respuesta   out varchar2,
                                 p_msj_respuesta   out varchar2
                                 );
       -- obtener cda vencidos de los clientes
  PROCEDURE pr_obt_cda_vencidos( p_nro_documento   IN ba_personas.nro_documento%type,
                                 p_serie           IN ah_cta_certificados.serie%type,
                                 p_nro_certificado IN ah_cta_certificados.nro_certificado%type,
                                 p_cod_moneda      IN ah_cta_certificados.cod_moneda%type,
                                 p_reg_firma       OUT ah_cta_certificados.reg_firma%type,
                                 p_imagen          OUT long,
                                 p_nro_cuenta_tit  OUT varchar2,
                                 p_beneficiario    OUT varchar2,
                                 p_moneda          IN OUT varchar2,
                                 p_plazo           OUT number,
                                 p_monto           OUT ah_cta_certificados.capital%type,
                                 p_sal_disponible  OUT ah_cta_certificados.sal_total%type,
                                 p_fec_apertura    OUT ah_cta_certificados.fec_apertura%type,
                                 p_fecha_venc      OUT ah_cupones.fec_vencimiento%type,
                                 p_cod_respuesta   out varchar2,
                                 p_msj_respuesta   out varchar2
                                 )    ;

-- Reversión de pago de Capital CDA
  PROCEDURE pr_rev_cda_vencido (
                                      p_nro_transaccion IN ge_movimientos.nro_documento3%type,
                                      p_usuario    IN ba_usuarios.cod_usuario%type,
                                      p_fecha      IN date,
                                      p_cod_respuesta   out varchar2,
                                      p_msj_respuesta   out varchar2
                                 );

  -- Pagos de Cupon Interés / CDA capital vencidos tipo Efectivo o Crédito
  PROCEDURE pr_pag_cda_cupon_vencido ( p_nro_documento     in ba_personas.cod_persona%type,
                                     p_nro_certificado   in ah_cta_certificados.nro_certificado%type,
                                     p_cod_moneda        in ah_cta_certificados.cod_moneda%type,
                                     p_serie             in ah_cta_certificados.serie%type,
                                     p_cod_ente          in varchar2,
                                     p_cod_servicio      in number,
                                     p_agencia           in bw_pag_servicios.pto_cobranza%type default null,
                                     p_nro_transaccion   in bw_pag_servicios.nro_transaccion%type,
                                     p_nro_cupon         in varchar2, -- Nro del cupon
                                     P_importe           in varchar2 default null,
                                     p_tipo              in varchar2,
                                     p_fecha             in date,
                                     p_nro_cuenta        in varchar2 default null,
                                     p_cod_respuesta   out varchar2,
                                     p_msj_respuesta   out varchar2
                                     ) ;

   PROCEDURE pr_obt_dat_tarjetas(p_nro_cuenta       in ta_cta_tarjetas.nro_cuenta%type,
                                 p_nro_tarjeta      out ta_tarjetas.nro_tarjeta%type,
                                 p_nro_documento    out ba_personas.nro_documento%type,
                                 p_nom_embozar      out ta_tarjetas.nom_embozar%type,
                                 p_des_modalidad    out ge_modalidades.descripcion%type,
                                 p_moneda           out ta_cta_tarjetas.cod_moneda%type,
                                 p_sal_pag_minimo   out ta_cta_tarjetas.sal_pag_minimo%type,
                                 p_mto_pag_minimo   out ta_cta_tarjetas.mto_pag_minimo%type,
                                 p_sal_ult_extracto out ta_cta_tarjetas.sal_ult_extracto%type,
                                 p_deu_tot_actual   out ta_cta_tarjetas.sal_ult_extracto%type,
                                 p_fec_ult_cierre   out ta_cta_tarjetas.fec_ult_cierre%type,
                                 p_cod_modulo       out ta_cta_tarjetas.cod_modulo%type,
                                 p_cod_modalidad    out ta_cta_tarjetas.cod_modalidad%type,
                                 p_cod_oficina      out ta_cta_tarjetas.cod_oficina%type,
                                 p_dia_mora         out ta_cta_tarjetas.dia_mora%type,
                                 p_det_error        out ge_log_errores.det_error%type,
                                 p_en_juicio        out ta_cta_tarjetas.en_juicio%type,
                                 p_estado           out ta_cta_tarjetas.estado%type,
                                 p_cod_error        out number,
                                 p_respuesta        out varchar2);

  procedure pr_cob_tarjeta(p_nro_cuenta    IN ta_tarjetas.nro_cuenta%TYPE,
                           p_importe       IN pr_cuotas.mto_capital%TYPE,
                           p_mon_bcp       IN VARCHAR2,
                           p_comprobante   ge_movimientos.referencia%type, --Identificador unico de transaccion
                           p_id_movimiento ge_movimientos.nro_documento2%type,
                           p_red_pago      IN NUMBER default null,
                           p_error         out number,
                           p_respuesta     out varchar2);

  PROCEDURE pr_rev_cob_tarjeta(p_id_transaccion ge_movimientos.referencia%type,
                               p_id_mov         ge_movimientos.nro_documento2%type,
                               p_red_pago       ge_movimientos.nro_documento%type,
                               p_error          out number,
                               p_respuesta      out varchar2);

END pag_ser;
/

