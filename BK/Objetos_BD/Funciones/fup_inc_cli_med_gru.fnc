CREATE OR REPLACE FUNCTION IT.fup_inc_cli_med_gru
(
   p_cod_gru_economico IN ge_clientes.cod_gru_economico%TYPE,
   p_cod_persona       IN ge_cta_clientes.cod_persona%TYPE
) RETURN VARCHAR2 IS
   v_incluir     VARCHAR2(1);
   v_fec_proceso DATE := pag_cal.fu_obt_fec_actual(6);
BEGIN
   ---incluir el prestamo de medida transitoria solo si todos los miembros del grupo económico tienen solo ope de ME.
   SELECT 'S'
     INTO v_incluir
     FROM ge_clientes
    WHERE cod_persona = p_cod_persona
      AND EXISTS (SELECT 1
             FROM ge_cla_operaciones s, ge_clientes e
            WHERE e.cod_persona = s.cod_persona
              AND s.cod_persona = p_cod_persona
              AND fup_inc_ope_med_gru(p_cod_gru_economico, s.nro_cuenta) = 'S');

   RETURN v_incluir;
EXCEPTION
   WHEN no_data_found THEN
      RETURN 'N';
   WHEN OTHERS THEN
      RETURN 'N';
END;
/

