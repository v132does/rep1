CREATE OR REPLACE PACKAGE IT.PAW_GEN IS

/*Paquete para procedimientos y funciones generales a 
ser utilizados en canales digitales*/

/**
   * Funcion para Obtener Datos de Clientes(Customers) 
   * @p_nro_documento  nro de documento
     @p_cod_tip_documento  codigo de Tipo de Documento
   * @return Lista de Etiqueta Valor
   */
FUNCTION fu_obt_customer(p_nro_documento IN VARCHAR2 default null,
                         p_cod_tip_documento IN VARCHAR2 default null
) RETURN typ_datCustomer;

FUNCTION fu_obt_customers(p_nro_documento IN VARCHAR2 default null,
                         p_cod_tip_documento IN VARCHAR2 default null
) RETURN typ_datCustomer;
/**
   * Funcion para Obtener Datos de Clientes por ID(Customers)
   * @p_cod_persona  codigo de persona
   * @return Lista de Etiqueta Valor
   */
FUNCTION fu_obt_customerid(p_cod_persona IN VARCHAR2 default null
) RETURN typ_datCustomer;


FUNCTION fu_obt_customersid(p_cod_persona IN VARCHAR2 default null
) RETURN typ_datCustomer;

/**
* Funcion que obtiene los datos de contacto de un cliente por su ID
* @p_cod_persona  codigo de persona
*/
FUNCTION fu_obt_cus_contact_info(p_cod_persona IN VARCHAR2 default null
) RETURN TYP_CUSTOMER_CONTACT;

FUNCTION fu_obt_businessid(p_cod_persona IN VARCHAR2)
RETURN typ_datBusiness;

FUNCTION fu_obt_businessesid(p_cod_persona IN VARCHAR2)
  RETURN typ_datBusiness ;

FUNCTION fu_obt_businesses(p_cod_persona IN VARCHAR2 default null, p_tip_documento IN VARCHAR2 default null,
  p_nro_documento IN VARCHAR2 default null, p_rows IN VARCHAR2 default null)
RETURN typ_datBusiness;

FUNCTION fu_obt_gru_economicos(p_nro_doc     IN VARCHAR2,
                               p_cod_tip_doc IN VARCHAR2)
RETURN TYP_GRUP_ECONOMICO;

FUNCTION fu_obt_niveles_riesgo(p_nro_doc     IN VARCHAR2,
                               p_cod_tip_doc IN VARCHAR2)
RETURN TYP_NIVELES_RIESGO;

FUNCTION fu_obt_addresses(codPersona IN VARCHAR2)
RETURN TYP_DATADDRESSES;

FUNCTION fu_obt_actividad_econ(codPersona IN VARCHAR2)
RETURN TYP_DATECONOMICDATA;
 
FUNCTION fu_obt_oficial_cuenta(codPersona IN VARCHAR2)
RETURN TYP_DATAGENT;

    FUNCTION fu_ins_dato_generico(p_tipo  IN BW_DAT_GENERICOS.tipo%TYPE,
                                  p_cod_persona  IN BW_DAT_GENERICOS.cod_persona%TYPE, 
                                  p_cod_empresa  IN BW_DAT_GENERICOS.cod_empresa%TYPE,
                                  p_descripcion  IN BW_DAT_GENERICOS.descripcion%TYPE,
                                  p_datos_genericos IN BW_DAT_GENERICOS.datos_genericos%TYPE,
                                  p_cod_canal  IN VARCHAR2, 
                                  p_cod_sesion IN VARCHAR2 DEFAULT NULL)
                                  RETURN TYP_MENSAJERESPUESTA;
                                  
/** Obtener bancos
  * @param p_tipo                 : B= Beneficiarios Internacionales, C= Corresponsal, S= SIPAP, T= todos
  * @param p_codigoSwift          : Codigo Swift del Banco
  * @param p_banco                : Descripcion del Banco
  * @param p_pais                 : Descripcion del Pais
  * @param p_cod_operacion        : Codigo de operacion en la que se utilizaran los bancos
  *
  * @return Lista de Bancos
  */ 
  FUNCTION fu_obtenerBancos( p_tipo        IN VARCHAR2 DEFAULT 'B',
                             p_codigoSwift IN VARCHAR2 DEFAULT NULL,
                             p_banco       IN VARCHAR2 DEFAULT NULL,
                             p_cod_banco       IN NUMBER DEFAULT NULL,
                             p_pais        IN VARCHAR2 DEFAULT NULL,
                             p_cod_pais       IN NUMBER DEFAULT NULL) RETURN typ_bancos;
                             
  /** Obtener tipos de documentos
  *
  * @param p_tipo_operacion  : Codigo tip mensaje o codigo api para operaciones bancarias. Ej 036 o TRA_INTERBANCARIA
  * @param p_cod_tipo_doc    : Codigo de un tipo de documento especifico
  * @param p_descripcion     : Descripcion del tipo de documento
  * @param p_abreviatura     : Abreviatura del tipo de documento
  * @param p_tipo_persona    : F= Fisica, J: Juridica, A= Ambas
  *
  * @return Lista de Tipos de documentos
  */                              
