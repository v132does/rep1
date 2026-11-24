CREATE OR REPLACE FUNCTION IT.fut_obt_exo_cargo
(
   p_cod_modulo    ta_tip_exo_costos.cod_modulo%TYPE,
   p_cod_modalidad ta_tip_exo_costos.cod_modalidad%TYPE,
   p_afinidad      ta_tip_exo_costos.afinidad%TYPE,
   p_sub_afinidad  ta_tip_exo_costos.sub_afinidad%TYPE
) RETURN VARCHAR2 IS
   CURSOR c_cargos IS
      SELECT lpad(cod_costo, 3, '000') cod_costo
        FROM ta_tip_exo_costos
       WHERE p_cod_modulo = cod_modulo
         AND p_cod_modalidad = cod_modalidad
         AND p_afinidad = afinidad
         AND p_sub_afinidad = sub_afinidad;
   v_gas_no_aplicados VARCHAR2(4000) := NULL;
BEGIN
   FOR i IN c_cargos LOOP
      v_gas_no_aplicados := nvl(v_gas_no_aplicados, '') || i.cod_costo;
   END LOOP;
   IF length(v_gas_no_aplicados) > 30 THEN
      raise_application_error(-2000, 'Solo se pueden exonerar hasta 10 cargos');
   END IF;
   RETURN(v_gas_no_aplicados);
END fut_obt_exo_cargo;
/

