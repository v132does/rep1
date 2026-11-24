begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

--Actualizar estado.
update IT.CJ_TIP_VALORES a
set a.estado = 'N'
where a.cod_moneda = 'BRL'
  and a.cod_tip_valor = 34;

--Actualizar nro_orden
update IT.CJ_TIP_VALORES a
set a.nro_orden = 2
where a.cod_moneda = 'BRL'
  and a.cod_tip_valor = 28;
  

update IT.CJ_TIP_VALORES a
set a.nro_orden = 3
where a.cod_moneda = 'BRL'
  and a.cod_tip_valor = 29;  
  

update IT.CJ_TIP_VALORES a
set a.nro_orden = 4
where a.cod_moneda = 'BRL'
  and a.cod_tip_valor = 30;  
  

update IT.CJ_TIP_VALORES a
set a.nro_orden = 5
where a.cod_moneda = 'BRL'
  and a.cod_tip_valor = 31;  
  

update IT.CJ_TIP_VALORES a
set a.nro_orden = 6
where a.cod_moneda = 'BRL'
  and a.cod_tip_valor = 32;  
  

update IT.CJ_TIP_VALORES a
set a.nro_orden = 7
where a.cod_moneda = 'BRL'
  and a.cod_tip_valor = 33;  

commit; 
