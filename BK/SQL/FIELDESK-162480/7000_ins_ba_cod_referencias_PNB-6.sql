begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;
/

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, val_maximo, activo)
values('SAL_EFE', 'Variable para Salida de Efectivo - LCR', sysdate, user, user, sysdate, '1', 'DEPOSITOS MINORISTAS', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, val_maximo, activo)
values('SAL_EFE', 'Variable para Salida de Efectivo - LCR', sysdate, user, user, sysdate, '2', 'DEPOSITOS MAYORISTAS', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, val_maximo, activo)
values('SAL_EFE', 'Variable para Salida de Efectivo - LCR', sysdate, user, user, sysdate, '3', 'SIN CATEGORIA', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, val_maximo, activo)
values('SAL_EFE', 'Variable para Salida de Efectivo - LCR', sysdate, user, user, sysdate, '4', 'MENORES A 500 SALARIOS MINIMOS MENSUALES', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, val_maximo, activo)
values('SAL_EFE', 'Variable para Salida de Efectivo - LCR', sysdate, user, user, sysdate, '5', 'IGUALES O MAYORES  A 500 SALARIOS MÍNIMOS MENSUALES', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, val_maximo, activo)
values('SAL_EFE', 'Variable para Salida de Efectivo - LCR', sysdate, user, user, sysdate, '6', 'ESTABLE', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, val_maximo, activo)
values('SAL_EFE', 'Variable para Salida de Efectivo - LCR', sysdate, user, user, sysdate, '7', 'MENOS ESTABLE', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, val_maximo, activo)
values('SAL_EFE', 'Variable para Salida de Efectivo - LCR', sysdate, user, user, sysdate, '8', 'OTROS', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, val_maximo, activo)
values('SAL_EFE', 'Variable para Salida de Efectivo - LCR', sysdate, user, user, sysdate, '9', 'VISTA', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, val_maximo, activo)
values('SAL_EFE', 'Variable para Salida de Efectivo - LCR', sysdate, user, user, sysdate, '10', 'DEPOSITOS CON UN PLAZO RESIDUAL MENOR O IGUAL A 30 DIAS', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, val_maximo, activo)
values('SAL_EFE', 'Variable para Salida de Efectivo - LCR', sysdate, user, user, sysdate, '11', 'DEPOSITOS A PLAZO CON VENCIMIENTO RESIDUAL SUPERIOR A 30 DIAS', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, activo)
values('SOCIEDADES_VALORES', 'Variable para Casas de Bolsas y Fondos de Inv. - LCR', sysdate, user, user, sysdate, '353497', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, activo)
values('SOCIEDADES_VALORES', 'Variable para Casas de Bolsas y Fondos de Inv. - LCR', sysdate, user, user, sysdate, '8890470', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, activo)
values('SOCIEDADES_VALORES', 'Variable para Casas de Bolsas y Fondos de Inv. - LCR', sysdate, user, user, sysdate, '9379086', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, activo)
values('SOCIEDADES_VALORES', 'Variable para Casas de Bolsas y Fondos de Inv. - LCR', sysdate, user, user, sysdate, '8282474', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, activo)
values('SOCIEDADES_VALORES', 'Variable para Casas de Bolsas y Fondos de Inv. - LCR', sysdate, user, user, sysdate, '8582449', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, activo)
values('SOCIEDADES_VALORES', 'Variable para Casas de Bolsas y Fondos de Inv. - LCR', sysdate, user, user, sysdate, '9452865', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, activo)
values('SOCIEDADES_VALORES', 'Variable para Casas de Bolsas y Fondos de Inv. - LCR', sysdate, user, user, sysdate, '2665235', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, activo)
values('SOCIEDADES_VALORES', 'Variable para Casas de Bolsas y Fondos de Inv. - LCR', sysdate, user, user, sysdate, '2666491', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, activo)
values('SOCIEDADES_VALORES', 'Variable para Casas de Bolsas y Fondos de Inv. - LCR', sysdate, user, user, sysdate, '1557890', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, activo)
values('SOCIEDADES_VALORES', 'Variable para Casas de Bolsas y Fondos de Inv. - LCR', sysdate, user, user, sysdate, '1558310', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, activo)
values('SOCIEDADES_VALORES', 'Variable para Casas de Bolsas y Fondos de Inv. - LCR', sysdate, user, user, sysdate, '8283546', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, activo)
values('SOCIEDADES_VALORES', 'Variable para Casas de Bolsas y Fondos de Inv. - LCR', sysdate, user, user, sysdate, '9551035', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, activo)
values('SOCIEDADES_VALORES', 'Variable para Casas de Bolsas y Fondos de Inv. - LCR', sysdate, user, user, sysdate, '8912977', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, activo)
values('SOCIEDADES_VALORES', 'Variable para Casas de Bolsas y Fondos de Inv. - LCR', sysdate, user, user, sysdate, '545444', 'S');

insert into ba_cod_referencias(dominio, significado, fec_insercion, usu_insercion, usu_modificacion, fec_modificacion, val_minimo, activo)
values('SOCIEDADES_VALORES', 'Variable para Casas de Bolsas y Fondos de Inv. - LCR', sysdate, user, user, sysdate, '487040', 'S');

commit;
