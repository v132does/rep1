CREATE OR REPLACE PACKAGE IT.PAG_IPS IS

   /**
   * Guarda los permisos de un usuario para una persona juridica
   * @param error Indica si ocurrio un error recuperando la clave del usuario
   * @param nombreRespuesta Indica el nombre del mensaje
   * @param descripcionRespuesta Indica una descripcion de la respuesta
   * @param autoriza Indica si la persona tiene el permiso para autorizar operaciones(A)
   * @param registra Indica si la persona tiene el permiso para registrar operaciones(I)
   * @param consulta Indica si la persona tiene el permiso para registrar consultar()
   */
   TYPE typ_obtenerPermisos IS RECORD(
      error                VARCHAR(1),
      nombreRespuesta      VARCHAR2(15),
      descripcionRespuesta VARCHAR2(200),
      autoriza             BOOLEAN,
      registra             BOOLEAN,
      consulta             BOOLEAN,
      canAutRequeridas     NUMBER);

   v_tip_mensaje        VARCHAR2(10); -- guarda el tipo IAC
   v_can_aut_requeridas NUMBER(5) := 0; -- cantidad de firmas requeridas   
   /** Codigo de respuesta OK generico  */
   MSG_OK           CONSTANT VARCHAR2(30) := 'OP_APROBADA';
   BITACORA_ERROR   CONSTANT VARCHAR2(3) := 'ERR';
   BITACORA_ENTRADA CONSTANT VARCHAR2(3) := 'ENT';
   BITACORA_SALIDA  CONSTANT VARCHAR2(3) := 'SAL';

   MSG_COD_CTA_INVALIDA    CONSTANT VARCHAR(15) := 'COD_CTA_INVALID';
   MSG_COD_CTA_INEXISTENTE CONSTANT VARCHAR(15) := 'COD_CTA_INEXIST';
   MSG_COD_CTA_DUPLICADA   CONSTANT VARCHAR(15) := 'COD_CTA_DUPLIC';
   MSG_COD_TRA_PROHIBIDA   CONSTANT VARCHAR(15) := 'COD_TRA_PROHIB';
   MSG_COD_SAL_INSUF       CONSTANT VARCHAR(15) := 'COD_SAL_INSUF';

   PROCEDURE pr_ins_bitacora(p_cod_ge_pag_sue_ips     IN GE_PAG_SUE_IPS_LOG.NRO_LOTE%TYPE DEFAULT NULL,
                             p_cod_ge_pag_sue_ips_det IN GE_PAG_SUE_IPS_LOG.NRO_ORDEN%TYPE DEFAULT NULL,
                             p_mensaje                IN VARCHAR2);
                             
   PROCEDURE PR_PRO_VALIDACION(p_lote ge_pag_sue_ips.nro_lote%TYPE);

   PROCEDURE PR_PRO_ACREDITACION(p_lote ge_pag_sue_ips.nro_lote%TYPE,
                                 p_tipo varchar2 default null);

   PROCEDURE PR_PRO_CONCILIACION(p_lote ge_pag_sue_ips.nro_lote%TYPE);
   
   PROCEDURE PR_ENV_NOT_PARAMETRO; --BSEVOCORE-426
   
   PROCEDURE PR_PRO_ACR_PENDIENTES; --BSEVOCORE-426
   
   PROCEDURE PR_REP_ACR_PENDIENTES; --BSEVOCORE-426
     
   PROCEDURE PR_PRO_ACREDITACIONES; --BSEVOCORE-461
END PAG_IPS;
/

