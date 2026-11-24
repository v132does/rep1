CREATE OR REPLACE FUNCTION IT.FUE_OBT_SIG_REFCODES
   (P_DOMINIO IN VARCHAR2
   ,P_VALOR IN VARCHAR2) RETURN VARCHAR2 IS
   
   v_referencia ba_cod_referencias.significado%type;
BEGIN
   select significado
     into v_referencia
     from ba_cod_referencias
    where dominio    = p_dominio
      and val_minimo = p_valor;
      
   return v_referencia;
exception
   when no_data_found then
      return('Referencia no registrada en el Sistema');
   when others then
      raise_application_error(-20000, 'ERROR al buscar BA_COD_REFERENCIAS :  '||SQLERRM);
END;
/

