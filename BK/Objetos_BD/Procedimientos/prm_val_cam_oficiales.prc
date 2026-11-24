create or replace procedure it.prm_val_cam_oficiales is
   
   -- Requerimiento: DYDMR-3261.
   -- Fecha: 15/03/2016.
   
   -- Cursor principal.
   cursor c_cambios is
   select * from tm_ge_clientes;
   
   -- Variables.
   v_existe number(10) := 0;
begin
   --- Proceso principal
   FOR reg IN c_cambios LOOP
      -- Valida que el usuario este marcado como Oficial en la tabla BA_USUARIOS.
      BEGIN
         SELECT 1
           INTO v_existe
           FROM ba_usuarios u
          WHERE u.cod_usuario = reg.cod_usu_oficial
            AND u.oficial = 'S';
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20000,'Oficial no registrado, verifique la planilla: '||reg.cod_usu_oficial);
      END;
      
      -- Verifica que el cliente exista.
      BEGIN
         SELECT 1
           INTO v_existe
           FROM ge_clientes ge
          WHERE ge.cod_persona = reg.cod_persona;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000,'Cliente '||reg.cod_persona||' no registrado');
      END;
   END LOOP;
EXCEPTION
  WHEN OTHERS THEN
     delete tm_ge_clientes;     
     raise_application_error(-20001, ' Error.'|| ' - ' || SQLERRM);   
end prm_val_cam_oficiales;
/

