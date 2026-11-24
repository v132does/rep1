CREATE OR REPLACE FUNCTION IT.fue_obt_val_max_referencia
(
   p_dominio IN VARCHAR2,
   p_valor   IN VARCHAR2
) RETURN VARCHAR2 IS

   v_referencia ba_cod_referencias.val_maximo%TYPE;

BEGIN

   SELECT val_maximo
     INTO v_referencia
     FROM ba_cod_referencias
    WHERE dominio = p_dominio
      AND val_minimo = p_valor;

   RETURN v_referencia;
EXCEPTION
   WHEN no_data_found THEN
      RETURN('Referencia no registrada en el Sistema');
   WHEN OTHERS THEN
      raise_application_error(-20000, 'ERROR al buscar BA_COD_REFERENCIAS :  ' || SQLERRM);
END;
/

