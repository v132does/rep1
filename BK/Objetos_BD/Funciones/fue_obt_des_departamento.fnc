CREATE OR REPLACE FUNCTION IT.FUE_OBT_DES_DEPARTAMENTO
 (P_COD_DEPARTAMENTO IN BA_DEPARTAMENTOS.COD_DEPARTAMENTO%TYPE
 )
 RETURN STRING
 IS

V_DESCRIPCION BA_DEPARTAMENTOS.DESCRIPCION%TYPE;
Begin
    --Obtiene el Nombre del departamento
    select descripcion
    into v_descripcion
    from ba_departamentos
    where cod_departamento = p_cod_departamento;

    return v_descripcion;

    exception
       when no_data_found then
           return null;
End;
/

