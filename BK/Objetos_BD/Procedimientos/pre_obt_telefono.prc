CREATE OR REPLACE PROCEDURE IT.pre_obt_telefono ( p_cod_persona         IN ba_personas.cod_persona%TYPE,
                                               p_tel_particular      OUT co_inf_cob_personas.tel_particular%TYPE,
                                               p_tel_laboral         OUT co_inf_cob_personas.tel_laboral%TYPE,
                                               p_tel_lab_alternativo OUT co_inf_cob_personas.tel_lab_alternativo%TYPE ) IS
   CURSOR telefonos IS
      SELECT substr(decode(area, NULL, NULL, '(' || area || ') ') || telefono ||
                    decode(interno, NULL, NULL, '-' || interno), 1, 20) telefono,
             principal,
             tipo
        FROM ba_telefonos
       WHERE cod_persona = p_cod_persona
       ORDER BY decode(principal, 'S', 0, 9), cod_telefono;
BEGIN
   FOR d IN telefonos LOOP
      IF d.tipo = 'L' THEN
         IF d.principal = 'S' OR p_tel_laboral IS NULL THEN
            p_tel_laboral := d.telefono;
         ELSIF p_tel_laboral IS NOT NULL AND p_tel_lab_alternativo IS NULL THEN
            p_tel_lab_alternativo := d.telefono;
         END IF;
      ELSIF d.tipo = 'P' THEN
         IF d.principal = 'S' OR p_tel_particular IS NULL THEN
            p_tel_particular := d.telefono;
         END IF;
      ELSIF d.tipo = 'O' THEN
         IF p_tel_lab_alternativo IS NULL THEN
            p_tel_lab_alternativo := d.telefono;
         END IF;
      END IF;
   END LOOP;
END;
/

