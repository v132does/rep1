CREATE OR REPLACE PACKAGE IT.PAW_NOT IS
   /**  Obtiene la URL del ServiceIntegrator para enviar correos*/
   g_not_webservice VARCHAR2(150) := fug_obt_pardinamico('G_URL_WEBSERVICE', NULL, NULL); --:= 'http://62.12.240.10:4802/ServiceIntegrator/notification/';
   /** Guarda la cantidad de minutos entre mensajes iguales*/
   g_min_men_repetido NUMBER (5,3):=5;
   /** Indica la longitud del mensaje a enviar*/
   g_men_longitud NUMBER(3):= 140;    --DYDMR-5295 Nov/2016
   /** Cursor de los eventos activos de un paquete de notificaciones */
   CURSOR g_cur_paquete(p_codigo NUMBER) IS
      SELECT e.*
        FROM bw_not_eventos e
        JOIN bw_not_paquetes p
          ON e.cod_evento = p.cod_evento
       WHERE p.activo = 'S'
         AND p.paquete = p_codigo;

   /** Cursor para obtener las cuentas validas de un cliente */
   CURSOR g_cur_cuentas(p_cod_persona ba_personas.cod_persona%TYPE, p_cod_modulo ge_modalidades.cod_modulo%TYPE,
                        p_cod_modalidad ge_modalidades.cod_modalidad%TYPE) IS
      SELECT cu.*
        FROM ge_est_cuentas ec, ge_cuentas cu, ge_cta_clientes cc
       WHERE cc.nro_cuenta = cu.nro_cuenta
       --  AND cc.relacion = 'P' -- solo en las cuentas que es principal
         AND cc.cod_persona = p_cod_persona
         AND cc.cod_modulo = p_cod_modulo
         AND cc.cod_modalidad = decode(p_cod_modalidad, 0, cc.cod_modalidad, p_cod_modalidad)
         AND ec.cod_modulo = cu.cod_modulo
         AND ec.cod_modalidad = cu.cod_modalidad
         AND ec.estado = cu.estado
         AND ec.activo = 'S' -- solo cuentas activas
         AND cu.estado <> 'X'; -- omitir 'pendiente de verificacion'

   /** Cursor de titulares de una cuenta */
   CURSOR g_cur_titulares(p_nro_cuenta ba_personas.cod_persona%TYPE) IS
      SELECT ge_cta_clientes.COD_PERSONA, ge_cta_clientes.COD_MODULO, ge_cta_clientes.COD_MODALIDAD, ge_cta_clientes.relacion
        FROM ge_cta_clientes
       WHERE ge_cta_clientes.nro_cuenta = p_nro_cuenta;


   /** Invoca al metodo de enviar todas las notificaciones del ServiceIntegrator*/
   FUNCTION fu_env_todos RETURN NUMBER;

   /** Obtener informacion de tarjeta de debito o tarjeta de creditos
   @param p_nro_tarjeta Nro de la tarjeta de debito o credito a buscar
   @param p_cod_persona Codigo de la persona asignada a la tarjeta Titular o Adicional
   @param p_embozado Nombre en la tarjeta
   @param p_nro_cuenta Nro de cuenta de la tarjeta
   @param p_titular S indica si la persona es el titular de la tarjeta
   @param p_gourmet S indica que la tarjeta es gourmet
   @return number 0 indica exito
   */
   FUNCTION fu_obt_dat_tarjeta(p_nro_tarjeta IN VARCHAR2, p_cod_persona OUT VARCHAR2, p_embozado OUT VARCHAR2, p_nro_cuenta OUT VARCHAR2,
                               p_titular OUT VARCHAR2, p_tipo OUT VARCHAR2,p_gourmet OUT VARCHAR2) RETURN NUMBER;

   /** Enviar un sms de prueba
   @param p_nro_telefono numero de telefono al cual enviar el sms
   @param p_mensaje texto del mensaje a enviar
   @return number 0 indica exito
   */

   FUNCTION fu_env_sms_prueba(p_nro_telefono IN VARCHAR2, p_mensaje IN VARCHAR2, p_origen IN VARCHAR2) RETURN NUMBER;

   /** Enviar un mail de prueba
   @param p_mail email al cual enviar el email
   @param p_mensaje texto del mensaje a enviar
   @return number 0 indica exito
   */

   FUNCTION fu_env_email_prueba(p_email IN VARCHAR2, p_mensaje IN VARCHAR2, p_origen IN VARCHAR2) RETURN NUMBER;


FUNCTION fu_env_push(p_destino IN VARCHAR2, p_mensaje IN VARCHAR2, p_tipo IN VARCHAR2, p_origen IN VARCHAR2) RETURN NUMBER;

