Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('TIEMPO_TIMER_UMBRAL', 'TIEMPO NOTIFICACIONES UMBRAL', 'GE_PAR_DINAMICOS', null, 'Frecuencia en segundos para sondeo de notificaciones de umbral. Si el valor dinámico es 0, el timer queda desactivado (Default 120 seg)', null, null, 'S', '120');

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('HABILITA_NOTIF_UMBRAL', 'HABILITA NOTIFICACIONES UMBRAL', 'GE_PAR_DINAMICOS', null, 'Activa o apaga el sondeo y las alertas de umbral en GCCONPER. S=Activo, N=Inactivo', null, null, 'S', 'S');

COMMIT;
