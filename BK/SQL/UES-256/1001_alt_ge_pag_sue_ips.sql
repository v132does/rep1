begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
ALTER TABLE it.ge_pag_sue_ips 
  ADD nro_lot_referencia NUMBER(20)
  ADD CONSTRAINT uk_nrolot_referencia UNIQUE (nro_lot_referencia);
  COMMENT ON COLUMN it.ge_pag_sue_ips.nro_lot_referencia IS 'Nro de lote de referencia del ente';
  


  
  
