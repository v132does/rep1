begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
 
insert into it.ge_par_entes
  (cod_ente, parametro, val_parametro)
values
  (5037, 'COD_TRA_PAD_AHO_JUB', '9836');    
  
insert into it.ge_par_entes
  (cod_ente, parametro, val_parametro)
values
  (5037, 'COD_TRA_PAD_CTE_JUB', '9838'); 
     
insert into it.ge_par_entes
  (cod_ente, parametro, val_parametro)
values
  (5037, 'COD_TRA_AHO_JUB', '9825');  
  
insert into it.ge_par_entes
  (cod_ente, parametro, val_parametro)
values
  (5037, 'COD_TRA_CTE_JUB', '9827');  

insert into it.ge_par_entes
  (cod_ente, parametro, val_parametro)
values
  (5037, 'COD_TRA_AHO_PRE', '9830'); 

insert into it.ge_par_entes
  (cod_ente, parametro, val_parametro)
values
  (5037, 'COD_TRA_CTE_PRE', '9832'); 
   
insert into it.ge_par_entes
  (cod_ente, parametro, val_parametro)
values
  (5037, 'COD_TRA_AHO_SUE', '9831'); 
  
insert into it.ge_par_entes
  (cod_ente, parametro, val_parametro)
values
  (5037, 'COD_TRA_CTE_SUE', '9833');   
 
insert into it.ge_par_entes
  (cod_ente, parametro, val_parametro)
values
  (5037, 'COD_TRA_DEB_IPS', '503');  
  
 insert into it.ge_par_entes
  (cod_ente, parametro, val_parametro)
values
  (5037, 'NRO_CTA_DEB_JUB', '900240025');
  
insert into it.ge_par_entes
  (cod_ente, parametro, val_parametro)
values
  (5037, 'NRO_CTA_DEB_PRE', '900168983');
  
insert into it.ge_par_entes
  (cod_ente, parametro, val_parametro)
values
  (5037, 'NRO_CTA_DEB_SUE', '900240032');  

commit;
