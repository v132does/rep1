CREATE OR REPLACE FUNCTION IT.FUE_OBT_DIR_PRINCIPA
 (P_COD_PERSONA IN VARCHAR2
 )
 RETURN VARCHAR
 IS

V_DIRECCION varchar2(100);-- BA_DIRECCIONES.DIRECCION%TYPE;
Begin
    --Obtiene el Nombre del tipo de retencion
    select direccion||decode(numero,null,'',' '||numero)
    into v_direccion
    from ba_direcciones
    where cod_persona = p_cod_persona
    and principal = 'S';
    return v_direccion;
exception
   when no_data_found then
   return('Dirección no registrada en el Sistema');
End;
/

