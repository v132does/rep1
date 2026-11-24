begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
update ah_cta_vistas a
set a.fec_ult_capitalizacion = '31/12/2023'
where a.nro_cuenta = 61995395;
commit;
