CREATE OR REPLACE PROCEDURE IT.PRG_TRA_ARC_EQUIFAX ( p_tip_archivo IN VARCHAR2,   --tipo de archivo a enviar
                                                  p_mensaje    OUT VARCHAR2,   --mensaje a retornar
                                                  p_generado   OUT VARCHAR2
                                                 ) IS
/* Proceso que permite transferir los archivos generados en la carpeta Ramail */
   v_respuesta          VARCHAR2(4000);
   v_ip                 VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
   v_port               VARCHAR2(100) := '21';
   v_user               VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
   v_pass               VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
   v_repository         VARCHAR2(100) := fug_obt_pardinamico('DIR_AUT_BANCARD');
   v_directorio         VARCHAR2(100) := fug_obt_pardinamico('DIR_GEN_ARC_EQUIFAX');
   v_generado           VARCHAR2(1)   := 'N';

   CURSOR C_ARCHIVOS IS
     SELECT a.val_maximo nom_archivo
       FROM ba_cod_referencias a
      WHERE a.dominio = 'TIP_ARC_EQUIFAX'
        AND a.val_maximo <> p_tip_archivo
        AND EXISTS (SELECT 0
                      FROM ge_equ_datos e
                     WHERE e.tip_proceso = 'M'
                       AND e.nom_archivo = a.val_maximo || '.zip');

PROCEDURE PR_INS_DAT_HIS( P_NOM_ARCHIVO VARCHAR2,
                          P_TIP_ARCHIVO VARCHAR2 ) IS
BEGIN
  BEGIN
    UPDATE ge_equ_datos a
       SET a.estado     = 'N',
           a.comentario = 'Proceso Satisfactorio'
     WHERE a.nom_archivo = p_nom_archivo||'.'||p_tip_archivo
       AND a.tip_proceso = 'M';
  EXCEPTION
    WHEN OTHERS THEN
       raise_application_error(-20002, 'Error al actualizar registro procesado. - '||sqlerrm);
  END;
  BEGIN
      INSERT INTO ge_equ_datos_his (fecha          ,
                                    hora           ,
                                    num_cliente    ,
                                    datos          ,
                                    tip_persona    ,
                                    nom_archivo    ,
                                    tip_operacion  ,
                                    comentario     ,
                                    tip_archivo    ,
                                    dat_base64     ,
                                    tip_proceso    ,
                                    estado         ,
                                    error          )
                             SELECT pag_cal.fu_obt_fec_actual(6),
                                    to_char(sysdate,'HH24:MM:SS'),
                                    c.num_cliente  ,
                                    c.datos        ,
                                    c.tip_persona  ,
                                    c.nom_archivo  ,
                                    c.tip_operacion,
                                    c.comentario   ,
                                    c.tip_archivo  ,
                                    c.dat_base64   ,
                                    c.tip_proceso  ,
                                    'N'            ,
                                    'Proceso Satisfactorio'
                               FROM ge_equ_datos c
                              WHERE c.nom_archivo = p_nom_archivo||'.'||p_tip_archivo
       													AND c.tip_proceso = 'M';
  EXCEPTION
     WHEN OTHERS THEN
       raise_application_error(-20003, 'Error Traslando datos al histórico. '||sqlerrm);
  END;
  DELETE ge_equ_datos x
   WHERE x.nom_archivo = p_nom_archivo||'.'||p_tip_archivo
     AND x.tip_proceso = 'M';
EXCEPTION
	WHEN OTHERS THEN
	  raise_application_error(-20004, 'Error al trasladar al histórico la nutrición. - '||sqlerrm);
END;

BEGIN
   IF p_tip_archivo = 'TODOS' THEN
      FOR i IN C_ARCHIVOS LOOP
          v_respuesta := pa_file_ftp.fu_put_binary(v_ip,
                                                   v_port,
                                                   v_user,
                                                   v_pass,
                                                   v_repository,
                                                   i.nom_archivo||'.zip',
                                                   v_directorio||i.nom_archivo||'.zip');
          IF v_respuesta <> 'OK' THEN
             IF v_respuesta LIKE '%No such file or directory%' THEN --> ORA-22288
                NULL;
             ELSE
                p_mensaje := 'Error al Descargar el Archivo '||i.nom_archivo||' => '||v_respuesta;
                EXIT;
             END IF;
          ELSE
             v_generado := 'S';
             PR_INS_DAT_HIS(i.nom_archivo, 'zip');
          END IF;
       END LOOP;
       IF v_generado = 'S' THEN -->  Se saca del loop para mostrar solo una vez.-
          p_mensaje := 'Archivos generados satisfactoriamente en '||v_directorio;
       END IF;
   ELSE
      v_respuesta := pa_file_ftp.fu_put_binary(v_ip,
                                               v_port,
                                               v_user,
                                               v_pass,
                                               v_repository,
                                               p_tip_archivo||'.zip',
                                               v_directorio||p_tip_archivo||'.zip');
      IF v_respuesta <> 'OK' THEN
         IF v_respuesta LIKE '%No such file or directory%' THEN --> ORA-22288
            p_mensaje := 'Archivo '||p_tip_archivo||'No Generado';
         ELSE
            p_mensaje := 'Error al Descargar el Archivo '||p_tip_archivo||' => '||v_respuesta;
         END IF;
      ELSE
         v_generado := 'S';
         p_mensaje  := 'Archivo '||p_tip_archivo||'Generado Satisfactoriamente en '||v_directorio;
         PR_INS_DAT_HIS(p_tip_archivo, 'zip');
      END IF;
   END IF;
   p_generado := v_generado;
END;
/

