CREATE OR REPLACE FUNCTION IT.FUG_OBT_DIR_CORREO
 RETURN VARCHAR2
 IS

RESULT GE_PAR_GENERALES.DIR_CORREO%TYPE;
Begin
  -- Obtiene la dirección de mail a ser utilizada para los envíos a través del Sistema
  SELECT DIR_CORREO
    INTO Result
    from GE_PAR_GENERALES
    where rownum = 1;
  return(Result);
Exception
  when others then
     raise_application_error(-20000,'FUG_OBT_DIR_CORREO '||sqlerrm);
End;
/

