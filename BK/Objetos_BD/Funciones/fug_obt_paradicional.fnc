CREATE OR REPLACE FUNCTION IT.FUG_OBT_PARADICIONAL
 (P_NRO_CUENTA IN GE_CTA_DAT_ADICIONALES.NRO_CUENTA%TYPE
 ,P_PARAMETRO IN GE_CTA_DAT_ADICIONALES.PARAMETRO%TYPE
 )
 RETURN VARCHAR2
 IS
v_val_parametro ge_cta_dat_adicionales.val_parametro%type;
BEGIN
   select val_parametro
   into v_val_parametro
   from ge_cta_dat_adicionales
   where nro_cuenta = p_nro_cuenta
   and   parametro  = p_parametro;
   return v_val_parametro;
   exception
      when no_data_found then
         return null;
END;
/

