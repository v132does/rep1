CREATE OR REPLACE FUNCTION it.fu_obt_ref_bcp_barrio (
   p_cod_persona IN ba_personas.cod_persona%TYPE
) RETURN NUMBER IS
   v_ref_bcp_barrio it.BA_BARRIOS_BCP.cod_barrio_bcp%TYPE;
BEGIN
   SELECT 
   CASE WHEN fue_obt_val_max_referencia('COD_BCP_BARRIOS',b.cod_barrio_bcp) = '1101001' THEN 1101001 ELSE NVL(b.cod_barrio_bcp, 45) END
   INTO v_ref_bcp_barrio
   FROM ba_direcciones d
   LEFT JOIN ba_paises p ON p.cod_pais = d.cod_pais
   LEFT JOIN ba_ciudades c ON c.cod_pais = d.cod_pais AND c.cod_ciudad = d.cod_ciudad
   LEFT JOIN IT.barrios_bcp_bankitti b ON b.cod_pais = d.cod_pais AND b.cod_ciudad = d.cod_ciudad AND b.cod_barrio = d.cod_barrio
   LEFT JOIN ba_departamentos dep ON c.cod_departamento = dep.cod_departamento
   WHERE d.cod_persona = p_cod_persona
   and (d.principal='S' and d.cod_barrio is not null)
   AND ROWNUM = 1;

   RETURN v_ref_bcp_barrio;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN 45;
   WHEN OTHERS THEN
      RETURN 45;
END;
/