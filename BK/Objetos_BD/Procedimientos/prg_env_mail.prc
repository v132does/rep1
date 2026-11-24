CREATE OR REPLACE PROCEDURE IT.PRG_ENV_MAIL(p_dir_correo_ent IN VARCHAR2,
                                         p_dir_correo     IN VARCHAR2,
                                         p_asunto         IN VARCHAR2,
                                         p_mensaje        IN VARCHAR2)
IS
-- RABP-DI-21-06-2013
-- Invocar paquete de envio de mail desde form
BEGIN
   it_mail.mail(p_dir_correo_ent,
                p_dir_correo,
                p_asunto,
                p_mensaje);
EXCEPTION
   when others then
      RAISE_APPLICATION_ERROR(-20061,'Error al llamar a it_mail '||sqlerrm);
END;
/

