Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

update ah_cta_certificados a
set a.fec_ult_capitalizacion = '28/06/2024'
where a.usu_insercion = 'MIGRAV'
and a.fec_ult_capitalizacion < '28/06/2024'
and a.estado NOT IN ('V','A','T','P','C','X');

commit;