function fu_obtenerDestinoPush(p_codigoPersona in Varchar2) return typ_mensajerespuesta;


   /** obtiene el vencimiento de la tarjeta de credito
   @param p_nro_cuenta el numero de cuenta de la tarjeta
   @param p_cod_modulo el modulo de la cuenta de la tarjeta
   @param p_cod_modalidad la modalidad de la cuenta de la tarjeta
   @return number 0 indica exito
   */
   FUNCTION fu_obt_tar_vencimiento(p_nro_cuenta IN VARCHAR2, p_cod_modulo IN VARCHAR2, p_cod_modalidad IN VARCHAR2) RETURN DATE;


   /** Recibe los parametros desde el servicio de replicacion de transacciones de Bancard y despacha al procedimiento que encola el mensaje
    @param ticketNumber Número de boleta
    @param transactionDate Fecha hora de la transacción
    @param commerceName Razon social del comercio
    @param authorizationNumber Código de autorización
    @param entityCode Código de entidad
    @param cardNumber Número de tarjeta
    @param currencyCode Código de moneda en ISO
    @param countryCode Código de pais en ISO
    @param transactionAmount Importe de la transacción
    @param responseCode Código de respuesta
    @param originCode Identificador de origen
    @param deviceType Tipo de dispositivo
    @param serviceCode Código del servicio
    @param provideServiceCode Código servicio de prestación
    @param mccCode Código MCC (Merchant Category Code)
    @param transactionType Código de tipo de transacción
    @param paymentSource Código de origen de pago
    @return 0 en caso de exito
   */
   FUNCTION fu_not_men_tarjetas(ticket_number NUMBER, transaction_date DATE, commerce_name VARCHAR2, authorization_number VARCHAR2, entity_code VARCHAR2,
                                card_number VARCHAR2, currency_code NUMBER, country_code NUMBER, transaction_amount NUMBER, response_code VARCHAR2,
                                origin_code VARCHAR2, device_type VARCHAR2, service_code VARCHAR2, provide_service_code VARCHAR2, mcc_code NUMBER,
                                transaction_type VARCHAR2, payment_source VARCHAR2, product_brand VARCHAR2 DEFAULT NULL, brand_code VARCHAR2 DEFAULT NULL,
                                customer_account_number VARCHAR2 DEFAULT NULL, payment_method VARCHAR2 DEFAULT NULL)
                                RETURN NUMBER;

   /** Manipulacion de suscripciones
   @param p_sesion sesion del usuario
   @param p_canal canal de comunicacion
   @param p_nro_cuenta Cuenta para manejar la suscripcion
   @param p_cod_evento Codigo de evento
   @param p_activo S: Activar, N: inactivar
   @param p_horario horario de envio
   @param p_mto_minimo monto minimo
   @param p_frecuencia frecuencia de envio
   @return number Cantidad de filas afectadas. En caso de error se
             retorna un numero negativo.
   */
   FUNCTION fu_ins_suscripciones(p_sesion IN VARCHAR2, p_canal IN VARCHAR2, p_nro_cuenta IN VARCHAR2, p_cod_evento IN NUMBER, p_activo IN VARCHAR2,
                                 p_horario IN VARCHAR2 DEFAULT NULL, p_mto_minimo IN NUMBER DEFAULT NULL, p_frecuencia IN VARCHAR2 DEFAULT NULL)
      RETURN NUMBER;

   /** Encola un mensaje para una notificacion que no requiere modificar el template
   * y que el evento sea mandatorio (no controla configuracion de activo)
   @param p_cod_persona La persona a quien notificar
   @param p_cod_tip_evento El tipo de evento
   @param p_cod_origen Identificador del origen
   @return number 0 indica exito
   */
FUNCTION fu_not_env_evento(p_cod_persona IN ba_personas.cod_persona%TYPE, p_cod_tip_evento IN bw_not_tip_eventos.cod_tip_evento%TYPE,
                           p_cod_origen IN VARCHAR2) RETURN NUMBER;


   /** Encola un mensaje para una notificacion
   @param  p_cod_evento NUMBER Codigo del evento del mensaje
   @param  p_cod_origen VARCHAR2 Donde se genero el mensaje
   @param  p_mensaje VARCHAR2 Mensaje. Maximo 140 caracteres. Preferible sin acentos ni simbolos especiales
   @param  p_cod_persona VARCHAR2 Codigo de la persona a la cual se va a enviar
   @param  p_nro_cuenta VARCHAR2 Numero de cuenta del evento
   @param  p_fec_programada DATE fecha en la que se desea enviar el mensaje
   @param  p_enviar VARCHAR2 DEFAULT 'N' Indica si se va a enviar o no
   */
   FUNCTION fu_ins_mensaje(p_cod_evento IN NUMBER, p_cod_origen IN VARCHAR2, p_mensaje IN VARCHAR2,p_titulo IN VARCHAR2, p_destino IN VARCHAR2, p_cod_persona IN VARCHAR2, p_nro_cuenta IN VARCHAR2,
                           p_fec_programada DATE DEFAULT NULL, p_enviar IN VARCHAR2 DEFAULT 'N', p_nro_documento3 IN NUMBER DEFAULT 0) RETURN NUMBER;

   /** Calcula las fechas de vencimiento de tarjetas de credito y de acuerdo con la configuracion del evento encola mensajes */
FUNCTION fu_not_tar_men_vencimientos RETURN NUMBER;

--QUitar
   FUNCTION lf_obt_men_duplicado(p_cod_persona IN ba_personas.cod_persona%TYPE, p_mensaje IN VARCHAR2, p_dias IN NUMBER,
                                 p_fec_programada IN DATE DEFAULT NULL) RETURN NUMBER;

   /** Calcula la fecha del proximo envio tomando la fecha del ultimo envio y la configuracion del evento para el usuario. Si se envia por primera vez el mensaje es encolado en el dia actual a la hora configurada para la recepcion.
   */
FUNCTION lf_obt_fec_sig_evento(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE,
                               p_cod_evento IN bw_not_eventos.cod_evento%TYPE) RETURN DATE;


   /** Funcion auxiliar para encontrar la fecha de cierre de una tarjeta
   @param  p_nro_cuenta ge_cuentas.nro_cuenta%TYPE Numero de cuenta de la tarjea
   @param  p_cod_modulo ta_cta_tarjetas.cod_modulo%TYPE Modulo de la tarjeta
   @param  p_cod_modalidad ta_cta_tarjetas.cod_modalidad%TYPE Modalidad de la tarjeta
   @return DATE La fecha del cierre
      */
