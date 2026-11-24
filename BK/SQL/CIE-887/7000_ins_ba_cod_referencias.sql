begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; pae_cnf.G_PROGRAMA := 'GPPROFIN'; end; 
/
-- Configuración para el Job de Capitalización
INSERT INTO ba_cod_referencias (
    dominio, significado, val_minimo, abreviatura, activo
) VALUES (
    'JOBS_PARALELOS', 
    'Contiene los jobs que corren en paralelo durante el cierre y que no están registrados dentro de la cadena de cierre. Este Job corresponde al de No Capitalización', 
    'JOB_CTA_NO_CAP_', -- val_minimo: Prefijo
    'PRA_CAP_CTA_VISTA', -- abreviatura: p_cod_programa programa desde el cual el job es lanzado
    'S'
);
--insercion de los procesos nuevos a ba_programas
INSERT INTO BA_PROGRAMAS (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, OBSERVACION,OPE_MOD_CERRADO, UBI_MENU, INA_CIERRE)
VALUES ('PRG_VER_JOB_DINAMICO', 'VERIFICA JOB DINAMICO', 4, 3, 'BASE DE DATOS', 'BASE DE DATOS', 'Procedimiento que controla el estado de la ejecución de los jobs',null,'S', ' ', 'N');
/
INSERT INTO BA_PROGRAMAS (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, OBSERVACION,OPE_MOD_CERRADO, UBI_MENU, INA_CIERRE)
VALUES ('PRG_VER_JOB_CIERRE', 'VERIFICA JOB DINAMICO', 4, 3, 'BASE DE DATOS', 'BASE DE DATOS', 'Procedimiento que se ejecuta en el cierre e invoca al PRG_VER_JOB_DINAMICO',null,'S', ' ', 'N');
/
--insercion del proceso nuevo a la cadena de cierre con obligatoriedad 'N' y frecuencia 'D'
insert into ge_procesos_det (COD_PROCESO, NRO_ORDEN, DESCRIPCION, COD_PROGRAMA, OBLIGATORIO, FRECUENCIA, HOR_INICIO, HOR_FIN, COD_USUARIO, ERROR, DIR_DESTINATARIO, ACTIVO, FORMATO, CLAVE, CON_COPIA, NOM_ARCHIVO, CON_CABECERA, SEP_CAMPOS, SEP_TEXTO, VAR_SUSTITUCION)
values (11, 994, 'VERIFICA JOB DINAMICO', 'PRG_VER_JOB_CIERRE', 'N', 'D', null, null, null, null, null, 'S', null, null, null, null, 'S', ',', '"', null);
/
commit;
