CREATE OR REPLACE FUNCTION IT.FUE_OBT_DES_REFCODES
 (P_DOMINIO IN VARCHAR2
 ,P_VALOR IN VARCHAR2
 ,P_TIPO  IN VARCHAR2 DEFAULT NULL
 )
 RETURN VARCHAR2
 IS
v_referencia ba_cod_referencias.significado%type;
BEGIN
    IF UPPER(P_TIPO) = 'S' THEN
       select significado
         into v_referencia
         from ba_cod_referencias
        where dominio    = p_dominio
          and val_minimo = p_valor;
    ELSE
       select abreviatura
         into v_referencia
         from ba_cod_referencias
        where dominio    = p_dominio
          and val_minimo = p_valor;
    END IF;
    RETURN v_referencia;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
       RETURN('Referencia  no registrada en el Sistema');
END;
/

