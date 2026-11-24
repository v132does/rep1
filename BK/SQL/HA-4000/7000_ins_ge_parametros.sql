Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION)
values ('COD_CIR_NOT_ONB', 'COD. CIRCUITOS A NOTIFICAR ONB.', 'GE_PAR_DINAMICOS', 'Utilizado en Trigger de wf_circuitos para notificar la creación de wf.');

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION)
values ('DIR_COR_TAR_ONB', 'DIR. CORREO ONB P/TAREA EXPERIENCIA', 'GE_PAR_DINAMICOS', 'Dirección de correo para envio de mail y generación de tarea para Experiencia.');

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION)
values ('HAB_NOT_CIR_ONB', 'HABILITA NOTIFICACION CIR.ONB.', 'GE_PAR_DINAMICOS', 'Indica si habilita o no la notificación por generación de circuitos en onboarding de personas S/N.');


commit;