CREATE OR REPLACE FUNCTION IT.FUE_OBT_DES_OFICINA
 (P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 )
 RETURN STRING
 IS

V_DESCRIPCION BA_OFICINAS.DESCRIPCION%TYPE;
Begin
    --Obtiene el Nombre de la Oficina
    select descripcion
    into v_descripcion
    from ba_oficinas
    where cod_oficina = p_cod_oficina;


    return v_descripcion;

    exception
       when no_data_found then
           return('Oficina no registrada en el Sistema');
End;
/

