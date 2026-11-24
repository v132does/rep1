CREATE OR REPLACE PROCEDURE IT.prt_log_pro_imp_archivos( p_ref_archivo ge_archivos.referencia%type ) IS
-- REPORTE DE LOG DE PROCESO DE IMPORTACION DE ARCHIVOS -- DYDMR-5157 -- CN 10/2016 --
  v_nom_proceso ta_logs.nom_proceso%type;
  --
  CURSOR cu_det  IS
    select a.nom_proceso, a.fec_hor_ini, a.fec_hor_fin, 
           replace(a.comentario,chr(10),' - ') comentario,
           replace(a.men_error,chr(10),' - ') men_error
      from ta_logs a
     where a.nom_proceso like '%'||substr(v_nom_proceso,1,22)||'%'
     order by a.fec_insercion, a.comentario, a.nom_proceso;
  --
  v_name             VARCHAR2(128); -- nombre del archivo
  v_flag             BOOLEAN;
  -- Variables de fechas
  v_fecha            VARCHAR2(8);

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(500);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         LONG;
  v_cabecera_mail    LONG;
  v_fin_mail         LONG := ' </table>
                             </i> <br><br> Atentamente,
                              </p>
                              <p><img src="http://www.bbva.com.py/images/logo-bbva.png" alt="Site Logo" />
                            </body>
                          </html>';
  v_detalle_mail     LONG := '';

  v_cabecera         VARCHAR2(32767);
  v_detalle          VARCHAR2(32767);
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;
  
  v_cod_programa     ba_programas.cod_programa%type;
  v_descripcion      ba_programas.descripcion%type;
  v_archivo          ge_archivos.archivo%type;
  v_hor_ini          ta_logs.fec_hor_ini%type;
  v_hor_fin          ta_logs.fec_hor_fin%type;
  v_est_fin          varchar2(30) := 'EXITOSO';
  v_con_error        varchar2(1)  := 'N';
  
