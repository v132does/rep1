CREATE OR REPLACE PROCEDURE IT.pre_obt_direccion ( p_cod_persona         IN ba_personas.cod_persona%TYPE,
                                                p_dir_particular      OUT ba_direcciones.direccion%TYPE,
                                                p_dir_laboral         OUT ba_direcciones.direccion%TYPE,
                                                p_dir_lab_alternativa OUT ba_direcciones.direccion%TYPE) IS
   CURSOR direcciones IS
      SELECT cod_direccion, substr(direccion, 1, 65) direccion, principal, tipo
        FROM ba_direcciones
       WHERE cod_persona = p_cod_persona
       ORDER BY decode(principal, 'S', 0, 9), cod_direccion;
BEGIN
   FOR d IN direcciones LOOP
      IF d.tipo = 'L' THEN
         IF d.principal = 'S' OR p_dir_laboral IS NULL THEN
            p_dir_laboral := d.direccion;
         ELSIF p_dir_laboral IS NOT NULL AND p_dir_lab_alternativa IS NULL THEN
            p_dir_lab_alternativa := d.direccion;
         END IF;
      ELSIF d.tipo = 'P' THEN
         IF d.principal = 'S' OR p_dir_particular IS NULL THEN
            p_dir_particular := d.direccion;
         END IF;
      END IF;
   END LOOP;
END;
/

