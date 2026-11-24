CREATE OR REPLACE FUNCTION IT.FUE_OBT_COD_DIR_TIPO
 (P_COD_PERSONA IN VARCHAR2
 ,P_TIPO IN BA_DIRECCIONES.TIPO%TYPE
 )
 RETURN NUMBER
 IS

  V_COD_DIRECCION BA_DIRECCIONES.COD_DIRECCION%TYPE;
Begin
 if p_tipo = 'L' then
    --obtener la dirección laboral
    select COD_DIRECCION into V_COD_DIRECCION from (
       select COD_DIRECCION
         from ba_direcciones
        where cod_persona = p_cod_persona
        and tipo = 'L'
        order by decode(principal,'S',0,9) -- ordernar de tal manera que el principal sea
                                           -- el primero si lo fuera
    )
    where rownum = 1 ;
 elsif p_tipo = 'P' then
    --obtener la dirección particular
    select COD_DIRECCION into V_COD_DIRECCION from (
       select COD_DIRECCION
         from ba_direcciones
        where cod_persona = p_cod_persona
        and tipo = 'P'
        order by decode(principal,'S',0,9) -- ordernar de tal manera que el principal sea
                                           -- el primero si lo fuera
    )
    where rownum = 1 ;
 else
    return(0);
 end if;
    return V_COD_DIRECCION;
exception
   when no_data_found then
   return 0;
--   return('Dirección no registrada en el Sistema');
End;
/