BEGIN 
   
   begin
     
     select a.archivo, a.pos_proceso
       into v_archivo, v_nom_proceso 
       from ge_archivos a
      where a.referencia = p_ref_archivo;
      
     v_name := 'LOG_'||v_nom_proceso; -- nombre del archivo

     select a.cod_programa, a.descripcion
       into v_cod_programa, v_descripcion
       from ba_programas a
      where a.cod_programa = v_nom_proceso; 
      
      select min(a.fec_hor_ini) fec_hor_ini, max(a.fec_hor_fin) fec_hor_fin
        into v_hor_ini, v_hor_fin
        from ta_logs a
       where a.nom_proceso like '%'||substr(v_nom_proceso,1,22)||'%';  
      
      begin
      select 'S'
        into v_con_error
        from ta_logs a
       where a.nom_proceso like '%'||substr(v_nom_proceso,1,22)||'%'
         and comentario NOT LIKE '***%***';   
      exception 
        when too_many_rows then
          v_con_error := 'S';
        when others then
          null;
      end;
      if nvl(v_con_error,'N') = 'S' then
        v_est_fin := 'CON ERROR';
      end if;
      v_flag := true;
   exception
     when others then
       v_flag := false;
   end;
 

  if v_flag then 
    v_fecha := to_char(sysdate,'DDMMYYYY');
    -- obtenemos mail de los que van a recibir el reporte
    v_para := fug_obt_pardinamico('ENV_EMA_PRO_TC');
    --
    v_det_error   := null;
    v_hini_mail   := null;
    v_hfin_mail   := null;
    v_asunto      := null;
    v_flag        := FALSE;
   
    -- Empezamos a cargar los datos del mail a enviar
    v_hini_mail := to_char(sysdate,'hh24:mi:ss');
    --
    v_asunto := 'Reporte de LOG del proceso: '|| v_nom_proceso || ', a la fecha: '||v_fecha||'.';

    v_cabecera_mail := '<html>
                    <body>
                           Remitimos el archivo  '||v_name||'_'||v_fecha||'.xls con el log del proceso de importacion del archivo '||v_archivo||', adjunto en el mail.
                    <br><br>
                    </p>
                    <table cellspacing="0"
                            cellpadding="5"
                            border="4">
                    <tr>
                      <td width="80%" bgcolor="B0C4DE"> <b>NOM_PROCESO</b></td>
                      <td width="80%" bgcolor="B0C4DE"> <b>COD_PROGRAMA</b></td>
                      <td width="80%" bgcolor="B0C4DE"> <b>FEC_HOR_INI</b></td>
                      <td width="80%" bgcolor="B0C4DE"> <b>FEC_HOR_FIN</b></td>
                      <td width="80%" bgcolor="B0C4DE"> <b>ESTADO_FINALIZACION</b></td>
                      <td width="80%" bgcolor="B0C4DE"> <b></b></td>
                    </tr>';


      begin
        v_detalle_mail := v_detalle_mail || '<tr>
                         <td width="180%" bgcolor="FFFFFF">'||v_descripcion||'</td>
                         <td width="180%" bgcolor="FFFFFF">'||v_cod_programa||'</td>
                         <td width="180%" bgcolor="FFFFFF">'||to_char(v_hor_ini,'DD/MM/YYYY HH24:MI:SS')||'</td>
                         <td width="180%" bgcolor="FFFFFF">'||to_char(v_hor_fin,'DD/MM/YYYY HH24:MI:SS')||'</td>
                         <td width="180%" bgcolor="FFFFFF">'||v_est_fin||'</td>
                         <td width="180%" bgcolor="E0FFFF"></td>
                        </tr> ';
        v_mje_mail := v_cabecera_mail||v_detalle_mail||v_fin_mail;
      end;

      begin
        --**

        v_conn := it_mail.begin_mail(fug_obt_dir_correo,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,  v_mje_mail,'text/html');

        it_mail.begin_attachment(v_conn,'text/plain',false,v_name||'_'||v_fecha||'.xls');
        --**
          -- Titulo del reporte
          -- Colocar el titulo a los campos
          v_cabecera :=
          'NOM_PROCESO'||CHR(9)||
          'FEC_HOR_INI'||CHR(9)||
          'FEC_HOR_FIN'||CHR(9)||
          'COMENTARIO'||CHR(9)||
          'MEN_ERROR'||CHR(13)||CHR(10) ;

          --** Arma el Archivo Anexo.
          it_mail.write_text(v_conn,v_cabecera);
          --**

          v_detalle := '';
          
          v_flag := FALSE;
          -- detalle del reporte
          FOR REC IN cu_det LOOP
            v_flag := TRUE;
            --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
            v_detalle :=
            to_char(rec.NOM_PROCESO)||chr(9)||
            to_char(rec.FEC_HOR_INI)||chr(9)||
            to_char(rec.FEC_HOR_FIN)||chr(9)||
            to_char(rec.COMENTARIO)||chr(9)||
            to_char(rec.MEN_ERROR)||CHR(13)||CHR(10);
            --Escribir la linea en el archivo
            --**
            it_mail.write_text(v_conn,v_detalle);
            v_detalle := '';
            --**
            EXIT WHEN cu_det%NOTFOUND;
          END LOOP;
        --**
        -- Verificamos si el cursor trajo por lo menos un registro, de ser asi enviamos el mail
        IF v_flag THEN
           it_mail.end_mail(v_conn);
        ELSE
          ROLLBACK;
        END IF;
      --**
    exception
      when utl_smtp.transient_error or utl_smtp.permanent_error then
      begin
        utl_smtp.quit(v_conn);
      exception
      when utl_smtp.transient_error or utl_smtp.permanent_error then
        null;
      end;
      v_det_error := substr(sqlerrm,1,4000);
    end;

    --
    v_hfin_mail := to_char(sysdate,'hh24:mi:ss');
  end if;
  
  -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
  IF v_det_error is not null THEN
      INSERT INTO ge_ra_log_mail
       (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
      VALUES
       (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
      COMMIT;
  END IF;
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error al enviar logs del proceso de importacion de archivos. Ref. '||p_ref_archivo||' - '||sqlerrm);
END;
/

