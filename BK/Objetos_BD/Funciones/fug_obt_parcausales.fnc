CREATE OR REPLACE FUNCTION IT.FUG_OBT_PARCAUSALES
 (P_COD_CAUSA IN GE_CAUSALES.COD_CAUSA%TYPE
 ,P_PARAMETRO IN GE_PAR_CAUSALES.PARAMETRO%TYPE
 )
 RETURN VARCHAR2
 IS

V_VAL_PARAMETRO GE_PAR_CAUSALES.VAL_PARAMETRO%TYPE;
v_parametro ge_par_causales.parametro%type;
BEGIN
   if p_cod_causa is not null and p_parametro is not null then
      v_parametro :=trim(p_parametro);
      select val_parametro
      into v_val_parametro
      from ge_par_causales
      where cod_causa = p_cod_causa
      and parametro = v_parametro;
   end if;
   return v_val_parametro;
   exception
      when no_data_found then
--         raise_application_error(-20000,
  --       'No existe valor p/Causa  '||p_cod_causa);
  RETURN NULL;
END;
/

