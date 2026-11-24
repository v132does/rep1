CREATE OR REPLACE PACKAGE IT.paw_con IS
   -- Purpose : Responder las transacciones generadas a traves del Tas

   /** Codigo de respuesta OK generico */
   msg_ok CONSTANT VARCHAR2(30) := '000';
   /** Codigo de error generico, Ej. excepciones no manejadas */
   c_msg_error       CONSTANT VARCHAR2(30) := '199';
   BITACORA_ERROR    CONSTANT VARCHAR2(3) := 'ERR';
   C_COD_HOMEBANKING CONSTANT VARCHAR2(3) := '999';
   BITACORA_ENTRADA  CONSTANT VARCHAR2(3) := 'ENT';
   BITACORA_SALIDA   CONSTANT VARCHAR2(3) := 'SAL';
   /** Constantes de tipo de Bitácora */

   c_bit_error   CONSTANT VARCHAR2(3) := 'ERR';
   c_bit_entrada CONSTANT VARCHAR2(3) := 'ENT';
   c_bit_salida  CONSTANT VARCHAR2(3) := 'SAL';

   c_cta_tamano     CONSTANT NUMBER(3) := 18;
   c_cod_mon_fuerte CONSTANT ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_fuerte;
   c_cod_mon_local  CONSTANT ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;

   v_tip_mensaje        VARCHAR2(10); -- guarda el tipo IAC
   v_can_aut_requeridas NUMBER(5) := 0; -- cantidad de firmas requeridas
   g_sesion             VARCHAR2(100);
   v_cod_mon_local      VARCHAR2(3) := pag_gen.FU_OBT_MON_LOCAL;
   v_fec_actual         DATE := pag_cal.fu_obt_fec_actual(9);

   /**
   *Estructura interna para verificar el estado de la caja.
   * @param error Indica si ocurrio un error recuperando la clave del usuario.
   * @param nombreRespuesta Indica el nombre del mensaje.
   * @param descripcionRespuesta Indica una descripcion de la respuesta.
   * @param estadoCaja Indica el estado de la caja.
   * @param tipoCaja Indica el tipo de caja.
   * @param codigoOficinaOrigen Codigo oficina origen.
   * @param codigoUsuario Codigo usuario.
   * @param fechaUltimoCierre Fecha de ultimo cierre.
   * @param fechaCierre Fecha de cierre.
   */
   TYPE typ_mensajeCaja IS RECORD(
      error                VARCHAR2(1),
      nombreRespuesta      VARCHAR2(15),
      descripcionRespuesta VARCHAR2(200),
      estadoCaja           VARCHAR2(1),
      tipoCaja             VARCHAR2(1),
      codigoOficinaOrigen  NUMBER(3),
      codigoUsuario        VARCHAR2(10),
      fechaUltimoCierre    DATE,
      fechaCierre          DATE);
   /**
   *typ_validarSesion
   *  Tipo  privado utilizado para retornar el estado de.
   *  validez de una sesion ademas de informacion relacionada
   *  a la sesion.
   * @param error Indica si ocurrio un error recuperando la clave del usuario.
   * @param nombreRespuesta Indica el nombre del mensaje.
   * @param descripcionRespuesta Indica una descripcion de la respuesta.
   * @param codigoPersona Codigo persona.
   * @param codigoCanal Indica el canal.
   * @param codigoEmpresa Indica el codigo de la empresa.
   * @param codigoPerfil Indica el codigo de perfil.
   * @param numeroTelefono Numero de telefono.
   */
   TYPE typ_validarSesion IS RECORD(
      error                VARCHAR2(1), -- hubo Error?
      nombreRespuesta      VARCHAR2(15), -- Codigo del mensaje
      descripcionRespuesta VARCHAR2(200), -- Descripcion del mensaje
      codigoPersona        VARCHAR2(10), -- Nombre del mensaje
      codigoCanal          VARCHAR2(3), -- Nombre del mensaje
      codigoEmpresa        VARCHAR2(10), -- Nombre del mensaje
      codigoPerfil         VARCHAR(20),
      numeroTelefono       VARCHAR2(30)); -- Número de Telefono

   /**
   * Guarda los permisos de un usuario para una persona juridica.
   * @param error Indica si ocurrio un error recuperando la clave del usuario.
   * @param nombreRespuesta Indica el nombre del mensaje.
   * @param descripcionRespuesta Indica una descripcion de la respuesta.
   * @param autoriza Indica si la persona tiene el permiso para autorizar operaciones(A).
   * @param registra Indica si la persona tiene el permiso para registrar operaciones(I).
   * @param consulta Indica si la persona tiene el permiso para registrar consultar().
   * @param autorizacionesRequeridas Indica las autorizaciones requeridas.
   */
   TYPE typ_obtenerPermisos IS RECORD(
      error                    VARCHAR(1),
      nombreRespuesta          VARCHAR2(15),
      descripcionRespuesta     VARCHAR2(200),
      autoriza                 BOOLEAN,
      registra                 BOOLEAN,
      consulta                 BOOLEAN,
      autorizacionesRequeridas NUMBER);

   /**
   * Respuesta de la llamada a fu_obtenerLimite.
   * @param error Indica si ocurrio un error recuperando la clave del usuario.
   * @param nombreRespuesta Indica el nombre del mensaje.
   * @param descripcionRespuesta Indica una descripcion de la respuesta.
   * @param codRespuesta Indica que tipo de clave solicitar al usuario.
   */
   TYPE typ_respuestaLimite IS RECORD(
      error                VARCHAR(1),
      nombreRespuesta      VARCHAR2(15),
      descripcionRespuesta VARCHAR2(200),
      codRespuesta         VARCHAR2(2));

   /**
   * Función Fu_obt_sal_actual para obtener el saldo actual.
   * @param p_cod_modulo Indica el codigo del modulo.
   * @param p_cod_modalidad Indica el codigo de la modalidad.
   * @param p_numeroCuenta Indica el número de cuenta.
   * @return El saldo actual de la cuenta.
   */
   FUNCTION Fu_obt_sal_actual
   (
      p_cod_modulo    IN NUMBER,
      p_cod_modalidad IN NUMBER,
      p_numeroCuenta  IN VARCHAR2
   ) RETURN NUMBER;

   /**
   * Función Fu_tip_cuenta para obtener el tipo de cuenta.
   * @param p_cod_modulo Indica el codigo del modulo.
   * @param p_cod_modalidad Indica el codigo de la modalidad.
   * @return El tipo de cuenta.
   */
   FUNCTION Fu_tip_cuenta
   (
      p_cod_modulo    IN NUMBER,
      p_cod_modalidad IN NUMBER
   ) RETURN CHAR;


   /**
   * Función Fu_es_ope_limitadas Verifica si el mensaje esta limitado.
   * @param p_cod_mensaje Indica el codigo del mensaje.
   * @param p_numeroCuenta Indica el número de cuenta.
   * @param codigoCanal Indica el canal.
   * @param p_fecha Fecha.
   * @return Si el mensaje esta limitado.
   */
   FUNCTION Fu_es_ope_limitadas
   (
      p_cod_mensaje IN VARCHAR2,
      p_nro_cuenta  IN VARCHAR2,
      p_cod_canal   IN VARCHAR2,
      p_fecha       IN DATE
   ) RETURN VARCHAR2;

   /**
   * Función Fu_enc_md5 Hashea un texto en md5.
   * @param p_encripta Texto a hashear.
   * @return texto hasheado a partir de p_encripta.
   */
   FUNCTION Fu_enc_md5(p_encripta VARCHAR2) RETURN VARCHAR2;

   /**
   * Función DepurarAlfanumerico Depurar alfanumerico.
   * @param p_string String a depurar.
   * @param maxLength Longitud del string.
   * @return Retorna el string depurado.
   */

   FUNCTION DepurarAlfanumerico
   (
      p_string  IN VARCHAR2,
      maxLength IN NUMBER
   ) RETURN VARCHAR2;

   /**
   * Función DepurarCuenta Depurar cuenta.
   * @param p_string String a depurar.
   * @param maxLength Longitud del string.
   * @return Retorna cuenta depurada.
   */

   FUNCTION DepurarCuenta
   (
      p_string  IN VARCHAR2,
      maxLength IN NUMBER
   ) RETURN VARCHAR2;

   /**
   * Función Fu_encriptacionCuentas Encripta cuentas.
   * @param p_clave Clave.
   * @return Retorna clave encriptada.
   */

   FUNCTION Fu_encriptacionCuentas(p_clave IN VARCHAR2) RETURN VARCHAR2;

   /**
   * Función Fu_desencriptacionCuentas Desencripta cuentas.
   * @param p_clave Clave.
   * @return Retorna clave desencriptada.
   */

   FUNCTION Fu_desencriptacionCuentas(p_clave IN VARCHAR2) RETURN VARCHAR2;

   /**
   * Función DepurarTextos Depurar textos.
   * @param p_string String a depurar.
   * @param maxLength Longitud del string.
   * @return Retorna texto depurado.
   */

   FUNCTION DepurarTextos
   (
      p_string  IN VARCHAR2,
      maxLength IN NUMBER
   ) RETURN VARCHAR2;

   /**
   * Función DepurarNumerico Depurar numericos.
   * @param p_string String a depurar.
   * @param maxLength Longitud del string.
   * @return Retorna numerico depurado.
   */

   FUNCTION DepurarNumerico
   (
      p_string  IN VARCHAR2,
      maxLength IN NUMBER
   ) RETURN VARCHAR2;

   /**
   * Función Fu_for_date Formatea una fecha.
   * @param p_dato Fecha a formatear.
   * @return Retorna fecha formateada.
   */

   FUNCTION Fu_for_date(p_dato IN DATE) RETURN CHAR;

   /**
   * Función Fu_es_conjunta Verifica si la cuenta es conjunta.
   * @param p_nro_cuenta  Indica el número de cuenta.
   * @param p_cod_persona  Indica el codigo de la persona.
   * @param p_cod_per_empresa Indica el codigo de la empresa.
   * @return Retorna si la cuenta es conjunta.
   */

   FUNCTION Fu_es_conjunta
   (
      p_nro_cuenta      IN VARCHAR2,
      p_cod_persona     IN VARCHAR2,
      p_cod_per_empresa IN VARCHAR2
   ) RETURN VARCHAR2;

   /**
   * Función Fu_es_juridica Verifica si la persona es juridica.
   * @param p_nro_cuenta Indica el número de cuenta.
   * @param p_cod_per_empresa Indica el codigo de la empresa.
   * @param p_cod_persona Indica el codigo de la persona.
   * @return Retorna si la persona es juridica.
   */
   FUNCTION Fu_es_juridica
   (
      p_nro_cuenta      IN VARCHAR2,
      p_cod_per_empresa IN VARCHAR2,
      p_cod_persona     IN VARCHAR2
   ) RETURN VARCHAR2;

   /**
   * Función Fu_val_monto Verifica si no sobrepasa el límite de operaciones por día y semana.
   * @param p_monto  Monto.
   * @param p_cod_moneda Codigo moneda.
   * @param p_cod_mensaje Codigo mensaje.
   * @param p_nro_cuenta Indica el número de cuenta.
   * @param codigoCanal Indica el canal.
   * @param p_fec_actual  Fecha actual.
   * @return Retorna si el monto no sobrepasa el límite de operaciones por día y semana.
   */

   FUNCTION Fu_val_monto
   (
      p_monto       IN NUMBER,
      p_cod_moneda  IN VARCHAR2,
      p_cod_mensaje IN VARCHAR2,
      p_nro_cuenta  IN VARCHAR2,
      p_cod_canal   IN VARCHAR2,
      p_fec_actual  IN DATE
   ) RETURN VARCHAR2;
    /**
   * Función Fu_obt_cta_tarjeta Obtiene el nro de cuenta de la tarjeta.
   * @param p_nro_cta_especifica  Numero de cuenta especificado.
   * @param p_cod_per_empresa Codigo persona empresa.
   * @param p_cod_persona Codigo persona.
   * @return Retorna el número de cuenta de la tarjeta.
   */
   FUNCTION Fu_obt_cta_tarjeta
   (
      p_nro_cta_especifica VARCHAR2,
      p_cod_per_empresa    VARCHAR2,
      p_cod_persona        VARCHAR2
   ) RETURN VARCHAR2;

   /**
   * Función Fu_obt_moneda Devuelve la moneda de una cuenta.
   * @param p_nro_cuenta Indica el número de cuenta.
   * @return Retorna la moneda de la cuenta.
   */
   FUNCTION Fu_obt_moneda(p_nro_cuenta IN VARCHAR2) RETURN VARCHAR2;

   /**
   * Función Fu_ver_horario Verifica el horario.
   * @param p_horario Horario.
   * @param p_es_mov_noc Es movimiento nocturno.
   * @param p_es_cta_noc Es cuenta nocturna.
   * @param p_ult_cierre Ultimo cierre.
   * @param p_cod_ofi_origen Codigo oficina origen.
   * @param p_fec_actual Fecha actual.
   * @param p_fec_cie_caja Fecha de cierre de caja.
   * @param p_fec_valor Valor de la fecha.
   * @return Retorna detalle sobre el horario.
   */
   FUNCTION Fu_ver_horario
   (
      p_horario        OUT VARCHAR2,
      p_es_mov_noc     OUT VARCHAR2,
      p_es_cta_noc     OUT VARCHAR2,
      p_ult_cierre     IN DATE,
      p_cod_ofi_origen IN VARCHAR2,
      p_fec_actual     OUT DATE,
      p_fec_cie_caja   IN DATE,
      p_fec_valor      OUT DATE
   ) RETURN typ_MensajeRespuesta;

   /**
   * Función Fu_val_cta_debito Valida la cuenta de debito.
   * @param p_nro_cta_debito Número cuenta de debito.
   * @param p_cod_tra_padre Codigo padre.
   * @param p_monto Monto.
   * @param p_cod_mon_debito Codigo monto debito.
   * @param p_cod_mod_debito Codigo modulo debito.
   * @param p_cod_mad_debito Codigo modalidad debito.
   * @param p_cod_ofi_debito Codigo oficina debito.
   * @param p_cta_for_debito Cuenta formato debito.
   * @param p_nom_cta_debito Nombre cuenta debito.
   * @param p_validarSesion Type validar sesion.
   * @param p_mensajeCaja Type mensaje caja.
   * @return Retorna detalle de validación.
   */
   FUNCTION Fu_val_cta_debito
   (
      p_nro_cta_debito IN VARCHAR2,
      p_cod_tra_padre  IN NUMBER,
      p_monto          IN NUMBER,
      p_cod_mon_debito OUT VARCHAR2,
      p_cod_mod_debito OUT NUMBER,
      p_cod_mad_debito OUT NUMBER,
      p_cod_ofi_debito OUT NUMBER,
      p_cta_for_debito OUT VARCHAR2,
      p_nom_cta_debito OUT VARCHAR2,
      p_validarSesion  IN typ_validarSesion,
      p_mensajeCaja    IN typ_mensajeCaja
   ) RETURN typ_mensajeRespuesta;



   /**
   * Función Fu_ver_transaccion Verifica que una transacción igual no se haya realizado en los últimos minutos
   * @param p_cod_transaccion Codigo transaccion.
   * @param p_cod_tra_padre Codigo transaccion padre.
   * @param p_nro_cuenta Numero de cuenta.
   * @param p_monto Monto.
   * @param p_mensajeCaja Type mensaje caja.
   * @return Retorna detalle de verificación de la trasacción.
   */
   FUNCTION Fu_ver_transaccion
   (
      p_cod_transaccion IN ge_movimientos.cod_transaccion%TYPE,
      p_cod_tra_padre   IN ge_movimientos.cod_tra_padre%TYPE,
      p_nro_cuenta      IN ge_movimientos.nro_cuenta%TYPE,
      p_monto           IN ge_movimientos.monto%TYPE,
      p_mensajeCaja     IN typ_mensajeCaja
   ) RETURN typ_mensajeRespuesta;

   /**
   * Función Fu_obt_permisos Obtiene los permisos.
   * @param p_cod_persona Codigo persona.
   * @param p_cod_perfil Codigo perfil.
   * @param p_cod_operacion Codigo Operación.
   * @param p_nro_terminal Número terminal.
   * @return Retorna detalle de permisos.
   */
   FUNCTION Fu_obt_permisos
   (
      p_cod_persona   IN VARCHAR2,
      p_cod_perfil    IN VARCHAR2,
      p_cod_operacion IN VARCHAR2,
      p_nro_terminal  IN VARCHAR2
   ) RETURN typ_obtenerPermisos;

  /**
   * Función Fu_obt_tot_transacciones Obtiene el total de transacciones.
   * @param p_codEmpresa  Codigo empresa.
   * @param p_codPersona Codigo persona.
   * @param p_nro_cuenta Numero de cuenta.
   * @param p_cod_tra_padre Codigo transaccion padre.
   * @param p_cod_tip_mensaje Codigo tipo mensaje.
   * @return Retorna total de transacciones.
   */
   FUNCTION Fu_obt_tot_transacciones
   (
      p_codEmpresa      IN VARCHAR2,
      p_codPersona      IN VARCHAR2,
      p_nro_cuenta      IN VARCHAR2,
      p_cod_tra_padre   IN NUMBER,
      p_cod_tip_mensaje IN VARCHAR2
   ) RETURN NUMBER;

   /**
   * Función Fu_obt_des_chequera Obtiene chequera.
   * @param p_tip_chequera Tipo de chequera.
   * @return Retorna detalle de chequera.
   */
   FUNCTION Fu_obt_des_chequera(p_tip_chequera IN VARCHAR2) RETURN VARCHAR2;
   /**
   * Función Fu_val_caja Valida los datos de la Caja.
   * @param p_sesion Type validar sesion.
   * @return Retorna detalle de validación de los datos de caja.
   */
   FUNCTION Fu_val_caja(p_sesion IN typ_validarSesion) RETURN typ_mensajeCaja;

   /**
   * Función Fu_validarSesion Verifica la validez de una sesion obtenida previamente de fu_iniciarSesion
   * @param p_sesionUsuario identificador de sesion a ser verificado
   * @param p_codCanal identificador del Canal para el cual la sesion fue obtenida
   * @return retorna información de la sesion o error si no pudo comprobarse su validez
   */
   FUNCTION Fu_validarSesion
   (
      p_sesionUsuario IN VARCHAR2,
      p_codCanal      IN VARCHAR2
   ) RETURN typ_validarSesion;

   --
   /**
   * Función Fu_ver_adicional verifica si la persona puede ver tarjetas adicionales.
   * @param p_cod_modulo Codigo modulo.
   * @param p_relacion  Relación.
   * @param p_nro_cuenta  Número de cuenta.
   * @param p_cod_persona  Codigo persona.
   * @return Retorna si la persona puede ver tarjetas adicionales.
   */
   FUNCTION Fu_ver_adicional
   (
      p_cod_modulo  NUMBER,
      p_relacion    VARCHAR2,
      p_nro_cuenta  VARCHAR2,
      p_cod_persona IN VARCHAR2
   ) RETURN VARCHAR2;

   /**
   * Función Fu_obt_nro_tarjeta Devuelve el numero de tarjeta de credito de la Persona o Cuenta.
   * @param p_numeroCuenta  Número de cuenta.
   * @param p_cod_persona  Codigo persona.
   * @param p_cod_persona  Codigo persona empresa.
   * @return Retorna el numero de tarjeta de credito de la Persona o Cuenta.
   */
   FUNCTION Fu_obt_nro_tarjeta
   (
      p_numeroCuenta    IN VARCHAR2,
      p_cod_persona     IN VARCHAR2,
      p_cod_per_empresa IN VARCHAR2
   ) RETURN VARCHAR2;
   /**
   * Función Fu_obt_che_devuelto que devuelve si una cuenta tiene o no cheque devuelto.
   * @param p_nro_cuenta  Número de cuenta.
   * @return Retorna si una cuenta tiene o no cheque devuelto.
   */
   FUNCTION Fu_obt_che_devuelto(p_nro_cuenta IN VARCHAR2) RETURN VARCHAR2;

   /**
   * Funcion Fu_val_cta_origen verifica que la Cuenta Origen corresponda a la persona.
   * @param p_nro_cuenta  Número de cuenta.
   * @param p_cod_persona  Codigo persona.
   * @return Retorna validacion de cuenta origen con la persona.
   */
   FUNCTION Fu_val_cta_origen
   (
      p_nro_cuenta  IN VARCHAR2,
      p_cod_persona IN VARCHAR2
   ) RETURN VARCHAR2;

   /**
   * Funcion Fu_obt_cta_limpia que extrae (guiones, espacios, etc.) del número de cuenta.
   * @param p_nro_cta_especifica  Número de cuenta.
   * @param p_cod_operacion  Codigo operación.
   * @param p_cod_persona  Codigo persona.
   * @return Retorna el número de cuenta sin guiones y sin espacios.
   */
   FUNCTION Fu_obt_cta_limpia
   (
      p_nro_cta_especifica VARCHAR2,
      p_cod_operacion      VARCHAR2,
      p_cod_persona        VARCHAR2
   ) RETURN VARCHAR2;

   /**
   * Funcion Fu_cta_valida valida si una cuenta pertenece a un documento dado.
   * @param p_nro_cuenta  Número de cuenta.
   * @param p_nro_documento  Número de documento.
   * @param p_validarSesion  Type validar sesión.
   * @param v_retError  Type mensaje respuesta.
   * @return Retorna si la cuenta pertenece a un numero de documento dado.
   */
   FUNCTION Fu_cta_valida
   (
      p_nro_cuenta    VARCHAR2,
      p_nro_documento IN VARCHAR2,
      p_validarSesion IN typ_validarSesion,
      v_retError      IN OUT typ_mensajeRespuesta
   ) RETURN VARCHAR2;

   /** Funcion Fu_obt_cod_transaccion obtiene el codigo de transaccion para las comisiones en transferencias (098,105).
   * @param p_es_cambio  Si es una operación de cambio.
   * @param p_es_cambio  Valor de la fecha.
   * @param p_cod_per_empresa  Codigo persona empresa.
   * @param p_cod_persona  Codigo persona.
   * @return Retorna el codigo de transaccion para las comisiones.
   */
   FUNCTION Fu_obt_cod_transaccion
   (
      p_es_cambio       BOOLEAN,
      p_fecha_valor     DATE,
      p_cod_per_empresa VARCHAR2,
      p_cod_persona     VARCHAR2
   ) -- O/B (Ordenante, Beneficiario)
    RETURN NUMBER;

   /**
   * Funcion Fu_obt_cotizacion obtener cotizacion para operaciones via banca electronica.
   * @param p_cod_moneda  Codigo moneda.
   * @param p_tipo  Codigo moneda.
   * @return Retorna la cotizacion de la moneda.
   */
   FUNCTION Fu_obt_cotizacion
   (
      p_cod_moneda IN ba_monedas.cod_moneda%TYPE,
      p_tipo       IN VARCHAR2 -- C-COMPRA o V-VENTA
   ) RETURN NUMBER;

   /**
   * Funcion Fu_obt_msg_mail que obtiene los email's relacionados al tipo de mensaje.
   * @param p_cod_tip_mensaje  Codigo tipo mensaje.
   * @return Retorna los email relacionados al tipo de mensaje.
   */
   FUNCTION Fu_obt_msg_mail(p_cod_tip_mensaje VARCHAR2) RETURN VARCHAR2;

   /**
   * Funcion Fu_obt_val_decodificado valida el decodificado.
   * @param p_clob  Dato codificado.
   * @return Retorna datos decodificados.
   */
   FUNCTION Fu_obt_val_decodificado(p_clob IN CLOB) RETURN BLOB;

   /**
   * Funcion Fu_generarBitacora genera los datos para la tabla bitacora.
   * @param error Indica si ocurrio un error recuperando la clave del usuario.
   * @param nombreRespuesta Indica el nombre del mensaje.
   * @param descripcionRespuesta Indica una descripcion de la respuesta.
   * @param mensajesAdicionales Mensajes adicionales.
   * @return Retorna datos para insertar en la tabla bitacora.
   */
   FUNCTION Fu_generarBitacora
   (
      error                IN VARCHAR2,
      nombreRespuesta      IN VARCHAR2,
      descripcionRespuesta IN VARCHAR2,
      mensajesAdicionales  IN VARCHAR2 := NULL
   ) RETURN VARCHAR2;

   /**
   * Funcion Fu_setearError Setea el campo error y limpia el código del cliente y nombre.
   * @param v_retorno Type iniciar sesion.
   * @return Retorna error seteado.
   */
   FUNCTION Fu_setearError(v_retorno IN OUT typ_iniciarSesion) RETURN typ_iniciarSesion;

   /**
   * Funcion Fu_val_ope_clave recibe la clave en minusculas y hasheada en md5 recupera el salt del usuario y verifica que la clave sea igual a la guardada.
   * @param p_clave Clave.
   * @param p_cod_persona Codigo persona.
   * @param p_cod_per_vinculada Codigo persona vinculada.
   * @param p_tip_clave Tipo clave.
   * @param p_act_visitas  Cantidad visitas.
   * @return Retorna detalle de operaciones de clave.
   */
   FUNCTION Fu_val_ope_clave
   (
      p_clave             IN VARCHAR2,
      p_cod_persona       IN VARCHAR2,
      p_cod_per_vinculada IN VARCHAR2,
      p_tip_clave         IN VARCHAR2,
      p_act_visitas       IN VARCHAR2 DEFAULT 'N'
   ) RETURN typ_mensajeRespuesta;

   /**
   * Funcion Fu_obt_cla_validar Verifica que la clave transaccional sea la correcta.
   * @param p_cla_transaccional Clave transaccional.
   * @param p_cod_persona Codigo persona.
   * @param p_cod_per_vinculada Codigo persona vinculada.
   * @param p_tip_clave Tipo clave.
   * @return Retorna detalle de operaciones de clave.
   */
   FUNCTION Fu_obt_cla_validar
   (
      p_cla_transaccional IN VARCHAR2,
      p_cod_persona       IN VARCHAR2,
      p_cod_per_vinculada IN VARCHAR2,
      p_tip_clave         IN VARCHAR2
   ) RETURN typ_mensajeRespuesta;

   /**
   * Funcion Fu_gen_ope_clave genera una clave lista para guardar en bw_ope_claves.
   * @param p_clave Clave.
   * @param p_cod_persona Codigo persona.
   * @param p_cod_per_vinculada Codigo persona vinculada.
   * @param p_accion Accion.
   * @param p_tip_clave Tipo clave.
   * @param p_cla_operacion Clave operación.
   * @return Retorna una clave con un numero aleatorio.
   */
   FUNCTION Fu_gen_ope_clave
   (
      p_clave             IN VARCHAR2,
      p_cod_persona       IN VARCHAR2,
      p_cod_per_vinculada IN VARCHAR2,
      p_accion            IN VARCHAR2,
      p_tip_clave         IN VARCHAR2,
      p_cla_operacion     OUT VARCHAR2
   ) RETURN VARCHAR2;

   /**
   * Funcion Fu_val_per_vinculada valida que el código de persona este vinculada a la empresa.
   * @param p_cod_per_empresa Codigo persona empresa.
   * @param p_cod_persona Codigo persona.
   * @return Retorna valida que el código de persona este vinculada a la empresa.
   */
   FUNCTION Fu_val_per_vinculada
   (
      p_cod_per_empresa IN ge_clientes.cod_persona%TYPE,
      p_cod_persona     IN ge_clientes.cod_persona%TYPE
   ) RETURN VARCHAR2;

   /**
   * Funcion Fu_val_vul_claves valida que una clave (de acceso o transaccional) no se repita.
   * @param p_cod_persona Codigo persona.
   * @param p_cla_nueva Clave.
   * @return una clave (de acceso o transaccional) que no se repita.
   */
   FUNCTION Fu_val_vul_claves
   (
      p_cod_persona IN bw_ope_claves.cod_persona%TYPE,
      p_cla_nueva   IN bw_ope_claves.clave%TYPE
   ) RETURN VARCHAR2;

   /**
   * Procedimiento que Inserta registro en bw_movimientos.
   * @param p_nro_cuenta Nro de cuenta.
   * @param p_cod_moneda Código de moneda.
   * @param p_monto monto.
   * @param p_nro_cta_contra Nro de cuenta.
   * @param p_cantidad Cantidad.
   * @param p_etiqueta Etiqueta.
   * @param p_dato Dato.
   * @param p_etiqueta2 Etiqueta2.
   * @param p_dato2 Dato2.
   * @param p_observacion Observación.
   * @param p_dir_ip Dirección ip.
   * @param p_cod_respuesta Codigo de respuesta.
   * @param p_cod_persona Codigo de persona.
   * @param p_cod_operacion Codigo de operación.
   * @param p_nro_operacion Nro de operación.
   * @param p_nro_terminal Nro de terminal.
   * @param p_clave Clave.
   * @param p_cod_per_empresa Código de empresa.
   */
   PROCEDURE pr_reg_operacion
   (
      p_nro_cuenta      IN VARCHAR2 DEFAULT NULL,
      p_cod_moneda      IN VARCHAR2 DEFAULT NULL,
      p_monto           IN NUMBER DEFAULT NULL,
      p_nro_cta_contra  IN VARCHAR2 DEFAULT NULL,
      p_cantidad        IN NUMBER DEFAULT NULL,
      p_etiqueta        IN VARCHAR2 DEFAULT NULL,
      p_dato            IN VARCHAR2 DEFAULT NULL,
      p_etiqueta2       IN VARCHAR2 DEFAULT NULL,
      p_dato2           IN VARCHAR2 DEFAULT NULL,
      p_observacion     IN VARCHAR2 DEFAULT NULL,
      p_dir_ip          IN VARCHAR2 DEFAULT NULL,
      p_cod_respuesta   IN VARCHAR2 DEFAULT NULL,
      p_cod_persona     IN VARCHAR2 DEFAULT NULL,
      p_cod_operacion   IN VARCHAR2 DEFAULT NULL,
      p_nro_operacion   IN VARCHAR2 DEFAULT NULL,
      p_nro_terminal    IN VARCHAR2 DEFAULT NULL,
      p_clave           IN VARCHAR2 DEFAULT NULL,
      p_cod_per_empresa IN VARCHAR2 DEFAULT NULL,
      p_nro_sobre       IN VARCHAR2 DEFAULT NULL
   );

   /**
   * Procedimiento que guarda una accion con las claves de operaciones.
   * @param p_cod_persona Codigo persona.
   * @param  p_accion  Accion.
   * @param p_cod_per_vinculada  Codigo persona vinculada.
   * @param p_tip_clave Tipo de clave
   */
   PROCEDURE pr_cla_reg_operacion
   (
      p_cod_persona       IN VARCHAR2,
      p_accion            IN VARCHAR2,
      p_cod_per_vinculada IN VARCHAR2,
      p_tip_clave         IN VARCHAR2
   );

   /** Obtiene un mensaje de la base de datos por el nombre del mensaje.
   * @param p_mensaje Nombre del mensaje.
   * @param p_nombreMensaje Nombre del mensaje.
   * @param p_descripcionMensaje Descripción del mensaje.
   * @param p_error Indicador de si es o no un mensaje de error.
   */
   PROCEDURE pr_mensajeUsuario
   (
      mensaje            IN VARCHAR2,
      codigoMensaje      OUT VARCHAR2,
      descripcionMensaje OUT VARCHAR2,
      error              OUT VARCHAR2
   );

   /**
   * Procedimiento que registra cuando ocurrio un error en el uso de la clave.
   * @param p_cta_debito  Cuenta debito.
   * @param  p_cta_credito  Cuenta credito.
   * @param p_monto  Codigo Monto.
   * @param p_cod_moneda Codigo moneda.
   * @param p_cod_mensaje Codigo mensaje.
   * @param p_cod_error Codigo error.
   * @param p_cod_motivo Codigo motivo.
   * @param p_comentario Comentario.
   * @param p_nro_telefono Número de telefono.
   * @param p_cod_canal Codigo canal.
   * @param p_cod_persona Codigo Persona.
   */
   PROCEDURE pr_reg_error
   (
      p_cta_debito   IN VARCHAR2,
      p_cta_credito  IN VARCHAR2,
      p_monto        IN NUMBER,
      p_cod_moneda   IN VARCHAR2,
      p_cod_mensaje  IN VARCHAR2,
      p_cod_error    IN VARCHAR2,
      p_cod_motivo   IN VARCHAR2,
      p_comentario   IN VARCHAR2,
      p_nro_telefono IN VARCHAR2,
      p_cod_canal    IN VARCHAR2,
      p_cod_persona  IN VARCHAR2
   );

   /** Inserta registro en la tabla bw_bitacora.
   * @param p_codigoPersona Código de persona.
   * @param p_codigoCanal Código de canal.
   * @param p_codSesion Código de la sesión.
   * @param p_tipoMensaje Tipo de mensaje.
   * @param p_codigoEmpresa Código de la persona vinculada.
   * @param p_datos Información de lo realizado.
   * @param p_tipo Tipo de la bitácora.
   * @param p_numeroTelefono Número de telefono.
   * @param p_codigoError Codigo error.
   * @param p_observacion Observacion.
   * @param p_codigoMotivo Codigo motivo.
   * @param p_numeroCuentaDebito Numero Cuenta Debito.
   * @param p_numeroCuentaCredito Numero Cuenta Credito.
   * @param p_monto  Monto.
   * @param p_codigoMoneda  Codigo moneda.
   * @param p_dato2   Información de lo realizado.
   */
   PROCEDURE pr_insertarBitacora
   (
      p_codigoPersona       IN VARCHAR2 DEFAULT NULL,
      p_codigoCanal         IN VARCHAR2 DEFAULT NULL,
      p_codSesion           IN VARCHAR2 DEFAULT NULL,
      p_tipoMensaje         IN VARCHAR2 DEFAULT NULL,
      p_codigoEmpresa       IN VARCHAR2 DEFAULT NULL,
      p_datos               IN VARCHAR2 DEFAULT NULL,
      p_tipo                IN VARCHAR2 DEFAULT NULL,
      p_numeroTelefono      IN VARCHAR2 DEFAULT NULL,
      p_codigoError         IN VARCHAR2 DEFAULT NULL,
      p_observacion         IN VARCHAR2 DEFAULT NULL,
      p_codigoMotivo        IN VARCHAR2 DEFAULT NULL,
      p_numeroCuentaDebito  IN VARCHAR2 DEFAULT NULL,
      p_numeroCuentaCredito IN VARCHAR2 DEFAULT NULL,
      p_monto               IN NUMBER DEFAULT NULL,
      p_codigoMoneda        IN VARCHAR2 DEFAULT NULL,
      p_dato2               IN CLOB DEFAULT NULL
   );

   /** obtener cantidad de registros historicos.
   * @param  p_nro_cuenta Numero de cuenta.
   * @param p_fecha Fecha.
   * @param p_horario Horario.
   */
   PROCEDURE pr_can_reg_historicos
   (
      p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE,
      p_fecha      IN ge_movimientos.fecha%TYPE,
      p_horario    OUT VARCHAR2
   );

   /** genera movimientos en movimientos.
   * @param p_retorno Type mensaje respuesta.
   * @param p_nro_secuencia Número de secuencia.
   * @param p_ses_usuario Sesion usuario.
   * @param p_men_caja Mensaje caja.
   * @param p_fec_actual Fecha actual.
   * @param p_hor_actual Hora actual.
   * @param p_fec_valor Valor fecha.
   * @param p_cod_mod_cta Codigo modulo.
   * @param p_cod_mad_cta Codigo modalidad.
   * @param p_cod_ofi_cta Codigo oficina.
   * @param p_nro_cuenta Número cuenta.
   * @param p_cod_moneda Codigo moneda.
   * @param p_cod_tra_padre Codigo trasacción padre.
   * @param p_cod_transaccion codigo trasacción.
   * @param p_nro_documento Número documento.
   * @param p_monto Monto.
   * @param p_afe_caja Afecta caja.
   * @param p_es_mov_noc Es movimiento nocturno.
   * @param p_cod_retencion Codigo retención.
   * @param p_concepto Concepto.
   * @param p_cotizacion Cotizacion.
   * @param p_cod_mod_padre Codigo modulo padre.
   * @param p_cod_mad_padre Codigo modalidad padre.
   * @param p_val_tasa Valor tasa.
   * @param p_tipo_movimiento Tipo movimiento.
   * @param p_cod_rubro Codigo rubro.
   */
   PROCEDURE pr_ins_movimiento
   (
      p_retorno           IN OUT typ_mensajerespuesta, -- agregado
      p_nro_secuencia     IN OUT NUMBER, -- agregado
      p_ses_usuario       IN typ_validarSesion, -- agregado
      p_men_caja          IN typ_mensajeCaja, -- agregado
      p_fec_actual        IN DATE, -- agregado
      p_hor_actual        IN VARCHAR2, -- agregado
      p_fec_valor         IN DATE, -- agregado
      p_cod_mod_cta       IN NUMBER,
      p_cod_mad_cta       IN NUMBER,
      p_cod_ofi_cta       IN NUMBER,
      p_nro_cuenta        IN VARCHAR2,
      p_cod_moneda        IN VARCHAR2,
      p_cod_tra_padre     IN NUMBER,
      p_cod_transaccion   IN NUMBER,
      p_nro_documento     IN NUMBER,
      p_monto             IN NUMBER,
      p_cod_operacion     IN VARCHAR2,
      p_nro_documento2    IN VARCHAR2,
      p_afe_caja          IN VARCHAR2 DEFAULT 'N', -- E-efectivo C-Cheq.Ntro.bco O-Cheq.otro.bco N-no afecta
      p_es_mov_noc        IN VARCHAR2 DEFAULT NULL,
      p_cod_retencion     IN NUMBER DEFAULT NULL,
      p_fec_fin_retencion IN DATE DEFAULT NULL,
      p_concepto          IN VARCHAR2 DEFAULT NULL,
      p_cotizacion        IN NUMBER DEFAULT NULL,
      p_cod_mod_padre     IN NUMBER DEFAULT NULL,
      p_cod_mad_padre     IN NUMBER DEFAULT NULL,
      p_val_tasa          IN NUMBER DEFAULT NULL,
      p_tipo_movimiento   IN VARCHAR2 DEFAULT NULL,
      p_cod_rubro         IN VARCHAR2 DEFAULT NULL
   );
   /**
   * procedimiento que valida el contrato de cotizacion.
   * @param p_operacion Operación.
   * @param p_nro_contrato Número contrato.
   * @param p_cod_mon_debito Codigo monto debito.
   * @param p_cod_mon_credito Codigo monto credito.
   * @param p_nro_cta_debito Número cuenta debito.
   * @param p_nro_cta_credito Número cuenta credito.
   * @param p_cotizacion Cotizacion.
   * @param p_importe Importe.
   * @param p_cod_mensaje Codigo Mensaje.
   */
   PROCEDURE pr_val_con_cambio
   (
      p_operacion       IN VARCHAR2,
      p_nro_contrato    IN NUMBER,
      p_cod_mon_debito  IN VARCHAR2 DEFAULT NULL,
      p_cod_mon_credito IN VARCHAR2 DEFAULT NULL,
      p_nro_cta_debito  IN VARCHAR2 DEFAULT NULL,
      p_nro_cta_credito IN VARCHAR2 DEFAULT NULL,
      p_cotizacion      IN NUMBER DEFAULT 0,
      p_importe         IN NUMBER DEFAULT 0,
      p_cod_mensaje     OUT VARCHAR2
   );

   /** Obtiene el Menor Cargo.
   * @param p_cod_ofi_origen Codigo Mensaje.
   * @param p_nro_cuenta Codigo Mensaje.
   * @param p_cod_moneda  Codigo Mensaje.
   * @param p_monto  Codigo Mensaje.
   * @param p_cod_modulo  Codigo Mensaje.
   * @param p_cod_modalidad Codigo Mensaje.
   * @param p_cod_tra_cargo Codigo Mensaje.
   * @param p_cod_tas_cargo Codigo Mensaje.
   * @param p_val_tas_cargo Codigo Mensaje.
   * @param p_val_cargo Codigo Mensaje.
   * @param p_cod_tra_impuesto Codigo Mensaje.
   * @param p_cod_tas_impuesto Codigo Mensaje.
   * @param p_val_tas_impuesto Codigo Mensaje.
   * @param p_val_impuesto Codigo Mensaje.

   */
   PROCEDURE pr_obt_cargos
   (
      p_cod_ofi_origen   IN ge_cuentas.cod_oficina%TYPE,
      p_nro_cuenta       IN ge_cuentas.nro_cuenta%TYPE,
      p_cod_moneda       IN ge_cuentas.cod_moneda%TYPE,
      p_monto            IN ge_movimientos.monto%TYPE,
      p_cod_modulo       IN ge_cuentas.cod_modulo%TYPE,
      p_cod_modalidad    IN ge_cuentas.cod_modalidad%TYPE,
      p_cod_tra_cargo    IN ge_movimientos.cod_transaccion%TYPE,
      p_cod_tas_cargo    OUT ge_movimientos.cod_tasa%TYPE,
      p_val_tas_cargo    OUT ge_movimientos.val_tasa%TYPE,
      p_val_cargo        OUT ge_movimientos.val_tasa%TYPE,
      p_cod_tra_impuesto OUT ge_movimientos.cod_transaccion%TYPE,
      p_cod_tas_impuesto OUT ge_movimientos.cod_tasa%TYPE,
      p_val_tas_impuesto OUT ge_movimientos.val_tasa%TYPE,
      p_val_impuesto     OUT ge_movimientos.val_tasa%TYPE
   );


   /** Verifica los ultimos accesos de las claves y actualiza el estado de la misma.
   * @param p_cod_persona Codigo persona.
   * @param p_cod_per_vinculada Codigo persona vinculada.
   * @param p_tip_clave  Tipo clave.
   * @param p_cod_canal  Codigo canal.
   */
   PROCEDURE pr_act_est_ope_clave
   (
      p_cod_persona       IN VARCHAR2,
      p_cod_per_vinculada IN VARCHAR2,
      p_tip_clave         IN VARCHAR2,
      p_cod_canal         IN VARCHAR2
   );


   /** Convierte de una moneda a otra  moneda.
   * @param p_cod_mon_original Codigo moneda original.
   * @param p_cod_mon_destino Codigo moneda destino.
   * @param p_mto_mon_original  Monto moneda original.
   * @param p_mto_mon_destino  Monto moneda destino.
   * @param p_cot_mon_original Cotizacion moneda original.
   * @param p_cot_mon_destino  Cotizacion moneda destino.
   * @param p_interbancaria Interbancaria.
   */
   PROCEDURE pr_con_mon_a_moneda
   (
      p_cod_mon_original IN ba_monedas.cod_moneda%TYPE,
      p_cod_mon_destino  IN ba_monedas.cod_moneda%TYPE,
      p_mto_mon_original IN NUMBER,
      p_mto_mon_destino  OUT NUMBER,
      p_cot_mon_original IN OUT NUMBER,
      p_cot_mon_destino  IN OUT NUMBER,
      p_interbancaria    IN VARCHAR2 DEFAULT NULL
   );

   /** Graba los movimientos que operan bajo limites en Mobile Banking.
   * @param p_cod_mensaje Codigo mensaje.
   * @param p_monto Monto.
   * @param p_cod_moneda  Codigo moneda.
   * @param p_nro_cuenta  Número de cuenta.
   * @param p_fec_actual Fecha actual.
   * @param p_cot_mon_destino  Cotizacion moneda destino.
   * @param p_cod_canal Codigo canal.
   */
   PROCEDURE pr_gen_monto
   (
      p_cod_mensaje IN VARCHAR2,
      p_monto       IN NUMBER,
      p_cod_moneda  IN VARCHAR2,
      p_nro_cuenta  IN VARCHAR2,
      p_fec_actual  IN DATE,
      p_cod_canal   IN VARCHAR2
   );
   FUNCTION pr_ver_horario(p_horario        OUT VARCHAR2
                          ,p_es_mov_noc     OUT VARCHAR2
                          ,p_es_cta_noc     OUT VARCHAR2
                          ,p_ult_cierre     IN  DATE
                          ,p_cod_ofi_origen IN  VARCHAR2
                          ,p_fec_actual     OUT DATE
                          ,p_fec_cie_caja   IN  DATE
                          ,p_fec_valor      OUT DATE) RETURN typ_MensajeRespuesta;


   FUNCTION  fu_val_usu_tas
   (
      p_cod_canal   VARCHAR2,
      p_clave       VARCHAR2,
      p_cod_persona VARCHAR2
   ) return typ_iniciarsesion ;

   FUNCTION fu_val_est_tas(p_cod_canal VARCHAR2) RETURN BOOLEAN ;

   PROCEDURE pr_val_dup_tas
   (
      p_nro_cta_cuenta IN VARCHAR2,
      p_nro_sobre      IN NUMBER,
      v_mensaje        OUT typ_mensajeCaja
   );

 END PAW_CON;
/

