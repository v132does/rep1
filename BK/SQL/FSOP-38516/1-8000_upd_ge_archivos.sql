begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;
/
update IT.GE_ARCHIVOS set UTI_LOADER = 'S'
WHERE REFERENCIA = 'BCP_CLASIFICACION'
AND ARCHIVO = 'CG.CSV'
AND NRO_SECUENCIA = 1
AND UTI_LOADER = 'N';

commit;