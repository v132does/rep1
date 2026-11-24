create or replace package it.PAW_BEE is
 
  -- Author  : XPY0040
  -- Created : 4/17/2019 5:09:09 PM
  -- Purpose : Paquete de banca empresas
  


  /** Crea una sesion para el canal y cuenta especificada
   * @param p_password        Contraseña en texto plano
   * @param p_dato            Información de tercero que desea iniciar sesion. El tipo esta especificado en p_tipoDato
   * @param p_tipoDato        Código del tipo de cuenta que desea iniciar sesion. "D" documento, "K" codigo Persona, "C" tarjeta de credito
   * @param p_nroDocEmpresa   nro de RUC de empresa a la que esta vinculada la persona.Opcional
   * @param p_tipoDocEmpresa  Tipo de Documento de la empresa. "D" RUC
   * @param p_codCanal        Código de Canal para el cual se creará la sesion
   * @return retorna informacion de la sesion creada  e información referente a la cuenta.
   */
   FUNCTION fu_iniciarSesion(p_password       IN VARCHAR2,
                             p_dato           IN VARCHAR2,
                             p_tipoDato       IN VARCHAR2,
                             p_nroDocEmpresa  IN VARCHAR2,
                             p_tipoDocEmpresa IN VARCHAR2,
                             p_identificadorsesion IN VARCHAR2,
                             p_codCanal       IN VARCHAR2) RETURN typ_iniciarSesion;

   -- obtiene la lista de participantes en un movimiento pendiente
   FUNCTION fu_obt_autorizadores(p_nro_documento IN bw_autorizaciones.nro_documento%TYPE) RETURN typ_listadetalleautorizador;
   
   /**
    * Obtiene las operaciones pendientes segun estado
    *
    * @param p_cod_persona codigo cliente
    * @param p_cod_empresa codigo empresa
    * @param p_cod_canal numero de caja
    * @param p_estados lista de estados separados por coma
    */
   FUNCTION fu_obt_operaciones(p_cod_persona IN VARCHAR2,
                               p_cod_empresa IN VARCHAR2,
                               p_cod_canal IN VARCHAR2,
                               p_estados IN VARCHAR2,
                               p_id_sesion IN VARCHAR2 DEFAULT NULL) RETURN typ_autorizacionesDelDia;
   
   -- valida un movimiento pendiente
   FUNCTION fu_val_doc_autorizacion(p_nro_documento IN bw_mov_pendientes.nro_documento%TYPE,
                                    p_cod_empresa   IN OUT ba_personas.cod_persona%TYPE,
                                    p_cod_persona   IN ba_personas.cod_persona%TYPE,
                                    p_cod_canal     IN cj_cajas.nro_caja%TYPE,
                                    p_estado        IN VARCHAR2,
                                    p_detalle       IN OUT typ_detallependiente) RETURN typ_mensajerespuesta;

   /**
    * Registrar dispositivo softtoken
    */
   FUNCTION fu_reg_softoken(p_cod_persona IN VARCHAR2,
                            p_cod_per_vinculada IN VARCHAR2,
                            p_cod_canal  IN VARCHAR2,
                            p_nro_serial IN VARCHAR2,
                            p_cod_dispositivo IN VARCHAR2,
                            p_cla_encriptacion IN VARCHAR2,
                            p_vec_inicializacion IN VARCHAR2,
                            p_dominio IN VARCHAR2, 
                            p_modo IN VARCHAR2,
                            p_id_sesion IN VARCHAR2 DEFAULT NULL,
                            p_es_migracion IN VARCHAR2 DEFAULT 'N') RETURN typ_mensajerespuesta;

   /**
    *  Desvincular SoftToken
    */
   FUNCTION fu_des_softoken(p_cod_persona IN VARCHAR2,
                            p_cod_per_juridica IN VARCHAR2,
                            p_nro_serial IN VARCHAR2,
                            p_dominio IN VARCHAR2,
                            p_cod_canal  IN VARCHAR2,
                            p_id_sesion IN VARCHAR2 DEFAULT NULL) RETURN typ_mensajerespuesta;

   /**
    * Procedimiento para volver a dejar pendiente un mensaje encolado.
    *
    * @param p_nro_documento numero de documento pendiente
    * @param p_cod_persona   codigo persona vinculada a la empresa
    * @param p_cod_empresa   codigo empresa
    * @param p_cod_canal     numero de caja
    * @param p_fec_hora      fecha de la creacion del movimiento
    */  
   PROCEDURE pr_set_pen_enconlado(p_nro_documento IN bw_mov_pendientes.nro_documento%TYPE,
                                  p_cod_empresa   IN ba_personas.cod_persona%TYPE,
                                  p_cod_persona   IN ba_personas.cod_persona%TYPE,
                                  p_cod_canal     IN cj_cajas.nro_caja%TYPE,
                                  p_fec_hora      IN bw_mov_pendientes.fec_hora%TYPE);
   /**
    * Firma un movimiento pendiente, disminuye la cantidad de firmas faltantes.
    *
    * @param p_cod_persona   codigo persona vinculada a la empresa
    * @param p_cod_empresa   codigo empresa
    * @param p_cod_canal     numero de caja
    * @param p_nro_documento nro de movimiento pendiente
    * @return lista de autorizaciones con firmas faltantes.
    */                           
   FUNCTION fu_firmarOperacion(p_cod_persona     IN ba_personas.cod_persona%TYPE,
                               p_cod_empresa     IN ba_personas.cod_persona%TYPE,
                               p_cod_canal       IN cj_cajas.nro_caja%TYPE,
                               p_nro_documento   IN VARCHAR2) RETURN typ_firmaOperacion;

    -- Se comenta la funcion porque requiera objetos de sipap/spi
   /**
    * Procesa un movimiento pendiente, si el estado es encolado.
    *
    * @param p_cod_persona    codigo persona vinculada a la empresa
    * @param p_cod_empresa    codigo empresa
    * @param p_cod_canal      numero de caja
    * @param p_id_session     sesion del consumidor
    * @param p_nro_documento  numero de documento a procesar
    * @return detalle de la autorizacion
    */
  /* FUNCTION fu_autorizarOperacion(p_cod_persona     IN ba_personas.cod_persona%TYPE,
                                  p_cod_empresa     IN ba_personas.cod_persona%TYPE,
                                  p_cod_canal       IN cj_cajas.nro_caja%TYPE,
                                  p_id_session      IN VARCHAR2,
                                  p_nro_documento   IN bw_mov_pendientes.nro_documento%TYPE) RETURN typ_mapa;*/
 
   /**
    * Obtiene las operaciones pendientes segun estado
    * @param p_cod_persona codigo cliente
    * @param p_cod_empresa codigo empresa
    * @param p_cod_canal numero de caja
    * @param p_operaciones lista de documentos separados por coma
    */
   FUNCTION fu_rechazarOperaciones(p_cod_persona IN VARCHAR2,
                                   p_cod_empresa IN VARCHAR2,
                                   p_cod_canal   IN VARCHAR2,
                                   p_operaciones IN VARCHAR2,
                                   p_id_sesion IN VARCHAR2 DEFAULT NULL) RETURN typ_rechazoOperacion;
   /**
    * Obtiene datos adicionales que no se pudieron guardar en bw_mov_pendientes para transferencias 
    * internacionales de operaciones pendientes.
    */
   PROCEDURE pr_obt_dat_tra_internacional(p_nro_documento        IN BW_MOV_PENDIENTES.NRO_DOCUMENTO%TYPE,
                                          fecha                  IN bw_mov_pendientes.Fec_Hora%TYPE,
                                          cod_per_vinculada      IN BW_MOV_PENDIENTES.COD_PER_PRINCIPAL%TYPE,
                                          p_nom_beneficiario     OUT lc_transferencias.nom_beneficiario%TYPE,
                                          p_dir_beneficiario     OUT lc_transferencias.dir_beneficiario%TYPE,
                                          p_nro_cta_referencia   OUT lc_transferencias.nro_cta_referencia%TYPE,
                                          p_nom_banco            OUT lc_transferencias.nom_banco%TYPE,
                                          p_cod_pais             OUT ba_paises.cod_pais%TYPE,
                                          p_cod_ciudad           OUT ba_ciudades.cod_ciudad%TYPE,
                                          p_cod_bco_corresponsal OUT lc_transferencias.cod_bco_corresponsal%TYPE,
                                          p_nom_bco_corresponsal OUT lc_transferencias.nom_bco_cor_contra%TYPE,
                                          p_swi_bco_corresponsal OUT lc_transferencias.cod_swi_bco_contra%TYPE,
                                          p_pai_bco_corresponsal OUT lc_transferencias.cod_pai_bco_contra%TYPE,
                                          p_ciu_bco_corresponsal OUT lc_transferencias.cod_ciu_bco_contra%TYPE,
                                          p_cod_mon_credito      OUT ba_monedas.cod_moneda%TYPE,
                                          p_nro_contrato         OUT lc_ope_pendientes.nro_diario%TYPE,
                                          p_tip_cargo            OUT VARCHAR2,
                                          p_plazo                OUT NUMBER,
                                          p_tip_motivo           OUT lc_transferencias.tip_motivo%TYPE,
                                          p_tip_fondo            OUT lc_transferencias.tip_fondo%TYPE,
                                          p_tip_financiacion     OUT lc_transferencias.tip_financiacion%TYPE,
                                          p_cod_swift            OUT lc_transferencias.cod_swi_banco%TYPE,
                                          p_ref_beneficiario     OUT lc_transferencias.referencia%TYPE,
                                          p_cod_pai_beneficiario OUT lc_transferencias.cod_pai_beneficiario%TYPE,
                                          p_cod_ciu_beneficiario OUT lc_transferencias.cod_ciu_beneficiario%TYPE,
                                          p_ord_pago             OUT VARCHAR2);
   -- notificar encolados
   FUNCTION fu_not_encolados RETURN NUMBER;
   
   -- reintentar encolados
   PROCEDURE pr_pen_reintentar(p_nro_documento IN bw_mov_pendientes.nro_documento%TYPE,
                               p_retorno       OUT VARCHAR2);

   -- asignacion softoken                            
   FUNCTION fu_asi_sof_token(p_session    IN VARCHAR2,
                             p_codCanal   IN NUMBER,
                             p_modo       IN VARCHAR2,
                             p_accion     IN VARCHAR2,
                             p_nro_serial IN VARCHAR2) RETURN typ_mensajerespuesta;

   PROCEDURE pr_act_fec_mov_pend;
            
   -- transferencia sipap
   FUNCTION fu_tra_snp(p_cod_persona           IN VARCHAR2,
                       p_cod_empresa           IN VARCHAR2,
                       p_cod_canal             IN VARCHAR2,
                       p_id_sesion             IN VARCHAR2,
                       p_modo                  IN VARCHAR2,
                       p_nroCuentaDebito       IN VARCHAR2, 
                       p_nroCuentaCredito      IN VARCHAR2, 
                       p_codMonCredito         IN VARCHAR2,
                       p_montoCredito          IN NUMBER,
                       p_concepto              IN VARCHAR2, 
                       p_codigoSwift           IN VARCHAR2, 
                       p_nombreBeneficiario    IN VARCHAR2,
                       p_codTipoDocumentoBen   IN NUMBER,
                       p_numeroDocBeneficiario IN VARCHAR2, 
                       p_tip_cargos            IN VARCHAR2,
                       p_canFirmas             IN NUMBER,
                       p_numeroContrato        IN NUMBER DEFAULT NULL) RETURN TYP_MAPA;

end PAW_BEE;
/

