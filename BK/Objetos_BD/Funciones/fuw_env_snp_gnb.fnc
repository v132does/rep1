CREATE OR REPLACE FUNCTION IT.fuw_env_snp_gnb(p_nro_transaccion IN ge_movimientos.nro_documento%TYPE,
                                           p_nro_cuenta      IN VARCHAR2,
                                           p_nro_documento   IN VARCHAR2,
                                           p_monto           IN ge_movimientos.monto%TYPE) RETURN VARCHAR2 IS


   v_response     typ_postrespuesta;
   p_headers      typ_listaetiquetavalor := typ_listaetiquetavalor();
   -- 
   v_api_path_gnb ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico( 'V_API_PATH_GNB');
   v_path_gnb     ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico( 'V_GNB_CONF_PATH');
   v_api_key      ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico( 'V_API_KEY');
   v_contenido    ge_par_dinamicos.val_parametro%TYPE;
   v_dat_response VARCHAR2(10000);
   v_ws_respuesta paw_json.JSONStructObj;
   v_retorno      VARCHAR2(2);
   
   PROCEDURE lp_reg_timeout IS
     PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
     INSERT INTO bw_mov_bts
        (nro_documento, fec_valor, nro_cta_credito, cod_mon_credito, mto_credito, estado)
     VALUES
        (p_nro_transaccion, trunc(SYSDATE), p_nro_cuenta, 'XXX', p_monto, 'T');
     COMMIT;
   EXCEPTION
     WHEN OTHERS THEN
       NULL;
   END;
BEGIN
   paw_uti.pr_add_value(p_headers, 'Runes-Api-Key', v_api_key);
   paw_uti.pr_add_value(p_headers, 'Content-Type', 'application/json');
   v_contenido := '{ "transactionId": "'||p_nro_transaccion||'",'||
	                   ' "accountNumber": "'||p_nro_cuenta||'",'||
	                   ' "documentNumber": "'||p_nro_documento||'",'||
	                   ' "amount": '||paw_uti.lf_for_money(p_monto)||' }';
   paw_uti.pr_add_value(p_headers, 'Content-Length', length(v_contenido));
   -- Call the function
   v_response := fue_env_http(v_api_path_gnb||v_path_gnb, 'POST', p_headers, v_contenido);
   
   p_headers.delete;  
   IF v_response.status_code >= 200 AND v_response.status_code < 300 THEN
      v_retorno := 'S';
      v_ws_respuesta := paw_json.String2JSON(v_response.respuesta, '"');
      -- se obtiene el tag "data"
      v_dat_response := paw_json.getAttrValue(v_ws_respuesta, 'data');
      IF v_dat_response IS NULL THEN
         v_retorno := 'N';
      END IF;
      v_ws_respuesta.delete;
   ELSIF v_response.status_code = 504 THEN
      v_retorno := 'S';
      -- TIMEOUT AL LLAMAR A BTS, ASUMIMOS QUE HUBO CREDITO Y SE TARDO EN LEER LA RESPUESTA
      lp_reg_timeout;
   ELSE
      v_retorno := 'N';
   END IF;
   paw_uti.pr_insertarbitacora('11198', 999, p_nro_transaccion, '055',  NULL, 'fuw_env_snp_gnb: ' || v_contenido||', status='||v_response.status_code||', res='||v_response.respuesta, paw_uti.bitacora_error);
   RETURN v_retorno;
EXCEPTION
  WHEN OTHERS THEN
     paw_uti.pr_insertarbitacora('11198', 999, p_nro_transaccion, '055',  NULL, 'fuw_env_snp_gnb: ' || SQLERRM, paw_uti.bitacora_error);   
     RETURN 'N';  
END;
/

