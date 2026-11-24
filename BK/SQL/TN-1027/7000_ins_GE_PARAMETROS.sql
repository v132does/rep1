begin
	DBMS_SESSION.SET_IDENTIFIER('SRER');
	pre_ini_aplicacion;
	pae_cnf.g_cod_modulo := 1;
end;
/
Insert into GE_PARAMETROS (PARAMETRO,DESCRIPCION,TAB_RELACION,OBSERVACION,MODIFICABLE) values ('PAG_EXT_MAX_MOVIMIENTOS','PAG_EXT CANTIDAD MAXIMA MOVIMIENTOS','GE_PAR_DINAMICOS','Cantidad máxima de movimientos por cuenta para el insert masivo para la Generación de Extractos','N');
COMMIT;