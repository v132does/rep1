begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; pae_cnf.G_PROGRAMA := 'GPPROFIN'; end;
/
-- Limpiamos registros previos de prueba para evitar duplicados
DELETE FROM ba_cod_referencias WHERE dominio = 'JOBS_PARALELOS';--1 registro afectado
/
-- Configuración para el Job de Capitalización
INSERT INTO ba_cod_referencias (
dominio,
significado,
val_minimo,
abreviatura,
activo
) VALUES (
'JOBS_PARALELOS', -- dominio
'Contiene los jobs que corren en paralelo durante el cierre y que no están registrados dentro de la cadena de cierre. Este Job corresponde al de No Capitalización, ejecutado desde el PRA_CAP_CTA_VISTA', -- significado: detalle breve
'JOB_CTA_NO_CAP_', -- val_minimo: Nombre del job
'PRA_CAP_CTA_VISTA_CIERRE', -- abreviatura: nombre del proceso que genera el job y que se encuentra dentro de ge_procesos_det
'S'
);
/
commit;
