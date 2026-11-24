CREATE OR REPLACE FUNCTION IT.fug_obt_cli_correo_adi(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2 IS
   v_dir_correo ba_personas.dir_correo%TYPE;
BEGIN 
   BEGIN  
      SELECT a.dir_correo
        INTO v_dir_correo
        FROM ba_mails a
       WHERE a.cod_persona = p_cod_persona
         AND a.principal = 'S';
   EXCEPTION
      WHEN no_data_found then
         SELECT a.dir_correo
           INTO v_dir_correo
           FROM ba_mails a
          WHERE a.cod_persona = p_cod_persona
            AND rownum = 1;
   END;
   RETURN v_dir_correo;
EXCEPTION
   WHEN OTHERS THEN
      RETURN NULL;
END;
/

