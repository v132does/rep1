Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ge_procesos_det (COD_PROCESO, NRO_ORDEN, DESCRIPCION, COD_PROGRAMA, OBLIGATORIO, FRECUENCIA, HOR_INICIO, HOR_FIN, COD_USUARIO, ERROR, DIR_DESTINATARIO, ACTIVO, FORMATO, CLAVE, CON_COPIA, NOM_ARCHIVO, CON_CABECERA, SEP_CAMPOS, SEP_TEXTO, VAR_SUSTITUCION)
values (47, 1, 'GEN. BLOQUEO DE SOBREGIROS VENCIDOS', 'PRG_BLO_VEN_SOBREGIROS', 'S', 'D', null, null, null, null, null, 'S', null, null, null, null, 'S', ',', '"', null);

commit;
