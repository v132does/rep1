begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros(parametro,
                          descripcion,
                          tab_relacion,
                          observacion,
                          permiso)
                  values('CTA_AHP_EXCLUIR', 
                         'Cuentas con error Ahorro Programado', 
                         'GE_PAR_DINAMICOS', 
                         'Cuentas con error en el cierre, aqui configuramos para excluir del proceso PAA_PRO.PR_PAG_AHO_PROGRAMADO y continuar el cierre diario.'||chr(10)||
                         'Configurar las cuentas sin espacios y entre comas (al inicio y final).'||chr(10)||
                         'Ej: ,123456,654987,',
                         'CIERRE-CIERRE DE MODULO');
commit;
