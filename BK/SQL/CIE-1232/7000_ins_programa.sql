begin
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;
end;
/

INSERT
  INTO ba_programas(cod_programa, descripcion, cod_tip_programa, cod_modulo, ubi_ejecutable, ubi_fisico, des_detallada, cod_herramienta, observacion, ope_mod_cerrado, cod_pro_equivalente, documento, ubi_menu, ina_cierre)
  SELECT 'PAC_SOB.PR_LIQ_SOB_BATCH',
         'PROCESO DE LIQUIDACION DE SOBREGIROS (CIERRE)',
         cod_tip_programa,
         cod_modulo,
         ubi_ejecutable,
         ubi_fisico,
         des_detallada,
         cod_herramienta,
         'Ejecucion batch equivalente a PRC_LIQ_SOBREGIROS',
         ope_mod_cerrado,
         cod_pro_equivalente,
         documento,
         ubi_menu,
         ina_cierre
    FROM ba_programas
   WHERE cod_programa = 'PRC_LIQ_SOBREGIROS';
commit;
UPDATE ge_procesos_det
   SET cod_programa     = 'PAC_SOB.PR_LIQ_SOB_BATCH',
       descripcion      = 'LIQUIDACION SOBREGIROS CIERRE',
       usu_modificacion = USER,
       fec_modificacion = SYSDATE
 WHERE cod_proceso = 11
   AND nro_orden = 248
   AND cod_programa = 'PRC_LIQ_SOBREGIROS';
   
   COMMIT;
