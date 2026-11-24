begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
---cheques rechazados
update ge_archivos
   set archivo = 'CDEV_TR1046.TXT'
 where referencia = 'CHE_RECHAZADOS';

update ge_arc_campos
   set archivo = 'CDEV_TR1046.TXT'
 where referencia = 'CHE_RECHAZADOS';

update ge_arc_tablas
set archivo = 'CDEV_TR1046.TXT'
where referencia = 'CHE_RECHAZADOS';
----------------1-------------------
   
update ge_archivos
   set archivo = 'CDEV_TR1046_USD.TXT'
 where referencia = 'CHE_RECHAZADOS_USD';

update ge_arc_campos
   set archivo = 'CDEV_TR1046_USD.TXT'
 where  referencia = 'CHE_RECHAZADOS_USD';

update ge_arc_tablas
set archivo = 'CDEV_TR1046_USD.TXT'
where referencia = 'CHE_RECHAZADOS_USD';

----------------2--------------------
update ge_archivos
   set archivo = 'CENVRMT0046.TXT'
 where referencia = 'CHE_ENV_PRODEP';

update ge_arc_campos
   set archivo = 'CENVRMT0046.TXT'
 where referencia = 'CHE_ENV_PRODEP';

update ge_arc_tablas
set archivo = 'CENVRMT0046.TXT'
where referencia = 'CHE_ENV_PRODEP';
---------------3------------------------
update ge_archivos
   set archivo = 'CENVRMT0046_USD.TXT'
 where referencia = 'CHE_ENV_PRODEP_USD';

update ge_arc_campos
   set archivo = 'CENVRMT0046_USD.TXT'
 where referencia = 'CHE_ENV_PRODEP_USD';

update ge_arc_tablas
set archivo = 'CENVRMT0046_USD.TXT'
 where referencia = 'CHE_ENV_PRODEP_USD';

----------------4------------------
update ge_archivos
   set archivo = 'CREC1046.TXT'
 where referencia = 'CHE_REC_BCP';

update ge_arc_campos
   set archivo = 'CREC1046.TXT'
 where referencia = 'CHE_REC_BCP';

update ge_arc_tablas
   set archivo = 'CREC1046.TXT'
 where referencia = 'CHE_REC_BCP';
 -----------------5----------------

update ge_archivos
   set archivo = 'CREC1046_USD.TXT'
 where referencia = 'CHE_REC_BCP_USD';

update ge_arc_campos
    set archivo = 'CREC1046_USD.TXT'
 where referencia = 'CHE_REC_BCP_USD';

update ge_arc_tablas
   set archivo = 'CREC1046_USD.TXT'
 where referencia = 'CHE_REC_BCP_USD';
---------------6--------------

commit;


