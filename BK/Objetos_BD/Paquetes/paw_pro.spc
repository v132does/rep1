create or replace package it.PAW_PRO is

  -- Author  : XPY0035
  -- Created : 10/06/2015 04:48:18 p.m.
  -- Purpose : Configurar operaciones programadas

   MSG_OK           CONSTANT VARCHAR2(30)    := 'OP_APROBADA';
   MSG_ERROR        CONSTANT VARCHAR2(30)    := 'OP_ERROR';
   MSG_OPE_INVALIDA    CONSTANT VARCHAR2(15) := 'P_OP_NO_PERM';
   
   BITACORA_ERROR   CONSTANT VARCHAR2(3) := 'ERR';
   BITACORA_ENTRADA CONSTANT VARCHAR2(3) := 'ENT';
   BITACORA_SALIDA  CONSTANT VARCHAR2(3) := 'SAL';
   
   
   G_XML_CTA_DEBITO     CONSTANT VARCHAR2(30) := '/operation/debitAccount/text()';
   G_XML_CTA_CREDITO    CONSTANT VARCHAR2(32) := '/operation/creditAccount/text()';
   G_XML_MONTO          CONSTANT VARCHAR2(25) := '/operation/amount/text()';
   G_XML_NRO_DOCUMENTO  CONSTANT VARCHAR2(38) := '/operation/documentNumber/text()';   
   G_XML_TIP_NRO_DOC    CONSTANT VARCHAR2(37) := '/operation/documentNumberType/text()';
   G_XML_COD_SWIFT      CONSTANT VARCHAR2(27) := '/operation/swiftCode/text()';
   G_XML_COD_CRE_MONEDA CONSTANT VARCHAR2(32) := '/operation/creditCurrency/text()';
   G_XML_CARGOS         CONSTANT VARCHAR2(25) := '/operation/charges/text()';
   G_XML_NOM_BENEF      CONSTANT VARCHAR2(33) := '/operation/beneficiaryName/text()';
   G_XML_DIR_BENEF      CONSTANT VARCHAR2(36) := '/operation/beneficiaryAddress/text()';
   G_XML_TIP_MENSAJE    CONSTANT VARCHAR2(29) := '/operation/messageType/text()';
   G_XML_NOM_BANCO      CONSTANT VARCHAR2(33) := '/operation/beneficiaryBank/text()';

   /** Obtiene la siguiente fecha habil
    *
    * @param p_frecuencia Frecuencia de la operacion D: diaria, S: semanal, etc
    * @param p_fec_inicio Fecha inicial para calcular la siguiente fecha
    * @param p_cantidad Si se recibe, se multiplica por los dias calculados segun frecuencia y fec_inicio
    * @return fecha habil calculada
   */
   FUNCTION fu_obt_fec_siguiente(p_frecuencia IN bw_ope_programadas.frecuencia%TYPE,
                                 p_fecha      IN bw_ope_programadas.fec_sig_operacion%TYPE,
                                 p_cantidad   IN bw_ope_programadas.can_operaciones%TYPE DEFAULT NULL) RETURN DATE;
   
    /** Obtiene la cantidad de dias de una frecuenca
    *
    * @param p_frecuencia Frecuencia de la operacion D: diaria, S: semanal, etc
    * @return cantidad de dias a contabilizar
   */
   FUNCTION fu_obt_cantidad(p_frecuencia IN bw_ope_programadas.frecuencia%TYPE) RETURN NUMBER;

   /** Obtiene la descripcion de una frecuenca
    *
    * @param p_frecuencia Frecuencia de la operacion D: diaria, S: semanal, etc
    * @return descripcion
   */
   FUNCTION fu_obt_nombre(p_frecuencia IN bw_ope_programadas.frecuencia%TYPE) RETURN VARCHAR2;

   PROCEDURE pr_obt_dat_sesion(p_sesion     IN VARCHAR2,
                               p_usu_sesion OUT paw_bel.typ_validarSesion);
   
   PROCEDURE pr_fin_operacion(p_nro_referencia IN bw_ope_programadas.nro_referencia%TYPE);

   -- actualiza los datos del movimientos generado en el detalle
   PROCEDURE pr_act_ope_detalle(p_nro_referencia IN bw_ope_programadas_det.nro_referencia%TYPE,
                                p_nro_detalle    IN bw_ope_programadas_det.nro_detalle%TYPE,
                                p_fecha          IN bw_ope_programadas_det.fecha%TYPE,
                                p_hora           IN bw_ope_programadas_det.hora%TYPE,
                                p_estado         IN bw_ope_programadas_det.estado%TYPE,
                                p_mto_debito     IN bw_ope_programadas_det.mto_debito%TYPE,
                                p_mto_credito    IN bw_ope_programadas_det.mto_credito%TYPE,
                                p_cotizacion     IN bw_ope_programadas_det.cotizacion%TYPE,
                                p_cot_contra     IN bw_ope_programadas_det.cot_contra%TYPE,
                                p_nro_documento  IN bw_ope_programadas_det.nro_documento%TYPE,
                                p_msj_error      IN bw_ope_programadas_det.observacion%TYPE);

   
   PROCEDURE pr_ins_ope_siguiente(p_nro_referencia  IN bw_ope_programadas.nro_referencia%TYPE,
                                  p_cod_tip_mensaje IN bw_ope_programadas.cod_tip_mensaje%TYPE,
                                  p_fec_programada  IN bw_ope_programadas.fec_sig_operacion%TYPE,
                                  p_nro_detalle     IN bw_ope_programadas.can_operaciones%TYPE,
                                  p_cod_mon_debito  IN bw_ope_programadas.cod_mon_debito%TYPE,
                                  p_cod_mon_credito IN bw_ope_programadas.cod_mon_credito%TYPE,
                                  p_monto           IN bw_ope_programadas.monto%TYPE);
   
   -- proceso que para insertar el detalle programado para generar el movimiento
   PROCEDURE pr_gen_programadas;

   -- procesa los debitos pendientes del dia
   PROCEDURE pr_pro_debitos;

   -- procedimiento para cancelar las operaciones programadas
   PROCEDURE pr_can_ope_programadas;
   
   -- obtiene la cantidad total programada de una fecha
   FUNCTION fu_obt_pro_cantidad(p_cod_persona     IN ba_personas.cod_persona%TYPE,
                                p_cod_tip_mensaje IN bw_tip_mensajes.cod_tip_mensaje%TYPE,
                                p_cod_moneda      IN ba_monedas.cod_moneda%TYPE,
                                p_fecha           IN bw_ope_programadas.fec_sig_operacion%TYPE) RETURN NUMBER;
   
   -- calcula el limite programado
   FUNCTION fu_obt_pro_limite(p_cod_persona     IN ba_personas.cod_persona%TYPE,
                              p_cod_tip_mensaje IN bw_tip_mensajes.cod_tip_mensaje%TYPE,
                              p_cod_moneda      IN ba_monedas.cod_moneda%TYPE,
                              p_fecha           IN bw_ope_programadas.fec_sig_operacion%TYPE) RETURN NUMBER;
   
   -- obtiene los limites maximos de monto y cantidad de una persona
   PROCEDURE pr_obt_max_limite(p_cod_persona     IN ba_personas.cod_persona%TYPE,
                               p_tip_persona     IN ba_personas.tipo%TYPE,
                               p_cod_tip_mensaje IN bw_tip_mensajes.cod_tip_mensaje%TYPE,
                               p_cod_moneda      IN ba_monedas.cod_moneda%TYPE,
                               p_mto_maximo      OUT bw_cla_lim_montos.mto_maximo%TYPE,
                               p_can_maxima      OUT bw_cla_lim_cantidades.can_maxima%TYPE);
                               
   /** Validacion y confirmacion de programacion de operaciones
    *
    * @param p_sesion Sesion del Cliente
    * @param p_codigoCanal Numero de caja
    * @param p_modo Modo de Operacion, V: validacion, C: Confirmacion
    * @param p_codigoMensaje Tipo de operacion a programar
    * @param p_operacion Operacion a realizar.
                         G: guardar una operacion programada
                         C: cancelar una operacion programada
    * @param p_frecuencia Frecuencia de la operacion
                          U: Unica vez
                          D: Diaria
                          S: Semanal
                          Q: Quincenal
                          M: Mensual
                          B: Bimensual
                          T: Trimestral                          
    * @param p_fechaInicio Fecha de inicio de la programacion
    * @param p_fechaFin Fecha de culminacion de la programacion
    * @param p_cantidad Cantidad de operaciones
    * @param p_concepto Concepto de la operacion
    * @param p_referencia Numero de referencia de la operacion, si la operacion es C(Cancelar)
    * @param p_xmlData XML de datos a programar
    * @param p_claveToken Clave OTP
    * @return resultado de la operacion
   */
   FUNCTION fu_programarOperacion(p_sesion         IN VARCHAR2,
                                  p_codigoCanal    IN VARCHAR2,
                                  p_modo           IN VARCHAR2,
                                  p_codigoMensaje  IN VARCHAR2,
                                  p_operacion      IN VARCHAR2,
                                  p_frecuencia     IN VARCHAR2, 
                                  p_fechaInicio    IN DATE,
                                  p_fechaFin       IN DATE,
                                  p_cantidad       IN NUMBER,
                                  p_concepto       IN VARCHAR2,
                                  p_referencia     IN NUMBER,
                                  p_xmlData        IN VARCHAR2,
                                  p_claveToken     IN VARCHAR2) RETURN typ_opeProgramada;
                                  
   /** Listar las operaciones programadas
    *
    * @param p_sesion Sesion del Cliente
    * @param p_codigoCanal Numero de caja
    * @param p_estado Estado de la programacion (Opcional)
    * @param p_fechaInicio Bucar por fecha Inicio  (Opcional)
    * @param p_fechaFin Buscar por fecha fin (Opcional)                         
    * @param p_concepto Buscar por concepto (Opcional)
    * @return resultado de la operacion
   */
   FUNCTION fu_obtenerProgramados(p_sesion      IN VARCHAR2,
                                  p_codigoCanal IN VARCHAR2,
                                  p_estado      IN VARCHAR2 DEFAULT NULL,
                                  p_fechaInicio IN DATE DEFAULT NULL,
                                  p_fechaFin    IN DATE DEFAULT NULL,
                                  p_concepto    IN VARCHAR2 DEFAULT NULL) RETURN typ_programadas;
    
   /** Listar los detalles de una operacion
    *
    * @param p_sesion Sesion del Cliente
    * @param p_codigoCanal Numero de caja
    * @param p_referencia Numero de referencia
    * @return resultado de la operacion
   */                              
   FUNCTION fu_obtenerDetalleProgramada(p_sesion      IN VARCHAR2,
                                        p_codigoCanal IN NUMBER,
                                        p_referencia  IN NUMBER) RETURN typ_opeprogramada;

   /* Utilitarios para notificaciones */
   -- procedimiento para generar las operaciones a realizar
   PROCEDURE pr_not_operaciones;
   
   -- procedimiento para notificar las operaciones realizadas el dia siguiente
   PROCEDURE pr_not_ope_siguiente;
   
   -- actualizar el estado de generacion de comprobante
   PROCEDURE pr_act_est_comprobante(p_nro_referencia IN bw_ope_programadas_det.nro_referencia%TYPE,
                                    p_nro_detalle    IN bw_ope_programadas_det.nro_detalle%TYPE,
                                    p_estado         IN bw_ope_programadas_det.est_comprobante%TYPE);
                                    
   -- invocar al generador de comprobantes web
   PROCEDURE pr_gen_web_comprobante;

   -- inicio mensaje notificacion
   FUNCTION fu_not_inicio RETURN VARCHAR2;

   -- fin mensaje notificacion
   FUNCTION fu_not_fin RETURN VARCHAR2;

   -- titulo para notificacion
   FUNCTION fu_not_titulo(p_titulo IN VARCHAR2) RETURN VARCHAR2;
   
      -- titulo para notificacion
   FUNCTION fu_not_titulo2(p_titulo IN VARCHAR2) RETURN VARCHAR2;

   -- titulo para notificacion con error
   FUNCTION fu_not_titulo_err(p_titulo IN VARCHAR2) RETURN VARCHAR2;

   -- subtitulo para notificacion
   FUNCTION fu_not_sub_titulo(p_sub_titulo IN VARCHAR2) RETURN VARCHAR2;
   
   -- subtitulo para notificacion
   FUNCTION fu_not_sub_titulo2(p_sub_titulo IN VARCHAR2) RETURN VARCHAR2;
   
   -- inicio tag table
   FUNCTION fu_not_ini_tabla RETURN VARCHAR2;

   -- fin tag table
   FUNCTION fu_not_fin_tabla RETURN VARCHAR2;

   -- inicio body table
   FUNCTION fu_not_ini_tab_cuerpo RETURN VARCHAR2;

   -- fin body table
   FUNCTION fu_not_fin_tab_cuerpo RETURN VARCHAR2;

   -- fila de informacion para notificacion (detalle)
   FUNCTION fu_not_row_tag(p_tag_izquierda IN VARCHAR2, p_tag_derecha IN VARCHAR2) RETURN VARCHAR2;
end PAW_PRO;
/

