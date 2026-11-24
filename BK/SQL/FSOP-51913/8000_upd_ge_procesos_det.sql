BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:= 1; END; 
/

update ge_procesos_det
set formato='CSV'
where COD_PROCESO = 992 
and formato='TXT'
AND NRO_ORDEN IN (1,4);

commit;