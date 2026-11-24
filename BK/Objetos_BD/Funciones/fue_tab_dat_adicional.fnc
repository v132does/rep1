CREATE OR REPLACE FUNCTION IT.FUE_TAB_DAT_ADICIONAL
 (P_TAB_RELACION IN VARCHAR2,
  P_PARAMETRO IN ba_TAB_DAT_ADICIONALES.PARAMETRO%TYPE,
  P_REFERENCIA IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
v_val_parametro ba_tab_dat_adicionales.val_parametro%type;
BEGIN
   select val_parametro
   into v_val_parametro
   from ba_tab_dat_adicionales
   where tab_relacion = p_tab_relacion
   and   parametro  = p_parametro
   and   referencia = p_referencia;
   return v_val_parametro;
   exception
      when no_data_found then
         return null;
END;
/

