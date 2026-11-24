CREATE OR REPLACE FUNCTION IT.FUG_OBT_UBI_BANCO
 (p_cod_banco ge_bancos.cod_banco%TYPE
 )
 RETURN varchar2
 IS
v_ubicacion ge_bancos.ubicacion%TYPE;
Begin
    --Obtiene la descripción de la Causa
    select ubicacion
      into v_ubicacion
      from ge_bancos
     where cod_banco = p_cod_banco;
    return v_ubicacion;
    exception
       when no_data_found then
           return('E');
End;
/

