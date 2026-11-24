--inserta PAGO A PROVEEDORES
BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END; 
/

update BW_CLA_LIM_MONTOS t
   set MTO_MAXIMO = 5000000000
 where t.cod_tip_mensaje = '075'
   and t.tip_persona = 'J'
   and t.activo = 'A'
   and t.cod_moneda = 'GS'
   and t.cod_persona is null;
   
commit;


--Actualiza PAGO DE SUELDOS
BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END; 
/
update BW_CLA_LIM_MONTOS t
set t.mto_maximo = 5000000000
 where t.cod_tip_mensaje = '070'
   and t.tip_persona = 'J'
   and t.cod_moneda = 'GS'
   and t.cod_persona is null;
   
commit;.


--Actualiza PAGO DE SERVICIOS
BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END; 
/
update BW_CLA_LIM_MONTOS t
   set t.mto_maximo = 15000000000
 where t.cod_tip_mensaje = '089'
   and t.tip_persona = 'J'
   and t.cod_moneda = 'GS'
   and t.cod_persona is null;
commit;


--Actualiza TRANSFERENCIA ENTRE CUENTAS
BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END; 
/
update BW_CLA_LIM_MONTOS t
   set t.mto_maximo = 20000000000
 where t.cod_tip_mensaje = '030'
   and t.tip_persona = 'J'
   and t.cod_moneda = 'GS'
   and t.cod_persona is null;
   
update BW_CLA_LIM_MONTOS t
   set t.mto_maximo = 3000000
 where t.cod_tip_mensaje = '030'
   and t.tip_persona = 'J'
   and t.cod_moneda = 'USD'
   and t.cod_persona is null;
   
commit;
