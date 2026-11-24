begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/

insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('GMSNPEND', 'ENVIO DE ENCAJE MT999 SIPAP', 1, 3, 'WL:\GF11G\EXE', 'SVN:\GF11G\RDF', 'Permite realizar el envio de encaje MT999 SIPAP', null, null, user, SYSDATE, user, SYSDATE, 'S', null, '<BLOB>', 'Operaciones => SIPAP => X-Adapter =>', 'N');

commit;
