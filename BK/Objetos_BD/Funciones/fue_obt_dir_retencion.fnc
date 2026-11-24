CREATE OR REPLACE FUNCTION IT.FUE_OBT_DIR_RETENCION
 (P_COD_DIR_RETENCION IN GE_DIR_RETENCIONES.COD_DIR_RETENCION%TYPE
 )
 RETURN STRING
 IS

V_DESCRIPCION GE_DIR_RETENCIONES.DESCRIPCION%TYPE;
Begin
    --Obtiene el Nombre del tipo de retencion
    select descripcion
    into v_descripcion
    from ge_dir_retenciones
    where cod_dir_retencion = p_cod_dir_retencion;


    return v_descripcion;

    exception
       when no_data_found then
           return('Retencion no registrada en el Sistema');
End;
/

