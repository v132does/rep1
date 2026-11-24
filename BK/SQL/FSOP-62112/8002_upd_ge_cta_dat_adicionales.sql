BEGIN
  dbms_session.set_identifier('FSOP-62112');
  pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
  
  FOR rec IN (select rowid from ge_cta_dat_adicionales a
               WHERE a.parametro = 'LIM_CRE_TRANSACCIONES'
               AND a.nro_cuenta IN (SELECT b.nro_cuenta
                                      FROM ge_cuentas b
                                     WHERE b.cod_modulo = 3
                                       AND b.cod_modalidad = 334)
               AND a.val_parametro <> '26091432')
  LOOP
   UPDATE ge_cta_dat_adicionales
      SET val_parametro = '26091432'
    WHERE ROWID = rec.rowid;
      
    commit; 
  END LOOP;

END;


