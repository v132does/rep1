begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

 update it.ge_par_dinamicos c
     set c.val_parametro = 'FIELPRODPRDCDB01'
   where c.parametro = 'BA_PRO_CRC_CONTROL';

 update it.ge_par_dinamicos c
     set c.val_parametro = 'DEVCDB01'
   where c.parametro = 'BA_OBJ_CRC_MENSUAL';

     
commit;
