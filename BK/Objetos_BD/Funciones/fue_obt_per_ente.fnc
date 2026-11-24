CREATE OR REPLACE FUNCTION IT.FUE_OBT_PER_ENTE
 (P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE
 )
 RETURN STRING
 IS
 --Objetivo    : devolver el código de persona del ente
v_cod_persona GE_ENTES.cod_persona%TYPE;
Begin
    --Obtiene el código de persona del ente
    select cod_persona
    into v_cod_persona
    from ge_entes
    where cod_ente = p_cod_ente;

    return v_cod_persona;

exception
  when no_data_found then
    return('Ente no registrado en el sistema');
End;
/

