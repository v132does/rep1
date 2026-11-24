begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;
/
insert into ge_procesos_det(cod_proceso, nro_orden, descripcion, cod_programa, obligatorio, frecuencia, activo, con_cabecera, sep_campos, sep_texto)
values(660, 1, 'REPROCESO DE INFORME LCR', 'PAS_LCR.PR_PRO_GEN_LCR', 'N', 'D', 'S', 'S', ',', '"');

commit;
