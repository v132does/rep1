CREATE OR REPLACE FUNCTION IT.fug_obt_blo_tarjetas(p_cod_persona ba_personas.cod_persona%TYPE)
   RETURN VARCHAR2 IS
   v_cantidad NUMBER := 0;
BEGIN

   SELECT COUNT(1)
     INTO v_cantidad
     FROM ta_tarjetas a
    WHERE a.cod_estado IN (13, 19)
      AND a.cod_persona = p_cod_persona;

   IF v_cantidad > 0 THEN
      RETURN 'S';
   ELSE
      RETURN 'N';
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Al obtener Tarjetas Bloqueadas. ' || SQLERRM);
   
END;
/

