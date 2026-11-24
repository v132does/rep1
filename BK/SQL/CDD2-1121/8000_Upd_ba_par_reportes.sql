begin 
    pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; 
end; 

update it.ba_par_reportes a set a.cod_campo = 'FEC_VALOR'
where a.cod_programa IN ('LLCOCOHI','LLCOVEHI' ) 
and  a.cod_campo ='FECHA';


COMMIT;