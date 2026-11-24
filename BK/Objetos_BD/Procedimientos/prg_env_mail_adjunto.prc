CREATE OR REPLACE PROCEDURE IT.PRG_ENV_MAIL_ADJUNTO
   (p_remitente       in varchar2,
    p_destinatario    in varchar2,
    p_asunto          in varchar2,
    p_html            in long default null,
    p_imagen          in blob default null,
    p_nom_archivo     in varchar2 default null
 )
/*11/05/2015 WA: Procedimiento creado para envío de mail, con adjunto
recibe un tipo de dato LOB, Sino recibe adjunto envía solamente el mail.
*/
is
    l_boundary         varchar2(255) default 'a1b2c3d4e3f2g1';
    l_body_html        clob := empty_clob; --This LOB will be the email message
    l_offset           number;
    l_ammount          number;
    l_temp             varchar2(32767) default null;
    l_step             PLS_INTEGER  := 12000; -- A multiple of 3 and <= 24573
    crlf               varchar2(2) := CHR(13) || CHR(10);
    v_length           integer := 0;
    conn      utl_smtp.connection;
    smtp_host          VARCHAR2(50) := 'exchange.gnbparaguay.local';
    v_html            long;
begin

conn := utl_smtp.open_connection(smtp_host, 25);
UTL_SMTP.helo (conn, smtp_host);
UTL_SMTP.mail (conn, p_remitente);
UTL_SMTP.rcpt (conn, p_destinatario);
--  Define the Header
    l_temp := l_temp || 'MIME-Version: 1.0' || crlf;
    l_temp := l_temp || 'To: '       || p_destinatario      || crlf;
    l_temp := l_temp || 'From: '     || p_remitente      || crlf;
    l_temp := l_temp || 'Subject: '  || p_asunto  || crlf;
    l_temp := l_temp || 'Content-Type: multipart/mixed; boundary=' ||
                         chr(34) || l_boundary ||  chr(34) || crlf;
    ----------------------------------------------------
    -- Write the headers
    dbms_lob.createtemporary( l_body_html, false, 10 );
    dbms_lob.write(l_body_html,length(l_temp),1,l_temp);

    ----------------------------------------------------
    -- Write the HTML boundary
    -- Identify the content type as text/html
    -- Determine the offset (initially it's 1)
    -- Write out
    l_temp   := crlf || crlf ||'--' || l_boundary || crlf;
    l_temp   := l_temp || 'content-type: text/html;' || crlf || crlf;
    l_offset := dbms_lob.getlength(l_body_html) + 1;
    dbms_lob.write(l_body_html,length(l_temp),l_offset,l_temp);

    ----------------------------------------------------
    -- Write the HTML portion of the message
   if p_html is not null then
         v_html := v_html||p_html;
         l_offset := dbms_lob.getlength(l_body_html) + 1;
       dbms_lob.write(l_body_html,length(v_html),l_offset,v_html);
   end if;
    ----------------------------------------------------
    -- Send the email body in 1900 byte chunks to UTL_SMTP
    l_offset  := 1;
    l_ammount := 1900;
    utl_smtp.open_data(conn);
    while l_offset < dbms_lob.getlength(l_body_html) loop
        utl_smtp.write_data(conn,
                            dbms_lob.substr(l_body_html,l_ammount,l_offset));
        l_offset  := l_offset + l_ammount ;
        l_ammount := least(1900,dbms_lob.getlength(l_body_html) - l_ammount);
    end loop;
    --The following crlf is necessary after the body is written
    utl_smtp.write_data(conn, crlf);
       -- Si se envia la imagen , sino a adjunta
       v_length := dbms_lob.getlength(p_imagen);
       if nvl(v_length,0)> 0 then
             -- Write out the boundary
              UTL_SMTP.write_data(conn, '--' || l_boundary || crlf);
              -- Write out the attachment metadata
              UTL_SMTP.write_data(conn, 'Content-Type:multipart/mixed' ||
                          '; name=' || chr(34) || p_nom_archivo || chr(34) || crlf);
              UTL_SMTP.write_data(conn, 'Content-Transfer-Encoding: base64' ||
                          crlf);
              UTL_SMTP.write_data(conn, 'Content-Disposition: attachment;
                          filename="' || p_nom_archivo || '"' || crlf || crlf);
              --Write out the attachment blob in portions of l_step length
              FOR k IN 0 .. TRUNC((DBMS_LOB.getlength(p_imagen) - 1 )/l_step)
                LOOP
                  UTL_SMTP.write_data(conn, UTL_RAW.cast_to_varchar2
                    (UTL_ENCODE.base64_encode(DBMS_LOB.substr(p_imagen,
                        l_step, k * l_step + 1))));
                END LOOP;
        end if;
        UTL_SMTP.write_data(conn, crlf);
    ----------------------------------------------------
    -- Write the final html boundary
    utl_smtp.write_data(conn,
                        crlf || '--' || l_boundary || '--' || crlf);
    ----------------------------------------------------
    -- Close the connection and end
    utl_smtp.close_data(conn);
    utl_smtp.quit( conn );
    dbms_lob.freetemporary(l_body_html);
EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001,'Error en envío adj.PROC:' || SQLERRM);
         utl_smtp.quit(conn);
END;
/

