EXEC Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;

INSERT INTO ba_programas (cod_programa
                         ,descripcion
                         ,cod_tip_programa
                         ,cod_modulo
                         ,ubi_ejecutable
                         ,ubi_fisico
                         ,des_detallada
                         ,ope_mod_cerrado
                         ,ubi_menu) VALUES('GLREFBAN','REFERENCIA BANCARIA','3','1','Z:\GF10G\EXE','Z:\GF10G\RDF','REFERENCIA BANCARIA', 'S', 'Buscar Programa'); --,ubi_menu)

						 
COMMIT;