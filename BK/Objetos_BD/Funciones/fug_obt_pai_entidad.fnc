CREATE OR REPLACE FUNCTION IT.FUG_OBT_PAI_ENTIDAD
 RETURN number
 IS

RESULT GE_PAR_GENERALES.cod_pais%TYPE;
Begin
  -- Obtiene el código de país de la entidad
  SELECT nvl(cod_pais, -1)
    INTO Result
    from GE_PAR_GENERALES
    where rownum = 1;
  return(Result);
Exception
  when others then
     raise_application_error(-20000,'FUG_OBT_PAI_ENTIDAD '||sqlerrm);
End;
/

