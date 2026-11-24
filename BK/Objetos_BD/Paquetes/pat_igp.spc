create or replace package it.pat_igp is
  v_cod_mon_local       ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_pro_correcto        number := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'),
                                      0);
  v_err_sql             number := nvl(fug_obt_pardinamico('COD_ERR_SQL'),
                                      999);
  v_cod_msg_exito       number := nvl(fug_obt_pardinamico('COD_MSG_EXITO'),
                                      200);
  v_ent_global          ah_tar_debitos.cod_ent_procesadora%type := fug_obt_pardinamico('COD_ENT_GLOBAL');
  v_cod_tar_deb_virtual ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('COD_TAR_DEB_VIRTUAL'),
                                                                   1);
  v_cod_tar_deb_fisica  ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('COD_TAR_DEB_FISICA'),
                                                                   1);

  /* procedimiento que inserta registros en el log */
  procedure PR_INS_LOG(p_log   in TA_LOGS_GP%ROWTYPE,
                       p_error IN BOOLEAN DEFAULT TRUE);
  /* Inicializa registros la tabla TA_LOGS_GP correspondiente a la fecha y procedimiento ejecutado */
  PROCEDURE PR_BOR_LOG(p_fecha       in ta_logs_gp.fec_insercion%type,
                       p_nom_proceso in ta_logs_gp.nom_proceso%type);
  /* Verifica la existencia de errores en el momento de la ejecucion */
  PROCEDURE PR_VER_LOG(p_fecha       in ta_logs_gp.fec_insercion%type,
                       p_nom_proceso in ta_logs_gp.nom_proceso%type);
  /* Verifica si corresponde fecha de cierre */
  FUNCTION FU_VER_FEC_CIERRE RETURN varchar2;
  /*Recibe un dato CLOB y retorna ese mismo dato codificado en base64 en CLOB*/
  FUNCTION FU_CON_B64_CLOB(a_input in CLOB) return CLOB;
  /*Recibe un dato VARCHAR2 y retorna ese mismo dato codificado en base64 en VARCHAR2*/
  FUNCTION FU_CON_B64_TEXT(a_input in varchar2) return varchar2;
  /*Interfaz para llamada a servicio utilizando como content un dato tipo clob*/
  procedure PR_WS_CONECTOR_CLOB(p_content     clob, -- estructura json formato clob
                                p_url         in varchar2, -- url para utilizar si es alta de cuenta o cambio estado
                                p_nro_cta     in varchar2, -- cuando es cambio de estado se requiere el nro de cuenta
                                p_cod_persona in varchar2, -- cod persona del cliente
                                p_accion      in varchar2, -- si es cambio de estado o alta
                                p_metodo      in varchar2, -- es el tipo de metodo PUT, POST, GET
                                p_cod_error   out number,
                                p_men_error   out varchar2);

  /* Devuelve la siguiente fecha de cierre de la procesadora en el mes/año indicado */
   FUNCTION FU_OBT_SIG_FEC_CIERRE
   (
      p_cod_procesadora IN NUMBER,
      p_cod_modalidad   IN NUMBER DEFAULT NULL,
      p_cod_tip_cierre  IN NUMBER DEFAULT 4
   ) RETURN DATE;
  /* Devuelve la fecha de cierre < a la actual de la procesadora en el mes/año indicado */
   FUNCTION FU_OBT_FEC_CIERRE
   (
      p_cod_procesadora IN NUMBER,
      p_cod_modalidad   IN NUMBER DEFAULT NULL,
      p_cod_tip_cierre  IN NUMBER DEFAULT 4,
      p_can_men_dias    IN NUMBER DEFAULT 0
   ) RETURN DATE;

   /* Devuelve la fecha de vencimiento de la procesadora en el mes/año indicado */
   FUNCTION FU_OBT_FEC_VENCIMIENTO
   (
      p_cod_procesadora IN NUMBER,
      p_cod_modalidad   IN NUMBER DEFAULT NULL,
      p_cod_tip_cierre  IN NUMBER DEFAULT 1
   ) RETURN DATE;

end pat_igp;
/
