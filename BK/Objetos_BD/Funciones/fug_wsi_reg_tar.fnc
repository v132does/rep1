CREATE OR REPLACE FUNCTION IT.fug_wsi_reg_tar RETURN VARCHAR2 IS
  /**
   * Funcion para llamar al WS de Bancard para Regrabaciones de tarjetas agpp737
   * BancardConnector
   * Solo realiza el llamado, verifica todos los registros de la tabla ta_tar_regrabaciones_tmp estado P
   */
  v_result       VARCHAR2(1000);
  v_url          ge_par_dinamicos.val_parametro%TYPE;
  v_resPost      TYP_POSTRESPUESTA;
  v_ws_respuesta paw_json.JSONStructObj;
  v_respuesta    VARCHAR2(32760);
  v_status       VARCHAR2(1000);
  v_data         VARCHAR2(1000);
  v_error     	 VARCHAR2(1000);
BEGIN
  -- http://192.168.253.9:18080/bancardconnect/services/regrabacionTarjeta prd 
  -- http://62.12.240.10:8080/bancardconnect/services/regrabacionTarjeta test 
  v_url        := fug_obt_pardinamico('WSI_REG_TAR_BANCARD', NULL, NULL);
  v_resPost    := fue_env_post(p_parametros => 'N', p_url => v_url);
  v_respuesta  := substr(v_resPost.respuesta,1,4000);
  IF (v_resPost.error = 'N') THEN
    v_ws_respuesta := paw_json.String2JSON(v_resPost.respuesta, '"');
    v_status       := paw_json.getAttrValue(v_ws_respuesta, 'status');
    v_error        := paw_json.getAttrValue(v_ws_respuesta, 'msgError');
    IF v_status = 'OK' THEN
       --Envio sin problemas
       v_result := v_status;
    ELSIF v_status = 'ERR' THEN
       --Rechazado por Bancard
       v_result := v_status||' - '||v_error;
    END IF;
  ELSE
    v_ws_respuesta := paw_json.String2JSON(v_resPost.respuesta, '"');
    v_status       := paw_json.getAttrValue(v_ws_respuesta, 'status');
    v_error        := paw_json.getAttrValue(v_ws_respuesta, 'msgError');
    v_result := v_status||' - '||v_error;
  END IF;
  RETURN(v_result);
EXCEPTION
   WHEN OTHERS THEN
     raise_application_error(-20000, sqlerrm);
END fug_wsi_reg_tar;
/

