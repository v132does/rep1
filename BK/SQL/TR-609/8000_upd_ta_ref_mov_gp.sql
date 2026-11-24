BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; End; 
/
UPDATE ta_ref_movimientos_gp a
SET a.procesa = 'S'
WHERE a.procesa IS NULL;
COMMIT;
