Begin PRE_INI_APLICACION;PAE_CNF.G_COD_MODULO:=1;End;
/
truncate table it.ta_logs;

delete ta_sucursales where cod_ent_procesadora = 7;

INSERT INTO ta_sucursales
   (cod_ent_procesadora, cod_sucursal, descripcion, abreviatura, cod_oficina, activo)
VALUES(7, 61, 'Insertado Automaticamente por Proceso', 'IAP', 61, 'S');

commit;
