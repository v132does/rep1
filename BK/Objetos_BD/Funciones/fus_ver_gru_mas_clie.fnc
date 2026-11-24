CREATE OR REPLACE FUNCTION IT.fus_ver_gru_mas_clie(p_cod_gru_economico IN ge_gru_economicos.cod_gru_economico%TYPE)
   RETURN NUMBER IS
   v_cant NUMBER(20) := 0;
BEGIN
   --
   BEGIN
      SELECT COUNT(*)
        INTO v_cant
        FROM ge_clientes c
       WHERE c.cod_gru_economico = p_cod_gru_economico
            --- Persona que poseea deuda todavia
         AND EXISTS (SELECT 1
                FROM ge_cta_clientes cc, ge_cuentas cu
               WHERE cu.nro_cuenta = cc.nro_cuenta
                 AND cu.estado <> 'N'
                 AND cu.cod_modulo IN (6, 10)
                 AND c.cod_persona = cc.cod_persona
                 AND cc.relacion = 'P'
              UNION
              SELECT 1
                FROM ge_cta_clientes cc, ge_cuentas cu
               WHERE cu.nro_cuenta = cc.nro_cuenta
                 AND cu.estado <> 'C'
                 AND cu.cod_modulo = 5
                 AND c.cod_persona = cc.cod_persona
                 AND cc.relacion = 'P'
                 AND EXISTS (SELECT t.nro_cuenta
                        FROM ta_tarjetas t
                       WHERE t.nro_cuenta = cc.nro_cuenta
                         AND t.vigente = 'S'));
   EXCEPTION
      WHEN no_data_found THEN
         v_cant := 0;
   END;
   --
   RETURN(v_cant);
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error en la Función ' || SQLERRM);
END;
/

