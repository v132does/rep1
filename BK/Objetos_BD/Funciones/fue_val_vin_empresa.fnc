CREATE OR REPLACE FUNCTION IT.fue_val_vin_empresa(p_cod_persona IN VARCHAR2) RETURN VARCHAR2 IS
   result VARCHAR2(1) := 'N';
BEGIN
   -- Verifico si la persona es vínculo de alguna empresa
   SELECT DISTINCT ('S')
     INTO result
     FROM ba_vinculos p, ba_personas b
    WHERE p.cod_per_vinculo = p_cod_persona
      AND p.cod_persona = b.cod_persona
      AND b.tipo = 'J';
   RETURN(result);
EXCEPTION
   WHEN no_data_found THEN
      RETURN('N');
   WHEN OTHERS THEN
      raise_application_error(-20000, 'FUE_VAL_VIN_EMPRESA ' || SQLERRM);
END fue_val_vin_empresa;
/

