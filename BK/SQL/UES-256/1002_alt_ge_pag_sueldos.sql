begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
ALTER TABLE it.ge_pag_sueldos 
  ADD nro_lot_ips NUMBER(10);
  COMMENT ON COLUMN it.ge_pag_sueldos.nro_lot_ips IS 'Nro de lote ips';
    
