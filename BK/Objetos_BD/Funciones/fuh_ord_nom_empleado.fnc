CREATE OR REPLACE FUNCTION IT.FUH_ORD_NOM_EMPLEADO (
   P_COD_EMPLEADO RH_EMPLEADOS.COD_PERSONA%TYPE)
   RETURN VARCHAR2
IS
v_nom_empleado VARCHAR2(200);
BEGIN
   select fue_obt_titulo( b.pri_apellido || ', ' || b.pri_nombre)
	 into   v_nom_empleado
	 from   ba_per_fisicas b
	 where  b.cod_persona = P_COD_EMPLEADO;
   RETURN v_nom_empleado;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN NULL;
END;
/

