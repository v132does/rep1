CREATE OR REPLACE FUNCTION IT."FUG_OBT_OFI_MATRIZ"
 return number
 IS

RESULT GE_PAR_GENERALES.cod_ofi_matriz%TYPE;
Begin
  -- Obtiene la Oficina Matriz
   SELECT nvl(cod_ofi_matriz, -1)
    INTO Result
    from GE_PAR_GENERALES
    where rownum = 1;

    return(Result);
Exception
  when others then
     raise_application_error(-20000,'FUG OBT OFI MATRIZ '||sqlerrm);
end FUG_OBT_OFI_MATRIZ;
/

