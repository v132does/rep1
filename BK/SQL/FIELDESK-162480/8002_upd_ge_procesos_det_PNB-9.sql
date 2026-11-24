Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; End;
/
update GE_PROCESOS_DET T
   set T.NOM_ARCHIVO =chr(38)||'NA'
 where T.COD_PROGRAMA='CD_LCR_INF';
 
update GE_PROCESOS_DET R
   set R.VAR_SUSTITUCION =CHR(38)||'NA=select '||CHR(39)||'LCR'||CHR(45)||CHR(39)||'||pag_gen.fu_obt_cod_entidad||'||CHR(39)||CHR(45)||CHR(39)||'||to_char (to_date('||CHR(38)||'FEC_PROCES),''yyyymmdd'') from dual;'
 where R.COD_PROGRAMA='CD_LCR_INF';

COMMIT;
