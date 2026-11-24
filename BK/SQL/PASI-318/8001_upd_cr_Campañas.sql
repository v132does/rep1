Begin pre_ini_aplicacion; end; 
/
update cr_campanas a 
set a.descripcion = 'Campaña Plan U'
where a.cod_campana = 81;

commit;
