 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:= 1; END; 
/


insert into ge_par_dinamicos (parametro,val_parametro,cod_modulo,cod_modalidad,cod_oficina) values ('VAL_ANO_TAS_HIP_RES12',3,null,null,null);

commit;