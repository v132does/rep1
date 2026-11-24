BEGIN 
PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1;
DBMS_SESSION.SET_IDENTIFIER('SRER-1847');

 END;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('MDD_MAD_ENCAJE', 'M', 'GE_PAR_DINAMICOS', null, 'EVERA', to_date('09-03-2026 14:33:01', 'dd-mm-yyyy hh24:mi:ss'), 'EVERA', to_date('09-03-2026 14:33:41', 'dd-mm-yyyy hh24:mi:ss'), 'Define las modalidades de Mesa de Dinero Informables en el Encaje', null, null, 'N', null);

commit; 
