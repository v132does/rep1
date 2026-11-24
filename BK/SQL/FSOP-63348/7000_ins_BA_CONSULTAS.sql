begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end;
/ 
INSERT INTO BA_CONSULTAS (COD_CONSULTA,DESCRIPCION,COD_USUARIO,TIPO,PERMISO,OBSERVACION,DET_SQL,FILTROS,COL_CORTES,COL_SUMAS)
VALUES ('ASIDETDIF','Detalle de Asiento con diferencias (ASIENTOS SIN CUADRAR) ',user,'G',NULL,'',
        'SELECT trunc(fecha) FECHA_PROCESO, to_date(cod_persona, ''dd/mm/yyyy'') FECHA, 
                substr(det_error, instr(det_error, ''='', 1, 2)+2, instr(det_error, '','', 1, 2)-instr(det_error, ''='', 1, 2)-2) NRO_ASIENTO, 
                trim(to_char(substr(det_error, instr(det_error, ''='', 1, 3)+2, instr(det_error, '','', 1, 3)-instr(det_error, ''='', 1, 3)-2), ''999,999,999,999,999,999,999'')) ASIENTO_777, 
                trim(to_char(substr(det_error, instr(det_error, ''='', 1, 4)+2, instr(det_error, '','', 1, 4)-instr(det_error, ''='', 1, 4)-2), ''999,999,999,999,999,999,999'')) MOVIMIENTOS,
                trim(to_char(substr(det_error, instr(det_error, ''='', 1, 5)+2), ''999,999,999,999,999,999,999'')) DIFERENCIA,
                substr(det_error, 1, instr(det_error, ''.'')) OBSERVACIONES  
            FROM ge_log_errores
            WHERE nro_cuenta = ''DIFASI''
            AND cod_programa = ''PRB_GEN_ASI_DET_DIF''  
            AND to_date(cod_persona, ''dd/mm/yyyy'') >= TRUNC(SYSDATE)-30
            ORDER BY to_date(cod_persona, ''dd/mm/yyyy'') desc',
		'',       -- FILTROS
		NULL,     -- COL_CORTES
		NULL      -- COL_SUMAS
);
COMMIT;
