BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
--Parámetros
insert into ge_retenciones (COD_RETENCION, DESCRIPCION)
values (10, 'DEPOSITOS EFECTIVO 24HS (TED)');

insert into ge_retenciones (COD_RETENCION, DESCRIPCION)
values (11, 'DEPOSITOS EFECTIVO 48HS (TED)');

insert into ge_retenciones (COD_RETENCION, DESCRIPCION)
values (12, 'DEPOSITOS EFECTIVO 72HS (TED)');

commit;
