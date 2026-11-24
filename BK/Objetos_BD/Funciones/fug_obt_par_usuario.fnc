CREATE OR REPLACE FUNCTION IT.FUG_OBT_PAR_USUARIO
 (P_CODIGO IN GE_PAR_USUARIOS.COD_USUARIO%TYPE
 ,P_PARAMETRO IN GE_PAR_USUARIOS.PARAMETRO%TYPE
 )
 RETURN VARCHAR2
 IS
 --COREPESI-1 / Proyecto Mejoras Performance SIPAP--
 v_val_parametro ge_par_USUARIOS.val_parametro%type;
BEGIN
   select val_parametro
     into v_val_parametro
     from ge_par_usuarios x
    where x.cod_usuario = p_codigo
      and x.parametro = p_parametro;
   return v_val_parametro;
   exception
      when no_data_found then
        RETURN null;
END;
/

