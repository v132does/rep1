CREATE OR REPLACE FUNCTION IT."FUP_OBT_CATEGORIA"
 (P_CAT_AUTOMATICA IN GE_CLIENTES.CAT_AUTOMATICA%TYPE
 ,P_CAT_SUBJETIVA IN GE_CLIENTES.CAT_SUBJETIVA%TYPE
 )
 RETURN NUMBER
 IS
BEGIN
   if round(p_cat_automatica,0) > p_cat_subjetiva then
      return round(p_cat_automatica,0);
   else
      return nvl(p_cat_subjetiva,round(p_cat_automatica,0));
   end if;
END;
/

