CREATE OR REPLACE FUNCTION IT.FUE_OBT_ISO_PAIS
 (P_COD_PAIS IN BA_PAISES.COD_PAIS%TYPE
 )
 RETURN STRING
 IS

V_ISO BA_PAISES.DESCRIPCION%TYPE;
Begin
    --Obtiene el Nombre del País
    select cod_pai_iso
    into V_ISO
    from ba_paises
    where cod_pais = p_cod_pais;

    return V_ISO;

    exception
       when no_data_found then
           return('País no registrado en el Sistema');
End;
/

