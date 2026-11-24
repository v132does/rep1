CREATE OR REPLACE FUNCTION IT.fug_obt_per_transferencia(p_cod_persona IN ba_personas.cod_persona%TYPE)
   RETURN VARCHAR2 IS
   v_exi_cliente VARCHAR2(1);
   v_exi_persona VARCHAR2(1);
   v_cod_persona ba_personas.cod_persona%TYPE := NULL;
BEGIN
   BEGIN
      SELECT 'S'
        INTO v_exi_cliente
        FROM ba_personas      a,
             ba_per_fisicas   cc,
             ba_per_juridicas ju
       WHERE a.cod_persona = ju.cod_persona(+)
         AND a.cod_persona = cc.cod_persona(+)
         AND a.cod_persona = p_cod_persona
         AND EXISTS (SELECT b.cod_persona
                FROM cr_act_esperadas b
               WHERE b.cod_persona = a.cod_persona)
         AND EXISTS (SELECT b.cod_persona
                FROM cr_inf_fondos b
               WHERE b.cod_persona = a.cod_persona);
      IF v_exi_cliente = 'S' THEN
         v_cod_persona := p_cod_persona;
         RETURN v_cod_persona;
      END IF;
   EXCEPTION
      WHEN no_data_found THEN
         BEGIN
            SELECT 'S'
              INTO v_exi_cliente
              FROM ge_cta_clientes
             WHERE cod_persona = p_cod_persona
               AND rownum = 1;
            IF v_exi_cliente = 'S' THEN
               v_cod_persona := p_cod_persona;
               RETURN v_cod_persona;
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               v_exi_cliente := 'N';
         END;
      WHEN OTHERS THEN
         v_exi_cliente := 'N';
   END;
   IF v_exi_cliente = 'N' THEN
      BEGIN
         SELECT 'S'
           INTO v_exi_persona
           FROM ba_personas
          WHERE cod_persona = p_cod_persona;

         IF v_exi_persona = 'S' THEN
            v_cod_persona := NULL;
            RETURN v_cod_persona;
         END IF;

      EXCEPTION
         WHEN OTHERS THEN
            v_cod_persona := NULL;
      END;
   END IF;
   RETURN v_cod_persona;
END;
/

