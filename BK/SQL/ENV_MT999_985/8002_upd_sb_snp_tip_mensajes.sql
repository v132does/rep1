begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update sb_snp_tip_mensajes m
   set m.obj_proceso = 'PAS_SNP.FU_REG_MSJ_GENERICO',
       m.tipo = 'R',
       m.descripcion = 'Mensaje de Reporte de Estado y Totales'
 where m.cod_mensaje = 'MT986';

commit;
