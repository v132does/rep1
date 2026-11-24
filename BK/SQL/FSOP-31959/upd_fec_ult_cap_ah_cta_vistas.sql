Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update ah_cta_vistas a 
set a.fec_ult_capitalizacion = '28/06/2024'
where a.fec_ult_capitalizacion <= '28/06/2024' and a.usu_insercion = 'MIGRAV';
commit;
