create or replace procedure it.ins_retenciones_cob_tarj is

cursor cur_ta_mov is
select * from ta_movimientos_his h
where h.cod_tra_padre=250 and h.cod_transaccion in(614,615)
and h.reversado='N'
and not exists(select 1 from ah_retenciones a
               where a.nro_cuenta=h.nro_cuenta and a.fec_inicio=h.fecha and a.monto=h.monto);

cursor cur_ge_mov is
select * from ge_movimientos g
where g.cod_tra_padre=250 and g.cod_transaccion in(614,615)
and g.reversado='N'
and not exists(select 1 from ah_retenciones a
               where a.nro_cuenta=g.nro_cuenta and a.fec_inicio=g.fecha and a.monto=g.monto);

begin

  --Para los que figuran en TA_MOVIMIENTOS_HIS se inserta en AH_RETENCIONES y se libera con PRA_LIB_RETENCION
  for x in cur_ta_mov loop
    begin
      insert into it.ah_retenciones(
             NRO_CUENTA,
             COD_MODULO,
             COD_MODALIDAD,
             COD_OFICINA,
             NRO_DOCUMENTO,
             COD_RETENCION,
             FEC_FINAL,
             COD_MONEDA,
             MONTO,
             FEC_INICIO,
             COD_USUARIO,
             COD_OFI_ORIGEN,
             LIBERADO,
             DETALLADO,
             LIB_POSTERIOR,
             SAL_RETENIDO)
      values(
             x.nro_cuenta,
             x.cod_modulo,
             x.cod_modalidad,
             x.cod_oficina,
             x.nro_documento,
             8,
             x.fecha,
             x.cod_moneda,
             x.monto,
             x.fecha,
             x.cod_usuario,
             x.cod_ofi_origen,
             'N',
             'N',
             'N',
             x.monto
      );

    exception
      when others then
        raise_application_error(-20000,'Error al insertar en AH_RETENCIONES movimientos de TA_MOVIMIENTOS_HIS. '|| sqlerrm);
    end;


    begin
      pra_lib_retencion(x.nro_cuenta,x.nro_cuenta,null,null,x.nro_documento);
    exception
      when others then
        raise_application_error(-20000,'Error al ejecutar PRA_LIB_RETENCION. '|| sqlerrm);
    end;
  end loop;


  --Para los que figuran en GE_MOVIMIENTOS se inserta en AH_RETENCIONES y no se libera
  for y in cur_ge_mov loop
    begin
      insert into it.ah_retenciones(
             NRO_CUENTA,
             COD_MODULO,
             COD_MODALIDAD,
             COD_OFICINA,
             NRO_DOCUMENTO,
             COD_RETENCION,
             FEC_FINAL,
             COD_MONEDA,
             MONTO,
             FEC_INICIO,
             COD_USUARIO,
             COD_OFI_ORIGEN,
             LIBERADO,
             DETALLADO,
             LIB_POSTERIOR,
             SAL_RETENIDO)
      values(
             y.nro_cuenta,
             y.cod_modulo,
             y.cod_modalidad,
             y.cod_oficina,
             y.nro_documento,
             8,
             y.fecha,
             y.cod_moneda,
             y.monto,
             y.fecha,
             y.cod_usuario,
             y.cod_ofi_origen,
             'N',
             'N',
             'N',
             y.monto
      );

    exception
      when others then
        raise_application_error(-20000,'Error al insertar en AH_RETENCIONES movimientos de GE_MOVIMIENTOS. '|| sqlerrm);
    end;

  end loop;

end ins_retenciones_cob_tarj;
/

