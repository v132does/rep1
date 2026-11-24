begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
--Actualizar estado
update IT.CJ_TIP_VALORES a
set a.estado = 'N'
where a.cod_moneda = 'GS'
  and a.cod_tip_valor = 10;
  
  
--Actualizar nro_orden
update IT.CJ_TIP_VALORES a
set a.nro_orden = 12
where a.cod_moneda = 'GS'
  and a.cod_tip_valor = 10;
  

update IT.CJ_TIP_VALORES a
set a.nro_orden = 13
where a.cod_moneda = 'GS'
  and a.cod_tip_valor = 11;
  

update IT.CJ_TIP_VALORES a
set a.nro_orden = 14
where a.cod_moneda = 'GS'
  and a.cod_tip_valor = 12;
  

update IT.CJ_TIP_VALORES a
set a.nro_orden = 15
where a.cod_moneda = 'GS'
  and a.cod_tip_valor = 13;
  

update IT.CJ_TIP_VALORES a
set a.nro_orden = 16
where a.cod_moneda = 'GS'
  and a.cod_tip_valor = 60;


insert into IT.CJ_TIP_VALORES (COD_TIP_VALOR, DESCRIPCION, COD_MONEDA, VALOR, NRO_ORDEN, TIPO, FOR_TOTAL)
values (71, 'Moneda de 50', 'GS', 50.00, 11, 'M', 'C');

commit; 
