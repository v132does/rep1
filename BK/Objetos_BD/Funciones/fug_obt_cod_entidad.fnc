CREATE OR REPLACE FUNCTION IT.fug_obt_cod_entidad RETURN NUMBER IS

   result ge_par_generales.cod_entidad%TYPE;
BEGIN
   -- Obtiene el Código de Entidad
   SELECT cod_entidad
     INTO result
     FROM ge_par_generales
    WHERE rownum = 1;

   RETURN(result);
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'FUG OBT COD ENTIDAD ' || SQLERRM);
END fug_obt_cod_entidad;
/

