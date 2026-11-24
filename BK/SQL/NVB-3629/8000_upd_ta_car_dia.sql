BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END; 
/
update it.ta_car_dia_ing_det a
set error='No se encuentra movimiento'
where a.error is null
and nvl(a.procesado,'N')='N'
and a.con_ajuste not in (select cod_referencia from ta_ref_movimientos_gp where ref_archivo='T3052S');
commit;