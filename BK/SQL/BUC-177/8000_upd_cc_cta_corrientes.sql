BEGIN
  pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
  
  FOR rec IN (select rowid from cc_cta_corrientes a
               WHERE  a.nro_cuenta IN ('900658202','900636350','900611371','900593873','900573325','900144620',
                                       '900127285','900100424','900022842','900018447','900016397'))
  LOOP
   
   UPDATE cc_cta_corrientes
      SET sal_blo_batch = sal_bloqueado
    WHERE ROWID = rec.rowid;  
    COMMIT; 
    
  END LOOP;

END;
