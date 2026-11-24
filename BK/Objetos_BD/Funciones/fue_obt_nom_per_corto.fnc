CREATE OR REPLACE FUNCTION IT.FUE_OBT_NOM_PER_CORTO(p_cod_persona IN ba_per_fisicas.cod_persona%TYPE) RETURN VARCHAR2 IS

   v_pri_nombre   ba_per_fisicas.pri_nombre%TYPE;
   v_pri_apellido ba_per_fisicas.pri_apellido%TYPE;
BEGIN
    --Obtiene el Nombre completo de la persona
    IF p_cod_persona IS NOT NULL THEN
        SELECT f.pri_nombre, f.pri_apellido
          INTO v_pri_nombre, v_pri_apellido
          FROM ba_per_fisicas f
         WHERE f.cod_persona = p_cod_persona;
    END IF;
    RETURN (v_pri_nombre||' '||v_pri_apellido);
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN '';
END;
/

