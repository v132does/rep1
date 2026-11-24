Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into BA_CONSULTAS (COD_CONSULTA, DESCRIPCION, COD_USUARIO, TIPO, PERMISO, OBSERVACION, DET_SQL, FILTROS, COL_CORTES, COL_SUMAS)
values ('CD_DEV_CAR', 'CONSULTA LOG DEVOLUCION CARGOS - TARJETAS', null, 'P', null,'Consulta logs Proceso Devolución de Cargos Tarjetas.', 'SELECT t.nro_cuenta      nro_cuenta,
       t.tipo_movimiento tipo_movimiento,
       t.desc_movimiento desc_movimiento,
       t.monto           monto,
       t.cod_tra_padre   cod_tra_padre,
       t.cod_transaccion cod_transaccion,
       t.cod_ofi_origen  cod_ofi_origen,
       t.fecha           fecha,
       t.fecha_hora      fecha_hora,
       t.cod_usuario     cod_usuario,
       t.procesado       procesado,
       t.mensaje_error   mensaje_error
  FROM (SELECT t.nro_cuenta,
               t.tipo_movimiento,
               t.desc_movimiento,
               t.monto,
               t.cod_tra_padre,
               t.cod_transaccion,
               t.cod_ofi_origen,
               to_char(t.fecha, ''dd/mm/yyyy'') fecha,
               t.fecha fecha_hora,
               t.cod_usuario,
               t.procesado,
               t.error mensaje_error
          FROM tm_dev_car_tarjetas t) t
 WHERE  &'||'P_FILTROS
 ORDER BY 1,8', null, null, null);

commit;
