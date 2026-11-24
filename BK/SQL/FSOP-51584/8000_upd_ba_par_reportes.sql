-- Se actualiza el parametro de fecha para el reporte de GLSALCLI 

BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END;
/

update IT.ba_par_reportes
   set tipo = 'F'
 where cod_programa = 'GLSALCLI'
   and cod_campo = 'FECHA';

COMMIT;
