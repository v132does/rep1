CREATE OR REPLACE FUNCTION IT.fue_val_nro_tel
(
   p_area     IN ba_telefonos.area%TYPE,
   p_telefono IN ba_telefonos.telefono%TYPE
) RETURN VARCHAR2 IS
   v_existe VARCHAR2(1) := 'N';

BEGIN
   BEGIN
      SELECT 'S'
        INTO v_existe
        FROM ba_telefonos t
       WHERE t.area = p_area
         AND t.telefono = p_telefono;
   EXCEPTION
      WHEN no_data_found THEN
         v_existe := 'N';
      WHEN too_many_rows THEN
         v_existe := 'S';
      WHEN OTHERS THEN
         v_existe := 'N';
   END;
   RETURN(v_existe);
EXCEPTION
  WHEN no_data_found THEN
    raise_application_error(-20000, 'Inconveniente al validar Nro. de Telefono.');
END;
/

