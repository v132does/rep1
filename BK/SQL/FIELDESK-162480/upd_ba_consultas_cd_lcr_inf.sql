Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; End;
/

UPDATE ba_consultas t
   SET t.det_sql =
'SELECT linea
   FROM it.sv_lcr_inf
  WHERE reporta = ''S''
    AND ' || CHR(38) || 'P_FILTROS'
 WHERE t.cod_consulta = 'CD_LCR_INF';

COMMIT;
