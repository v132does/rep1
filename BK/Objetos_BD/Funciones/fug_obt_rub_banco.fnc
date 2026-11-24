CREATE OR REPLACE FUNCTION IT.FUG_OBT_RUB_BANCO (P_DOMINIO IN VARCHAR2,
                                              P_VALOR   IN VARCHAR2) RETURN VARCHAR2 IS
   v_cod_rubro BA_COD_REFERENCIAS.VAL_MAXIMO%type;
BEGIN
    select val_minimo
     into v_cod_rubro
     from ba_cod_referencias
    where dominio    = p_dominio
      and val_maximo = p_valor;
    return v_cod_rubro;
EXCEPTION
       when no_data_found then
           raise_application_error(-20000,'Rubro No Definido para el Banco '||P_VALOR);
END;
/

