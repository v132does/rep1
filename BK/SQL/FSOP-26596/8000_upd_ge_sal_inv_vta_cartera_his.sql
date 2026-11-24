begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/  
update ge_entes g
set g.descripcion = 'UENO HOLDING S.A.E.C.A'
where g.cod_ente = 17;

update ge_entes g
set g.descripcion = 'VINANZAS S.A.'
where g.cod_ente = 3452;
  
update ge_cta_dat_adicionales s
set s.val_parametro = '17 - UENO HOLDING S.A.E.C.A'
where s.parametro = 'ENT_ADM_CARTERA' and s.val_parametro = '9811 - UENO HOLDING S.A.E.C.A';
 
update ge_sal_inv_vta_cartera_his d
set d.cod_ente = 17
where d.cod_ente = 9811;

update pr_vta_carteras p
set p.cod_ente = 17
where p.cod_ente = 9811;
  
commit;
