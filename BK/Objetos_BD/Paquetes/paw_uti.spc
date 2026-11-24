CREATE OR REPLACE PACKAGE IT.PAW_UTI IS
   
  -- Author  : XPY0035
  -- Created : 16/12/2015 10:10:23 a.m.
  -- Purpose : Funciones utilitarias

--- Constantes definidas en PAW_BEL, 
--- Hacer referencia de aca en PAW_BEL
   /** Codigo de respuesta OK generico */
   MSG_OK CONSTANT VARCHAR2(30) := 'OP_APROBADA';

   /** Codigo de error generico, Ej. excepciones no manejadas */
   MSG_ERROR CONSTANT VARCHAR2(30) := 'OP_ERROR';

   /** Codigo de respuesta OK, para proceso nocturno*/
   MSG_OK_NOC CONSTANT VARCHAR2(15) := 'OP_APR_NOCTURNA';

   /** Constantes de tipo de Bitácora */
   BITACORA_ERROR   CONSTANT VARCHAR2(3) := 'ERR';
   BITACORA_ENTRADA CONSTANT VARCHAR2(3) := 'ENT';
   BITACORA_SALIDA  CONSTANT VARCHAR2(3) := 'SAL';

   CUENTA_TAMANO CONSTANT NUMBER(3) := 18;
