CREATE OR REPLACE FUNCTION IT.FUE_ENV_TCP_MENSAJES ( p_servidor   IN VARCHAR2,
                                                  p_puerto     IN NUMBER,
                                                  p_tie_espera IN NUMBER,
                                                  p_mensaje    IN LONG,
                                                  p_respuesta  OUT VARCHAR2
                                                )
/* PARAMETROS
*  p_servidor   : direccion ip del servidor
*  p_puerto     : nro. de puerto
*  p_tie_espera : tiempo de espera en segundos
*  p_mensaje    : mensaje a enviar
*  p_respuesta  : valor de retorno
*/
RETURN VARCHAR2 IS
  v_con utl_tcp.connection;
  v_ok  VARCHAR2(1) := 'N';
  v_lon PLS_INTEGER;

  PROCEDURE LP_REG_OPERACION( p_mensaje      IN LONG,
                              p_respuesta    IN VARCHAR2
                            ) is
    PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
     v_respuesta ba_log_mensajeria.respuesta%type;
  BEGIN
     v_respuesta := substr(p_respuesta,1,4000);
     insert into ba_log_mensajeria
       (mensaje, respuesta)
     values
       (p_mensaje, v_respuesta);
     commit;
  EXCEPTION
     WHEN OTHERS THEN
        raise_application_error(-20000,sqlerrm);
  END;
BEGIN
  BEGIN
      v_con := utl_tcp.open_connection(remote_host => p_servidor,
                                       remote_port => p_puerto,
                                       tx_timeout  => p_tie_espera,
                                       charset     => 'US7ASCII');
      v_lon := utl_tcp.write_line(v_con, p_mensaje);
      p_respuesta := utl_tcp.get_line(v_con);
      utl_tcp.close_connection(v_con);
      v_ok := 'S';
    -- p_respuesta:= '00-OK';
    lp_reg_operacion(p_mensaje,p_respuesta);
  EXCEPTION
    WHEN utl_tcp.network_error THEN
      p_respuesta := '01- network_error '||sqlerrm;
      lp_reg_operacion(p_mensaje,p_respuesta);
      utl_tcp.close_connection(v_con);
    WHEN utl_tcp.transfer_timeout THEN
      p_respuesta := '02- Timeout '||sqlerrm;
      lp_reg_operacion(p_mensaje,p_respuesta);
      utl_tcp.close_connection(v_con);
    WHEN OTHERS THEN
      p_respuesta := '03- '||sqlerrm;
      lp_reg_operacion(p_mensaje,p_respuesta);
      utl_tcp.close_connection(v_con);
  END;

  RETURN(v_ok);
END;
/

