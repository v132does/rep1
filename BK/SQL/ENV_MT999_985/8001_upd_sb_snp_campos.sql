begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update sb_snp_campos c
   set c.ind_requerido = 'N',
       c.formato = NULL
 where c.cod_mensaje = 'MT986'
   and c.campo = 79
   and c.orden between 6 and 15;
   
commit;
   
update sb_snp_campos c
   set c.ind_requerido = 'N'
 where c.cod_mensaje = 'MT986'
   and c.campo = 59
   and c.orden = 4;

commit;
