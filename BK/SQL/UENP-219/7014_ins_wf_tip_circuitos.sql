begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into wf_tip_circuitos (cod_tip_circuito, descripcion, detalle, estado, cod_obj_base, cod_tar_inicial, referencia, det_sql, cod_programa, cod_modulo, cod_modalidad, nom_par_referencia, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, ref_val_limite)
values (925, 'TRAMITES CHE ROGA', 'Trámites Legales para formalización de Escritura - Che Roga', 'A', 'BA_PER_IMA_DOCUMENTOS', null, null, null, null, 6, 668, 'WK_NRO_REFERENCIA', user, sysdate,user, sysdate, null);

commit;
