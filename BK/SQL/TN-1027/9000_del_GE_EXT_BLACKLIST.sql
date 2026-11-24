begin
	DBMS_SESSION.SET_IDENTIFIER('SRER');
	pre_ini_aplicacion;
	pae_cnf.g_cod_modulo := 1;
end;
/
delete
from ge_Ext_blacklist
where cod_persona not in ('1', '172320');
COMMIT;