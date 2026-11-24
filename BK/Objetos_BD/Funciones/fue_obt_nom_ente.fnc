CREATE OR REPLACE FUNCTION IT.FUE_OBT_NOM_ENTE
 (P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE
 )
 RETURN STRING
 IS
 --Creado por : Julio Leguizamon
 --Fecha       : 01/07/2008
 --Objetivo    : devolver el nombre del ente
V_DESCRIPCION GE_ENTES.DESCRIPCION%TYPE;
Begin
    --Obtiene el Nombre del ente
    select descripcion
    into v_descripcion
    from ge_entes
    where cod_ente = p_cod_ente;

    return v_descripcion;

exception
  when no_data_found then
    return('Ente no registrado en el sistema');
End;
/