FUNCTION lf_obt_fec_cierre(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_cod_modulo IN ta_cta_tarjetas.cod_modulo%TYPE,
                              p_cod_modalidad IN ta_cta_tarjetas.cod_modalidad%TYPE) RETURN DATE;

   /**
   Busca todas las tarjetas de clientes suscriptos y si la fecha del cierre es el dia de mañana encola un mensaje para avisar el cierre de ciclo de facturacion de la tarjeta.
   */
FUNCTION fu_not_tar_men_cierres RETURN NUMBER;


   FUNCTION lf_obt_cant_suscripciones(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN NUMBER;
   /** Obtiene el template para el mensaje
   @param  p_cod_tip_evento bw_not_tip_eventos.cod_tip_evento%TYPE El tipo de mensaje
   @param  p_template OUT bw_not_tip_eventos.template%TYPE Puntero a la variable
   @param  p_response_code IN ta_ban_transaciones.response_code%TYPE DEFAULT '00' si es 00 se retorna el template 1 sino se retorna el template 2
   @return 0 si se encontro el template
   */
   FUNCTION fu_obt_not_template(p_cod_tip_evento bw_not_tip_eventos.cod_tip_evento%TYPE, p_template OUT bw_not_tip_eventos.template%TYPE,
                                p_response_code IN ta_ban_transaciones.response_code%TYPE DEFAULT '00') RETURN NUMBER;

   /** Encola la notificacion de pago de salarios
   @param p_cod_persona ba_personas.cod_persona%TYPE Codigo de la persona que va a recibir la notificacion
   @param p_nro_cuenta ge_cuentas.nro_cuenta%TYPE Numero de cuenta que recibe el credito
   @param p_moneda IN VARCHAR2 Moneda del pago en formato ITGF
   @param p_monto ge_pag_sueldos.monto%TYPE Monto del pago
   @param p_tipo ge_pag_sueldos.tipo%TYPE <ul><li>A: Aguinaldo</li><li>C:Comision</li><li>S:Sueldo</li><li>T: Credito en cuenta</li></ul>
   */
   FUNCTION fu_not_pag_sueldo(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_moneda IN VARCHAR2,
                              p_monto ge_pag_sueldos.monto%TYPE, p_tipo ge_pag_sueldos.tipo%TYPE) RETURN NUMBER;
FUNCTION fu_not_sal_cuenta RETURN NUMBER;
--Obtiene la fecha del ultimo cierre de la cuenta p_nro_cuenta
 FUNCTION lf_obt_fec_saldo(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE) RETURN DATE;

FUNCTION lf_not_tar_debitos(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_tip_tarjeta IN VARCHAR2,
                               ticket_number NUMBER, transaction_date DATE, commerce_name VARCHAR2, authorization_number VARCHAR2, entity_code VARCHAR2,
                               card_number VARCHAR2, currency_code NUMBER, country_code NUMBER, transaction_amount FLOAT, response_code VARCHAR2,
                               origin_code VARCHAR2, device_type VARCHAR2, service_code VARCHAR2, provide_service_code VARCHAR2, mcc_code NUMBER,
                               transaction_type VARCHAR2, payment_source VARCHAR2,p_gourmet VARCHAR2, product_brand VARCHAR2, brand_code VARCHAR2,
                               payment_method VARCHAR2) RETURN NUMBER;
   FUNCTION lf_not_tar_transferencias(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_tip_tarjeta IN VARCHAR2,
                                     ticket_number NUMBER, transaction_date DATE, commerce_name VARCHAR2, authorization_number VARCHAR2,
                                     entity_code VARCHAR2, card_number VARCHAR2, currency_code NUMBER, country_code NUMBER, transaction_amount FLOAT,
                                     response_code VARCHAR2, origin_code VARCHAR2, device_type VARCHAR2, service_code VARCHAR2,
                                      provide_service_code VARCHAR2, mcc_code NUMBER, transaction_type VARCHAR2, payment_source VARCHAR2,
                                      product_brand VARCHAR2, brand_code VARCHAR2) RETURN NUMBER;
FUNCTION lf_not_tar_deb_automatico(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_tip_tarjeta IN VARCHAR2,
                                     ticket_number NUMBER, transaction_date DATE, commerce_name VARCHAR2, authorization_number VARCHAR2,
                                     entity_code VARCHAR2, card_number VARCHAR2, currency_code NUMBER, country_code NUMBER, transaction_amount FLOAT,
                                     response_code VARCHAR2, origin_code VARCHAR2, device_type VARCHAR2, service_code VARCHAR2,
                                      provide_service_code VARCHAR2, mcc_code NUMBER, transaction_type VARCHAR2, payment_source VARCHAR2) RETURN NUMBER;
   /** Retorna la fecha en formato varchar de la forma DD/MM HH:MIN
      @param p_fecha Fecha en formato Date
      @return varchar2 la fecha en formato varchar de la forma DD/MM HH:MIN
   */
FUNCTION lf_obt_fec_tra_formateado(p_fecha IN DATE) RETURN VARCHAR2;

   /** Retorna los ultimos 4 digitos y el inicio con *
    @param p_nro_tarjeta el numero de tarjeta completo
    @return varchar2 el numero de tarjeta en formato *1234
   */
FUNCTION lf_obt_ult_tarjeta(p_nro_tarjeta IN VARCHAR2) RETURN VARCHAR2 ;

   /** Retorna el monto separado por miles y decimales dependiendo de la moneda
    @param p_monto float con el monto total
    @param p_moneda moneda en formato ISO
    @return varchar2 con el monto formateado de acuerdo a la moneda.
   */

FUNCTION lf_obt_mto_formateado(p_monto IN FLOAT, p_moneda IN NUMBER DEFAULT 600) RETURN VARCHAR2;
   --Para cambio de pin tiene que estar suscrito a otros debitos
   FUNCTION lf_not_tar_cam_pin(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_tip_tarjeta IN VARCHAR2,
                               ticket_number NUMBER, transaction_date DATE, commerce_name VARCHAR2, authorization_number VARCHAR2, entity_code VARCHAR2,
                               card_number VARCHAR2, currency_code NUMBER, country_code NUMBER, transaction_amount FLOAT, response_code VARCHAR2,
                               origin_code VARCHAR2, device_type VARCHAR2, service_code VARCHAR2, provide_service_code VARCHAR2, mcc_code NUMBER,
                               transaction_type VARCHAR2, payment_source VARCHAR2, product_brand VARCHAR2, brand_code VARCHAR2) RETURN NUMBER;

   /** Funcion para desuscribir al servicio push del cliente
   *   de notificaciones
   *
   @param p_sesion Sesion del cliente que se suscribe
   @param p_cod_canal Canal por el cual ingreso la peticion
   @return number 0 Indica exito
   */
   FUNCTION fu_des_push(p_sesion IN bw_aut_sesiones.cod_sesion%TYPE, p_cod_canal IN cj_cajas.nro_caja%TYPE) RETURN NUMBER;

   /** Funcion para suscribir a un cliente al paquete basico
   *   de notificaciones
   *
   @param p_sesion Sesion del cliente que se suscribe
   @param p_cod_canal Canal por el cual ingreso la peticion
   @return number Cantidad de eventos agregados
   */
   FUNCTION fu_sus_paq_basico(p_sesion IN bw_aut_sesiones.cod_sesion%TYPE, p_cod_canal IN cj_cajas.nro_caja%TYPE) RETURN NUMBER;

   /** Funcion para desuscribir a un cliente del paquete basico
   *   de notificaciones
   *
   @param p_sesion Sesion del cliente que se suscribe
   @param p_cod_canal Canal por el cual ingreso la peticion
   @return number Cantidad de eventos quitados
   */
   FUNCTION fu_des_paq_basico(p_sesion IN bw_aut_sesiones.cod_sesion%TYPE, p_cod_canal IN cj_cajas.nro_caja%TYPE) RETURN NUMBER;

   /** Funcion para notificar los pagos hechos en Batch. Los pagos seran en guaranies
   @param p_nro_tarjeta Numero de la tarjeta a ser pagada
   * @p_monto del pago
   * @p_fecha Fecha del pago
   @return number 0 en caso exitoso
   */
   FUNCTION fu_tar_pag_batch(p_nro_tarjeta IN ta_tarjetas.nro_tarjeta%TYPE, p_monto ge_movimientos.monto%TYPE) RETURN NUMBER;

   /** Funcion para notificar que el usuario excedio su linea de credito
   @param p_nro_tarjeta Numero de la tarjeta a ser pagada
   @return number 0 en caso exitoso
   */
   FUNCTION fu_tar_exc_linea RETURN NUMBER;

   /** Funcion para notificar a los usuarios que el vencimiento de la cuota actual de su prestamo esta por vencer.   */
   FUNCTION fu_pre_vencimientos RETURN NUMBER;

   /** Funcion para notificar a los usuarios la liberacion de fondos de cheques depositados
   @param p_nro_cuenta Numero de cuenta en la que se deposito el cheque
   @param p_monto monto del cheque depositado
   @param p_cod_moneda moneda
   @param p_tipo <ul><li>B si el cheque es del BBVA </li><li>O si el cheque es de otro banco</li><ul>
   @param p_fecha Fecha del deposito
   @return number 0 en caso exitoso
   */
   FUNCTION fu_che_lib_fondos(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_monto ge_movimientos.monto%TYPE, p_cod_moneda IN ba_monedas.cod_moneda%TYPE,
                              p_tipo VARCHAR2, p_fecha IN DATE) RETURN NUMBER;

   /** Funcion para notificar a los usuarios la devolucion de cheques depositados
   @param p_nro_cuenta Numero de cuenta en la que se deposito el cheque
   @param p_monto monto del cheque depositado
   @param p_cod_moneda moneda
   @param p_tipo <ul><li>B si el cheque es del BBVA </li><li>O si el cheque es de otro banco</li><ul>
   @return number 0 en caso exitoso
   */
   FUNCTION fu_che_dev_cheques(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_nro_cheque IN VARCHAR2, p_monto ge_movimientos.monto%TYPE,
                               p_cod_moneda IN ba_monedas.cod_moneda%TYPE, p_tipo VARCHAR2, p_fecha IN DATE) RETURN NUMBER;


   /** Funcion para notificar a los usuarios el pago o rechazo de cheques girados
   @param p_nro_cuenta Numero de cuenta en la que se deposito el cheque
   @param p_monto monto del cheque depositado
   @param p_cod_moneda moneda
   @param p_tipo <ul><li>S si se pago el cheque </li><li>N se rechazo el cheque</li><ul>
   @return number 0 en caso exitoso
   */
   FUNCTION fu_che_pag_girado(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_nro_cheque IN VARCHAR2, p_monto ge_movimientos.monto%TYPE,
                            p_cod_moneda IN ba_monedas.cod_moneda%TYPE, p_tipo VARCHAR2, p_fecha IN DATE) RETURN NUMBER;

   /** Funcion para notificar a los usuarios los debitos en caja
   @param p_nro_cuenta Numero de cuenta de la operacion
   @param p_monto monto de la operacion
   @param p_cod_moneda moneda
   @param p_fecha Fecha de la operacion
   @return number 0 en caso exitoso
   */
   FUNCTION fu_not_deb_caja(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_monto ge_movimientos.monto%TYPE, p_cod_moneda IN ba_monedas.cod_moneda%TYPE,
                            p_fecha IN DATE) RETURN NUMBER;
   /**
    Funcion para notificar a los usuarios que su cuenta corriente esta en sobregiro
   */
   FUNCTION fu_not_sobregiro RETURN NUMBER;

   /**
    Funcion para notificar a los usuarios que su cuenta corriente superon la linea de sobregiro
   */
   FUNCTION fu_not_exc_sobregiro RETURN NUMBER;

   /** Funcion para notificar a los usuarios la realizacion de una transferencia
    * Esta funcion para el debito hace uso del mismo cod_tip_mensaje utilizado en Transferencias desde ATM
    * La suscripcion solamente toma 'TATRANATM' para debitos y creditos
   @param p_nro_cuenta Numero de cuenta de credito o debito
   @param p_monto monto de la transferencia
   @param p_cod_moneda moneda
   @param p_tipo <ul><li>B si es un debito </li><li>C si es un credito</li><ul>
   @param p_fecha fecha de la operacion
   @return number 0 en caso exitoso
   */
   FUNCTION fu_not_transferencias(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_monto ge_movimientos.monto%TYPE,
                                  p_cod_moneda IN ba_monedas.cod_moneda%TYPE, p_tipo IN VARCHAR2, p_fecha IN DATE) RETURN NUMBER;
      
   FUNCTION fu_not_tra_gnb(p_nro_cta_debito   IN VARCHAR2,
                           p_cod_mon_debito   IN VARCHAR2,
                           p_mto_debito       IN NUMBER,
                           p_nro_cta_credito  IN VARCHAR2,
                           p_cod_mon_credito  IN VARCHAR2,
                           p_mto_credito      IN NUMBER,
                           p_nom_beneficiario IN VARCHAR2,
                           p_concepto         IN VARCHAR2,
                           p_nro_referencia   IN NUMBER,
                           p_tipo             IN VARCHAR2 DEFAULT 'C') RETURN NUMBER;
                         
   FUNCTION fu_not_tra_gnb_mail(p_nro_cta_debito   IN VARCHAR2,
                                p_cod_mon_debito   IN VARCHAR2,
                                p_mto_debito       IN NUMBER,
                                p_nro_cta_credito  IN VARCHAR2,
                                p_cod_mon_credito  IN VARCHAR2,
                                p_mto_credito      IN NUMBER,
                                p_nom_beneficiario IN VARCHAR2,
                                p_concepto         IN VARCHAR2,
                                p_nro_referencia   IN NUMBER,
                                p_tipo             IN VARCHAR2 DEFAULT 'C') RETURN NUMBER;
                          
   /** Funcion para verificar que el cliente esta suscripto al servicio
   @param p_cod_persona codigo de la persona
   @return varchar2 S si el cliente esta suscripto
   */
   FUNCTION fu_obt_suscripcion(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2;

   /** Da de alta a los usuarios titulares de tarjetas y a los que reciben pago de salarios. */
   PROCEDURE pr_alt_compulsiva;

   /** Funcion para obtener un numero de telefono de un cliente
      Se busca de acuerdo con:
     <ul><li>1ro. N° Celular de Notificaciones (solo si el usuario no se encuentra actualmente activo en el servicio de notificaciones)</li>
     <li>Nro Celular de Claves Dinamicas.</li>
     <li>Nro Celular declarado en Datos Personales (Carpeta General de la Persona - Pestaña Direcciones - Apartado Telefonos).</li>
    </ul>
     En este último caso, priorizar:
     Nro Celular de prestador Personal y Claro, por sobre el prestador TIGO (previendo exigencia p/envío previo "BBVA" al 88288).
     tipo de Nro Celular Particular sobre el Tipo Laboral (excluye a los tipos "Otro" y "Marketing", eventualmente no amparados en formularios suscriptos por el Cliente y/o validado por front).

   @param p_cod_persona codigo de la persona
   @return varchar2 S si el cliente esta suscripto
   */
   FUNCTION fu_obt_tel_cliente(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2;

   /* Da de alta a un cliente en notificaciones, y opcionalmente suscribe a un evento
   @param p_cod_persona BA_PERSONAS.COD_PERSONA%TYPE Codigo del cliente
   @param p_cod_destino BW_NOT_CLI_DESTINO.COD_DESTINO%TYPE Codigo del tipo de destino del cliente
   @param p_direccion BW_NOT_CLI_DESTINO.DIRECCION%TYPE Direccion del cliente (nro de telefono o direccion de mail)
   @param p_cod_origen in BW_NOT_CLI_DESTINO.COD_ORIGEN%TYPE Origen de la suscripcion
   @param p_cod_evento BW_NOT_EVENTOS.COD_EVENTO%TYPE Codigo del evento al cual va a ser suscripto el cliente
   @param p_nro_cuenta in GE_CUENTAS.NRO_CUENTA%TYPE Numero de cuenta a ser suscripto
   @return <ul><li><b>0:</b>Caso exitoso</li>
             <li><b>1:</b>Cliente ya suscripto. No se hace nada</li>
             <li><b>2:</b>Cliente suscripto. No se agrego la direccion</li>
             <li><b>10:</b>Otro Error</li></ul>
    */
   FUNCTION fu_alt_cliente(p_cod_persona IN BA_PERSONAS.COD_PERSONA%TYPE, p_cod_destino IN BW_NOT_CLI_DESTINO.COD_DESTINO%TYPE,
                           p_direccion IN BW_NOT_CLI_DESTINO.DIRECCION%TYPE, p_cod_origen IN BW_NOT_CLI_DESTINO.COD_ORIGEN%TYPE,
                           p_cod_evento IN BW_NOT_EVENTOS.COD_EVENTO%TYPE DEFAULT 0, p_nro_cuenta IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL) RETURN NUMBER;


   /** Funcion para activar o desactivar suscripciones a eventos de una cuenta
   @param p_sesion Sesion del cliente que se suscribe
   @param p_nro_cuenta Numero de cuenta
   @param p_modo Modo de operacion <ul><li><b>A:</b>Activar</li><li><b>B:</b>Deactivar</li><li><b>C:</b>Consulta</li></ul>
   @return number 0 en caso exitoso
   */
   FUNCTION fu_sus_cuenta(p_sesion IN bw_aut_sesiones.cod_sesion%TYPE, p_cod_canal in bw_movimientos.nro_caja%type, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_modo IN VARCHAR2) RETURN NUMBER;

   /** Funcion para ver si una tarjeta es gourmet S si la modalidad pertenece a las tarjetas gourmets
   @param p_cod_modalidad Modalidad de la tarjeta
   @return <ul><li><b>S:</b>Si es una modalidad de Gourmet</li>
             <li><b>N:</b>No es</li></ul>
    */
   FUNCTION lf_es_gourmet(p_cod_modalidad IN ge_cuentas.cod_modalidad%TYPE) RETURN VARCHAR2;

   /** Funcion para notificar a los usuarios la realizacion de un pago de servicios o una reversion de un pago de servicios
   @param p_nro_cuenta Numero de cuenta de credito o debito
   @param p_monto monto de la transferencia
   @param p_cod_moneda moneda
   @param p_tipo <ul><li>D si es un debito </li><li>R si es una reversion</li><ul>
   @param p_fecha fecha de la operacion
   @return number 0 en caso exitoso
   */
   FUNCTION fu_not_pag_servicios(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_monto ge_movimientos.monto%TYPE, p_cod_moneda IN ba_monedas.cod_moneda%TYPE,
                            p_tipo VARCHAR2,p_fecha in date) RETURN NUMBER;

   /**Funcion para enviar mails pendientes de solicitudes de cancelacion de productos*/
   FUNCTION fu_env_mail_can_prod RETURN NUMBER;

  /** Reemplaza los acentos de una cadena**/
  FUNCTION lf_reemplazoAcentos(p_texto IN VARCHAR2) RETURN VARCHAR2 ;


   /** Funcion para verificar si un usuario esta o no suscripto al blacklist de notificaciones
   @param p_cod_persona Numero de cuenta
   @param p_cod_tip_evento tipo del evento a verificar
   @return varchar2 S indica que el cliente esta suscripto al blacklist global o para el evento
   */
  FUNCTION fu_obt_con_blacklist(p_cod_persona IN ba_personas.cod_persona%TYPE, p_cod_tip_evento IN bw_not_tip_eventos.cod_tip_evento%TYPE) RETURN VARCHAR;

  /** Activa o desactiva bloqueos en el blacklist
   *
   * @param p_cod_sesion Sesión del cliente
   * @param p_cod_canal Código del canal
   * @param p_tip_operacion Tipo de operación (A=Activar, D=Desactivar)
   * @param p_tip_bloqueo Tipo de bloqueo (1=Evento, 2=Total)
   * @param p_cod_tip_evento Código del tipo de evento a activar/desactivar (Opcional)
   * @return
  */
  FUNCTION fu_blacklist(p_cod_sesion     IN BW_AUT_SESIONES.COD_SESION%TYPE,
                        p_cod_canal      IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                        p_tip_operacion  IN VARCHAR2,
                        p_tip_bloqueo    IN BW_NOT_BLACKLIST.TIP_BLOQUEO%TYPE,
                        p_cod_tip_evento IN BW_NOT_BLACKLIST.COD_TIP_EVENTO%TYPE DEFAULT NULL) RETURN TYP_MENSAJERESPUESTA;

  /** Funcion para encolar mensajes push para personas especificas
   @param p_cod_persona Codigo de la persona
   @param p_mensaje Mensaje a enviar
   @return number 0 indica que se envio correctamente
   */
  FUNCTION fu_enc_push(p_cod_persona IN ba_personas.cod_persona%TYPE, p_mensaje IN bw_not_mensajes.mensaje%TYPE) RETURN NUMBER;
   /** Funcion para enviar mensajes de publicidad a los clientes suscriptos via push
   @return number 0 indica que se envio correctamente
   */
  FUNCTION fu_not_pus_publicidad RETURN NUMBER;

   /**
   * Para saber si existe algun destino activo en notificaciones, sea o no activo
   * @param p_cod_persona Codigo cliente
   * @return number destino activo
   */
  FUNCTION fu_obt_cli_des_activo(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2;

  /**
   * Funcion para insertar compulsivamente a un cliente.
   *
   * Verifica si esta inactivo al servicio y lo activa en tal caso, caso contrario lo agrega.
   * Verifica si tiene destino activo y lo actualiza en tal caso
   *
   * @param p_cod_persona Codigo cliene a suscribir
   * @param p_direccion Direccion destino activo
   * @return number 0 en caso exitoso
   */
   FUNCTION fu_alt_notificacion(p_cod_persona IN bw_not_cli_destino.cod_persona%TYPE,
                                p_direccion   IN OUT VARCHAR2) RETURN NUMBER;

  /**
   * Funcion para notificar disponibilidad de extractos
   *
   *   AH/CC : una notificacion para todas las cuentas del cliente (proceso de inicio de dia).
   * Tarjeta : una notificacion por cada tarjeta principal del cliente (a requerimiento invocado por SAN)
   *
   * @param p_dato Codigo cliente (para cuentas) o Cedula del cliente (para tarjetas)
   * @param p_fecha Fecha cierre del extracto
   * @param p_nro_tarjeta Numero de la tarjeta (Opcional)
   * @return resultado de la operacion, 0 existoso
   */
  FUNCTION fu_not_extracto(p_dato        IN VARCHAR2,
                           p_fecha       IN ge_calendarios.fec_actual%TYPE,
                           p_nro_tarjeta IN ta_tarjetas.nro_tarjeta%TYPE DEFAULT NULL) RETURN NUMBER;

  -- obtener codigo de evento de un tipo
  FUNCTION fu_obt_cod_evento(p_cod_tip_evento IN bw_not_eventos.cod_tip_evento%TYPE,
                             p_cod_modulo     IN bw_not_eventos.cod_modulo%TYPE DEFAULT NULL,
                             p_cod_modalidad  IN bw_not_eventos.cod_modalidad%TYPE DEFAULT NULL,
                             p_mandatorio     IN bw_not_eventos.mandatorio%TYPE DEFAULT NULL) RETURN NUMBER;

  /**
   * Funcion para obtener si el Cliente está suscrito a Extracto Clic (para CC/AH)
   * AH/CC : una notificacion para todas las cuentas del cliente (proceso de inicio de dia).
   * @param p_cod_persona Código de Persona o cliente
   * @param p_nro_cuenta Número de Cuenta de la Tarjeta del Cliente
   */
  FUNCTION fu_obt_sus_ext_clic(p_cod_persona IN ba_personas.cod_persona%TYPE,
                               p_nro_cuenta IN ta_tarjetas.nro_cuenta%TYPE DEFAULT NULL) RETURN VARCHAR2;

  FUNCTION fu_not_sus_op_sin_tarjeta( p_nro_cuenta          IN BW_CTA_TELEFONOS.NRO_CUENTA%TYPE,
                                      p_nro_celular         IN BW_CTA_TELEFONOS.NRO_CELULAR%TYPE) RETURN NUMBER;


  /**
  * Retorna el tipo de destino del cliente suscripto a notificaciones
  * @param p_cod_persona Codigo de persona del cliente
  * @return tipo de destino al cual esta suscripto el cliente de acuerdo a bw_not_destinos.nombre
  */
  FUNCTION lf_ver_des_suscripto(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2;
   /**
  * Encola los mensajes de envio masivo de notificacion ips
  **/
  procedure pr_not_sms_ips;
  /**
  * Encola los mensajes de envio masivo de publicidades push
  **/
  procedure PR_NOT_REQ_MASIVO;
  /**
  * Notificion de transferencias BBVA via mail
  **/
  FUNCTION fu_not_mail_transferencias(p_nro_cta_debito IN ge_cuentas.nro_cuenta%TYPE,
                                     p_nro_cta_credito IN ge_cuentas.nro_cuenta%TYPE,
                                     p_cod_mon_debito IN ba_monedas.cod_moneda%TYPE,
                                     p_cod_mon_credito IN ba_monedas.cod_moneda%TYPE,
                                     p_tip_mensaje in bw_tip_mensajes.cod_tip_mensaje%type,
                                     p_mto_debito  in ge_movimientos.monto%TYPE,
                                     p_mto_credito  in ge_movimientos.monto%TYPE,
                                     p_fecha IN DATE) RETURN NUMBER;

/** Funcion para notificar a los usuarios el rechazo de cobro, vencimiento poliza de Seguro
   @param p_nro_cuenta Numero de cuenta de credito o debito
   @param p_cod_modulo Modulo
   @param p_cod_modalidad  Modalidad
   @param p_cod_persona Codigo de Persona
   @param p_ente Nombre del Ente
   @param p_cod_tip_evento Tipo de Evento
   @param p_fecha fecha
   @return number 0 en caso exitoso
   */
   FUNCTION fu_not_seguros(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE DEFAULT NULL,
     p_cod_modulo     IN bw_not_eventos.cod_modulo%TYPE DEFAULT NULL,
     p_cod_modalidad  IN bw_not_eventos.cod_modalidad%TYPE DEFAULT NULL,
     p_cod_persona in ba_personas.cod_persona%type DEFAULT NULL,
     p_ente ge_entes.descripcion%TYPE DEFAULT NULL,
     p_cod_tip_evento bw_not_eventos.cod_tip_evento%TYPE,
     p_fecha in date DEFAULT NULL) RETURN NUMBER;
  /**
  * Encola los mensajes de Envio de Notificaciones de Retiro de Productos en sucursal
  **/
   PROCEDURE pr_not_ret_pro_suc;
   
  /**
   * Obtiene un horario segun hora de inicio y fin. Si la hora esta en el rango se usa sysdate + 0.75 minutos.
   *  - Si la hora es mayor a la hora de fin, se retorna la fecha siguiente.
   *  - Si la hora es menor a la hora de inicio, se retorna una fecha desde las 8AM + 0.75 minutos de sysdate.
   * @param p_hor_inicio Hora inicial
   * @param p_hor_fin Hora final
   */
  FUNCTION fu_obt_horario(p_hor_inicio IN NUMBER,
                          p_hor_fin    IN NUMBER) RETURN DATE;
   
   /**
    * Funcion para notificar a los usuarios el cobro de cuota programado
    * 
    * @param p_cod_persona Codigo de Persona
    * @param p_nro_cuenta Numero de cuenta de ahorro programado
    * @param p_moneda Moneda de la cuenta
    * @param p_monto Monto
    * @param p_nro_cuota Numero de cuota
    * @param p_cod_error Suceso o error
    */
  PROCEDURE fu_not_cob_ahorro(p_cod_persona    IN ba_personas.cod_persona%TYPE,
                              p_nro_cuenta     IN ge_cuentas.nro_cuenta%TYPE, 
                              p_moneda         IN ba_monedas.cod_moneda%TYPE,
                              p_monto          IN ah_pro_cuotas.mto_cuota%TYPE, 
                              p_nro_cuota      IN ah_pro_cuotas.nro_cuota%TYPE,
                              p_cod_error      IN VARCHAR2);

   /**
    * Funcion para notificar a los usuarios el recibo de solicitud de transferencia.
    * 
    * @param p_tipo A: aviso recepcion, C: confirmacion solicitud, R: rechazo solicitud
    * @param p_cod_persona Codigo de Persona
    * @param p_moneda Moneda de la cuenta
    * @param p_monto Monto
    * @param p_nro_cuenta Numero de cuenta de ahorro programado
    */                
  FUNCTION fu_not_rec_multiple(p_tipo           IN VARCHAR2,
                               p_cod_persona    IN ba_personas.cod_persona%TYPE,
                               p_moneda         IN ba_monedas.cod_moneda%TYPE,
                               p_monto          IN ge_movimientos.monto%TYPE,
                               p_nro_cuenta     IN ge_cuentas.nro_cuenta%TYPE,
                               p_fecha          IN DATE) RETURN NUMBER;
    /**
  * Encola los mensajes de envio masivo de publicidades push
  **/
  procedure pr_not_req_mas_push;
  FUNCTION fu_not_cam_cla(p_cod_persona bw_ope_claves.cod_persona%TYPE,
                          p_cod_per_vinculada bw_ope_claves.cod_per_vinculada%TYPE,
                          p_tip_notificacion VARCHAR2,
                          p_tip_clave VARCHAR2) RETURN NUMBER;
                          
  FUNCTION fu_not_pre_apr(p_cod_persona bw_ope_claves.cod_persona%TYPE,
                          p_nro_cta_credito VARCHAR2) RETURN NUMBER; 
                          
  --Envía mail y notificacion al canal correspondiente cuando ingresa desde nuevo dispositivo
  PROCEDURE pr_not_nue_dispositivo (p_codPersona        IN ba_personas.cod_persona%TYPE,
                                    p_cod_per_vinculada IN ba_personas.cod_persona%TYPE,
                                    p_os                IN VARCHAR2,
                                    p_os_version        IN VARCHAR2,
                                    p_model             IN VARCHAR2,
                                    p_brand             IN VARCHAR2,
                                    p_ip                IN VARCHAR2,
                                    p_ubication         IN VARCHAR2,
                                    p_cod_fac           IN VARCHAR2,
                                    p_cli_type          IN VARCHAR2);
  
   PROCEDURE pr_not_nue_dispositivo_error (p_codPersona        IN ba_personas.cod_persona%TYPE,
                                     p_cod_per_vinculada IN ba_personas.cod_persona%TYPE,
                                     p_os                IN VARCHAR2,
                                     p_os_version        IN VARCHAR2,
                                     p_model             IN VARCHAR2,
                                     p_brand             IN VARCHAR2,
                                     p_ip                IN VARCHAR2,
                                     p_ubication         IN VARCHAR2,
                                     p_cod_fac           IN VARCHAR2,
                                     p_cli_type          IN VARCHAR2);
                                    
   PROCEDURE pr_not_deu_ven_pag_servicios (p_datos IN TYP_LISTAPSNOTIF DEFAULT NULL) ;                               
                                    
   FUNCTION fu_not_deu_ven_pag_seg_envio(p_cod_persona IN  ba_personas.cod_persona%TYPE,
                                         p_tip_persona IN VARCHAR2,
                                         p_mai_cuerpo IN VARCHAR2
                                      ) RETURN NUMBER ;

   FUNCTION fu_not_pag_ban_qr(p_cod_persona IN  ba_personas.cod_persona%TYPE,
                                          p_mai_cuerpo IN VARCHAR2,
                                          p_metodo_pago IN VARCHAR,
                                          p_monto       IN NUMBER,
                                          p_nro_cuenta  IN VARCHAR2,
                                          p_nro_tarjeta IN VARCHAR2,
                                          p_comercio IN VARCHAR2,
                                          p_fecha IN DATE,
                                          p_estado IN VARCHAR2
                                          ) RETURN VARCHAR2;
END PAW_NOT;
/

