begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; pae_cnf.G_PROGRAMA := 'GPPROFIN'; end; 
/
update ba_cod_referencias
   set val_maximo = 'D',--frecuencia diara
       abreviatura = '11',--ciclo 11 (cierre)
       significado = 'Control Job Cierre - PRP_PRO_INI_PRE',
       val_minimo = 'PRP_INI_PRE_'--nuevo nombre
 where dominio = 'JOBS_PARALELOS'
   and val_minimo = 'JOB_DAILY_PRP_PRO_INI_PRE';--1 registro afectado
/
commit;
