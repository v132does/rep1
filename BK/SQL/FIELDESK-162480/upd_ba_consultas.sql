Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; End; 
/

UPDATE ba_consultas t
   SET t.det_sql =
'SELECT
       TO_CHAR(fec_proceso, ''YYYYMMDD'') AS yyyymmdd,
       id_bcp,
       NULL AS cod_referencia,
       sal_guaranies AS valor_texto,
       sal_extranjera AS cantidad,
       sal_total AS monto
  FROM it.sv_lcr_inf
 WHERE ' || CHR(38) || 'P_FILTROS'
 WHERE t.cod_consulta = 'CD_LCR_INF';

COMMIT;
