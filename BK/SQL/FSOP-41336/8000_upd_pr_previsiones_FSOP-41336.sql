BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/ 
UPDATE pr_previsiones p 
SET tot_cap_pri_prevision = 0, 
    tot_cap_seg_prevision = 0, 
    tot_int_pri_prevision = 0, 
    tot_int_seg_prevision = 0 
WHERE fecha = '28/06/2024' 
AND nro_cuenta IN('2915559',
                  '2915711',
                  '2917571',
                  '2917477',
                  '2915639',
                  '2919392',
                  '2915674');

COMMIT;
