CREATE OR REPLACE FUNCTION IT.FUG_OBT_TIP_IMPLEMENTACION
 RETURN number
 IS

RESULT GE_PAR_GENERALES.TIP_IMPLEMENTACION%TYPE;
Begin
  -- Obtiene el tipo de implementación utilizada en la entidad
  SELECT nvl(TIP_IMPLEMENTACION, -1)
    INTO Result
    from GE_PAR_GENERALES
    where rownum = 1;
  return(Result);
Exception
  when others then
     raise_application_error(-20000,'FUG_OBT_TIP_IMPLEMENTACION '||sqlerrm);
End;
/

