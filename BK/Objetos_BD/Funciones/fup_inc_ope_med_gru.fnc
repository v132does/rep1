CREATE OR REPLACE FUNCTION IT.fup_inc_ope_med_gru
(
   p_cod_gru_economico IN ge_clientes.cod_gru_economico%TYPE,
   p_nro_cuenta        IN ge_cta_clientes.nro_cuenta%TYPE
) RETURN VARCHAR2 IS
   v_incluir     VARCHAR2(1);
   v_fec_proceso DATE := pag_cal.fu_obt_fec_actual(6);
BEGIN
   ---incluir el prestamo de medida transitoria solo si todos los miembros del grupo económico tienen solo ope de ME.
   SELECT 'S'
     INTO v_incluir
     FROM ge_cla_operaciones s, ge_clientes e
    WHERE e.cod_persona = s.cod_persona
      AND e.cod_gru_economico = p_cod_gru_economico
      AND s.nro_cuenta = p_nro_cuenta
      AND ((EXISTS (SELECT 1
                      FROM ge_par_dinamicos p
                     WHERE p.parametro IN ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                       AND p.cod_modalidad = s.cod_modalidad
                       AND p.cod_modulo = s.cod_modulo
                       AND nvl(p.val_parametro, 'N') = 'S') AND --es operacion ME,
           NOT EXISTS (SELECT 1 -- todos los miembros tienen solo ope de ME.
                          FROM ge_cla_operaciones s, ge_clientes e
                         WHERE e.cod_persona = s.cod_persona
                           AND e.cod_gru_economico = p_cod_gru_economico
                           AND NOT EXISTS (SELECT 1
                                  FROM ge_par_dinamicos p
                                 WHERE p.parametro IN ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                                   AND p.cod_modalidad = s.cod_modalidad
                                   AND p.cod_modulo = s.cod_modulo
                                   AND nvl(p.val_parametro, 'N') = 'S'))) OR NOT EXISTS
           (SELECT 1 -- no es operacion ME.
              FROM ge_par_dinamicos p
             WHERE p.parametro IN ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
               AND p.cod_modalidad = s.cod_modalidad
               AND p.cod_modulo = s.cod_modulo
               AND nvl(p.val_parametro, 'N') = 'S'));

   RETURN v_incluir;
EXCEPTION
   WHEN no_data_found THEN
      RETURN 'N';
   WHEN OTHERS THEN
      RETURN 'N';
END;
/

