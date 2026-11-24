CREATE OR REPLACE FUNCTION IT.FUG_OBT_PAR_DEFADICIONAL
 (P_PARAMETRO IN BA_PER_DAT_ADICIONALES.PARAMETRO%TYPE)
 RETURN VARCHAR2
 IS
v_val_parametro ba_per_def_adicionales.val_defecto%type;
BEGIN
   select val_defecto
   into v_val_parametro
   from ba_per_def_adicionales
   where parametro  = p_parametro;
   return v_val_parametro;
   exception
      when no_data_found then
         return null;
END;
/

