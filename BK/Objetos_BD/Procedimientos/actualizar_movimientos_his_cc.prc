CREATE OR REPLACE PROCEDURE IT.ACTUALIZAR_MOVIMIENTOS_HIS_CC is
  v_cant_total number         := 0;
  v_cant_actualizado number   := 0;
  v_cantidad number := 0;
  cursor cur_mov is
  select * from cc_movimientos_his_docum where cod_usuario = 'MIGRA';

begin
  --registrar_fase3('Inicio del procedimiento ACTUALIZAR_MOVIMIENTOS_HIS_CC','CCM');

  for x in cur_mov loop

    v_cant_total := v_cant_total + 1;

    begin
        select count(*) into v_cantidad from it.cc_movimientos_his h where
        h.cod_usuario = 'MIGRA'
        and h.fec_valor = x.fec_valor
        and h.fecha = x.fecha
        and h.monto = x.monto
        and h.nro_cuenta = x.nro_cuenta
        and h.cod_moneda = x.cod_moneda
        and h.cod_modulo = x.cod_modulo
        and h.cod_modalidad = x.cod_modalidad
        and h.cod_oficina = x.cod_oficina
        and h.concepto = x.concepto
        and h.cod_tra_padre = x.cod_tra_padre
        and h.cod_mod_padre = x.cod_mod_padre
        and h.cod_mad_padre = x.cod_mad_padre
        and h.cod_transaccion =x.cod_transaccion ;

        if(v_cantidad = 1) then

             update it.cc_movimientos_his h set
                    h.nro_documento = x.nro_documento
                    where
                    h.cod_usuario = 'MIGRA'
                    and h.fec_valor = x.fec_valor
                    and h.fecha = x.fecha
                    and h.monto = x.monto
                    and h.nro_cuenta = x.nro_cuenta
                    and h.cod_moneda = x.cod_moneda
                    and h.cod_modulo = x.cod_modulo
                    and h.cod_modalidad = x.cod_modalidad
                    and h.cod_oficina = x.cod_oficina
                    and h.concepto = x.concepto
                    and h.cod_tra_padre = x.cod_tra_padre
                    and h.cod_mod_padre = x.cod_mod_padre
                    and h.cod_mad_padre = x.cod_mad_padre
                    and h.cod_transaccion =x.cod_transaccion ;

             commit;

             v_cant_actualizado := v_cant_actualizado + 1;

             /*if(mod(v_cant_actualizado,1000) = 0) then
                 registrar_fase3('ACTUALIZAR_MOVIMIENTOS_HIS_CC - actualizados:' ||v_cant_actualizado, 'CCM');
             end if;*/
        /*else
              registrar_error_fase3('ACTUALIZAR_MOVIMIENTOS_HIS_CC',
                 x.nro_cuenta,'No se actualizo el documento: '||x.nro_documento||
              ' debido a la cantidad de registros: '||v_cantidad||
              ' con la fecha '||x.fecha||' Monto: '|| x.monto||'CONCEPTO: '||x.concepto ,'CCM');*/
        end if;

    exception
      when others THEN
        NULL;
        --registrar_error_fase3('ACTUALIZAR_MOVIMIENTOS_HIS_CC - fecha: '||x.fecha,x.nro_cuenta,sqlerrm,'CCM');
    end;
  end loop;

  commit;

  --registrar_fase3('Se actualizaron los Movimientos Históricos CC: '||v_cant_actualizado||' registros de '||v_cant_total,'CCM');
  --registrar_fase3('Fin del procedimiento ACTUALIZAR_MOVIMIENTOS_HIS_CC','CCM');

end ACTUALIZAR_MOVIMIENTOS_HIS_CC;
/

