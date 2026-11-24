Begin pre_ini_aplicacion; end; 
/
update ge_modalidades a 
set a.descripcion = 'Plan U'
where a.cod_modulo = 6
and a.cod_modalidad = 705;

commit;
