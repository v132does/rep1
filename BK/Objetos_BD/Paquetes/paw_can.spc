CREATE OR REPLACE PACKAGE IT.paw_can IS

  -- Created : 20/8/2018 16:03:24
  -- Modificado 07/09/2021
  -- Purpose : Agrupar las funciones necesarias para el canje de puntos

  /**
  * Función de verificación de canje
  * La verificación consiste en actualizar el valor de BW_CANJES.verificado
  * a 'S' y BW_CANJES.fec_verificacion a SYSDATE
  *
  * @p_api_key   Cadena para validar acceso a la función
  * @p_cod_canal '999' -> Web
  * @p_nro_canje Número del canje
  * @p_cod_verificador Código verificador
  *
  * @return TYP_CANJE
  */
  FUNCTION fu_ver_can_puntos(p_api_key         IN ge_par_dinamicos.val_parametro%TYPE,
               p_cod_canal       IN BW_AUT_SESIONES.COD_CANAL%TYPE,
               p_nro_canje       IN BW_CANJES.NRO_CANJE%TYPE DEFAULT NULL,
               p_cod_verificador IN BW_CANJES.COD_VERIFICADOR%TYPE) RETURN TYP_CANJE;

  /**
    * Obtiene la cantidad de puntos por tarjeta, solo de las que generen puntos
    * @param p_cod_persona codigo del cliente
    * @param p_cod_canal codigo del canal
    * @return lista de tarjetas con la cantidad de puntos
   */
   FUNCTION fu_ns_obt_punt_lealtad(p_cod_persona IN BW_AUT_SESIONES.COD_PERSONA%TYPE,
                                p_cod_canal  IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                                p_cod_sesion_aux    IN BW_AUT_SESIONES.COD_SESION%TYPE DEFAULT NULL) RETURN TYP_OBTPUNTOSLEALTAD;

   FUNCTION fu_ns_obt_can_puntos(p_cod_persona IN BW_AUT_SESIONES.COD_PERSONA%TYPE,
                              p_cod_canal  IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                              p_nro_canje  IN BW_CANJES.NRO_CANJE%TYPE,
                              p_cod_sesion_aux    IN BW_AUT_SESIONES.COD_SESION%TYPE DEFAULT NULL) RETURN TYP_CANJE;

   FUNCTION fu_ns_ins_can_puntos(p_cod_persona IN BW_AUT_SESIONES.COD_PERSONA%TYPE,
                              p_cod_canal            IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                              p_nro_tarjeta          IN BW_CANJES.NRO_TARJETA%TYPE DEFAULT NULL,
                              p_cat_producto         IN BW_CANJES.CAT_PRODUCTO%TYPE,
                              p_nom_producto         IN BW_CANJES.NOM_PRODUCTO%TYPE,
                              p_des_producto         IN BW_CANJES.DES_PRODUCTO%TYPE,
                              p_tel_contacto         IN BW_CANJES.TEL_CONTACTO%TYPE,
                              p_ema_contacto         IN BW_CANJES.EMA_CONTACTO%TYPE,
                              p_ema_des_notificacion IN BW_CANJES.EMA_DES_NOTIFICACION%TYPE,
                              p_cantidad             IN BW_CANJES.CANTIDAD%TYPE DEFAULT NULL,
                              p_puntos               IN BW_CANJES.PUNTOS%TYPE DEFAULT NULL,
                              p_tel_proveedor        IN BW_CANJES.TEL_PROVEEDOR%TYPE DEFAULT NULL,
                              p_showroom             IN BW_CANJES.SHOWROOM%TYPE DEFAULT NULL,
                              p_direccion            IN BW_CANJES.DIRECCION%TYPE DEFAULT NULL,
                              p_rec_autorizada       IN BW_CANJES.REC_AUTORIZADA%TYPE DEFAULT NULL,
                              p_per_autorizada       IN BW_CANJES.PER_AUTORIZADA%TYPE DEFAULT NULL,
                              p_cod_tip_autorizado   IN BW_CANJES.COD_TIP_AUTORIZADO%TYPE DEFAULT NULL,
                              p_nro_doc_autorizado   IN BW_CANJES.NRO_DOC_AUTORIZADO%TYPE DEFAULT NULL,
                              p_hor_inicio           IN BW_CANJES.HOR_INICIO%TYPE DEFAULT NULL,
                              p_hor_fin              IN BW_CANJES.HOR_FIN%TYPE DEFAULT NULL,
                              p_ben_titular          IN BW_CANJES.BEN_TITULAR%TYPE DEFAULT NULL,
                              p_beneficiario         IN BW_CANJES.BENEFICIARIO%TYPE DEFAULT NULL,
                              p_turno                IN BW_CANJES.TURNO%TYPE DEFAULT NULL,
                              p_sol_ida              IN BW_CANJES.SOL_IDA%TYPE DEFAULT NULL,
                              p_fec_salida           IN BW_CANJES.FEC_SALIDA%TYPE DEFAULT NULL,
                              p_fec_retorno          IN BW_CANJES.FEC_RETORNO%TYPE DEFAULT NULL,
                              p_fec_flexible         IN BW_CANJES.FEC_FLEXIBLE%TYPE DEFAULT NULL,
                              p_cla_servicio         IN BW_CANJES.CLA_SERVICIO%TYPE DEFAULT NULL,
                              p_can_ninos            IN BW_CANJES.CAN_NINOS%TYPE DEFAULT NULL,
                              p_can_adultos          IN BW_CANJES.CAN_ADULTOS%TYPE DEFAULT NULL,
                              p_lin_aerea            IN BW_CANJES.LIN_AEREA%TYPE DEFAULT NULL,
                              p_nro_doc_beneficiario IN Bw_Canjes.NRO_DOC_BENEFICIARIO%TYPE DEFAULT NULL,
                              p_fec_entrada          IN BW_CANJES.FEC_ENTRADA%TYPE DEFAULT NULL,
                              p_cod_verificador      IN BW_CANJES.COD_VERIFICADOR%TYPE DEFAULT NULL,
                              p_condiciones          IN VARCHAR2 DEFAULT NULL,
                              p_detalles             IN TYP_LISTADETALLECANJE DEFAULT NULL,
                              p_est_canje            IN BW_CANJES.ESTADO%TYPE,
            p_nom_proveedor        IN BW_CANJES.COMERCIO%TYPE DEFAULT NULL,
                              p_cod_producto         IN BW_CANJES.COD_PRODUCTO%TYPE DEFAULT NULL,
                              p_cod_sesion_aux       IN BW_AUT_SESIONES.COD_SESION%TYPE DEFAULT NULL,
                              p_usr_operador         IN BW_CANJES.OPE_CANJE%TYPE DEFAULT NULL,
                              p_suc_env_voucher      IN BW_CANJES.SUC_ENV_VOUCHER%TYPE DEFAULT NULL) RETURN TYP_CANJE;

  FUNCTION fu_ns_obtenerDetalleCuentas(p_cod_persona         IN BW_AUT_SESIONES.COD_PERSONA%TYPE,
                                        p_cod_empresa         IN BW_AUT_SESIONES.COD_PER_VINCULADA%TYPE,
                                        p_codCanal            IN VARCHAR2,
                                        p_nroCuentaEspecifica IN VARCHAR2 DEFAULT NULL,
                                        p_cod_sesion_aux      IN BW_AUT_SESIONES.COD_SESION%TYPE DEFAULT NULL) RETURN typ_obtenerDetalleCuentas;

 FUNCTION fu_ns_obt_can_entradas(p_cod_persona IN BW_AUT_SESIONES.COD_PERSONA%TYPE,
                              p_cod_canal  IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                              p_nro_canje  IN BW_CANJES.NRO_CANJE%TYPE,
                              p_cod_sesion_aux    IN BW_AUT_SESIONES.COD_SESION%TYPE DEFAULT NULL) RETURN typ_canjeentradas;

  /**
   * Retorna un listado de los seguros contratados para el usuario con el cod persona y/o cod empresa ingresado
   * @p_codigoPersona Codigo de la persona
   * @p_codigoEmpresa Codigo de la empresa
   * @p_codCanal Codigo de canal
   * @return Lista de Etiqueta Valor
   **/
   FUNCTION fu_obtenerSeguros(p_codigoPersona IN VARCHAR2,
                              p_codigoEmpresa IN VARCHAR2,
                              p_codigoCanal   IN VARCHAR2,
                              p_id_session    IN VARCHAR2,
                              p_codigoSeguro  IN VARCHAR2 DEFAULT NULL) RETURN TYP_SEGUROS;

   /**
    * Verificar si un documento fue autorizado por un usuario
    * @param p_nro_documento numero de documento pendiente
    * @param p_cod_persona codigo cliente vinculado
    * @return 'S' existe, 'N' no existe
    */
   FUNCTION fu_ver_autorizacion(p_nro_documento IN bw_autorizaciones.nro_documento%TYPE,
                                p_cod_persona   IN bw_autorizaciones.cod_persona%TYPE) RETURN VARCHAR2;

   /**
    * Verifica si la persona ya autorizo en numero de documento
    * @param p_nro_documento numero de documento pendiente
    * @param p_cod_persona codigo cliente vinculado
    * @return 'S' existe, 'N' no existe
    */
   FUNCTION fu_ver_mov_autorizado(p_nro_documento IN bw_autorizaciones.nro_documento%TYPE,
                                  p_cod_persona   IN bw_autorizaciones.cod_persona%TYPE) RETURN VARCHAR2;

   /**
    * Volver a dejar pendiente un pendiente de empresa con error.
    * @param p_cod_persona codigo persona fisica
    * @param p_cod_empresa codigo empresa
    * @param p_cod_operacion tipo de operacion
    * @param p_dato token del servicio
    * @param p_proveedor proveedor del servicio
    */
   PROCEDURE pr_act_pendiente(p_cod_persona     IN ba_personas.cod_persona%TYPE,
                              p_cod_per_empresa IN ba_personas.cod_persona%TYPE,
                              p_cod_operacion   IN bw_tip_mensajes.cod_tip_mensaje%TYPE,
                              p_dato            IN bw_mov_pendientes.dato%TYPE,
                              p_proveedor       IN bw_mov_pendientes.referencia%TYPE DEFAULT NULL);

    /**
    * Verifica un lote de proveedores sipap
    * @param p_cod_ente codigo ente de la empresa
    * @param p_fec_pago fecha de pago
    * @param p_nro_archivo numero de archivo
    */
    FUNCTION fu_obt_pag_snp_proveedores(p_cod_ente    IN ge_pag_proveedores_tmp.cod_ente%TYPE,
                                        p_fec_pago    IN ge_pag_proveedores_tmp.fec_pago%TYPE,
                                        p_nro_archivo IN ge_pag_proveedores_tmp.nro_archivo%TYPE)RETURN NUMBER;

   /**
   * Retorna un listado de cuentas de tarjetas canceladas
   * @p_codigoPersona Codigo de la persona
   * @p_codigoEmpresa Codigo de la empresa
   * @p_codCanal Codigo de canal
   * @p_nroCuentaEspecifica Numero de cuenta
   * @p_cod_sesion_aux   Codigo de sesion
   * @return Lista de cuentas de tarjetas canceladas
   **/
    FUNCTION fu_ns_obtenerCuentascancel(p_cod_persona         IN BW_AUT_SESIONES.COD_PERSONA%TYPE,
                                        p_cod_empresa         IN BW_AUT_SESIONES.COD_PER_VINCULADA%TYPE,
                                        p_codCanal            IN VARCHAR2,
                                        p_nroCuentaEspecifica IN VARCHAR2 DEFAULT NULL,
                                        p_cod_sesion_aux      IN BW_AUT_SESIONES.COD_SESION%TYPE DEFAULT NULL) RETURN typ_obtenerDetalleCuentas;
   FUNCTION fu_ns_obtDetCtas_Bancard(p_cod_persona         IN BW_AUT_SESIONES.COD_PERSONA%TYPE,
                                     p_cod_empresa         IN BW_AUT_SESIONES.COD_PER_VINCULADA%TYPE,
                                     p_codCanal            IN VARCHAR2,
                                     p_nroCuentaEspecifica IN VARCHAR2 DEFAULT NULL,
                                     p_cod_sesion_aux      IN BW_AUT_SESIONES.COD_SESION%TYPE DEFAULT NULL) RETURN typ_obtdetctas_hb_bancard;

END PAW_CAN;
/

