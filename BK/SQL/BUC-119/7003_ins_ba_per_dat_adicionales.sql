Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/ 
INSERT
  INTO ba_per_dat_adicionales(cod_persona, parametro, val_parametro)
  SELECT p.cod_persona, 'EXC_VAL_EFE_CAM_CAJA', 'S'
    FROM ba_personas p
   WHERE p.nro_documento IN ('80047977-7',
                             '80025401-5',
                             '80027005-3',
                             '80039157-8',
                             '80028818-1',
                             '80062853-5',
                             '80085427-6',
                             '80053857-9',
                             '80020956-7',
                             '80098897-3',
                             '80053955-9',
                             '80052397-0',
                             '80028928-5',
                             '80086759-9',
                             '80007706-7',
                             '80018076-3');
COMMIT;
