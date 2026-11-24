CREATE OR REPLACE PROCEDURE IT.ACTUALIZAR_MOVTOS_CC_BOR_V2 is
  v_cant_total number         := 0;
  v_cant_actualizado number   := 0;
  v_cantidad_tabla number := 0;
  v_cantidad_bkp number := 0;
  v_nro_secuencia number := 0;
  v_nro_cuenta_ant varchar2(15) := null;
  v_nro_cuenta varchar2(15) := null;
  v_cant_nro_cuenta_err number := 0;
  v_cant_mismo_concepto number := 0;
  v_cant_actual_normal number := 0;
  
  cursor cur_mov is
  select* from it.cc_movimientos_his where fecha >= to_date('01/01/2010','dd/MM/yyyy')
  and cod_modulo = 4 and cod_modalidad = 41 and reversado <> 'S';

begin
  --registrar_fase3('Inicio del procedimiento ACTUALIZAR_MOVTOS_CC_BOR_V2','CCM');

  for x in cur_mov loop

    v_cant_total := v_cant_total + 1;

    begin

      /*   select count(*) into v_cantidad_tabla
          from it.cc_movimientos_his h where
          h.cod_usuario = 'MIGRA'
          and h.fec_valor = x.fec_valor
          and h.fecha = x.fecha
          and h.monto = x.monto
          and h.nro_cuenta = x.nro_cuenta
          and h.cod_moneda = x.cod_moneda
          and h.cod_oficina = x.cod_oficina
          and h.cod_modulo = x.cod_modulo
          and h.cod_modalidad = x.cod_modalidad
          and h.cod_transaccion = x.cod_transaccion;

         select count(*) into v_cantidad_bkp
          from bkp1_cc_movimientos_his h where
           h.fec_valor = x.fec_valor
          and h.fecha = x.fecha
          and h.monto = x.monto
          and h.nro_cuenta = x.nro_cuenta
          and h.cod_moneda = x.cod_moneda
          and h.cod_oficina = x.cod_oficina
          and h.cod_modulo = x.cod_modulo
          and h.cod_modalidad = x.cod_modalidad
          and h.cod_transaccion = x.cod_transaccion
          and reversado <> 'S';
          */
        if(v_cantidad_tabla = 1 and v_cantidad_bkp = 1) then

             /*update it.cc_movimientos_his h set
                    h.cod_error         = x.cod_error,
                    h.cod_retencion     = x.cod_retencion,
                    h.fec_fin_retencion = x. fec_fin_retencion,
                    h.est_cuenta     = x.est_cuenta,
                    h.estado         = x.estado,
                    h.cod_causa      = x.cod_causa,
                    h.cod_banco      = x.cod_banco,
                    h.cod_ofi_origen = x.cod_ofi_origen,
                    h.concepto = x.concepto,
                    h.cod_tasa = x.cod_tasa,
                    h.val_tasa = x.val_tasa,
                    h.cod_rubro         = x.cod_rubro,
                    h.cod_ref_cambio    = x.cod_ref_cambio,
                    h.reversado         = x.reversado,
                    h.cod_usu_reversion = x.cod_usu_reversion,
                    h.hor_reversion     = x.hor_reversion,
                    h.emi_aviso         = x.emi_aviso,
                    h.cod_tra_padre   = x.cod_tra_padre,
                    h.cod_mod_padre   = x.cod_mod_padre,
                    h.cod_mad_padre   = x.cod_mad_padre,
                    h.mto_equ_local   = x.mto_equ_local,
                    h.nro_caja        = x.nro_caja,
                    h.cotizacion      = x.cotizacion,
                    h.cod_bco_central = x.cod_bco_central,
                    h.nro_documento   = x.nro_documento,
                    h.nro_documento2  = x.nro_documento2,
                    h.nro_documento3  = x.nro_documento3,
                    h.nro_documento4  = x.nro_documento4,
                    h.protegido       = x.protegido,
                    h.tip_mov_rubro        = x.tip_mov_rubro,
                    h.cod_autorizacion     = x.cod_autorizacion,
                    h.cod_usu_autorizador  = x.cod_usu_autorizador,
                    h.cod_tip_ope_cambio   = x.cod_tip_ope_cambio,
                    h.nro_folio            = x.nro_folio,
                    h.referencia           = x.referencia,
                    h.cod_persona          = x.cod_persona,
                    h.cod_sit_contable     = x.cod_sit_contable,
                    h.nro_conciliacion     = x.nro_conciliacion,
                    h.nro_secuencia        = x.nro_secuencia
                    where
                    h.cod_usuario = 'MIGRA'
                    and h.fec_valor = x.fec_valor
                    and h.fecha = x.fecha
                    and h.monto = x.monto
                    and h.nro_cuenta = x.nro_cuenta
                    and h.cod_moneda = x.cod_moneda
                    and h.cod_oficina = x.cod_oficina
                    and h.cod_modulo = x.cod_modulo
                    and h.cod_modalidad = x.cod_modalidad
                    and h.cod_transaccion = x.cod_transaccion;
                    
                    update bkp1_cc_movimientos_his set actualizado = 'S'
                    where fecha = x.fecha and nro_secuencia = x.nro_secuencia and 
                    hora = x.hora and cod_usuario = x.cod_usuario;
                    
                    commit;*/

                    v_cant_actualizado := v_cant_actualizado + 1;
                    v_cant_actual_normal := v_cant_actual_normal + 1;
                    
          elsif(v_cantidad_tabla = 0 and v_cantidad_bkp = 1)then
              
               if(length(x.nro_cuenta) < 10)then
                        v_nro_cuenta := lpad(x.nro_cuenta,10,'0');   
                        
                /* select count(*) into v_cantidad_tabla
                  from it.cc_movimientos_his h where
                  h.cod_usuario = 'MIGRA'
                  and h.fec_valor = x.fec_valor
                  and h.fecha = x.fecha
                  and h.monto = x.monto
                  and h.nro_cuenta = v_nro_cuenta
                  and h.cod_moneda = x.cod_moneda
                  and h.cod_oficina = x.cod_oficina
                  and h.cod_modulo = x.cod_modulo
                  and h.cod_modalidad = x.cod_modalidad
                  and h.cod_transaccion = x.cod_transaccion;
                   */
                  if(v_cantidad_tabla = 1) then
                   /*  update it.cc_movimientos_his h set
                            h.cod_error         = x.cod_error,
                            h.cod_retencion     = x.cod_retencion,
                            h.fec_fin_retencion = x. fec_fin_retencion,
                            h.est_cuenta     = x.est_cuenta,
                            h.estado         = x.estado,
                            h.cod_causa      = x.cod_causa,
                            h.cod_banco      = x.cod_banco,
                            h.cod_ofi_origen = x.cod_ofi_origen,
                            h.concepto = x.concepto,
                            h.cod_tasa = x.cod_tasa,
                            h.val_tasa = x.val_tasa,
                            h.cod_rubro         = x.cod_rubro,
                            h.cod_ref_cambio    = x.cod_ref_cambio,
                            h.reversado         = x.reversado,
                            h.cod_usu_reversion = x.cod_usu_reversion,
                            h.hor_reversion     = x.hor_reversion,
                            h.emi_aviso         = x.emi_aviso,
                            h.cod_tra_padre   = x.cod_tra_padre,
                            h.cod_mod_padre   = x.cod_mod_padre,
                            h.cod_mad_padre   = x.cod_mad_padre,
                            h.mto_equ_local   = x.mto_equ_local,
                            h.nro_caja        = x.nro_caja,
                            h.cotizacion      = x.cotizacion,
                            h.cod_bco_central = x.cod_bco_central,
                            h.nro_documento   = x.nro_documento,
                            h.nro_documento2  = x.nro_documento2,
                            h.nro_documento3  = x.nro_documento3,
                            h.nro_documento4  = x.nro_documento4,
                            h.protegido       = x.protegido,
                            h.tip_mov_rubro        = x.tip_mov_rubro,
                            h.cod_autorizacion     = x.cod_autorizacion,
                            h.cod_usu_autorizador  = x.cod_usu_autorizador,
                            h.cod_tip_ope_cambio   = x.cod_tip_ope_cambio,
                            h.nro_folio            = x.nro_folio,
                            h.referencia           = x.referencia,
                            h.cod_persona          = x.cod_persona,
                            h.cod_sit_contable     = x.cod_sit_contable,
                            h.nro_conciliacion     = x.nro_conciliacion,
                            h.nro_secuencia        = x.nro_secuencia
                            where
                            h.cod_usuario = 'MIGRA'
                            and h.fec_valor = x.fec_valor
                            and h.fecha = x.fecha
                            and h.monto = x.monto
                            and h.nro_cuenta = v_nro_cuenta
                            and h.cod_moneda = x.cod_moneda
                            and h.cod_oficina = x.cod_oficina
                            and h.cod_modulo = x.cod_modulo
                            and h.cod_modalidad = x.cod_modalidad
                            and h.cod_transaccion = x.cod_transaccion;
                   

                    update bkp1_cc_movimientos_his set actualizado = 'S'
                    where fecha = x.fecha and nro_secuencia = x.nro_secuencia and
                    hora = x.hora and cod_usuario = x.cod_usuario;

                    commit;
               */
                    v_cant_actualizado := v_cant_actualizado + 1;
                    v_cant_nro_cuenta_err := v_cant_nro_cuenta_err + 1;
                    
                /*else
                  registrar_error_fase3('ACTUALIZAR_MOVTOS_CC_BOR_V2',x.nro_cuenta,' - v_cantidad_tabla: '||v_cantidad_tabla||' v_cantidad_bkp: '||v_cantidad_bkp
                  ||' Despues de la actualizacion del nro_cuenta: '||v_nro_cuenta,'CCM');  */    
                            
                  end if;                 
              /* else
                  registrar_error_fase3('ACTUALIZAR_MOVTOS_CC_BOR_V2 ',x.nro_cuenta,'- v_cantidad_tabla: '||v_cantidad_tabla||' v_cantidad_bkp: '||v_cantidad_bkp
                  ||' Pero la longitud del nro de cuenta es: '||length(x.nro_cuenta),'CCM');
               */
               end if;
          
          /*else
              registrar_error_fase3('ACTUALIZAR_MOVTOS_CC_BOR_V2',
                 x.nro_cuenta,'No se actualizo el documento: '||x.nro_documento||
              ' debido a la cantidad de registros en la tabla de movtos: '||v_cantidad_tabla||' en la tabla de bkp: '
              ||v_cantidad_bkp||
              ' con la fecha '||x.fecha||' Monto: '|| x.monto||'CONCEPTO: '||x.concepto,'CCM');*/
        end if;


        v_nro_cuenta_ant := x.nro_cuenta;

    exception
    /*  when no_data_found then
       registrar_error_fase3('ACTUALIZAR_MOVTOS_CC_BOR_V2 - fecha: '||x.fecha||'-nro_secuencia: '||v_nro_secuencia,
                                                                     x.nro_cuenta,sqlerrm,'CCM');*/
      when others then
     --   registrar_error_fase3('ACTUALIZAR_MOVTOS_CC_BOR_V2 - fecha: '||x.fecha,x.nro_cuenta,sqlerrm,'CCM');
     null;
    end;
  end loop;

  commit;

 /* registrar_fase3('Se actualizaron los Movimientos Históricos: '||v_cant_actualizado||' registros de '||v_cant_total,'CCM');
  registrar_fase3(v_cant_nro_cuenta_err||' de '||v_cant_total||' Tenían numeros de cuenta erróneo en el backup ','CCM');
  registrar_fase3( v_cant_mismo_concepto||' de '||v_cant_actualizado||' actualizados tomando en cuenta el concepto ','CCM');   
  registrar_fase3('Fin del procedimiento ACTUALIZAR_MOVTOS_CC_BOR_V2','CCM');*/

end ACTUALIZAR_MOVTOS_CC_BOR_V2;
/

