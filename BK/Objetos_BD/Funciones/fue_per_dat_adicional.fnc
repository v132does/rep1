CREATE OR REPLACE FUNCTION IT.FUE_PER_DAT_ADICIONAL
 (P_COD_PERSONA IN VARCHAR2,
 P_PARAMETRO IN GE_CTA_DAT_ADICIONALES.PARAMETRO%TYPE
 )
 RETURN VARCHAR2
 IS
v_val_parametro ge_cta_dat_adicionales.val_parametro%type;
BEGIN
   select val_parametro
   into v_val_parametro
   from ba_per_dat_adicionales
   where cod_persona = p_cod_persona
   and   parametro  = p_parametro;
   return v_val_parametro;
   exception
      when no_data_found then
         return null;
END;
/

