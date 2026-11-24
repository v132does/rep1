CREATE OR REPLACE FUNCTION IT.FUY_OBT_GRUPO
 (P_COD_USUARIO IN BA_USUARIOS.COD_USUARIO%TYPE
 )
 RETURN NUMBER
 IS

V_COD_GRUPO AP_GRU_USUARIOS.COD_GRUPO%TYPE;
Begin
    --Obtiene el Codigo del grupo al cual pertenece el usuario
    select cod_grupo
    into v_cod_grupo
    from ap_gru_usuarios
    where cod_usuario = p_cod_usuario;

    return v_cod_grupo;

    exception
       when no_data_found then
             raise_application_error(-20000,
             'Usuario: ' ||p_cod_usuario || ' no existe en Gru_Usuarios');



End;
/

