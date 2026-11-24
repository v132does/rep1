CREATE OR REPLACE FUNCTION IT.FUE_OBT_TEL_TIPO
 (P_COD_PERSONA IN VARCHAR2
 ,P_TIP_LINEA IN VARCHAR2
 ,P_TIPO IN VARCHAR2
 ,P_COD_TELEFONO IN BA_TELEFONOS.COD_TELEFONO%TYPE
 )
 RETURN VARCHAR
 IS

V_AREA BA_TELEFONOS.AREA%TYPE;
V_TELEFONO BA_TELEFONOS.TELEFONO%TYPE;
Begin
    --Obtiene el Teléfono según especificaciones.

   if p_cod_telefono is null and p_tip_linea is not null then -- Obtener telefono según tipo de linea y telefono
      select area, telefono
       into v_area, v_telefono from (
                                     select area, telefono
                                       from ba_telefonos
                                      where cod_persona = p_cod_persona
                                        and tipo = p_tipo
                                        and tip_linea = p_tip_linea
                                        Order by decode(principal, 'S', 0, 9))
      where rownum = 1;
   elsif p_cod_telefono is null and p_tip_linea is null then
            select area, telefono
              into v_area, v_telefono from (
                                     select area, telefono
                                       from ba_telefonos
                                      where cod_persona = p_cod_persona
                                        and tipo = p_tipo
                                        Order by decode(principal, 'S', 0, 9))
            where rownum = 1;
        

    elsif p_cod_telefono is not null then  -- Obtener teléfono según Código de Teléfono
       select area, telefono
       into v_area, v_telefono
       from ba_telefonos
      where cod_persona = p_cod_persona
       and tipo = p_tipo
       and tip_linea = p_tip_linea
       and cod_telefono = p_cod_telefono;
    end if;

    if v_area is not null then
       return '('||v_area||') '||v_telefono;
    elsif v_area is null then
       return v_telefono;
    else
       return null;
    end if;

exception
   when no_data_found then
   return('Nro. de Teléfono no registrado en el Sistema');
End;
/

