begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
INSERT INTO IT.GE_PARAMETROS (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE) VALUES
('ACT_DEB_AUT_PAGSUE', 'ACTIVAR DEBITO AUTOMATICO EN PAGSUE', 'GE_PAR_DINAMICOS', 'Activar debito automatico en Pago de salarios', 'N');

commit;