create or replace function it.FUN_OBT_OFI_MATRIZ
 return number
 IS

RESULT GE_PAR_GENERALES.cod_ofi_matriz%TYPE;
Begin
  -- Obtiene el tipo de implementación utilizada en la entidad
   SELECT nvl(cod_ofi_matriz, -1)
    INTO Result
    from GE_PAR_GENERALES
    where rownum = 1;

    return(Result);
Exception
  when others then
     raise_application_error(-20000,'FUN OBT OFI MATRIZ '||sqlerrm);
end FUN_OBT_OFI_MATRIZ;
/

