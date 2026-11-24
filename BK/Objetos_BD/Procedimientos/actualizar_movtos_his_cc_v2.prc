CREATE OR REPLACE PROCEDURE IT.ACTUALIZAR_MOVTOS_HIS_CC_V2 is
  v_cant_total number         := 0;
  v_cant_actualizado number   := 0;
  v_cantidad number := 0;
  v_nro_secuencia number := 0;
  v_nro_cuenta_ant varchar2(15) := null;
  v_nro_documento varchar2(15) := null;
  v_hora varchar2(8) := null;
  
  --Obtiene todos los documentos que no tienen número de documento en IT
  cursor cur_mov is
  select* from it.cc_movimientos_his where cod_usuario = 'MIGRA'  and fecha >= to_date('01/01/2010','dd/MM/yyyy')
  and nro_documento is null;

begin
 -- registrar_fase3('Inicio del procedimiento ACTUALIZAR_MOVTOS_HIS_CC_V2','CCM');

  for x in cur_mov loop

    v_cant_total := v_cant_total + 1;

    begin
      
       /* 
         select count(*), min(h.nro_secuencia) into v_cantidad, v_nro_secuencia 
          from cc_movimientos_his_docum_v2 h where
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
          and h.actualizado = 'N';
                  */
        
        if(v_cantidad > 0) then
                      
          /*   select nro_documento, hora into v_nro_documento, v_hora
              from cc_movimientos_his_docum_v2 h where
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
              and h.nro_secuencia  = v_nro_secuencia 
              and rownum < 2;
          
          
             update it.cc_movimientos_his h set
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
                    cc_movimientos_his_docum_v2 h set h.actualizado = 'S' 
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

             commit;
*/
             v_cant_actualizado := v_cant_actualizado + 1;
             
          /*   if(mod(v_cant_actualizado,1000) = 0) then
                 registrar_fase3('ACTUALIZAR_MOVTOS_HIS_CC_V2 - actualizados:' ||v_cant_actualizado, 'CCM');
             end if;*/
        /*else
              registrar_error_fase3('ACTUALIZAR_MOVTOS_HIS_CC_V2',
                 x.nro_cuenta,'No se actualizo el documento: '||x.nro_documento||
              ' debido a la cantidad de registros: '||v_cantidad||
              ' con la fecha '||x.fecha||' Monto: '|| x.monto||'CONCEPTO: '||x.concepto||'v_nro_secuencia: '||v_nro_secuencia ,'CCM');*/
        end if;

        v_nro_cuenta_ant := x.nro_cuenta;
        
    exception
     /* when no_data_found then
       registrar_error_fase3('ACTUALIZAR_MOVTOS_HIS_CC_V2 - fecha: '||x.fecha||'-nro_secuencia: '||v_nro_secuencia,
                                                                        x.nro_cuenta,sqlerrm,'CCM');*/
      when others then
        NULL;
    --    registrar_error_fase3('ACTUALIZAR_MOVTOS_HIS_CC_V2 - fecha: '||x.fecha,x.nro_cuenta,sqlerrm,'CCM');
    end;
  end loop;

  commit;

 /* registrar_fase3('Se actualizaron los Movimientos Históricos: '||v_cant_actualizado||' registros de '||v_cant_total,'CCM');
  registrar_fase3('Fin del procedimiento ACTUALIZAR_MOVTOS_HIS_CC_V2','CCM');*/

end ACTUALIZAR_MOVTOS_HIS_CC_V2;
/

