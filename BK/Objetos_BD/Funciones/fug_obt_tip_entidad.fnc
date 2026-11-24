CREATE OR REPLACE FUNCTION IT.FUG_OBT_TIP_ENTIDAD
 RETURN varchar2
 IS

RESULT GE_PAR_GENERALES.TIP_ENTIDAD%TYPE;
Begin
  -- Obtiene el tipo de entidad de la empresa
  SELECT TIP_entidad
    INTO Result
    from GE_PAR_GENERALES
    where rownum = 1;
  return(Result);
Exception
  when others then
     raise_application_error(-20000,'FUG_OBT_TIP_ENTIDAD '||sqlerrm);
End;
/

