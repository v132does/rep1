begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
update sb_snp_campos t
set t.ind_requerido = 'N'
where t.cod_mensaje = 'MT548'
and t.campo = '97A'
and t.ind_requerido = 'S';

update sb_snp_campos t
set t.ind_requerido = 'N'
where t.cod_mensaje = 'MT548'
and t.campo = '16S'
and t.orden in (51, 54)
and t.ind_requerido = 'S';

update sb_snp_campos t
set t.ind_requerido = 'N'
where t.cod_mensaje = 'MT548'
and t.campo = '16R'
--and t.orden = 52
AND T.DESCRIPCION = 'SETPRTY'
and t.ind_requerido = 'S'; 

update sb_snp_campos t 
set t.ind_detalle = 'S'
where t.cod_mensaje = 'MT506'
and t.campo in ('35B','36B')
and t.ind_requerido = 'S';
/
commit;