--Fin de constantes

   /* Permite obtener la Información de Paises, Ciudades y Barrios */
   FUNCTION fu_obtenerDatosGeograficos(p_tipoPedido IN VARCHAR2,
                                       p_codPedido  IN NUMBER DEFAULT NULL,
                                       p_codPais    IN NUMBER DEFAULT NULL) RETURN typ_datosGeograficos;


   /**
    * Obtener los tipos de documentos en estado Activo.
    * 
    * @param p_tipoPersona Filtro para tipos de personas, F : Fisicas, J : Juridicas.
                           Si no se especifica el filtro, se devuelven todos
    */
   FUNCTION fu_tipDocumentos(p_tipoPersona IN VARCHAR2 DEFAULT NULL) RETURN typ_listaconsultadocumentos;
   
   /* Obtener las profesiones del sistema */
   FUNCTION fu_profesiones RETURN typ_listaconsultadocumentos;
   
   FUNCTION rellenarDerecha(p_dato     IN VARCHAR2,
                            p_longitud IN NUMBER,
                            p_char     IN CHAR) RETURN VARCHAR2;
                         
  /**
   * Valida si una dirección de correo es válida
   *
   * @param p_mail Dirección de correo a validar
   * @return Retorna 'S' si la dirección de correo es válida, en caso contrario retorna 'N'
   */
   FUNCTION fu_validarMail(p_mail IN VARCHAR2) RETURN VARCHAR2;
   
   /**
    * Funcion para depurar correo electronico
    * @param p_string dato
    * @param maxLength maxima longitud
    *
    * @return correo electronico valido
    */
   FUNCTION depurarMail(p_string  IN VARCHAR2,
                        maxLength IN NUMBER) RETURN VARCHAR2;
   
   /**
    * Funcion para obtener el campo N p_orden de una 
    * p_cadena separada por p_seperador
    * 
    * @param p_cadena Cadena recibida
    * @param p_orden Numero de campo
    * @param p_separador Separador
    * @return Campo de cadena 
    */
   FUNCTION fu_obt_campo(p_cadena    IN VARCHAR2,
                         p_orden     IN NUMBER,
                         p_separador IN VARCHAR2) RETURN VARCHAR2;
   
   /** 
    * Obtener significado de ba_cod_referencias
    * 
    * @param p_dominio Codigo de dominio
    * @param p_valor valor a buscar del dominio
    * @return Abreviatura de la tabla, NULL en caso de no encontrar
    */
   FUNCTION fu_obtenerCodigoReferencia(p_dominio IN VARCHAR2,
                                       p_valor IN VARCHAR2) RETURN VARCHAR2;
   
   /** 
    * Validar una abreviatura de tipo de documento
    * 
    * @param p_tipo Abreviatura de documento (CI, PAS, CRC, etc)
    * @return Codigo de tipo de documento, NULL en caso de no encontrar
    */
   FUNCTION fu_validarTipoDocumento(p_tipo IN VARCHAR2) RETURN VARCHAR2;
   
   /**
    * Funcion para convertir una fecha a varchar2
    * @param p_fecha Fecha a convertir
    * @param p_formato 0: ddmmyyyy, 1: yyyymmdd, 2: dd/mm/yyyy, 3: yyyy/mm/dd
    */
   FUNCTION fu_fec_char(p_fecha   IN DATE, 
                        p_formato IN NUMBER) RETURN VARCHAR2;
   
      /**
    * Funcion para convertir un varchar2 a fecha
    * @param p_fecha Fecha a convertir
    * @param p_formato 0: ddmmyyyy, 1: yyyymmdd, 2: dd/mm/yyyy, 3: yyyy/mm/dd
    */
   FUNCTION fu_str_fecha(p_fecha   IN VARCHAR2, 
                         p_formato IN NUMBER) RETURN DATE;
   
   
   /**
    * Funcion para depurar un varchar2 a number
    * @param p_numero Numero a convertir
    * @param p_longitud Longitud maxima a convertir
    * @param p_formato 0: 1200000.23 1: 1200000,23
   */
   FUNCTION fu_for_number(p_numero   IN VARCHAR2, 
                          p_longitud IN NUMBER, 
                          p_formato  IN NUMBER DEFAULT 0) RETURN NUMBER;
   
   /**
    * Funcion para validar que un numero tenga prefijo celular
    * @param p_numero Numero a validar
    * @return S: celular valido, N: celular invalido
    */
   FUNCTION fu_val_celular(p_numero IN VARCHAR2) RETURN VARCHAR2;
   
   /**
    * Funcion para validar que un numero sea linea baja
    * @param p_numero Numero a validar
    * @return S: linea baja valida, N: linea baja invalida
    */
   FUNCTION fu_val_telefono(p_numero IN VARCHAR2) RETURN VARCHAR2;
   
   /**
    * Funcion para obtener el mensaje parametrizado del extracto
    * 
    * @param p_mes Mes solicitado en formato MM
    * @param p_anho Anho solicitado en formato YYYY
    * @return mensaje
    */
   FUNCTION fu_msg_extracto(p_fecha_cierre IN DATE) RETURN VARCHAR2;
   
   /**
    * Funcion para cargar una etiqueta/valor
    * 
    * @param p_lista lista que almacena los tag/value
    * @param p_tag nombre de la etiqueta
    * @param p_value valor de la etiqueta
    */
   PROCEDURE pr_add_value(p_lista IN OUT typ_listaetiquetavalor,
                          p_tag   IN VARCHAR2,
                          p_value IN VARCHAR2);

   /**
    * Funcion para cargar una etiqueta/valor/tipo
    * 
    * @param p_lista lista que almacena los typ_clavevalor
    * @param p_tag nombre de la etiqueta
    * @param p_value valor de la etiqueta
    */                
   PROCEDURE pr_add_value(p_lista IN OUT typ_listaclavevalor,
                          p_tag   IN VARCHAR2,
                          p_value IN VARCHAR2,
                          p_tipo  IN VARCHAR2);
              
   /**
    * Funcion para indicar si un cliente imprime su extracto de cuenta cc/ah
    * 
    * @param p_cod_persona Codigo Cliene
    * @return 'S':imprime, 'N': no imprime
    */
   FUNCTION fu_imp_extracto(p_cod_persona IN ge_clientes.cod_persona%TYPE) RETURN VARCHAR2;

    /**
    * Funcion para indicar si es una tarjeta prepaga
    *
    * @param p_cod_modalidad modalidad del producto
    * @return 'S':tarjeta prepaga, 'N': no es una prepaga
    */
   FUNCTION fu_es_prepaga(p_cod_modalidad IN ge_cuentas.cod_modalidad%TYPE) RETURN VARCHAR2;
