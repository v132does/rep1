create or replace procedure it.prg_tra_his_reg_sueldos is

  --Variables--
  v_fec_has_eliminar date := TO_DATE(fug_obt_pardinamico('FEC_ELI_REG_PAG_SUELDOS'),'DD/MM/YYYY');
  v_fecha date;

  --Cursores--
  cursor c_fec_pagos is
    select x.fec_proceso
      from ge_pag_sueldos x
     where x.fec_proceso <= v_fec_has_eliminar
    group by x.fec_proceso;

begin
  if v_fec_has_eliminar is null then
     raise_application_error(-20000,'Error. Debe cargar el parametro de fecha hasta FEC_ELI_REG_PAG_SUELDOS');
  end if;
  FOR FEC IN c_fec_pagos loop
      v_fecha := fec.fec_proceso;
      insert into ge_pag_sueldos_his
      (cod_usuario, cod_ente, fec_proceso, nro_secuencia, cod_modalidad, nro_cuenta, cod_moneda, fec_envio,
       tipo, monto, estado, cod_proceso, cod_modulo, ano, nivel, entidad, observacion, procesado,
       fec_insercion, usu_insercion, fec_modificacion, usu_modificacion)
      select
        cod_usuario, cod_ente, fec_proceso, nro_secuencia, cod_modalidad, nro_cuenta, cod_moneda, fec_envio,
        tipo, monto, estado, cod_proceso, cod_modulo, ano, nivel, entidad, observacion, procesado,
        fec_insercion, usu_insercion, fec_modificacion, usu_modificacion
       from ge_pag_sueldos y
       where y.fec_proceso = v_fecha;

       delete from ge_pag_sueldos z
       where z.fec_proceso = v_fecha;

      --Confirmar por fecha--
      commit;
  end loop;
  delete from ge_par_dinamicos u
  where u.parametro = 'FEC_ELI_REG_PAG_SUELDOS';
exception 
  when others then
       raise_application_error(-20000,'Error al Transferir Datos de Sueldos al Historico. '||sqlerrm);
end;
/

