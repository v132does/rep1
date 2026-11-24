CREATE OR REPLACE FUNCTION IT.FUE_OBT_NOM_USUARIO
 (P_COD_USUARIO IN BA_USUARIOS.COD_USUARIO%TYPE
 )
 RETURN VARCHAR2
 IS

V_NOMBRE BA_USUARIOS.NOMBRE%TYPE;
Begin
    --Obtiene el Codigo del grupo al cual pertenece el usuario
    select nombre
    into v_nombre
    from ba_usuarios
    where cod_usuario = p_cod_usuario;

    return v_nombre;

    exception
       when no_data_found then
           return('Usuario no registrado en el Sistema');
End;
/

