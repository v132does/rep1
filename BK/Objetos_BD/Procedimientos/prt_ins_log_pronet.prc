CREATE OR REPLACE PROCEDURE IT.PRT_INS_LOG_PRONET( p_log   TA_LOG_PRONET%ROWTYPE,
                                               p_error BOOLEAN DEFAULT TRUE
                                             ) IS
-- 12/07/2013-DI-RABP:
-- Procedimiento para la insercion de datos a la tabla de log de errores de Pronet - TA_LOG_PRONET

  v_log TA_LOG_PRONET%ROWTYPE;
BEGIN
  v_log := p_log;
  IF p_error THEN
    v_log.nro_error := sqlcode;
    v_log.men_error := sqlerrm;
  END IF;
  insert into TA_LOG_PRONET( fec_envio,
                             hor_envio,
                             nom_proceso,
                             nom_archivo,
                             nro_lote,
                             nro_boleta,
                             nro_tarjeta,
                             comentario,
                             nro_linea,
                             nro_error,
                             men_error)
                     values( v_log.fec_envio,
                             v_log.hor_envio,
                             v_log.nom_proceso,
                             v_log.nom_archivo,
                             v_log.nro_lote,
                             v_log.nro_boleta,
                             v_log.nro_tarjeta,
                             v_log.comentario,
                             v_log.nro_linea,
                             v_log.nro_error,
                             v_log.men_error );
  COMMIT;                           
	EXCEPTION
  when others then
    NULL;
END;
/

