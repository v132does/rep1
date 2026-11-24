CREATE OR REPLACE FUNCTION IT.FUE_OBT_DIR_TIPO
 (P_COD_PERSONA IN VARCHAR2
 ,P_TIPO IN BA_DIRECCIONES.TIPO%TYPE
 )
 RETURN VARCHAR
 IS

V_DIRECCION VARCHAR2(100);--BA_DIRECCIONES.DIRECCION%TYPE;
Begin
 if p_tipo = 'L' then
    --obtener la dirección laboral
    select direccion into v_direccion from (
       select direccion||decode(numero,null,'',' '||numero) direccion, principal
         from ba_direcciones
        where cod_persona = p_cod_persona
        and tipo = 'L'
        order by decode(principal,'S',0,9) -- ordernar de tal manera que el principal sea
                                           -- el primero si lo fuera
    )
    where rownum = 1 ;
 elsif p_tipo = 'P' then
    --obtener la dirección particular
    select direccion into v_direccion from (
       select direccion||decode(numero,null,'',' '||numero) direccion, principal
         from ba_direcciones
        where cod_persona = p_cod_persona
        and tipo = 'P'
        order by decode(principal,'S',0,9) -- ordernar de tal manera que el principal sea
                                           -- el primero si lo fuera
    )
    where rownum = 1 ;
 else
    return('Dirección no registrada en el Sistema');
 end if;
    return v_direccion;
exception
   when no_data_found then
   return null;
--   return('Dirección no registrada en el Sistema');
End;
/

