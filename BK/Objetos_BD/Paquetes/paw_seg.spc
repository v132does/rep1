CREATE OR REPLACE PACKAGE IT.paw_seg IS

   /** Validar datos del cliente
   * @param p_TipoDocumento tipo de documento
   * @param p_nroDocumento número de documento del cliente
   * @param p_fechaNacimiento Fecha de nacimiento del cliente
   * @param p_TipoTarjeta tipo de tarjeta, débito inicialmente
   * @param p_nroTarjeta número de la tarjeta de débito
   * @param p_Origen Origen del solicitud
   * @return typ_solicitudNuevaClave
   **/
   FUNCTION fu_valDatosSolNuevaClave(p_TipoDocumento IN NUMBER, p_nroDocumento IN VARCHAR2, p_fechaNacimiento IN DATE, p_TipoTarjeta IN VARCHAR2, p_nroTarjeta IN VARCHAR2, p_Origen IN VARCHAR2, p_dato_adicional IN VARCHAR2, p_nro_ip in varchar2, p_tip_clave IN VARCHAR2 DEFAULT NULL)
      RETURN typ_solicitudNuevaClave;

   /** Genera la clave del cliente
   * @param p_cod_persona token registrado en la solicitud de claves
   * @param p_cod_per_vinculada código de la persona vinculada
   * @param p_clave clave en md5
   * @param p_estado estado de la clave
   * @param p_tipo_Clave tipo de clave 'A' Acceso, 'T' Transaccional, 'K' Token
   * @return number 0 éxito y 1 fracaso
   **/
   FUNCTION fu_gen_Clave(p_cod_persona IN VARCHAR2, p_cod_per_vinculada IN VARCHAR2, p_clave IN OUT VARCHAR2, p_estado IN VARCHAR2 DEFAULT 'A', p_tip_clave IN VARCHAR2) RETURN number;

   /** Guarda la clave del cliente
   * @param p_token token registrado en la solicitud de claves
   * @param p_clave clave en md5
   * @param p_tipo_Clave tipo de clave 'A' Acceso, 'T' Transaccional, 'K' Token
   * @return typ_MensajeRespuesta
   **/
   FUNCTION fu_guardarClave(p_token IN VARCHAR2, p_clave IN VARCHAR2, p_tipo_Clave IN VARCHAR2) RETURN typ_MensajeRespuesta;

   /** Devuelve datos espécificos del cliente
   * @param p_nroCuenta código de la persona correspondiente al cliente
   * @param p_tipoClave tipo de clave
   * @param p_claveAcceso clave de acceso
   * @param p_nroTelefono número telefónico del cliente
   * @param p_TipoDocumento tipo de documento
   * @param p_nroDocumento númeron de documento
   * @param p_fechaNacimiento fecha de nacimiento
   * @param p_TipoTarjeta tipo de tarjeta, débito en este caso
   * @param p_nroTarjeta número de tarjeta de débito
   **/
   PROCEDURE pr_datosAtm(p_nroCuenta IN VARCHAR2, p_tipoClave IN VARCHAR2, p_claveAcceso IN VARCHAR2, p_nroTelefono IN VARCHAR2, p_TipoDocumento OUT NUMBER, p_nroDocumento OUT VARCHAR2, p_fechaNacimiento OUT DATE, p_TipoTarjeta OUT VARCHAR2,
                         p_nroTarjeta OUT VARCHAR2);

   /** Envía un correo electrónico al cliente
   * @param p_cod_persona código de la persona correspondiente al cliente
   * @param p_tipClave tipo de clave 'A' Acceso, 'T' Transaccional, 'K' Token
   * @return NUMBER número 0 en caso de éxito, 1 en caso de fracaso
   **/
   FUNCTION fu_env_mai_clavefacil(p_cod_persona IN VARCHAR2, p_tipClave IN VARCHAR2) RETURN number;

   /** Obtiene el número de celular particular del cliente
   * @param p_cod_persona código de la persona correspondiente al cliente
   * @return VARCHAR2 número de celular, vacio('') en caso de no encontrar resultado
   **/
   FUNCTION fu_obt_celular(p_cod_persona IN VARCHAR2) RETURN VARCHAR2;

   /** Obtiene el correo electrónico que corresponde al cliente
   * @param p_cod_persona código de la persona correspondiente al cliente
   * @return VARCHAR2 correo electrónico, vacio('') en caso de no encontrar resultado
   **/
   FUNCTION fu_obt_mail(p_cod_persona IN VARCHAR2) RETURN VARCHAR2;

   /** Obtiene el primer número de tarjeta de débito del cliente activa
   * @param p_cod_persona código de la persona correspondiente al cliente
   * @return VARCHAR2 nro de tarjeta de débito, vacio('') en caso de no encontrar resultado
   **/
   FUNCTION fu_obt_tar_deb_activa(p_cod_persona IN VARCHAR2) RETURN VARCHAR2;

   /** Envía un sms al celular configurado como principal del cliente
   * @param p_cod_persona código de la persona correspondiente al cliente
   * @param p_tipClave tipo de clave 'A' Acceso, 'T' Transaccional, 'K' Token
   * @return NUMBER número 0 en caso de éxito, 1 en caso de fracaso
   **/
   FUNCTION fu_env_sms_clavefacil(p_cod_persona IN VARCHAR2, p_tipClave IN VARCHAR2) RETURN number;

   /** Obtiene el motivo de rechazo de la solicitud de claves
   * @param p_token el código de sesión del cliente
   * @return VARCHAR2 descripción del motivo del rechazo, si fue satisfactoria la generación devuelve vacío('')
   **/
   FUNCTION fu_obt_mot_rechazo(p_token IN VARCHAR2) RETURN VARCHAR2;

   /** Que clave solicitar al usuario
   * @param p_par_cla_transaccional Parametro de clave transaccional
   * @param p_par_cla_token Parametro de clave otp
   * @param p_cod_persona cliente asociado
   */
   FUNCTION fu_obt_cla_operacion(p_par_cla_transaccional IN ge_par_entes.parametro%TYPE,
                                 p_par_cla_token         IN ge_par_entes.parametro%TYPE,
                                 p_cod_persona           IN ba_personas.cod_persona%TYPE DEFAULT NULL) RETURN VARCHAR2;

   /** se inserta la lista de cierres de tarjeta obtenidos del DMS
   * @param p_sesion Sesion del usuario
   * @param p_codigoCanal Numero de terminal
   * @param p_listaId lista de tarjetas
   * @return 0 Exito
   */
   FUNCTION fu_ins_dms_tarjetas(p_sesion      IN VARCHAR2,
                                p_codigoCanal IN VARCHAR2,
                                p_listaId     IN TYP_LISTADETALLEDMS) RETURN NUMBER;

   /** funcion para verificar que un id de tarjeta pertenezca al cliente
   * @param p_sesion Sesion del usuario
   * @param p_codigoCanal Numero de terminal
   * @param p_cardId identificador de tarjeta
   * @return 0 Pertenece
   */
   FUNCTION fu_val_dms_tarjeta(p_sesion      IN VARCHAR2,
                               p_codigoCanal IN VARCHAR2,
                               p_cardId      IN NUMBER) RETURN NUMBER;

   /**
    * Registra el dispositivo del cliente para login biometrico
    * @param p_cod_persona codigo de persona del cliente
    * @param p_id_dispositivo identificador del registro a insertar
    * @param p_cod_dispositivo identificador unico por instalacion del dispositivo
    * @param p_cla_privada clave privada RSA en base64
    * @param p_marca marca del dispositivo
    * @param p_modelo  modelo del dispositivo
    * @param p_sistema sistema del dispositivo
    * @param p_sis_version version del so del dispositivo
    * @param p_alias alias del dispositivo
    * @param p_clave clave que sera generada en el procedimiento
    * @param p_retorno objeto retorno
    * @param p_modo modo (A: alta, M: modificacion)
   */
   PROCEDURE pr_reg_cla_privada(p_cod_persona IN VARCHAR2,
                              p_id_dispositivo IN VARCHAR2,
                              p_cod_dispositivo IN VARCHAR2,
                              p_cla_privada IN VARCHAR2,
                              p_marca IN VARCHAR2,
                              p_modelo IN VARCHAR2,
                              p_sistema IN VARCHAR2,
                              p_sis_version IN VARCHAR2,
                              p_alias IN VARCHAR2,
                              p_clave IN OUT VARCHAR2,
                              p_retorno IN OUT typ_regclave,
                              p_modo IN VARCHAR2);

   /**
    * Registra el dispositivo del cliente para login biometrico
    * @param p_nro_serial identificador unico del serial SoftToken
    * @param p_cod_persona codigo de persona del cliente
    * @param p_cod_dispositivo identificador unico del dispositivo
    * @param p_cla_encriptacion clave de encriptado AES
    * @param p_vec_inicializacion vector de inicializacion de la clave AES
    * @param estado estado del serial SoftToken
    * @param p_retorno tipo de retorno del procedimiento
   */
   PROCEDURE pr_reg_cla_softoken(p_nro_serial IN VARCHAR2,
                              p_cod_persona IN VARCHAR2,
                              p_cod_dispositivo IN VARCHAR2,
                              p_cla_encriptacion IN VARCHAR2,
                              p_vec_inicializacion IN VARCHAR2,
                              p_estado IN VARCHAR2,
                              p_retorno IN OUT typ_regsoftokenkey,
                              p_dominio IN VARCHAR2 DEFAULT 'RETAILPY',
                              p_modo IN VARCHAR2 DEFAULT 'A',
                              p_cod_per_vinculada IN VARCHAR2 DEFAULT NULL,
                              p_es_migracion IN VARCHAR2 DEFAULT 'N');
   /**
    * Valida la clave recibida
    * @param p_cod_persona codigo de persona del cliente
    * @param p_id_dispositivo identificador del dispositivo
    * @param p_clave clave del cliente generado de forma automatica en fu_reg_cla_privada
    * @param p_retorno objeto retorno
   */
   PROCEDURE pr_val_cla_estatica(p_cod_persona IN VARCHAR2,
                                 p_id_dispositivo IN VARCHAR2,
                                 p_clave IN VARCHAR2,
                                 p_retorno IN OUT typ_iniciarSesion);
   /**
    * Actualiza la cantidad de visitas en bw_cla_cli_destino
    * @param p_cod_persona codigo de persona del cliente
    * @param p_id_dispositivo identificador del dispositivo
   */
   PROCEDURE pr_act_visitas(p_cod_persona       IN VARCHAR2,
                            p_id_dispositivo IN VARCHAR2);

   /*
   * Agrega al blacklist de canales digitales
   */
   procedure pr_agregarBlacklist;

   /**
   Quita del Blacklist de canales digitales
   */
   PROCEDURE pr_quitarBlacklist;
   /**
    * Verifica el estado de la persona en el blacklist de canales digitales
    * @param p_cod_persona codigo de persona del cliente
    * @return S en caso de que este en el estado activo del blacklist. N sino
   */
   FUNCTION fu_obtenerBlacklist(p_cod_persona IN VARCHAR2) RETURN VARCHAR2;

   /**
    * Valida que no se usen datos personales para generar o cambiar clave.
    *
    * @param p_cod_persona codigo cliente
    * @param p_cla_md5 clave en md5 recibido del canal
    * @return 0: ok
    *        -1: contenido en nro. doc
    *        -2: contenido en telefono
    *        -3: contenido en fec. nacimiento en cualquier formato de fecha
    *       -10: cliente no encontrado
    *       -11: otro error
    */
   FUNCTION fu_val_gen_clave(p_cod_persona IN ba_personas.cod_persona%TYPE,
                             p_cla_md5     IN VARCHAR2) RETURN NUMBER;

   --recibe la clave en minusculas y hasheada en md5 recupera el salt del usuario y verifica que la clave sea igual a la guardada
   FUNCTION fu_val_ope_clave(p_clave             IN VARCHAR2,
                             p_cod_persona       IN VARCHAR2,
                             p_cod_per_vinculada IN VARCHAR2,
                             p_tip_clave         IN VARCHAR2,
                             p_act_visitas       IN VARCHAR2 DEFAULT 'N') RETURN typ_mensajeRespuesta;

   PROCEDURE pr_act_est_ope_clave(p_cod_persona       IN VARCHAR2,
                                  p_cod_per_vinculada IN VARCHAR2,
                                  p_tip_clave         IN VARCHAR2);

   FUNCTION fu_obt_permisos(p_cod_persona        IN varchar2,
                            p_cod_perfil        IN varchar2,
                            p_cod_canal         in varchar2,
                            p_cod_operacion IN VARCHAR2) RETURN typ_permisos;

   /**
    * Verificacion de estado de clave transaccional
    * 0 no tiene clave ni solicitud
    * 1 tiene una clave transaccional y no tiene que hacer nada
    * 2 ya tiene una o más claves en bw_ope_claves o solicitudes en bw_sol_claves
    * 3 tiene que cambiar su clave
    */
   FUNCTION fu_verificarClaveTransaccional(p_codPersona          IN VARCHAR2,
                                           p_codPersonaVinculada IN VARCHAR2) RETURN NUMBER;

   FUNCTION fu_val_cla_transaccional(p_cod_persona       IN VARCHAR2,
                                   p_cod_per_vinculada IN VARCHAR2,
                                   p_cla_transaccional IN VARCHAR2) RETURN typ_mensajeRespuesta;

   FUNCTION fu_obt_cla_val_operacion(p_cod_tip_mensaje       IN bw_tip_mensajes.cod_tip_mensaje%TYPE,
                                  p_cod_persona           IN ba_personas.cod_persona%TYPE DEFAULT NULL,
                                  p_cod_empresa           IN ba_personas.cod_persona%TYPE DEFAULT NULL,
                                  p_cod_canal             IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                                  p_cod_sesion_aux        IN BW_AUT_SESIONES.COD_SESION%TYPE DEFAULT NULL) RETURN TYP_CLAVE_VALIDACION;

   /** Crea una sesion para el canal y cuenta especificada
    * @param p_password        Contraseña en texto plano
    * @param p_dato            Información de tercero que desea iniciar sesion. El tipo esta especificado en p_tipoDato
    * @param p_tipoDato        Código del tipo de cuenta que desea iniciar sesion. "D" documento, "K" codigo Persona, "C" tarjeta de credito
    * @param p_nroDocEmpresa   nro de RUC de empresa a la que esta vinculada la persona.Opcional
    * @param p_tipoDocEmpresa  Tipo de Documento de la empresa. "D" RUC
    * @param p_codCanal        Código de Canal para el cual se creará la sesion
    * @return retorna informacion de la sesion creada  e información referente a la cuenta.
    */
   FUNCTION fu_iniciarsesion(p_password       IN VARCHAR2,
                             p_dato           IN VARCHAR2,
                             p_tipodato       IN VARCHAR2,
                             p_nrodocempresa  IN VARCHAR2,
                             p_tipodocempresa IN VARCHAR2,
                             p_codcanal       IN VARCHAR2) RETURN typ_iniciarsesion;

   FUNCTION fu_ins_otp(p_cod_persona           IN VARCHAR2,
                       p_cod_per_vinculada     IN VARCHAR2,
                       p_cod_canal             IN VARCHAR2,
                       p_otp_value             IN VARCHAR2,
                       p_id_sesion IN VARCHAR2 DEFAULT NULL) RETURN typ_mensajerespuesta;

   FUNCTION fu_val_otp(p_cod_persona           IN VARCHAR2,
                       p_cod_per_vinculada     IN VARCHAR2,
                       p_cod_canal             IN VARCHAR2,
                       p_otp_value             IN VARCHAR2,
                       p_id_sesion IN VARCHAR2 DEFAULT NULL) RETURN typ_mensajerespuesta;
   /**
    * Verifica una pseudo sesion recibida desde el consumidor invocado por runes.
    */
   PROCEDURE fu_val_ses_consumer(p_sesion        IN VARCHAR2,
                                 p_cod_canal     IN cj_cajas.nro_caja%TYPE,
                                 p_error         OUT VARCHAR2,
                                 p_nom_respuesta OUT VARCHAR2,
                                 p_des_respuesta OUT VARCHAR2,
                                 p_cod_persona   OUT ba_personas.cod_persona%TYPE,
                                 p_cod_empresa   OUT ba_personas.cod_persona%TYPE,
                                 p_cod_perfil    OUT bw_perfiles.cod_perfil%TYPE);

   FUNCTION fu_val_per_operacion(p_cod_persona           IN VARCHAR2,
                                 p_cod_per_vinculada     IN VARCHAR2,
                                 p_cod_canal             IN VARCHAR2,
                                 p_operaciones           IN VARCHAR2) RETURN typ_mapa;

   FUNCTION fu_obt_cla_validar(p_clave IN VARCHAR2,
                               p_cod_persona       IN VARCHAR2,
                               p_cod_per_vinculada IN VARCHAR2,
                               p_cod_canal         IN VARCHAR2,
                               p_operaciones       IN VARCHAR2) RETURN typ_mapa;

   FUNCTION fu_obt_tok_validar(p_cla_token         IN VARCHAR2,
                               p_cod_persona       IN VARCHAR2,
                               p_cod_per_vinculada IN VARCHAR2,
                               p_modo              IN VARCHAR2) RETURN typ_mensajeRespuesta;

   /* Genera semilla randomica necesaria para encriptar QRs de autorizaciones */
   FUNCTION fu_gen_semilla_autorizacion(p_nro_documento         IN NUMBER,
                                        p_cod_persona           IN NUMBER) RETURN NUMBER;

   FUNCTION fu_act_est_softoken(p_cod_persona       IN VARCHAR2,
                               p_cod_per_vinculada IN VARCHAR2,
                               p_estado IN VARCHAR2) RETURN typ_mensajerespuesta;

  /** 3DSECURE
   * Author  : XPG0614
   * Created : 8/1/2020 10:26:19
   * Purpose : SD3DSECURE-1
   * Verifica la existencia de la persona en base de datos según la información de pago proveída por Bancard
   *
   * @param P_NRO_CUENTA Numero de cuenta del comprador
   * @param P_P6_TAR     Primeros 6 numeros de la tarjeta usada por el comprador
   * @param P_U4_TAR     Ultimos 4 numeros de la tarjeta usada por el comprador
   * @param P_FEC_VENC   Fecha de vencimiento de la tarjeta formato MM/YYYY
   * @param P_CARD_TYPE  Tipo de tarjeta, credito o debito
   *
   * @return Código de la persona, -1 en el caso que no exista
   */
   FUNCTION fu_ver_inf_pago(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE,
                                            P_P6_TAR     IN TA_TARJETAS.NRO_TARJETA%TYPE,
                                            P_U4_TAR     IN TA_TARJETAS.NRO_TARJETA%TYPE,
                                            P_FEC_VENC   in VARCHAR2,
                                            P_CARD_TYPE IN VARCHAR2) RETURN VARCHAR2;
   /** 3DSECURE
   * Author  : XPG0614
   * Created : 8/1/2020 10:26:19
   * Purpose : SD3DSECURE-1
   * Prepara el texto del sms y lo envía al numero del comprador
   * @param P_COD_TRANSACCION
   * @param P_COD_INITRANSAC
   */
   FUNCTION fu_env_sms_3dsecure(P_COD_TRANSACCION IN TA_LOG_SEC_INITRAN.COD_TRANSACCION%TYPE,
                                P_COD_INITRANSAC  IN TA_LOG_SEC_INITRAN.COD_INITRANSAC%TYPE) RETURN VARCHAR2;

   /** 3DSECURE
   * Author  : XPG0614
   * Created : 8/1/2020 10:26:19
   * Purpose : SD3DSECURE-1
   * @param P_COD_PERSONA
   * Obtiene el numero del telefono de cliente para el uso de 3dsecure
   */
   FUNCTION fu_obt_tel_cli_3dsecure(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
   RETURN VARCHAR2;

 FUNCTION fu_log_dispositivo( p_cod_persona           IN VARCHAR2,
                         p_cod_per_vinculada     IN VARCHAR2,
                         p_id_dispositivo        IN VARCHAR2,
                         p_cod_canal             IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                         p_os                    IN VARCHAR2,
                         p_os_version            IN VARCHAR2,
                         p_modelo                IN VARCHAR2,
                         p_marca                 IN VARCHAR2,
                         p_emulator              IN VARCHAR2,
                         p_cli_type              IN VARCHAR2,
                         p_ip                    IN VARCHAR2,
                         p_ext_data              IN VARCHAR2,
                         p_latitud               IN NUMBER,
                         p_longitud              IN NUMBER,
                         p_cod_sesion_aux        IN BW_AUT_SESIONES.COD_SESION%TYPE DEFAULT NULL,
                         p_logueado              IN VARCHAR2) RETURN typ_mapa ;

  /** VTS
   * Author  : PY01357
   * Created : 25/02/2020 10:26:19
   * Purpose : SDTOKBINVI-1
   * Verifica la existencia de la persona en base de datos según la información de la tarjeta proveída por Bancard
   *
   * @param P_TARJETA       Numero de la tarjeta del usuario
   * @param P_FEC_VENC      Fecha de vencimiento de la tarjeta
   * @param P_TIP_TARJETA   CREDIT o DEBIT
   * @param P_ADHERENTE     Solo en caso de TD
   *
   * @return Código de la persona, -1 en el caso que no exista
   */
   FUNCTION fu_ver_inf_tarjeta(P_TARJETA IN TA_TARJETAS.NRO_TARJETA%TYPE,
                        P_FEC_VENC   in VARCHAR2,
                        P_TIP_TARJETA in VARCHAR2,
                        P_ADHERENTE IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;
   /** VTS
   * Author  : PY01357
   * Created : 26/02/2020 12:00:19
   * Purpose : SDTOKBINVI-1
   * Prepara el texto del sms y lo envía al numero del usuario
   * @param P_COD_PAN_REF
   * @param P_COD_TOKEN
   */
   FUNCTION fu_env_vts_token(P_COD_PAN_REF IN BW_TOK_TAR_TOKENIZACION.COD_REF_PAN%TYPE,
                          P_COD_TOKEN  IN BW_TOK_TAR_TOKENIZACION.COD_REF_TOKEN%TYPE) RETURN VARCHAR2;


   /**
    * Verifica los limites de operacion o tipo de clave para controlar segun la operacion.
    *
    * @param p_cod_persona Codigo cliente.
    * @param p_cod_empresa Codigo empresa.
    * @param p_nro_cuenta Cuenta a debitar.
    * @param p_monto Monto operacion.
    * @param p_modo V-validar, C-confirmar.
    * @param p_tip_operacion Tipo de operacion (transf., aduana, tarjeta).
    * @param p_cod_canal Nro. de caja.
    * @param p_sesion_aux Sesion de llamada al core(Opcional)
    * @return tipo de clave a solicitar al cliente
    */
   FUNCTION fu_validarClave(p_cod_persona   IN ba_personas.cod_persona%TYPE,
                            p_cod_empresa   IN ba_personas.cod_persona%TYPE,
                            p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
                            p_monto         IN NUMBER,
                            p_modo          IN VARCHAR2,
                            p_tip_operacion IN VARCHAR2,
                            p_cod_canal     IN cj_cajas.nro_caja%TYPE,
                            p_sesion_aux    IN VARCHAR2 DEFAULT NULL) RETURN typ_clave_validacion;

   /**
    * Verifica los limites de operacion o tipo de clave para controlar segun la operacion,
    * se controlar la clave segun corresponda.
    *
    * @param p_cod_persona Codigo cliente.
    * @param p_cod_empresa Codigo empresa.
    * @param p_nro_cuenta Cuenta a debitar.
    * @param p_monto Monto operacion.
    * @param p_tip_operacion Tipo de operacion (transf., aduana, tarjeta).
    * @param p_cod_canal Nro. de caja.
    * @param p_clave Clave a validar.
    * @param p_sesion_aux Sesion de llamada al core(Opcional)
    * @return tipo de clave a solicitar al cliente
    */
   FUNCTION fu_verificarClave(p_cod_persona   IN ba_personas.cod_persona%TYPE,
                              p_cod_empresa   IN ba_personas.cod_persona%TYPE,
                              p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
                              p_monto         IN NUMBER,
                              p_tip_operacion IN VARCHAR2,
                              p_cod_canal     IN cj_cajas.nro_caja%TYPE,
                              p_clave         IN VARCHAR2,
                              p_sesion_aux    IN VARCHAR2 DEFAULT NULL) RETURN typ_mensajerespuesta;
       --
   /**
    * Retorna los permisos que tiene configurado el usuario
    * @param p_cod_persona Codigo cliente.
    * @param p_cod_empresa Codigo empresa.
    * @param p_cod_canal Nro. de caja.
    * @param p_tip_operaciones Codigo/s de operaciones separadas por comas por las cuales filtrar los permisos
    * @return permisos del usuario
    */
   FUNCTION fu_obtenerPermisos(p_cod_empresa        IN ba_personas.cod_persona%TYPE,
                                p_cod_persona        IN ba_personas.cod_persona%TYPE,
                                p_cod_canal          IN cj_cajas.nro_caja%TYPE,
                                p_tip_operaciones      IN VARCHAR2 DEFAULT NULL) RETURN typ_permisosUsuarios;

   /**
    * Obtiene los datos del serial del cliente para validacion soft-token.
    */
   FUNCTION fu_obt_aes_tkd(p_cod_persona IN ba_personas.cod_persona%TYPE,
                           p_cod_empresa IN ba_personas.cod_persona%TYPE) RETURN typ_mapa;


   /**
    * Validar nro. de caja
    * @param p_cod_canal nro. de canal
    */
   FUNCTION fu_val_caja(p_cod_canal IN cj_cajas.nro_caja%TYPE) RETURN typ_mensajeCaja;

   /**
    *Retorna S/N si se va a validar la clave desde la tabla bw_ope_clave
   */
   FUNCTION fu_ver_ctr_clave(p_tip_clave VARCHAR2
                          )  RETURN VARCHAR2;

END PAW_SEG;
/

