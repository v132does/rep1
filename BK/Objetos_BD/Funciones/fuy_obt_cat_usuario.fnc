CREATE OR REPLACE FUNCTION IT.FUY_OBT_CAT_USUARIO
 (P_COD_USUARIO IN BA_USUARIOS.COD_USUARIO%TYPE
 )
 RETURN VARCHAR2
 IS

V_CATEGORIA BA_USUARIOS.CATEGORIA%TYPE;
Begin
    --Obtiene el Codigo del grupo al cual pertenece el usuario
    select categoria
    into v_categoria
    from ba_usuarios
    where cod_usuario = p_cod_usuario;

    return v_categoria;

    exception
       when no_data_found then
             raise_application_error(-20000,
             'Usuario: ' ||p_cod_usuario || ' no posee categoria');



End;
/

