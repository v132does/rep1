CREATE OR REPLACE FUNCTION IT.FUG_OBT_VAL_DEFECTO
 (P_COD_PROGRAMA IN BA_PRO_CAMPOS.COD_PROGRAMA%TYPE
 ,P_CAMPO IN BA_PRO_CAMPOS.COD_CAMPO%TYPE
  )
 RETURN VARCHAR2
 IS
v_val_defecto varchar2(1000);
BEGIN
   select val_defecto
   into v_val_defecto
   from ba_pro_campos
   where cod_programa = p_cod_programa
   and cod_campo = p_campo;
   return v_val_defecto;
exception
   when no_data_found then
      return null;
   when others then
      raise_application_error(-20000, 'Recup. valor x defecto para '||p_campo||'. '||sqlerrm);
END;
/