FUNCTION fu_obtenerTiposDocumentos( p_tipo_operacion  IN VARCHAR2 DEFAULT NULL,
                                     p_cod_tipo_doc    IN NUMBER DEFAULT NULL,
                                     p_descripcion     IN VARCHAR2 DEFAULT NULL,
                                     p_abreviatura     IN VARCHAR2 DEFAULT NULL,
                                     p_tipo_persona    IN VARCHAR2 DEFAULT NULL)  RETURN typ_tiposdocumentos;   

  /** Obtener monedas
  *
  * @param p_tipo_operacion  : Codigo tip mensaje o codigo api para operaciones bancarias. Ej 036 o TRA_INTERBANCARIA
  * @param p_moneda_operacion    : En caso de utilizarse en una operacion, es el codigo de moneda de la operacion
  * @param p_cod_moneda    : Codigo moneda especifico a buscar
  * @param p_cod_iso     : Codigo estandar internacional de la moneda
  * @param p_cod_bcp     : codigo de moneda en el Banco Central del Paraguay
  * @param p_cod_pais    : codigo de pais de origen de la moneda
  * @param p_descripcion    : texto parcial o total a buscar en el campo descripcion
  * @param p_cod_operacion    : codigo de operacion proveniente de bw_tip_mensajes
  *
  * @return Lista de monedas que cumplan con todos los filtros proporcionados
  */                        
FUNCTION fu_obtenerMonedas(p_tipo_operacion  IN VARCHAR2 DEFAULT NULL,
                              p_moneda_operacion IN VARCHAR2 DEFAULT NULL,
                           p_cod_moneda    IN VARCHAR2 DEFAULT NULL,
                           p_cod_iso     IN VARCHAR2 DEFAULT NULL,
                           p_cod_bcp     IN NUMBER DEFAULT NULL,
                           p_cod_pais    IN NUMBER DEFAULT NULL,
                           p_descripcion     IN VARCHAR2 DEFAULT NULL)  RETURN typ_monedas;
                             
FUNCTION fu_obtenerSnpHorarios(p_cod_periodo     IN ge_snp_horarios.cod_periodo%TYPE DEFAULT NULL,
                               p_estado               IN ge_snp_horarios.estado%TYPE DEFAULT NULL) RETURN typ_SnpPeriodos;  

  /** Obtener horarios
  *
  * @param p_codigo  : Codigo del horario
  * @param p_tipo_operacion    : Codigo de operacion del api, 'SIN_OPE' en caso de que el horario no es ligado a una operacion especifica
  * @param p_estado     : estado del horario A:Abierto, C: Cerrado
  * @return Lista de horarios
  */ 
FUNCTION fu_obtenerHorarios(p_tipo_operacion  IN VARCHAR2,
                            p_codigo          IN VARCHAR2 DEFAULT NULL,
                            p_estado          IN VARCHAR2 DEFAULT NULL) RETURN typ_SnpPeriodos;                                                           

  /** Obtener contratos de cambio
  *
  * @param p_cod_empresa  : Codigo de la empresa
  * @param p_cod_persona    : Codigo persona
  * @param p_tipo_contrato     : C: Compra, V: Venta, A: Arbitraje
  * @param p_tipo_operacion     : Codigo de operacion
  * @param p_cod_moneda     : Moneda del contrato
  * @return Lista de contratos de cambio
  */ 
   FUNCTION fu_obtenerContratoCambio(p_cod_empresa        IN ba_personas.cod_persona%TYPE,
                                     p_cod_persona        IN ba_personas.cod_persona%TYPE,
                                     p_tipo_contrato      IN VARCHAR2,
                                     p_tipo_operacion     IN bw_cod_lim_relacion.nombre%TYPE DEFAULT NULL,
                                     p_cod_moneda             IN VARCHAR DEFAULT NULL) RETURN typ_respuestaContratoCambio;


END PAW_GEN;
/

