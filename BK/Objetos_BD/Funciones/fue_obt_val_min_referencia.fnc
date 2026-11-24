CREATE OR REPLACE FUNCTION IT.FUE_OBT_VAL_MIN_REFERENCIA(P_DOMINIO IN VARCHAR2,
                                                         P_VALOR   IN VARCHAR2)
  RETURN VARCHAR2 IS
  v_referencia ba_cod_referencias.significado%type;
BEGIN
  select b.val_minimo
    into v_referencia
    from ba_cod_referencias b
   where b.dominio = p_dominio
     and b.significado = p_valor;
  return v_referencia;
exception
  when no_data_found then
    return('Referencia  no registrada en el Sistema');
END;
/

