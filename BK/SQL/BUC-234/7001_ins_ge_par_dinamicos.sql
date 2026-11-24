Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
INSERT INTO ge_par_dinamicos
  (parametro, val_parametro)
VALUES
  ('TIEMPO_TIMER_UMBRAL', '120');
  
INSERT INTO ge_par_dinamicos
  (parametro, val_parametro)
VALUES
  ('HABILITA_NOTIF_UMBRAL', 'S');
  
COMMIT;
