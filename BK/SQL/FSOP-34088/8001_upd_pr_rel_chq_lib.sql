begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;  
/
update pr_rel_chq_lib p 
set p.cod_banco = 46
where p.cod_banco =39;  

commit;