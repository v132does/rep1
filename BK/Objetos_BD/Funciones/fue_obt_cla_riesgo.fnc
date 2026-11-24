CREATE OR REPLACE FUNCTION IT.FUE_OBT_CLA_RIESGO
 (P_DOMINIO IN VARCHAR2
 ,P_VALOR IN VARCHAR2)
 RETURN VARCHAR2
 IS
v_referencia cg_ref_codes.rv_abbreviation%type;
BEGIN
    select abreviatura
     into v_referencia
     from ba_cod_referencias
    where dominio    = p_dominio
      and fug_con_numero(val_minimo) = p_valor;
return v_referencia;
    exception
       when no_data_found then
           return('Referencia  no registrada en el Sistema');
END;
/

