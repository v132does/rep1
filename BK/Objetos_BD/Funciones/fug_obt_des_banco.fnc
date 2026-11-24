CREATE OR REPLACE FUNCTION IT.FUG_OBT_DES_BANCO
 (p_cod_banco ge_bancos.cod_banco%TYPE
 )
 RETURN varchar2
 IS
V_DESCRIPCION ge_bancos.descripcion%TYPE;
Begin
    --Obtiene la descripción de la Causa
    select descripcion
      into v_descripcion
      from ge_bancos
     where cod_banco = p_cod_banco;
    return v_descripcion;
    exception
       when no_data_found then
           return('Banco no registrado en el Sistema');
End;
/

