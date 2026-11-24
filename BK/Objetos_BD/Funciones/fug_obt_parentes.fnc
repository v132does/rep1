CREATE OR REPLACE FUNCTION IT.FUG_OBT_PARENTES
 (P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE
 ,P_CAMPO IN GE_PAR_ENTES.PARAMETRO%TYPE
 )
 RETURN VARCHAR2
 IS
v_val_parametro ge_par_entes.val_parametro%type;
BEGIN
   select val_parametro
     into v_val_parametro
     from ge_par_entes
    where cod_ente = p_cod_ente
     and parametro = p_campo;
   return v_val_parametro;
   exception
      when no_data_found then
        -- raise_application_error(-20000,
        -- 'No existe valor p/Ente  '||p_cod_ente);
        RETURN null;
END;
/

