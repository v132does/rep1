begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into bw_tip_mensajes (COD_TIP_MENSAJE, DESCRIPCION, CONSULTA, INGRESA, AUTORIZA, DIR_MAIL, NOM_FUNCION, INTERNO, AFE_WEB, AFE_TAS, AFE_IVR, AFE_MOVIL)
values ('300', 'DEBITO AUTOMATICO', 'S', 'S', 'S', null, null, 'N', 'S', null, null, null);

commit;
