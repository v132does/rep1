CREATE OR REPLACE PROCEDURE IT.pre_obt_pai_iso
(
   p_cod_persona     IN ba_personas.cod_persona%TYPE DEFAULT NULL,
   p_cod_pais        IN ba_paises.cod_pais%TYPE DEFAULT NULL,
   p_cod_ciudad      IN ba_ciudades.cod_ciudad%TYPE DEFAULT NULL,
   p_des_bco_central OUT ba_ciudades.des_bco_central%TYPE,
   p_cod_pai_iso     OUT ba_paises.cod_pai_iso%TYPE
) IS
BEGIN
   IF p_cod_persona IS NOT NULL THEN
      BEGIN
         SELECT d.cod_pai_iso, c.des_bco_central
             INTO p_cod_pai_iso, p_des_bco_central
           FROM ba_direcciones a, ba_ciudades c, ba_paises d
          WHERE cod_persona = p_cod_persona
            AND principal = 'S'
            AND a.cod_ciudad = c.cod_ciudad
            AND a.cod_pais = c.cod_pais
            AND d.cod_pais = c.cod_pais;
      EXCEPTION
         WHEN no_data_found THEN
            BEGIN
               SELECT d.cod_pai_iso, NULL
                 INTO p_cod_pai_iso, p_des_bco_central
                 FROM ba_direcciones a, ba_paises d
                WHERE cod_persona = p_cod_persona
                  AND principal = 'S'
                  AND d.cod_pais = a.cod_pais;
            EXCEPTION
                WHEN no_data_found THEN 
                   p_cod_pai_iso     := NULL;
                   p_des_bco_central := NULL; 
                WHEN OTHERS THEN
                   p_cod_pai_iso     := NULL;
                   p_des_bco_central := NULL;                    
             END;              
         WHEN OTHERS THEN
            p_cod_pai_iso     := NULL;
            p_des_bco_central := NULL;
      END;
   ELSIF p_cod_pais IS NOT NULL THEN
      BEGIN
         SELECT d.cod_pai_iso, c.des_bco_central
           INTO p_cod_pai_iso, p_des_bco_central
           FROM ba_paises d, ba_ciudades c
          WHERE d.cod_pais = c.cod_pais(+)
            AND d.cod_pais = p_cod_pais
            AND (c.cod_ciudad = p_cod_ciudad or p_cod_ciudad IS NULL);
      EXCEPTION
         WHEN no_data_found THEN
            p_cod_pai_iso     := NULL;
            p_des_bco_central := NULL;
         WHEN too_many_rows THEN
            BEGIN
               SELECT cod_pai_iso
                 INTO p_cod_pai_iso
                 FROM ba_paises
                WHERE cod_pais = p_cod_pais;
                p_des_bco_central := NULL;
            EXCEPTION
               WHEN OTHERS THEN
                  p_cod_pai_iso     := NULL;
                  p_des_bco_central := NULL;
            END;
         WHEN OTHERS THEN
            p_cod_pai_iso     := NULL;
            p_des_bco_central := NULL;
      END;
   END IF;
   --BSEVOCORE-904 Solo debe devolver la descripcion del BCP, no la descripción local.
END;
/

