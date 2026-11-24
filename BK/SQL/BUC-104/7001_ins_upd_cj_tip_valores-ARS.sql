begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
--Actualizar estado
update IT.CJ_TIP_VALORES a
set a.estado = 'N'
where a.cod_moneda = 'ARS'
  and a.cod_tip_valor in (25,26,27);
  
--Actualizar nro_orden
update IT.CJ_TIP_VALORES a
set a.nro_orden = 4
where a.cod_moneda = 'ARS'
  and a.cod_tip_valor = 69;
  
  
update IT.CJ_TIP_VALORES a
set a.nro_orden = 5
where a.cod_moneda = 'ARS'
  and a.cod_tip_valor = 68;


update IT.CJ_TIP_VALORES a
set a.nro_orden = 7
where a.cod_moneda = 'ARS'
  and a.cod_tip_valor = 22;


update IT.CJ_TIP_VALORES a
set a.nro_orden = 8
where a.cod_moneda = 'ARS'
  and a.cod_tip_valor = 23; 
  

update IT.CJ_TIP_VALORES a
set a.nro_orden = 9
where a.cod_moneda = 'ARS'
  and a.cod_tip_valor = 24; 
  
update IT.CJ_TIP_VALORES a
set a.nro_orden = 10
where a.cod_moneda = 'ARS'
  and a.cod_tip_valor = 62; 
  
--insertar biletes 2.000, 10.000 y 20.000)
insert into IT.CJ_TIP_VALORES (COD_TIP_VALOR, DESCRIPCION, COD_MONEDA, VALOR, NRO_ORDEN, TIPO, FOR_TOTAL)
values (72, 'Billetes de 20.000', 'ARS', 20000.00, 1, 'B', 'C');

insert into IT.CJ_TIP_VALORES (COD_TIP_VALOR, DESCRIPCION, COD_MONEDA, VALOR, NRO_ORDEN, TIPO, FOR_TOTAL)
values (73, 'Billetes de 10.000', 'ARS', 10000.00, 2, 'B', 'C');

insert into IT.CJ_TIP_VALORES (COD_TIP_VALOR, DESCRIPCION, COD_MONEDA, VALOR, NRO_ORDEN, TIPO, FOR_TOTAL)
values (74, 'Billetes de 2.000', 'ARS', 2000.00, 3, 'B', 'C');

insert into IT.CJ_TIP_VALORES (COD_TIP_VALOR, DESCRIPCION, COD_MONEDA, VALOR, NRO_ORDEN, TIPO, FOR_TOTAL)
values (75, 'Billetes de 200', 'ARS', 200.00, 6, 'B', 'C');

commit;
