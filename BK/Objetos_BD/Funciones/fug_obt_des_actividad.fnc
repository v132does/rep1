CREATE OR REPLACE FUNCTION IT.FUG_OBT_DES_ACTIVIDAD
 (P_COD_ACTIVIDAD varchar2,
  P_TIPO varchar2 DEFAULT 'V'
 )
 RETURN varchar2
 IS
V_DESCRIPCION GE_ACTIVIDADES.DESCRIPCION%TYPE;
Begin
    --Obtiene la descripción de la Actividad
    if p_tipo = 'V' then
       select descripcion
         into v_descripcion
         from ge_actividades
        where cod_actividad = to_number(p_cod_actividad);
    --Obtiene la descripción del Rubro
    elsif p_tipo = 'N' then
       select descripcion
         into v_descripcion
         from ge_rub_economicos
        where cod_rub_economico = p_cod_actividad;
    end if;
    return v_descripcion;
    exception
       when no_data_found then
           return('Rubro / Actividad no registrados en el Sistema');
End;
/

