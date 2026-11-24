CREATE OR REPLACE PACKAGE IT.PAG_PAC IS

   -- Author  : XPY0155
   -- Created : 03/10/2017 
   -- Purpose : Agrupar funciones a utilizar para manejar Peticiones de Acreditaciones a Comercios.

   /* Funcion para verificación de horario */
   FUNCTION fu_ver_horario(p_horario OUT VARCHAR2, p_es_mov_noc OUT VARCHAR2, p_es_cta_noc OUT VARCHAR2, p_cod_ofi_origen OUT NUMBER,
                           p_fec_actual OUT DATE) RETURN typ_MensajeRespuesta;

   /* Devolver el numero de Cuenta del Banco */
   FUNCTION fu_obt_cta_banco(p_banco IN ge_bancos.cod_banco%TYPE, p_moneda IN ba_monedas.cod_moneda%TYPE) RETURN ge_cuentas.nro_cuenta%TYPE;

   /* Obtener el siguiente nro de referencia */
   FUNCTION fu_obt_sig_nro_referencia(p_fecha IN DATE DEFAULT NULL) RETURN NUMBER;

   /* Funcion para Validar ApiKey/IpOrigen */
   FUNCTION fu_val_api_key(p_api_key IN VARCHAR2, p_ip_origen IN VARCHAR2) RETURN typ_MensajeRespuesta;
   
   /* Funcion para obtener datos de Boleta */
   FUNCTION fu_obt_dat_boleta(p_nro_boleta ge_acr_comercios.nro_boleta%TYPE, p_cod_ente ge_entes.cod_ente%TYPE) RETURN ge_acr_comercios%ROWTYPE;
      
   /* Procedimiento para Validar ApiKey/IpOrigen y obtener Código de Ente */
   PROCEDURE pr_val_ente(p_api_key IN VARCHAR2, p_ip_origen IN VARCHAR2, p_cod_ente IN OUT NUMBER, p_respuesta IN OUT typ_MensajeRespuesta);

   /* Obtener datos de Cuenta */
   PROCEDURE pr_obt_dat_cuenta(p_nro_cuenta IN VARCHAR2, p_cod_modulo OUT NUMBER, p_cod_modalidad OUT NUMBER, p_cod_oficina OUT NUMBER,
                               p_cod_moneda OUT VARCHAR2, p_respuesta IN OUT typ_MensajeRespuesta);

   /* Procedimiento para insercion de log de peticiones procesadas */
   PROCEDURE pr_ins_log(p_mensaje VARCHAR2, p_respuesta VARCHAR2, p_datos VARCHAR2, p_cod_ente NUMBER, p_fec_inicio DATE, p_error VARCHAR2);

   /* Procedimiento para insercion de peticiones de acreditaciones */
   PROCEDURE pr_ins_acr_comercios(p_rg_acr_comercios IN ge_acr_comercios%ROWTYPE);

   /* Procedimiento para realizar validaciones de parámetros requeridos */
   PROCEDURE pr_val_parametros(p_cod_ente NUMBER, p_datAcreditaciones IN OUT typ_datosAcreditaciones,
                               p_lisMenAcreditaciones IN OUT typ_lisMenAcreditaciones, p_retorno IN OUT typ_resAcreditaciones);

   /* Procedimiento para realizar validaciones iniciales */
   PROCEDURE pr_val_inicial(p_cod_ente IN NUMBER, p_fec_actual IN DATE, p_cod_moneda IN OUT ba_monedas.cod_moneda%TYPE,
                            p_cta_bco_ente IN OUT ge_cuentas.nro_cuenta%TYPE, p_bco_ente IN OUT ge_bancos.cod_banco%TYPE,
                            p_cod_tra_padre IN OUT ge_transacciones.cod_transaccion%TYPE, p_ind_rub_debito IN OUT VARCHAR2,
                            p_tra_con_debito IN OUT ge_movimientos.cod_transaccion%TYPE, p_tra_con_credito IN OUT ge_movimientos.cod_transaccion%TYPE,
                            p_mod_con_credito IN OUT ge_movimientos.cod_modulo%TYPE, p_mad_con_credito IN OUT ge_movimientos.cod_modalidad%TYPE,
                            p_cod_rub_credito IN OUT ge_movimientos.cod_rubro%TYPE, p_nro_cta_cli_cre IN OUT VARCHAR2, p_nro_cta_fic_cre OUT VARCHAR2,
                            p_mod_con_debito IN OUT ge_movimientos.cod_modulo%TYPE, p_mad_con_debito IN OUT ge_movimientos.cod_modalidad%TYPE,
                            p_cod_rub_debito IN OUT ge_movimientos.cod_rubro%TYPE, p_nro_cta_cli_deb IN OUT VARCHAR2, p_nro_cta_fic_deb OUT VARCHAR2,
                            p_ind_rub_credito IN OUT VARCHAR2, p_datAcreditaciones IN OUT typ_datosAcreditaciones,
                            p_lisMenAcreditaciones IN OUT typ_lisMenAcreditaciones, p_retorno IN OUT typ_resAcreditaciones);

   /* Procedimiento para Procesar operacion */
   PROCEDURE pr_ver_operacion(p_cta_debito IN ge_cuentas.nro_cuenta%TYPE, p_cta_credito IN ge_cuentas.nro_cuenta%TYPE,
                              p_cod_tra_padre IN ge_transacciones.cod_transaccion%TYPE, p_cod_mod_padre IN ge_transacciones.cod_modulo%TYPE,
                              p_cod_mad_padre IN ge_transacciones.cod_modalidad%TYPE, p_cod_mon_debito IN ba_monedas.cod_moneda%TYPE,
                              p_cod_mon_credito IN ba_monedas.cod_moneda%TYPE, p_imp_debito IN NUMBER, p_imp_credito IN NUMBER,
                              p_cod_ofi_origen IN ba_oficinas.cod_oficina%TYPE, p_mod_cta_deb IN OUT ba_modulos.cod_modulo%TYPE,
                              p_mad_cta_deb IN OUT ge_modalidades.cod_modalidad%TYPE, p_mod_cta_cre IN OUT ba_modulos.cod_modulo%TYPE,
                              p_mad_cta_cre IN OUT ge_modalidades.cod_modalidad%TYPE, p_cod_per_deb IN OUT ba_personas.cod_persona%TYPE,
                              p_cod_per_cre IN OUT ba_personas.cod_persona%TYPE, p_nro_cta_comb_deb IN OUT ge_cuentas.nro_cuenta%TYPE,
                              p_est_cta_deb IN OUT ge_cuentas.estado%TYPE, p_est_cta_cre IN OUT ge_cuentas.estado%TYPE,
                              p_sal_dis_deb IN OUT ah_cta_vistas.sal_total%TYPE, p_sal_dis_cre IN OUT ah_cta_vistas.sal_total%TYPE,
                              p_lisMenAcreditaciones IN OUT typ_lisMenAcreditaciones, p_retorno IN OUT typ_resAcreditaciones);

   /* Procedimiento para Procesar operacion */
   PROCEDURE pr_pro_operacion(p_cta_debito IN ge_cuentas.nro_cuenta%TYPE, p_cta_credito IN ge_cuentas.nro_cuenta%TYPE,
                              p_bco_credito IN ge_bancos.cod_banco%TYPE, p_nro_cta_comb ge_cuentas.nro_cuenta%TYPE,
                              p_cod_persona IN ba_personas.cod_persona%TYPE, p_cod_tra_padre IN ge_movimientos.cod_tra_padre%TYPE,
                              p_mod_cta_deb IN ge_cuentas.cod_modulo%TYPE, p_mad_cta_deb IN ge_cuentas.cod_modalidad%TYPE,
                              p_mod_cta_cre IN ge_cuentas.cod_modulo%TYPE, p_mad_cta_cre IN ge_cuentas.cod_modalidad%TYPE,
                              p_ofi_cta_deb IN ba_oficinas.cod_oficina%TYPE, p_ofi_cta_cre IN ba_oficinas.cod_oficina%TYPE,
                              p_ofi_origen IN ba_oficinas.cod_oficina%TYPE, p_mon_cta_deb IN ba_monedas.cod_moneda%TYPE,
                              p_mon_cta_cre IN ba_monedas.cod_moneda%TYPE, p_cod_moneda IN ba_monedas.cod_moneda%TYPE,
                              p_est_cta_deb IN ge_cuentas.estado%TYPE, p_est_cta_cre IN ge_cuentas.estado%TYPE,
                              p_sal_dis_debito IN OUT ah_cta_vistas.sal_total%TYPE, p_cod_usuario IN OUT ba_usuarios.cod_usuario%TYPE,
                              p_hora IN OUT ge_movimientos.hora%TYPE, p_fecha IN OUT ge_movimientos.fecha%TYPE, p_es_nocturno IN VARCHAR2,
                              p_horario IN VARCHAR2, p_concepto IN ge_movimientos.concepto%TYPE, p_cod_modulo IN ge_movimientos.cod_modulo%TYPE,
                              p_cod_modalidad IN ge_movimientos.cod_modalidad%TYPE, p_fec_valor IN ge_movimientos.fec_valor%TYPE,
                              p_imp_debito IN ge_movimientos.monto%TYPE, p_imp_credito IN ge_movimientos.monto%TYPE,
                              p_cot_debito IN ge_movimientos.cotizacion%TYPE, p_cot_credito IN ge_movimientos.cotizacion%TYPE,
                              p_nro_documento IN ge_movimientos.nro_documento%TYPE, p_nro_documento2 IN ge_movimientos.nro_documento2%TYPE,
                              p_nro_documento3 IN ge_movimientos.nro_documento3%TYPE, p_ind_rub_debito IN VARCHAR2, p_ind_rub_credito IN VARCHAR2,
                              p_tra_con_debito IN OUT ge_movimientos.cod_transaccion%TYPE, p_tra_con_credito IN OUT ge_movimientos.cod_transaccion%TYPE,
                              p_cod_rub_debito IN OUT ge_movimientos.cod_rubro%TYPE, p_cod_rub_credito IN OUT ge_movimientos.cod_rubro%TYPE,
                              p_mod_con_credito IN OUT ge_movimientos.cod_modulo%TYPE, p_mad_con_credito IN OUT ge_movimientos.cod_modalidad%TYPE,
                              p_cod_ente IN NUMBER, p_lisMenAcreditaciones IN OUT typ_lisMenAcreditaciones, p_retorno IN OUT typ_resAcreditaciones);

   /** Funcion para procesar las Peticiones de Acreditaciones a Comercios. 
   -- Recibe los parametros desde el servicio de Acreditaciones a Comercios
   @param p_peticion Peticion de Acreditacion Recibida -- TYP_DATOSACREDITACIONES
   @param p_api_key  Codigo de aplicacion
   @param p_ip_origen Ip de la Entidad que consume el Servicio
   @return v_retorno Respuesta de a la Peticion recibida -- TYP_RESACREDITACIONES
   */
   FUNCTION fu_acr_comercios(p_peticion IN typ_datosAcreditaciones, p_api_key VARCHAR2, p_ip_origen VARCHAR2) RETURN typ_resAcreditaciones;
   
   /** Funcion para Consultar Peticiones de Acreditaciones a Comercios
   -- Recibe los parametros desde el servicio de Acreditaciones a Comercios
   @param p_nro_boleta Numero de Boleta de la Acreditacion
   @param p_api_key  Codigo de aplicacion
   @param p_ip_origen Ip de la Entidad que consume el Servicio
   @return v_retorno Respuesta de a la Peticion recibida -- TYP_RESACREDITACIONES
   */
   FUNCTION fu_con_acr_comercios(p_nro_boleta IN NUMBER, p_api_key IN VARCHAR2, p_ip_origen IN VARCHAR2) RETURN typ_resAcreditaciones;
   
END PAG_PAC;
/

