BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

    INSERT INTO ba_par_consultas (cod_consulta,cod_campo,alias,tipo,nro_orden)
    values ('CD_FE_LOG','FE_FEC_LOG',NULL,'F',1); 
    
    INSERT INTO ba_par_consultas (cod_consulta,cod_campo,alias,tipo,nro_orden)
    values ('CD_FE_REC','FE_FEC_REC','CLV','F',1);

commit;
