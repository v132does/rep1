begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
UPDATE BA_COD_REFERENCIAS
   SET significado = 'Relación de tipos de Préstamos entre el banco y Equifax'
 WHERE DOMINIO IN ('TIP_PRE_EQUIFAX');
UPDATE BA_COD_REFERENCIAS
   SET significado = 'Relación de tipos de Vinculos entre el banco y Equifax'
 WHERE DOMINIO IN ('TIP_VIN_EQUIFAX');
 
commit;
/
