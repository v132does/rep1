CREATE OR REPLACE FUNCTION IT.FUG_OBT_POR_EXCESO (P_TOT_GAR_COMPUTABLE IN ge_clientes.tot_gar_computables%TYPE
 ,P_COD_SEC_CONTABLE IN ge_clientes.cod_sec_contable%TYPE) RETURN number IS
BEGIN
   if P_TOT_GAR_COMPUTABLE > 0 or P_COD_SEC_CONTABLE in ('F','I') then
        return 30;
   else
       return 20;
   end if;
END;
/

