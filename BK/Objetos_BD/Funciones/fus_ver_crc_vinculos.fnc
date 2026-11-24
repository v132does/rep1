CREATE OR REPLACE FUNCTION IT.fus_ver_crc_vinculos
(
   p_cod_persona   IN ge_cta_clientes.cod_persona%TYPE,
   p_relacion      IN ge_cta_clientes.relacion%TYPE,
   p_nro_operacion IN ge_cta_clientes.nro_cuenta%TYPE DEFAULT NULL
) RETURN VARCHAR2 IS
   v_existe      VARCHAR2(1) := 'N';
BEGIN
   -- Si fué informada anteriormente la operación 
   IF p_nro_operacion IS NOT NULL THEN
      -- Devolvemos S y en el trigger si es new es una vinculación y si es old es una desvinculación
      BEGIN
         SELECT DISTINCT 'S'
           INTO v_existe
           FROM sb_crc_vinculos_det
          WHERE nro_operacion = p_nro_operacion;
            /*AND cod_persona = p_cod_persona;*/--fieldesk-81123
      EXCEPTION
         WHEN no_data_found THEN
            v_existe := 'N';
         WHEN OTHERS THEN
            v_existe := 'N';
      END;
   ELSE
      -- es un vínculo de Esposo solo podemos verificar si es que la persona fué informada alguna vez en vínculos diario
      BEGIN
         SELECT DISTINCT 'S'
           INTO v_existe
           FROM sb_crc_vinculos_det
          WHERE cod_persona = p_cod_persona
            AND tip_vinculo = 7;
      EXCEPTION
         WHEN no_data_found THEN
            -- si no fue informada con el vínculo pero fue informada la operacion es vinculación.
            v_existe := 'N';
         WHEN OTHERS THEN
            v_existe := 'N';
      END;
   END IF;
   RETURN v_existe;
END;
/
