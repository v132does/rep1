Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; End;
/
update BA_PAR_CONSULTAS T
   set T.VAL_DEFECTO ='select ''Igual_a ''||chr(39)||to_char(max(FEC_PROCESO),''dd/mm/yyyy'')||chr(39) from IT.SV_LCR_INF'
 where T.COD_CONSULTA='CD_LCR_INF';
 
COMMIT;
