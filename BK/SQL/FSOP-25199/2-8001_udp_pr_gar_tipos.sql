BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END;
/
update pr_gar_tipos a 
set a.por_bco_central=70 
where a.cod_garantia in (32,39) ; 

update pr_gar_tipos a 
set a.por_bco_central=80
where a.cod_garantia in (33,40); 

update pr_gar_tipos a 
set a.por_bco_central= 90
where a.cod_garantia in (34,41) ; 

commit; 