/**
* Valida que la cuenta cumpla los valores pasados
* @p_codpersona codigo de la persona relacionada con la cuenta.
* @p_nrocuenta numero de cuenta
* @p_codmodulo modulo de la cuenta a comparar NULL si no importa
* @p_modalidad modelidad de la cuenta a comparar NULL si no importa
* @p_relacion tipo de relacion  de la cuenta a comparar NULL si no importa
*/
 FUNCTION fu_val_cuenta(p_codpersona IN ge_clientes.cod_persona%TYPE,
                        p_nrocuenta  IN ge_cuentas.nro_cuenta%TYPE,
                        p_codmodulo  IN ge_cuentas.cod_modulo%TYPE,
                        p_modalidad  IN ge_cuentas.cod_modalidad%TYPE,
                        p_relacion   IN ge_cta_clientes.relacion%TYPE) RETURN typ_mensajerespuesta;

   FUNCTION depurarAlfanumerico(p_string IN VARCHAR2, maxLength IN NUMBER, p_espacio IN CHAR DEFAULT 'N') RETURN VARCHAR2;
   FUNCTION depurarTextos(p_string IN VARCHAR2, maxLength IN NUMBER, p_documento IN VARCHAR2 DEFAULT 'N') RETURN VARCHAR2;
   FUNCTION depurarNumerico(p_string IN VARCHAR2, maxLength IN NUMBER) RETURN VARCHAR2;
   /** Obtiene un mensaje de la base de datos por el nombre del mensaje
   * @param p_mensaje Nombre del mensaje
   * @return p_nombreMensaje Nombre del mensaje
   * @return p_descripcionMensaje Descripción del mensaje
   * @return p_error Indicador de si es o no un mensaje de error
   */
   PROCEDURE pr_mensajeUsuario(mensaje IN VARCHAR2, nombreMensaje OUT VARCHAR2, descripcionMensaje OUT VARCHAR2, error OUT VARCHAR2);
   PROCEDURE pr_con_mon_a_moneda(p_cod_mon_original IN ba_monedas.cod_moneda%TYPE, p_cod_mon_destino IN ba_monedas.cod_moneda%TYPE,
                                 p_mto_mon_original IN NUMBER, p_mto_mon_destino OUT NUMBER, p_cot_mon_original IN OUT NUMBER,
                                 p_cot_mon_destino IN OUT NUMBER, p_interbancaria IN VARCHAR2 DEFAULT NULL);
   /* Devuelve la cuenta en formato IT - Cuenta Bepsa */
   FUNCTION fu_ver_cuenta(p_cta IN VARCHAR2) RETURN VARCHAR2;
   /* Devuelve la cuenta en formato IT - Cuenta Bancard */
   FUNCTION fu_for_cuenta(p_cta IN VARCHAR2) RETURN VARCHAR2;
   /* Verifica si existe Banco */
   FUNCTION fu_exi_banco(p_cod_banco NUMBER) RETURN VARCHAR2;
   /* Verifica si existe Financiera */
   FUNCTION fu_exi_financiera(p_cod_ente NUMBER) RETURN VARCHAR2;
   
   /** Inserta registro en la tabla bw_bitacora
   * @param p_codigoPersona Codigo de persona
   * @param p_codigoCanal Codigo de canal
   * @param p_codSesion Codigo de la sesion
   * @param p_tipoMensaje Tipo de mensaje
   * @param p_codigoEmpresa Codigo de la persona vinculada
   * @param p_datos Informacion de lo realizado
   * @param p_tipo Tipo de la bitacora
   */   
   PROCEDURE pr_insertarBitacora(p_codigoPersona IN VARCHAR2 DEFAULT NULL,
                                 p_codigoCanal   IN VARCHAR2 DEFAULT NULL,
                                 p_codSesion     IN VARCHAR2 DEFAULT NULL,
                                 p_tipoMensaje   IN VARCHAR2 DEFAULT NULL,
                                 p_codigoEmpresa IN VARCHAR2 DEFAULT NULL,
                                 p_datos         IN VARCHAR2 DEFAULT NULL,
                                 p_tipo          IN VARCHAR2 DEFAULT NULL);
				 
   /* Obtiene el codigo de persona desde el numero de documento y valida que este en ge_clientes */
   FUNCTION fu_obt_codPersona(p_nro_documento IN VARCHAR2) RETURN VARCHAR2;
   
   FUNCTION fu_apertura_cuenta_pre(p_sesion IN VARCHAR2,p_cod_persona IN ge_clientes.cod_persona%TYPE, p_codigoCanal IN VARCHAR2) RETURN TYP_CUENTAGENERADA;
   
   /*genera la bitacora, es una copia de la funcion de PAW_BEL*/
   FUNCTION fu_generarBitacora(error in varchar2, nombreRespuesta in varchar2 ,descripcionRespuesta in varchar2, mensajesAdicionales in varchar2 := NULL) RETURN VARCHAR2;
      
   FUNCTION fu_es_juridica(p_numeroCuenta    IN VARCHAR2,
                           p_cod_per_empresa IN VARCHAR2,
                           p_cod_persona     IN VARCHAR2) RETURN VARCHAR2;
                               
   FUNCTION lf_for_date(p_dato IN DATE) RETURN CHAR ;
   
   -- devuelve el campo monto formateado
   FUNCTION lf_for_money(p_dato IN NUMBER,
                         p_longitud IN NUMBER DEFAULT NULL) RETURN VARCHAR2;
                         
   /* Función que devuelve si una cuenta tiene o no cheque devuelto
   */
   FUNCTION lf_obt_che_devuelto(p_nro_cuenta IN VARCHAR2) RETURN VARCHAR2;
   
   PROCEDURE lp_reg_operacion(p_nro_cuenta      IN VARCHAR2 DEFAULT NULL,
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
                              p_parametros      IN VARCHAR2 DEFAULT NULL,
                              p_etiqueta3       IN VARCHAR2 DEFAULT NULL,
                              p_dato3           IN VARCHAR2 DEFAULT NULL);

    FUNCTION fu_ver_horario(p_horario        OUT VARCHAR2,
                           p_es_mov_noc     OUT VARCHAR2,
                           p_es_cta_noc     OUT VARCHAR2,
                           p_ult_cierre     IN DATE,
                           p_cod_ofi_origen IN VARCHAR2,
                           p_fec_actual     OUT DATE) RETURN typ_MensajeRespuesta;
        
    PROCEDURE lp_can_reg_historicos(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE,
                                   p_fecha      IN ge_movimientos.fecha%TYPE,
                                   p_horario    OUT VARCHAR2);
   /** 
    * Insertar comprobante comprimido.
    *
    * @param p_cod_persona   codigo cliente
    * @param p_cod_operacion tipo de operacion web
    * @param p_nro_documento numero de comprobante
    * @param p_comprobante archivo a insertar
    * @param p_nombre nombre del documento
    *
    * @return tamanho del archivo insertado, -1 en caso de error.
    */
   FUNCTION fu_ins_archivo(p_cod_persona   IN bw_archivos.cod_persona%TYPE,
                           p_cod_operacion IN bw_archivos.cod_tip_operacion%TYPE,
                           p_nro_documento IN bw_archivos.nro_documento%TYPE,
                           p_comprobante   IN bw_archivos.contenido%TYPE,
                           p_nombre        IN bw_archivos.nombre%TYPE) RETURN NUMBER;
	
   FUNCTION fu_obt_abr_refcodes(P_DOMINIO   IN VARCHAR2,
                                P_VALOR_MIN IN VARCHAR2,
                                P_VALOR_MAX IN VARCHAR2) RETURN VARCHAR2;
                           
END paw_uti;
/

