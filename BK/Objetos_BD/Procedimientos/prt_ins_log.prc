CREATE OR REPLACE PROCEDURE IT.PRT_INS_LOG( p_log   IN TA_LOGS%ROWTYPE,
                                         p_error IN BOOLEAN DEFAULT TRUE
                                         ) IS
 PRAGMA AUTONOMOUS_TRANSACTION; 
  v_log TA_LOGS%ROWTYPE;
BEGIN
  v_log := p_log;
  
IF p_error THEN
    IF v_log.nro_error IS NULL THEN
        v_log.nro_error := SQLCODE;
        v_log.men_error := SQLERRM;
     END IF;
  END IF;

    insert into ta_logs( nom_proceso,
                       fec_hor_ini,
                       fec_hor_fin,
                       nro_reg,
                       nro_error,
                       men_error,
                       comentario )
               values( v_log.nom_proceso,
                       v_log.fec_hor_ini,
                       sysdate,
                       v_log.nro_reg,
                       v_log.nro_error,
                       v_log.men_error,
                       v_log.comentario );

            COMMIT;

 EXCEPTION -- Dejo como excepción el cod 'original' . Contemplo los casos en los que se esté enviando un error por SQLERRM

    WHEN OTHERS THEN
        ROLLBACK; 

     IF p_error THEN
       v_log.nro_error := SQLCODE;
      v_log.men_error := SQLERRM;
      v_log.comentario := 'FALLO AL REGISTRAR LOG. Error: ' || SQLERRM;
     END IF;

        BEGIN
            
            INSERT INTO ta_logs( nom_proceso, fec_hor_ini, fec_hor_fin, nro_reg, nro_error, men_error, comentario )
            VALUES( v_log.nom_proceso, v_log.fec_hor_ini, SYSDATE, v_log.nro_reg, v_log.nro_error, v_log.men_error, v_log.comentario );
            COMMIT;

        EXCEPTION
            WHEN OTHERS THEN
                NULL; 
        END;
END;