CREATE OR REPLACE FUNCTION IT.FUY_OBT_NOM_USUARIO
 (P_COD_USUARIO IN BA_USUARIOS.COD_USUARIO%TYPE
 )
 RETURN VARCHAR2
 IS

V_NOMBRE BA_USUARIOS.NOMBRE%TYPE;
Begin
   select nombre
   into v_nombre
   from ba_usuarios
   where cod_usuario = p_cod_usuario;

   return v_nombre;

    exception
       when no_data_found then
             raise_application_error(-2000,
             'No se encuentra nombre de usuario '||p_cod_usuario);

End;
/

