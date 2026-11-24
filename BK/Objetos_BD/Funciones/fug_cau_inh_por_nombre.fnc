CREATE OR REPLACE FUNCTION IT.fug_cau_inh_por_nombre
(
   p_nom_completo IN VARCHAR2,
   p_entorno      IN VARCHAR2 DEFAULT NULL
) RETURN VARCHAR2 IS
   /* Retorna el tipo de Lista (OFAC, WORLDCHECK, SEPRELAD, etc) en el cual se encuentra un nombre parecido al
      codigo de persona enviado. Sino se encuentra parecidos, retorna NULO
      Se guarda el código de persona coincidente con la lista encontrada para utilizar en procesos donde se requiera conocer la persona con cumplimiento.
   */
   --Variables--
   v_retorno          VARCHAR2(100);
   v_cod_causa        ge_per_inhibidas.cod_causa%type;
   v_cod_per_parecida ba_personas.cod_persona%type;
   v_nom_completo     ba_personas.nom_completo%type := fug_obt_con_busqueda(REPLACE(p_nom_completo, chr(39), ' '));
   --Cursores--
   CURSOR c_personas IS
      SELECT a.cod_causa, a.cod_persona
        FROM ba_personas b, ba_per_fisicas c, ge_per_inhibidas a
       WHERE a.cod_persona = b.cod_persona
         AND a.cod_persona = c.cod_persona
         AND (p_entorno = 'X' AND a.cod_causa IN (26, 98, 100) OR
             p_entorno IS NULL AND a.cod_causa IN (26, 98, 99, 100)) -- los causales buscados
         AND a.estado = 'I'
         AND b.nom_completo LIKE p_nom_completo
         AND rownum = 1
      UNION ALL
      SELECT a.cod_causa, a.cod_persona
        FROM ba_personas b, ba_per_juridicas c, ge_per_inhibidas a
       WHERE a.cod_persona = b.cod_persona
         AND a.cod_persona = c.cod_persona
         AND c.raz_social LIKE p_nom_completo
         AND (p_entorno = 'X' AND a.cod_causa IN (26, 98, 100) OR
             p_entorno IS NULL AND a.cod_causa IN (26, 98, 99, 100)) -- los causales buscados
         AND a.estado = 'I'
         AND rownum = 1;
   /*
    Se comentaron las lineas de los cursores por que se requiere que la coincidencia
    de nombres sea completa y no parcial.
   */

   -- Cursores utilizando el catsearch
   CURSOR c_personas_cs IS
      SELECT a.cod_causa, a.cod_persona
        FROM ba_personas b, ba_per_fisicas c, ge_per_inhibidas a
       WHERE a.cod_persona = b.cod_persona
         AND a.cod_persona = c.cod_persona
         AND (p_entorno = 'X' AND a.cod_causa IN (26, 98, 100) OR
             p_entorno IS NULL AND a.cod_causa IN (26, 98, 99, 100)) -- los causales buscados
         AND a.estado = 'I'
         AND catsearch(b.nom_completo, v_nom_completo, NULL) > 0
         AND rownum = 1
      UNION ALL
      SELECT a.cod_causa, a.cod_persona
        FROM ba_personas b, ba_per_juridicas c, ge_per_inhibidas a
       WHERE a.cod_persona = b.cod_persona
         AND a.cod_persona = c.cod_persona
         AND catsearch(b.nom_completo, v_nom_completo, NULL) > 0
         AND (p_entorno = 'X' AND a.cod_causa IN (26, 98, 100) OR
             p_entorno IS NULL AND a.cod_causa IN (26, 98, 99, 100)) -- los causales buscados
         AND a.estado = 'I'
         AND rownum = 1;

BEGIN
   -- Inicio de variable.
   pag_gen.pr_ini_variables(null,null,null);
   BEGIN
      -- Realizar la búsqueda con los cursores con catsearch
      OPEN c_personas_cs;
      FETCH c_personas_cs
         INTO v_cod_causa, v_cod_per_parecida;
      CLOSE c_personas_cs;

      v_retorno             := NULL;
      pag_gen.pr_ini_variables(null,null,null);
      IF v_cod_causa IS NOT NULL THEN
         v_retorno             := v_cod_causa;
         pag_gen.g_cod_persona := v_cod_per_parecida;
      ELSE
         v_retorno             := NULL;
         pag_gen.pr_ini_variables(null,null,null);
         IF v_cod_causa IS NOT NULL THEN
            v_retorno             := v_cod_causa;
            pag_gen.g_cod_persona := v_cod_per_parecida;
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         -- En el caso de error ejecutar los cursores con like
         OPEN c_personas;
         FETCH c_personas
            INTO v_cod_causa, v_cod_per_parecida;
         CLOSE c_personas;

         v_retorno             := NULL;
         pag_gen.pr_ini_variables(null,null,null);
         IF v_cod_causa IS NOT NULL THEN
            v_retorno             := v_cod_causa;
            pag_gen.g_cod_persona := v_cod_per_parecida;
         ELSE
            v_retorno             := NULL;
            pag_gen.pr_ini_variables(null,null,null);
            IF v_cod_causa IS NOT NULL THEN
               v_retorno             := v_cod_causa;
               pag_gen.g_cod_persona := v_cod_per_parecida;
            END IF;
         END IF;
   END;
   RETURN(v_retorno);
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'FUG_CAU_INH_POR_NOMBRE ' || SQLERRM);
END;
/

