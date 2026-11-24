CREATE OR REPLACE PROCEDURE IT.ACTUALIZAR_MOVIMIENTOS_HIS_V2 is
  v_cant_total number         := 0;
  v_cant_actualizado number   := 0;
  v_cantidad number := 0;
  v_nro_secuencia number := 0;
  v_nro_cuenta_ant varchar2(15) := null;
  v_nro_documento varchar2(15) := null;
  v_hora varchar2(8) := null;
  
  cursor cur_mov is
  select* from it.ah_movimientos_his where cod_usuario = 'MIGRA' and fecha >= to_date('01/01/2010','dd/MM/yyyy') 
  and nro_documento is null;

begin
  --registrar_fase3('Inicio del procedimiento ACTUALIZAR_MOVIMIENTOS_HIS_V2','AHM');

  for x in cur_mov loop

    v_cant_total := v_cant_total + 1;

    begin
      
        
         /*select count(*), min(h.nro_secuencia) into v_cantidad, v_nro_secuencia 
          from ah_movimientos_his_docum_v2 h where
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
          and h.cod_transaccion =x.cod_transaccion 
          and h.actualizado = 'N';*/
          
         -- dbms_output.put_line('Se obtiene la cantidad y menor nro_secuencia -  v_nro_cuenta_ant: '||
           --                     v_nro_cuenta_ant||' x.nro_cuenta: '||x.nro_cuenta||' - v_cantidad: '||v_cantidad
             --                   ||' - v_nro_secuencia: '||v_nro_secuencia ||' fecha: '||x.fecha);
        
        
        if(v_cantidad > 0) then
                      
             /*select nro_documento, hora into v_nro_documento, v_hora
              from ah_movimientos_his_docum_v2 h where
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
              and h.cod_transaccion =x.cod_transaccion 
              and h.nro_secuencia  = v_nro_secuencia;
          
          
             update it.ah_movimientos_his h set
                    h.nro_documento = v_nro_documento
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
                    and h.cod_transaccion =x.cod_transaccion 
                    and h.nro_secuencia = x.nro_secuencia
                    and h.hora = x.hora;

                    update
                    ah_movimientos_his_docum_v2 h set h.actualizado = 'S' 
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
                    and h.cod_transaccion =x.cod_transaccion 
                    and h.nro_documento = v_nro_documento 
                    and h.nro_secuencia = v_nro_secuencia
                    and h.hora = v_hora;

             commit;*/

             v_cant_actualizado := v_cant_actualizado + 1;
             
             /*if(mod(v_cant_actualizado,1000) = 0) then
                 registrar_fase3('ACTUALIZAR_MOVIMIENTOS_HIS_V2 - actualizados:' ||v_cant_actualizado, 'AHM');
             end if;*/
/*        else
              registrar_error_fase3('ACTUALIZAR_MOVIMIENTOS_HIS_V2',
                 x.nro_cuenta,'No se actualizo el documento: '||x.nro_documento||
              ' debido a la cantidad de registros: '||v_cantidad||
              ' con la fecha '||x.fecha||' Monto: '|| x.monto||'CONCEPTO: '||x.concepto||'v_nro_secuencia: '||v_nro_secuencia ,'AHM');*/
        end if;

        v_nro_cuenta_ant := x.nro_cuenta;
        
    exception
      /*when no_data_found then
       registrar_error_fase3('ACTUALIZAR_MOVIMIENTOS_HIS_V2 - fecha: '||x.fecha||'-nro_secuencia: '||v_nro_secuencia,
                                                                        x.nro_cuenta,sqlerrm,'AHM');*/
      when others THEN
        NULL;
        --registrar_error_fase3('ACTUALIZAR_MOVIMIENTOS_HIS_V2 - fecha: '||x.fecha,x.nro_cuenta,sqlerrm,'AHM');
    end;
  end loop;

  commit;

  --registrar_fase3('Se actualizaron los Movimientos Históricos: '||v_cant_actualizado||' registros de '||v_cant_total,'AHM');
  --registrar_fase3('Fin del procedimiento ACTUALIZAR_MOVIMIENTOS_HIS_V2','AHM');

end ACTUALIZAR_MOVIMIENTOS_HIS_V2;
/

