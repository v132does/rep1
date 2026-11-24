CREATE OR REPLACE PACKAGE IT.PAG_CON IS
   /**********************
   -- Autor    : Milton Benitez
   -- Creado   : 01/2019
   -- Objetivo : Procesamiento de Datos Enviados a IT-GF desde otras aplicaciones, y enviar de IT-GF a Otras aplicaciones.
                 V1: Pre-Carga de Limites de Creditos desde el CRM a IT-GF.
   ***********************/

   g_archivo varchar2(2000);--variable global para tipo de servicio
   g_url_crm varchar2(2000);--url crm
   g_guid_crm  GE_EXP_APLICACIONES_CAB.GUID_CRM%TYPE;     
   g_cod_mon_factura varchar2(50);--              
   /*Pre-Carga de L?mites de Creditos*/
   FUNCTION  FU_INS_LIN_CREDITO (P_MENSAJE GE_EXP_APLICACIONES_CAB.MENSAJE%TYPE) RETURN VARCHAR2;
   PROCEDURE PR_INS_MENSAJE     (P_FECHA               IN DATE     ,
                                 P_HORA                IN VARCHAR2 ,
                                 P_DATOS               IN CLOB     ,
                                 V_ID                  OUT NUMBER  ,
                                 V_URL                 OUT VARCHAR2,
                                 V_GUID_CRM            OUT VARCHAR2,
                                 V_COD_USU_SOLICITANTE OUT VARCHAR2,
                                 V_COD_USU_SANCIONADOR OUT VARCHAR2,
                                 V_COD_ERROR           OUT VARCHAR2,
                                 V_MENSAJE             OUT VARCHAR2);
   /**
    * Procedimiento para obtener datos del CRM
    * @param p_cod_persona codigo persona del cliente
    * @param p_nro_solicitud nro solicitud
    */
   PROCEDURE pr_obt_dat_crm(p_cod_persona   IN pr_solicitudes.cod_persona%TYPE,
                            p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
                            p_cod_modulo    IN pr_solicitudes.cod_modulo%TYPE,
                            p_cod_modalidad IN pr_solicitudes.cod_modalidad%TYPE,
                            p_nro_sol_crm   OUT  ge_exp_aplicaciones_det.nro_sol_crm%TYPE,
                            p_est_crm       OUT ba_cod_referencias.abreviatura%TYPE,
                            p_url_crm       OUT ge_exp_aplicaciones_cab.url_crm%TYPE);
   /**
    * Procedimiento para insertar en la tabla ge_exp_aplicaciones_cab
    * @param rp_ge_exp_app_cab registro de la tabla ge_exp_aplicaciones_cab
    */
   PROCEDURE pr_ins_ge_exp_app_cab(rp_ge_exp_app_cab IN ge_exp_aplicaciones_cab%ROWTYPE);
   /**
    * Procedimiento para insertar en la tabla ge_exp_aplicaciones_cab
    * @param rp_ge_exp_app_cab registro de la tabla ge_exp_aplicaciones_cab
    */
   PROCEDURE pr_ins_ge_exp_app_det(rp_ge_exp_app_det IN ge_exp_aplicaciones_det%ROWTYPE);
   /**
    * Procedimiento que genera JSON dinamicamente
    * @param p_destino desitno a donde se enviara JSON generado
    * @param p_referencia referencia que se definio en ba_cod_referencias
    * @param p_nro_sol_it nro solicitud
    * @param p_cod_persona codigo persona del cliente
    */
   PROCEDURE pr_gen_json(p_destino     IN VARCHAR2,
                         p_referencia  IN VARCHAR2,
                         p_nro_sol_it  IN VARCHAR2,
                         p_json        OUT CLOB);
   /**
    * Procedimiento para enviar por web service solicitud al CRM
    * @param p_nro_solicitud numero de solicitud de prestamo
    * @param p_cod_persona codigo persona del cliente
    */
   PROCEDURE pr_env_json(p_nro_solicitud  IN VARCHAR2,
                         p_cod_persona    IN VARCHAR2,
                         p_referencia in varchar2 default 'ENV_DAT_CRM');

   /**
    * Funcion para envio Post (Content-Type', VALUE => 'text/plain)
    * @param p_parametros datos a enviar
    * @param p_url url para enviar
    * @param p_metodo metodo a utlizar default POST
    */
   FUNCTION fu_env_post(p_parametros IN VARCHAR2,
                        p_url        IN VARCHAR2,
                        p_metodo     IN VARCHAR2 DEFAULT 'POST') RETURN TYP_POSTRESPUESTA;
   /**
    * Funcion para formatear monto
    * @param p_monto monto de la solicitud
    * @param p_cod_moneda moneda de la solicitud
    */
   FUNCTION fu_for_monto(p_monto      IN NUMBER,
                         p_cod_moneda IN VARCHAR2) RETURN VARCHAR2;

   /**
   * Funcion para Obtener cod moneda de pago por ente proveedor
   * @param p_cod_ent_proveedor cod ente del proveedor
   */
   function FU_OBT_COD_MON_PAGO(P_COD_ENT_PROVEEDOR in number) return varchar2;

   /**
   * Funcion para Obtener cta del proveedor
   * @param p_cod_ent_proveedor cod ente del proveedor
   */
   function FU_OBT_CTA_PROVEEDOR(P_COD_ENT_PROVEEDOR in number) return varchar2;

   /**
   * Funcion para generar cod compra
   * @param p_cod_ent_proveedor cod ente del proveedor
   */
   function FU_GEN_COD_COMPRA(P_COD_ENT_PROVEEDOR in number) return number;

   /**
   * Funcion para Obtener cod compra
   * @param p_cod_ent_proveedor cod ente del proveedor
   */
   function FU_OBT_COD_COMPRA(P_COD_ENT_PROVEEDOR in number) return number;
   /**
   * Funcion para ejecutar funcion con parametros
   * @param p_funcion funcion a ejecutar
   * @param p_parametro parametro de la funcion
   */
   function FU_EXE_FUNCION(P_FUNCION   in varchar2
                          ,P_PARAMETRO in varchar2) return varchar2;

   /**
   * Funcion para ejecutar funcion con parametros
   * @param p_funcion funcion a ejecutar
   * @param p_parametro parametro de la funcion
   */
   function FU_OBT_RUC_ENTE(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE) return varchar2;
   
   /**
   * Funcion para ejecutar funcion con parametros
   * @param p_funcion funcion a ejecutar
   * @param p_parametro parametro de la funcion
   */
   function FU_OBT_CRM_URL(p_cod_ente in varchar2) return varchar2;
   
   /**
   * Funcion para ejecutar funcion con parametros
   * @param p_funcion funcion a ejecutar
   * @param p_parametro parametro de la funcion
   */
   function FU_OBT_FOR_PAGO(p_cod_ente in varchar2) return varchar2;
   
   /**
   * Funcion para desplegar mensajes mas legibles al usuario
   * @param p_funcion funcion a ejecutar
   * @param p_parametro parametro de la funcion
   */
   function FU_OBT_MSJ_ERROR(P_MENSAJE in varchar2) return varchar2;
   
   
   /**
   * Funcion para ejecutar funcion con parametros
   * @param p_funcion funcion a ejecutar
   * @param p_parametro parametro de la funcion
   */
   function FU_OBT_RUC_PROVEEDOR(P_COD_ENTE in varchar2) return varchar2;
   
   /**
   * Funcion para ejecutar funcion con parametros
   * @param p_funcion funcion a ejecutar
   * @param p_parametro parametro de la funcion
   */
   function FU_OBT_NOM_PROVEEDOR(P_COD_ENTE in varchar2) return varchar2;
   

END PAG_CON;
/

