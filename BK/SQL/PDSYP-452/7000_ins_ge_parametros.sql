begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('HAB_NOT_ENTES', 'HAB. NOT. PARA ENTES', 'GE_PAR_DINAMICOS', 'Lista de códigos de ente habilitados para el envío de notificaciones a empleados durante el pago de salarios. Formatos válidos: códigos separados por doble numeral (##) o numeral simple (#). Ejemplos: #123##3234##1234# o #123#1324#4321#. Nota: La lista debe comenzar y terminar obligatoriamente con #.', 'N');

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('HAB_NOT_PAG_SALARIO', 'HAB. NOT. PAG. SALARIO', 'GE_PAR_DINAMICOS', 'Habilita Notificacion para pago de salarios', 'N');


insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('HAB_NOT_ENTES', '##');


insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('HAB_NOT_PAG_SALARIO', 'N');

commit;
