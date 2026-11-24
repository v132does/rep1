CREATE OR REPLACE FUNCTION IT.FUE_OBT_VAL_USER_DOMINIO
 (P_DOMINIO IN VARCHAR2
 ,P_VALOR IN VARCHAR2
 ,P_ABREVIATURA  IN VARCHAR2 DEFAULT NULL
 )
 RETURN VARCHAR2
 IS
v_val_minimo ba_cod_referencias.val_minimo%type;
BEGIN
    
       select val_minimo
         into v_val_minimo
         from ba_cod_referencias
        where dominio    = p_dominio
          and val_maximo = p_valor
          and abreviatura=p_abreviatura;
   
    RETURN v_val_minimo;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
       RETURN('Referencia  no registrada en el Sistema');
    WHEN OTHERS THEN
       RETURN('Error al recueperar valor '||sqlerrm);
END;
/

