begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; pae_cnf.G_PROGRAMA := 'GPPROFIN'; end; 
/
--insertamos el nuevo proceso que correrá en paralelo luego del PRA_ACT_CUENTAS
insert into ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, COD_PROCESO_PRE, COD_PROGRAMA_PRE, TIPO, OBSERVACION)
values (11, 'PRE_EJE_DEPURACION(1)', 11, 'PRA_ACT_CUENTAS', 'P', 'El proceso PRE_EJE_DEPURACION(1) debe lanzarse al finalizar el PRA_ACT_CUENTAS.');
/
--el nuevo proceso debe finalizar antes del PRG_TRA_HISTORICO
insert into ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, COD_PROCESO_PRE, COD_PROGRAMA_PRE, TIPO, OBSERVACION)
values (11, 'PRG_TRA_HISTORICO', 11, 'PRE_EJE_DEPURACION(1)', 'F', 'El proceso PRG_TRA_HISTORICO no debe de iniciar sin que finalice el PRE_EJE_DEPURACION(1)');
/
commit;
/
--actualizamos el nuevo cod_programa del registro existente
update ge_procesos_dep
  set cod_programa = 'PRE_EJE_DEPURACION(2)'
 where cod_programa = 'PRE_EJE_DEPURACION';
/
commit;
/
--actualizamos el nuevo cod_programa del registro existente
update ge_procesos_dep
  set cod_programa = 'PRE_EJE_DEPURACION(2)'
 where cod_programa = 'PRG_AUD_TRIGGERS(''H'')';
/
commit;
/
--modificamos la nueva dependencia de fin del PRA_GEN_ASI_AUTOMATICOS
update ge_procesos_dep
  set cod_programa = 'PRE_EJE_DEPURACION(1)'
 where cod_programa = 'PRA_GEN_ASI_AUTOMATICOS';
/
commit;
