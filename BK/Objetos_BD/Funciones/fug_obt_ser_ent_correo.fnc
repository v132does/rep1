CREATE OR REPLACE FUNCTION IT.fug_obt_ser_ent_correo RETURN VARCHAR2 IS
   v_servidor ge_par_generales.ema_servidor%TYPE;
BEGIN
   SELECT ema_servidor INTO v_servidor FROM ge_par_generales WHERE rownum = 1;

   RETURN v_servidor;
EXCEPTION
   WHEN no_data_found THEN
      raise_application_error(-20000, 'No se encontró registrado el Servidor de Correo.');
   WHEN OTHERS THEN
      raise_application_error(-20000, 'fug_obt_ser_ent_correo ' || SQLERRM);
END;
/

