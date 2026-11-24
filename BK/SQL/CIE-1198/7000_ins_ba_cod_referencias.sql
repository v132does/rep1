begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; pae_cnf.G_PROGRAMA := 'GPPROFIN'; end; 
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('JOBS_PARALELOS', 'Control Job Cierre - PRA_ACT_SAL_PROMEDIO', 'PRA_ACT_SAL_', 'D', '10', 'S');
/
commit;
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('JOBS_PARALELOS', 'Control Job Cierre - PRP_ACT_FEC_SOLICITUDES', 'PRP_ACT_FEC_', 'D', '10', 'S');
/
commit;
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('JOBS_PARALELOS', 'Control Job Cierre - PRP_ACT_DEV_DIARIOS', 'PRP_ACT_DEV_', 'D', '12', 'S');
/
commit;
/
update ge_procesos_det
    set activo = 'N'
  where cod_proceso = 12
    and nro_orden = 31;-- se desactiva DEVENGADO DIARIO PRESTAMOS PRP_ACT_DEV_DIARIOS
/
commit;
