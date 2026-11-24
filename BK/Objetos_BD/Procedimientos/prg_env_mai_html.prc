CREATE OR REPLACE PROCEDURE IT.PRG_ENV_MAI_HTML(p_dir_correo_ent IN VARCHAR2,
                                                   p_dir_correo     IN VARCHAR2,
                                                   p_asunto         IN VARCHAR2,
                                                   p_mensaje        IN VARCHAR2,
                                                   p_mime_type      IN VARCHAR2)
IS
   conn   utl_smtp.connection;
BEGIN
   conn := it_mail.begin_mail(p_dir_correo_ent, p_dir_correo, p_asunto, p_mime_type);
   it_mail.write_text(conn, p_mensaje);
   it_mail.end_mail(conn);
EXCEPTION
   WHEN OTHERS THEN
      it_mail.end_session(conn);
      RAISE_APPLICATION_ERROR(-20061,'Error al llamar a it_mail ' || sqlerrm);
END;
/

