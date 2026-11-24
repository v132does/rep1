begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_procesos (cod_proceso, descripcion, nro_orden, obligatorio, tipo, hor_inicio, hor_fin, cod_usuario, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, error, permiso)
values (190, 'PR_PRE_CHE_ROGA', 1, 'N', 'P', null, null, null, user, sysdate, user, sysdate, null, 'QA_HOMOLOGACION-QA_HOMOLOGACION ó INFORMATICA-INFORMATICA ó FIELCO_SOPORTETI-SOPORTE TI - CONSULTAS ó FIELCO_JEFCOBRANZ-JEFE COBRANZAS');

commit;
