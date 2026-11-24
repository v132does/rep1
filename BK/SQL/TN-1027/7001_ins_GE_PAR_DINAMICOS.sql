begin
	DBMS_SESSION.SET_IDENTIFIER('SRER');
	pre_ini_aplicacion;
	pae_cnf.g_cod_modulo := 1;
end;
/
Insert into GE_PAR_DINAMICOS (PARAMETRO,VAL_PARAMETRO) values ('PAG_EXT_MAX_MOVIMIENTOS','10000');
COMMIT;