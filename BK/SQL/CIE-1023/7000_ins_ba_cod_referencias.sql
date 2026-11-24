begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; pae_cnf.G_PROGRAMA := 'GPPROFIN'; end;
/
-- Configuración para el Job de ELIMINAR CTAS. CANCELADAS DEL DIA
INSERT INTO ba_cod_referencias (
dominio,
significado,
val_minimo,
activo
) VALUES (
'JOBS_PARALELOS', -- dominio
'Contiene los jobs que corren en paralelo durante el cierre y que no están registrados dentro de la cadena de cierre. Este Job ejecuta el PRP_PRO_INI_PRE', -- significado: detalle breve
'JOB_DAILY_PRP_PRO_INI_PRE', -- val_minimo: Nombre del job
'S'
);
/
commit;
/
delete from ge_procesos_det
where cod_proceso = 11
and nro_orden = 94;--se elimina el PRP_PRO_INI_PRE del cierre
/
commit;
