create or replace procedure it.prg_gen_dat_his_acc_roles is
  v_fecha date := pag_cal.FU_OBT_FEC_ACTUAL(1);
begin
  -- Author  : Christian Leiva
  -- Created : 28/03/2014
  -- Purpose : Realiza una copia del respaldo de tablas de roles y permisos.
  
  --Eliminacion de Resgistros del Dia--
  delete from ba_usu_roles_his a    ;-- where a.fecha = v_fecha;
  delete from ba_rol_programas_his a;-- where a.fecha = v_fecha;
  delete from ge_tra_roles_his a    ;-- where a.fecha = v_fecha;
  delete from ge_parametros_his a   ;-- where a.fecha = v_fecha;
  delete from ge_procesos_his a     ;-- where a.fecha = v_fecha;
  delete from ba_consultas_his a    ;-- where a.fecha = v_fecha;

  --Inserción de datos--
  insert into ba_usu_roles_his
  (fecha, cod_rol, cod_usuario,  usu_insercion,  fec_insercion,  usu_modificacion, fec_modificacion)
  select v_fecha, cod_rol, cod_usuario,  usu_insercion,  fec_insercion,  usu_modificacion, fec_modificacion
   from ba_usu_roles ;

  insert into ba_rol_programas_his
  (fecha,cod_programa,cod_rol, inserta, actualiza, elimina, consulta, imprime, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
  select v_fecha,cod_programa,cod_rol, inserta, actualiza, elimina, consulta, imprime, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion
   from ba_rol_programas ;

  insert into ge_tra_roles_his
  (fecha, cod_transaccion, cod_modulo, cod_modalidad,cod_rol, usu_insercion, fec_insercion,usu_modificacion, fec_modificacion, hor_inicio, hor_fin, ope_fec_valor, can_dias)
  select v_fecha, cod_transaccion, cod_modulo, cod_modalidad,cod_rol, usu_insercion, fec_insercion,usu_modificacion, fec_modificacion, hor_inicio, hor_fin, ope_fec_valor, can_dias
   from ge_tra_roles ;

  insert into ge_parametros_his
  (fecha,parametro,descripcion,tab_relacion, referencia, usu_insercion,fec_insercion, usu_modificacion,fec_modificacion,observacion,pro_verificacion,permiso, modificable,val_defecto)
  select v_fecha, parametro,descripcion,tab_relacion, referencia, usu_insercion,fec_insercion, usu_modificacion,fec_modificacion,observacion,pro_verificacion,permiso, modificable,val_defecto
   from ge_parametros ;

 insert into ge_procesos_his
  (fecha,cod_proceso, descripcion, nro_orden, obligatorio,tipo, hor_inicio, hor_fin,cod_usuario, usu_insercion,fec_insercion,usu_modificacion, fec_modificacion, error, permiso, ubi_destino)
  select v_fecha, cod_proceso,descripcion,nro_orden,obligatorio, tipo,hor_inicio, hor_fin, cod_usuario,usu_insercion,fec_insercion,usu_modificacion,fec_modificacion,error,permiso,ubi_destino
   from ge_procesos ;

  insert into ba_consultas_his
  (fecha, cod_consulta, descripcion, cod_usuario, permiso, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
  select v_fecha, cod_consulta, descripcion, cod_usuario, permiso, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion
   from ba_consultas ;

exception
  when others then
      raise_application_error(-20001, 'Error en la Inserción de Datos'|| SQLERRM);
end;
/

