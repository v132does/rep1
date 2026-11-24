begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/

insert into it.bw_men_respuestas (NOMBRE, DES_MENSAJE, ERROR)
values ('PRO_ERR_PRO_CRE', 'Error en CTA. CRE.', 'S');


insert into it.bw_men_respuestas (NOMBRE, DES_MENSAJE, ERROR)
values ('PRO_ERR_SUE_CRE', 'Error en CTA. CRE.', 'S');

insert into it.bw_men_respuesta (NOMBRE, DES_MENSAJE, ERROR)
values ('PRO_ERR_PRO_CRE', 'Error en CTA. CRE.', 'S');

insert into it.bw_men_respuesta (NOMBRE, DES_MENSAJE, ERROR)
values ('PRO_ERR_SUE_CRE', 'Error en CTA. CRE.', 'S');

commit;


