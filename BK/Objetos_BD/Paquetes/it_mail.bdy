CREATE OR REPLACE PACKAGE BODY IT.IT_MAIL IS

   -- Return the next email address in the list of email addresses, separated
   -- by either a "," or a ";".  The format of mailbox may be in one of these:
   --   someone@some-domain
   ----   "Someone at some domain" <someone@some-domain>
   --   Someone at some domain <someone@some-domain>
   FUNCTION get_address(addr_list IN OUT VARCHAR2) RETURN VARCHAR2 IS

      addr VARCHAR2(256);
      i    PLS_INTEGER;

      FUNCTION lookup_unquoted_char
      (
         str  IN VARCHAR2,
         chrs IN VARCHAR2
      ) RETURN PLS_INTEGER AS
         c            VARCHAR2(5);
         i            PLS_INTEGER;
         len          PLS_INTEGER;
         inside_quote BOOLEAN;
      BEGIN
         inside_quote := FALSE;
         i            := 1;
         len          := length(str);
         WHILE (i <= len) LOOP

            c := substr(str, i, 1);

            IF (inside_quote) THEN
               IF (c = '"') THEN
                  inside_quote := FALSE;
               ELSIF (c = '\') THEN
                  i := i + 1; -- Skip the quote character
               END IF;
               GOTO next_char;
            END IF;

            IF (c = '"') THEN
               inside_quote := TRUE;
               GOTO next_char;
            END IF;

            IF (instr(chrs, c) >= 1) THEN
               RETURN i;
            END IF;

            <<next_char>>
            i := i + 1;

         END LOOP;

         RETURN 0;

      END;

   BEGIN

      addr_list := ltrim(addr_list);
      i         := lookup_unquoted_char(addr_list, ',;');
      IF (i >= 1) THEN
         addr      := substr(addr_list, 1, i - 1);
         addr_list := substr(addr_list, i + 1);
      ELSE
         addr      := addr_list;
         addr_list := '';
      END IF;

      i := lookup_unquoted_char(addr, '<');
      IF (i >= 1) THEN
         addr := substr(addr, i + 1);
         i    := instr(addr, '>');
         IF (i >= 1) THEN
            addr := substr(addr, 1, i - 1);
         END IF;
      END IF;

      RETURN addr;
   END;

   -- Write a MIME header
   PROCEDURE write_mime_header
   (
      conn  IN OUT NOCOPY utl_smtp.connection,
      NAME  IN VARCHAR2,
      VALUE IN VARCHAR2
   ) IS
   BEGIN
      utl_smtp.write_data(conn, NAME || ': ' || VALUE || utl_tcp.crlf);
   END;

   -- Mark a message-part boundary.  Set <last> to TRUE for the last boundary.
   PROCEDURE write_boundary
   (
      conn IN OUT NOCOPY utl_smtp.connection,
      LAST IN BOOLEAN DEFAULT FALSE
   ) AS
   BEGIN
      IF (LAST) THEN
         utl_smtp.write_data(conn, last_boundary);
      ELSE
         utl_smtp.write_data(conn, first_boundary);
      END IF;
   END;

   ------------------------------------------------------------------------
   PROCEDURE mail(sender     IN VARCHAR2,
                 recipients IN VARCHAR2,
                 subject    IN VARCHAR2,
                 message    IN VARCHAR2) IS

    conn       utl_smtp.connection;
    v_db_name  VARCHAR2(20);
    v_terminal VARCHAR2(20);
    v_cod_usu  VARCHAR2(10);
    v_error    varchar2(300);

  BEGIN
    -- Tomar las Variables SID Base de Datos y Nombre de Terminal
    SELECT upper(sys_context('USERENV', 'DB_NAME')),
           upper(sys_context('USERENV', 'TERMINAL'))
      INTO v_db_name, v_terminal
      FROM dual;
    v_cod_usu := substr(USER, 1, 10);

    IF v_db_name = fug_obt_pardinamico('BD_PRODUCCION') THEN
      If nvl(fug_obt_pardinamico('GEN_ENV_MAI_HTML'), 'N') = 'N' then
        conn := begin_mail(sender, recipients, subject);
      else
        conn := begin_mail(sender, recipients, subject,'text/html');
      End if;
      write_text(conn, message);
      end_mail(conn);
    ELSE
      -- Si la Base NO es Produccion inserta en la tabla de prueba
      INSERT INTO tm_mails
        (env_por,
         env_para,
         asunto,
         detalles,
         fec_sistema,
         nom_maquina,
         cod_usuario,
         sid_base)
      VALUES
        (sender,
         recipients,
         subject,
         substr(message,1,4000),
         SYSDATE,
         v_terminal,
         v_cod_usu,
         v_db_name);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_error := sqlerrm;
      --insertar log
      INSERT INTO tm_mails
        (env_por, env_para,  asunto, detalles,
         fec_sistema, nom_maquina, cod_usuario, sid_base)
      VALUES
        (sender, recipients, subject, substr('<Error envÃ­o de mail '||v_error||'.> '||message,1,3000),
         SYSDATE, v_terminal, v_cod_usu, v_db_name);

  END;

   /*PROCEDURE mail
   (
      sender     IN VARCHAR2,
      recipients IN VARCHAR2,
      subject    IN VARCHAR2,
      message    IN VARCHAR2
   ) IS

      conn       utl_smtp.connection;
      v_db_name  VARCHAR2(20);
      v_terminal VARCHAR2(20);
      v_cod_usu  VARCHAR2(10);
      PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
      v_ser_env_ema_habilitado varchar2(1) := fug_obt_pardinamico('SER_ENV_EMA_HABILITADO');
      v_ser_env_notificacion varchar2(1) := fug_obt_pardinamico('SER_ENV_EMA_NOTIFICACIONES'); -- DYDMR-14189 NAF 12/2020
   BEGIN
      --  /*
      -- Tomar las Variables SID Base de Datos y Nombre de Terminal
      SELECT upper(sys_context('USERENV', 'DB_NAME')), upper(sys_context('USERENV', 'TERMINAL'))
        INTO v_db_name, v_terminal
        FROM dual;
      v_cod_usu := substr(USER, 1, 10);

      IF ((v_db_name = fug_obt_pardinamico('BD_PRODUCCION')) and (nvl(v_ser_env_ema_habilitado,'S') = 'S')) THEN
         --v_ser_env_ema_habilitado: Agregado para posibilitar la deshabilitacion del servicio--
         --cuando este esta abajo--
         -- Si la Base es Produccion envia mail
         IF nvl(v_ser_env_notificacion,'N') = 'S' then
             -- DYDMR-14189 NAF 12/2020
             prg_ins_aut_notificacion(trunc(sysdate),
                                      sender,
                                      recipients,
                                      subject,
                                      message,
                                      'IT_MAIL',
                                      'NOTIT_MAIL');
         ELSE
             conn := begin_mail(sender, recipients, subject);
             write_text(conn, message);
             end_mail(conn);
         END IF;
      ELSE
         -- Si la Base NO es Produccion inserta en la tabla de prueba
         INSERT INTO tm_mails
            (env_por, env_para, asunto, detalles, fec_sistema, nom_maquina, cod_usuario, sid_base)
         VALUES
            (sender, recipients, subject, message, SYSDATE, v_terminal, v_cod_usu, v_db_name);
         COMMIT;
      END IF;
      --*/
      --null;
   /*EXCEPTION
      WHEN OTHERS THEN
         end_session(conn);
         --null;
   END;*/
   ------------------------------------------------------------------------
   PROCEDURE mail_attach
   (
      sender     IN VARCHAR2,
      recipients IN VARCHAR2,
      subject    IN VARCHAR2,
      message    IN VARCHAR2,
      data       IN CLOB,
      filename   IN VARCHAR2
   ) IS

      conn       utl_smtp.connection;
      v_db_name  VARCHAR2(20);
      v_terminal VARCHAR2(20);
      v_cod_usu  VARCHAR2(10);
      PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
      v_cant NUMBER(18) := 1; -- Contador
      v_max  NUMBER(18) := 4000; -- Tamaño Máximo
      v_tot  NUMBER(18); -- Tamaño total de la Variable Data
      v_ser_env_ema_habilitado varchar2(1) := fug_obt_pardinamico('SER_ENV_EMA_HABILITADO');
   BEGIN
      -- Tomar las Variables SID Base de Datos y Nombre de Terminal
      SELECT upper(sys_context('USERENV', 'DB_NAME')), upper(sys_context('USERENV', 'TERMINAL'))
        INTO v_db_name, v_terminal
        FROM dual;
      v_cod_usu := substr(USER, 1, 10);

      IF ((v_db_name = fug_obt_pardinamico('BD_PRODUCCION')) and (nvl(v_ser_env_ema_habilitado,'S') = 'S')) THEN
         --v_ser_env_ema_habilitado: Agregado para posibilitar la deshabilitacion del servicio--
         --cuando este esta abajo--
         -- Si la Base es Produccion (ITBANK) envia mail
         conn := begin_mail(sender, recipients, subject, it_mail.multipart_mime_type);
         --
         attach_text(conn, message, 'text/plain');
         --
         v_tot := length(data);
         IF v_tot > v_max THEN
            begin_attachment(conn, 'text/plain', FALSE, filename);
            LOOP
               -- Si es el último bloque de Datos
               IF v_cant + v_max >= v_tot THEN
                  write_text(conn, substr(data, v_cant));
                  end_attachment(conn, TRUE);
                  EXIT;
               ELSE
                  write_text(conn, substr(data, v_cant, v_max));
               END IF;
               EXIT WHEN v_cant = v_tot;
               v_cant := v_cant + v_max;
            END LOOP;
         ELSE
            attach_text(conn, data, 'text/plain', FALSE, filename, TRUE);
         END IF;
         --
         end_mail(conn);
      ELSE
         -- Si la Base NO es Produccion inserta en la tabla de prueba
         INSERT INTO tm_mails
            (env_por, env_para, asunto, detalles, fec_sistema, nom_maquina, cod_usuario, sid_base)
         VALUES
            (sender, recipients, subject, message, SYSDATE, v_terminal, v_cod_usu, v_db_name);
         COMMIT;
      END IF;
   END;

   -- FMM 25/03/2014 - Nuevo procedimiento para envio de mail con excel adjunto
   PROCEDURE mail_attach_xls
   (
      sender     IN VARCHAR2,
      recipients IN VARCHAR2,
      subject    IN VARCHAR2,
      message    IN VARCHAR2,
      data       IN CLOB,
      filename   IN VARCHAR2
   ) IS

      conn       utl_smtp.connection;
      v_db_name  VARCHAR2(20);
      v_terminal VARCHAR2(20);
      v_cod_usu  VARCHAR2(10);
      PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
      v_cant NUMBER(18) := 1; -- Contador
      v_max  NUMBER(18) := 4000; -- Tamaño Máximo
      v_tot  NUMBER(18); -- Tamaño total de la Variable Data
      v_ser_env_ema_habilitado varchar2(1) := fug_obt_pardinamico('SER_ENV_EMA_HABILITADO');
   BEGIN
      -- Tomar las Variables SID Base de Datos y Nombre de Terminal
      SELECT upper(sys_context('USERENV', 'DB_NAME')), upper(sys_context('USERENV', 'TERMINAL'))
        INTO v_db_name, v_terminal
        FROM dual;
      v_cod_usu := substr(USER, 1, 10);

      IF ((v_db_name = fug_obt_pardinamico('BD_PRODUCCION')) and (nvl(v_ser_env_ema_habilitado,'S') = 'S')) THEN
         --v_ser_env_ema_habilitado: Agregado para posibilitar la deshabilitacion del servicio--
         --cuando este esta abajo--
         -- Si la Base es Produccion (ITBANK) envia mail
         conn := begin_mail(sender, recipients, subject, it_mail.multipart_mime_type);
         --
         attach_text(conn, message, 'text/plain');
         --
         v_tot := length(data);
         IF v_tot > v_max THEN
            begin_attachment(conn, 'application/vnd.ms-excel', FALSE, filename);
         --Esta linea es para adjuntar con word
        --  begin_attachment(conn, 'application/msword'/*'application/vnd.ms-word'*/, FALSE, filename);

            LOOP
               -- Si es el último bloque de Datos
               IF v_cant + v_max >= v_tot THEN
                  write_text(conn, substr(data, v_cant));
                  end_attachment(conn, TRUE);
                  EXIT;
               ELSE
                  write_text(conn, substr(data, v_cant, v_max));
               END IF;
               EXIT WHEN v_cant = v_tot;
               v_cant := v_cant + v_max;
            END LOOP;
         ELSE
            attach_text(conn, data, 'application/vnd.ms-excel', FALSE, filename, TRUE);
         END IF;
         --
         end_mail(conn);
      ELSE
         -- Si la Base NO es Produccion inserta en la tabla de prueba
         INSERT INTO tm_mails
            (env_por, env_para, asunto, detalles, fec_sistema, nom_maquina, cod_usuario, sid_base)
         VALUES
            (sender, recipients, subject, message, SYSDATE, v_terminal, v_cod_usu, v_db_name);
         COMMIT;
      END IF;
   END;

   PROCEDURE mail_attach_blob
   (
      sender       IN VARCHAR2,
      recipients   IN VARCHAR2,
      subject      IN VARCHAR2,
      message      IN VARCHAR2,
      data         IN BLOB,
      mime_text    IN VARCHAR2,
      mime_attach  IN VARCHAR2,
      filename     IN VARCHAR2
   ) IS

      conn       utl_smtp.connection;
      v_db_name  VARCHAR2(20);
      v_terminal VARCHAR2(20);
      v_cod_usu  VARCHAR2(10);
      PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
      v_step NUMBER := 12000; -- multiplo de 3 no mayor a 24573
      v_max  NUMBER(18) := 4000; -- Tamaño Máximo
      v_tot  NUMBER(18); -- Tamaño total de la Variable Data
      v_ser_env_ema_habilitado varchar2(1) := fug_obt_pardinamico('SER_ENV_EMA_HABILITADO');
   BEGIN
      -- Tomar las Variables SID Base de Datos y Nombre de Terminal
      SELECT upper(sys_context('USERENV', 'DB_NAME')), upper(sys_context('USERENV', 'TERMINAL'))
        INTO v_db_name, v_terminal
        FROM dual;
      v_cod_usu := substr(USER, 1, 10);

      IF ((v_db_name = fug_obt_pardinamico('BD_PRODUCCION')) and (nvl(v_ser_env_ema_habilitado,'S') = 'S')) THEN
         --v_ser_env_ema_habilitado: Agregado para posibilitar la deshabilitacion del servicio--
         --cuando este esta abajo--
         -- Si la Base es Produccion (ITBANK) envia mail
         conn := begin_mail(sender, recipients, subject, it_mail.multipart_mime_type);
         --
         attach_text(conn, message, mime_text);
         --
         v_tot := dbms_lob.getlength(data);
         IF v_tot > v_max THEN
            begin_attachment(conn, mime_attach, FALSE, filename, 'base64');

            FOR i IN 0 .. trunc((v_tot - 1 ) / v_step) LOOP
               write_text(conn,
               utl_raw.cast_to_varchar2(utl_encode.base64_encode(dbms_lob.substr(data, v_step, i * v_step + 1))));
            END LOOP;
            end_attachment(conn);
         END IF;
         --
         end_mail(conn);
      ELSE
         -- Si la Base NO es Produccion inserta en la tabla de prueba
         INSERT INTO tm_mails
            (env_por, env_para, asunto, detalles, fec_sistema, nom_maquina, cod_usuario, sid_base)
         VALUES
            (sender, recipients, subject, message, SYSDATE, v_terminal, v_cod_usu, v_db_name);
         COMMIT;
      END IF;
   END;


   FUNCTION begin_mail
   (
      sender     IN VARCHAR2,
      recipients IN VARCHAR2,
      subject    IN VARCHAR2,
      mime_type  IN VARCHAR2 DEFAULT 'text/plain',
      priority   IN PLS_INTEGER DEFAULT NULL
   ) RETURN utl_smtp.connection IS
      v_db_name  VARCHAR2(20);
      v_terminal VARCHAR2(20);
      conn utl_smtp.connection;
      v_ser_env_ema_habilitado varchar2(1) := fug_obt_pardinamico('SER_ENV_EMA_HABILITADO');
   BEGIN
      -- PCCDEEVO-993: Validar el envio de mail en caso de que la base sea de producción y el esté habilitado para enviar
      SELECT upper(sys_context('USERENV', 'DB_NAME')), upper(sys_context('USERENV', 'TERMINAL'))
      INTO v_db_name, v_terminal
      FROM dual;
      
      IF ((v_db_name = fug_obt_pardinamico('BD_PRODUCCION')) and (nvl(v_ser_env_ema_habilitado,'S') = 'S')) THEN
         -- Si la Base es Produccion envia mail
         conn := begin_session;
         begin_mail_in_session(conn, sender, recipients, subject, mime_type, priority);
      ELSE
        -- Si la Base NO es Produccion inserta en la tabla de prueba
         INSERT INTO tm_mails
            (env_por, env_para, asunto, detalles, fec_sistema, nom_maquina, cod_usuario, sid_base)
         VALUES
            (sender, recipients, subject, NULL, SYSDATE, v_terminal, USER, v_db_name);
         COMMIT;
      END IF;         
      RETURN conn;
   END;

   ------------------------------------------------------------------------
   PROCEDURE write_text
   (
      conn    IN OUT NOCOPY utl_smtp.connection,
      message IN VARCHAR2
   ) IS
      v_db_name  VARCHAR2(20);
      v_terminal VARCHAR2(20);
     v_ser_env_ema_habilitado varchar2(1) := fug_obt_pardinamico('SER_ENV_EMA_HABILITADO');
   BEGIN
      -- PCCDEEVO-993: Validar el envio de mail en caso de que la base sea de producción y el esté habilitado para enviar
      SELECT upper(sys_context('USERENV', 'DB_NAME')), upper(sys_context('USERENV', 'TERMINAL'))
      INTO v_db_name, v_terminal
      FROM dual;
      
      IF ((v_db_name = fug_obt_pardinamico('BD_PRODUCCION')) and (nvl(v_ser_env_ema_habilitado,'S') = 'S')) THEN
                     utl_smtp.write_data(conn, message);      
      END IF;         
   END;

   ------------------------------------------------------------------------
   PROCEDURE write_mb_text
   (
      conn    IN OUT NOCOPY utl_smtp.connection,
      message IN VARCHAR2
   ) IS
   BEGIN
      utl_smtp.write_raw_data(conn, utl_raw.cast_to_raw(message));
   END;

   ------------------------------------------------------------------------
   PROCEDURE write_raw
   (
      conn    IN OUT NOCOPY utl_smtp.connection,
      message IN RAW
   ) IS
   BEGIN
      utl_smtp.write_raw_data(conn, message);
   END;

   ------------------------------------------------------------------------
   PROCEDURE attach_text
   (
      conn      IN OUT NOCOPY utl_smtp.connection,
      data      IN VARCHAR2,
      mime_type IN VARCHAR2 DEFAULT 'text/plain',
      inline    IN BOOLEAN DEFAULT TRUE,
      filename  IN VARCHAR2 DEFAULT NULL,
      LAST      IN BOOLEAN DEFAULT FALSE
   ) IS
   BEGIN
      begin_attachment(conn, mime_type, inline, filename);
      write_text(conn, data);
      end_attachment(conn, LAST);
   END;

   ------------------------------------------------------------------------
   PROCEDURE attach_base64
   (
      conn      IN OUT NOCOPY utl_smtp.connection,
      data      IN RAW,
      mime_type IN VARCHAR2 DEFAULT 'application/octet',
      inline    IN BOOLEAN DEFAULT TRUE,
      filename  IN VARCHAR2 DEFAULT NULL,
      LAST      IN BOOLEAN DEFAULT FALSE
   ) IS
      i   PLS_INTEGER;
      len PLS_INTEGER;
   BEGIN

      begin_attachment(conn, mime_type, inline, filename, 'base64');

      -- Split the Base64-encoded attachment into multiple lines
      i   := 1;
      len := utl_raw.length(data);
      WHILE (i < len) LOOP
         IF (i + max_base64_line_width < len) THEN
            -- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
            -- After upgrade to Oracle 9i, replace it_base64.encode with the
            -- native utl_encode.base64_encode for better performance:
            --
            --   utl_smtp.write_raw_data(conn,
            --     utl_encode.base64_encode(utl_raw.substr(data, i,
            --     MAX_BASE64_LINE_WIDTH)));
            --
            -- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
            utl_smtp.write_data(conn,
                                it_base64.encode(utl_raw.substr(data, i, max_base64_line_width)));
         ELSE
            -- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
            -- After upgrade to Oracle 9i, replace it_base64.encode with the
            -- native utl_encode.base64_encode for better performance:
            --
            --   utl_smtp.write_raw_data(conn,
            --     utl_encode.base64_encode(utl_raw.substr(data, i)));
            --
            -- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
            utl_smtp.write_data(conn, it_base64.encode(utl_raw.substr(data, i)));
         END IF;
         utl_smtp.write_data(conn, utl_tcp.crlf);
         i := i + max_base64_line_width;
      END LOOP;

      end_attachment(conn, LAST);

   END;

   ------------------------------------------------------------------------
   PROCEDURE begin_attachment
   (
      conn         IN OUT NOCOPY utl_smtp.connection,
      mime_type    IN VARCHAR2 DEFAULT 'text/plain',
      inline       IN BOOLEAN DEFAULT TRUE,
      filename     IN VARCHAR2 DEFAULT NULL,
      transfer_enc IN VARCHAR2 DEFAULT NULL
   ) IS
   BEGIN
      write_boundary(conn);
      write_mime_header(conn, 'Content-Type', mime_type);

      IF (filename IS NOT NULL) THEN
         IF (inline) THEN
            write_mime_header(conn, 'Content-Disposition', 'inline; filename="' || filename || '"');
         ELSE
            write_mime_header(conn, 'Content-Disposition',
                              'attachment; filename="' || filename || '"');
         END IF;
      END IF;

      IF (transfer_enc IS NOT NULL) THEN
         write_mime_header(conn, 'Content-Transfer-Encoding', transfer_enc);
      END IF;

      utl_smtp.write_data(conn, utl_tcp.crlf);
   END;

   ------------------------------------------------------------------------
   PROCEDURE end_attachment
   (
      conn IN OUT NOCOPY utl_smtp.connection,
      LAST IN BOOLEAN DEFAULT FALSE
   ) IS
   BEGIN
      utl_smtp.write_data(conn, utl_tcp.crlf);
      IF (LAST) THEN
         write_boundary(conn, LAST);
      END IF;
   END;

   ------------------------------------------------------------------------
PROCEDURE end_mail(conn IN OUT NOCOPY utl_smtp.connection) IS
      v_db_name  VARCHAR2(20);
      v_terminal VARCHAR2(20);
      v_ser_env_ema_habilitado varchar2(1) := fug_obt_pardinamico('SER_ENV_EMA_HABILITADO');
   BEGIN
      -- PCCDEEVO-993: Validar el envio de mail en caso de que la base sea de producción y el esté habilitado para enviar
      SELECT upper(sys_context('USERENV', 'DB_NAME')), upper(sys_context('USERENV', 'TERMINAL'))
      INTO v_db_name, v_terminal
      FROM dual;
      
      IF ((v_db_name = fug_obt_pardinamico('BD_PRODUCCION')) and (nvl(v_ser_env_ema_habilitado,'S') = 'S')) THEN           
         end_mail_in_session(conn);
         end_session(conn);       	  
      END IF;         
   END;  

   ------------------------------------------------------------------------
   FUNCTION begin_session RETURN utl_smtp.connection IS
      conn utl_smtp.connection;
   BEGIN
      -- open SMTP connection
      conn := utl_smtp.open_connection(smtp_host, smtp_port);
      utl_smtp.helo(conn, smtp_domain);
      RETURN conn;
   END;

   ------------------------------------------------------------------------
   PROCEDURE begin_mail_in_session
   (
      conn       IN OUT NOCOPY utl_smtp.connection,
      sender     IN VARCHAR2,
      recipients IN VARCHAR2,
      subject    IN VARCHAR2,
      mime_type  IN VARCHAR2 DEFAULT 'text/plain',
      priority   IN PLS_INTEGER DEFAULT NULL
   ) IS
      my_recipients VARCHAR2(32767) := recipients;
      my_sender     VARCHAR2(32767) := sender;
      v_sender      VARCHAR2(32767) := sender;
      v_dominio     varchar2(100) := fug_obt_pardinamico('DOM_SENDER');
      v_dom_sender  varchar2(100);
   BEGIN
     v_sender := trim(v_sender);
     v_dom_sender := trim(substr(v_sender,instr(v_sender,'@')+1,length(v_sender)));
     
     if v_dom_sender != v_dominio then
       v_sender := substr(v_sender,1, instr(v_sender,'@'))||v_dominio;
       my_sender := v_sender;
     end if;
     

      -- Specify sender's address (our server allows bogus address
      -- as long as it is a full email address (xxx@yyy.com).
      utl_smtp.mail(conn, get_address(v_sender));

      -- Specify recipient(s) of the email.
      WHILE (my_recipients IS NOT NULL) LOOP
         utl_smtp.rcpt(conn, get_address(my_recipients));
      END LOOP;

      -- Start body of email
      utl_smtp.open_data(conn);

      -- Set "From" MIME header
      write_mime_header(conn, 'From', my_sender);

      -- Set "To" MIME header
      write_mime_header(conn, 'To', recipients);

      -- Set "Subject" MIME header
      write_mime_header(conn, 'Subject', subject);

      -- Set "Content-Type" MIME header
      write_mime_header(conn, 'Content-Type', mime_type);

      -- Set "X-Mailer" MIME header
      write_mime_header(conn, 'X-Mailer', mailer_id);

      -- Set priority:
      --   High      Normal       Low
      --   1     2     3     4     5
      IF (priority IS NOT NULL) THEN
         write_mime_header(conn, 'X-Priority', priority);
      END IF;

      -- Send an empty line to denotes end of MIME headers and
      -- beginning of message body.
      utl_smtp.write_data(conn, utl_tcp.crlf);

      IF (mime_type LIKE 'multipart/mixed%') THEN
         write_text(conn, 'This is a multi-part message in MIME format.' || utl_tcp.crlf);
      END IF;

   END;

   ------------------------------------------------------------------------
   PROCEDURE end_mail_in_session(conn IN OUT NOCOPY utl_smtp.connection) IS
   BEGIN
      utl_smtp.close_data(conn);
   END;

   ------------------------------------------------------------------------
   PROCEDURE end_session(conn IN OUT NOCOPY utl_smtp.connection) IS
   BEGIN
      utl_smtp.quit(conn);
   END;

END;
/

