create or replace function it.FUJ_PRO_TRANSACCION_120(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_cod_tra_padre   in varchar2, -- Codigo de transaccion
      p_hora            in varchar2 default null) -- hora de la transaccion a reimprimir
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;               -- Caja
  v_cod_modalidad number(3) := 91;           -- Caja
  v_cod_transaccion number(3) := 120;        -- Transaccion
  --
  v_nro_operacion cj_movimientos.nro_documento%type;
  v_nro_cuenta    cj_movimientos.nro_cuenta%type;
  v_mod_cobro number(3);               -- Caja
  v_mad_cobro number(3);           -- Caja
  --
  v_cod_oficina number(3);                   -- oficina de la caja
  v_cod_usuario varchar2(10) := upper(user); -- usuario
  --
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_estado            number(1);             -- estado de la caja
  v_fec_caja          date;                  -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);          -- saldo actual de la caja en cheques
  v_cod_moneda        varchar2(3);           -- moneda de la operacion
  --
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(8000) := 'Operacion Confirmada'; -- sin errores
  --
  v_tipo          varchar2(01);  -- Debito para la caja (ingreso)
  v_tip_monto     varchar2(01);  -- E/efectivo C-cheq
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  --
  v_cantidad      number(3) := 0;
  --
  r_gmovi         ge_movimientos%rowtype;
  -- CRO-JM-03/2015: CROGEFIT-3
  v_fecha          cj_acu_imp_transacciones.fecha%type;
  v_hora           cj_acu_imp_transacciones.hora%type;
  v_cod_persona    cj_acu_imp_transacciones.cod_persona%type;
  f_nro_cuenta     cj_acu_imp_transacciones.nro_cuenta%type;
  v_monto          number;
  v_mto_calculado  number;
  --
  -- Procedimiento interno para generar movimiento y act. de control de caja
  --por ahora no se genera, sólo se imprimen las operaciones autorizadas
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo el control de caja
      update cj_controles
         set estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = v_cod_moneda
         and fecha = v_fec_caja;
      -- genero el movimiento por el  cheque
      insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia,
          cod_tra_padre, cod_mod_padre, cod_mad_padre,
          cod_oficina, cod_moneda, nro_caja,
          nro_documento, nro_cuenta, monto, tip_monto, tipo,nro_doc_referencia)
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 1, -- secuencia 1
          v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
          v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
          v_nro_operacion, v_nro_cuenta, 0,'E' /* cheq.otros bcos */, v_tipo,
          null); /* no es debito ni credito */
  end lp_gen_transaccion;

begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido los datos ingresados
 if p_cod_tra_padre is  null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Transacción a imprimir.';
 elsif p_cod_tra_padre not in (245,246) then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Transacción no se puede imprimir.';
 elsif p_hora is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la hora de la Operación. Presione F9 para ver Lista de Operaciones';
 else
    -- Obtengo los datos de la caja
      prj_obt_datos_caja(p_nro_caja,
                          v_cod_moneda,
                          v_cod_oficina,
                          v_fec_caja,
                          v_estado,
                          v_sal_actual,
                          v_sal_cheques);
    -- Datos del movimiento a imprimir
     select count(*)
       into v_cantidad
       from cj_movimientos a
      where nro_caja = to_number(p_nro_caja)
        and hora = p_hora
        and cod_tra_padre = p_cod_tra_padre
        and estado = 'N' -- normal
        and cod_usuario = v_cod_usuario
        and exists (select 0
                        from ge_movimientos
                        where hora = a.hora
                        and cod_usuario = a.cod_usuario
                        and emi_aviso ='S') --comprobante manual
        and exists(select 0
                  from ge_aut_pedidos xr
                  where xr.fecha       = a.fecha
                    and xr.hora        = a.hora
                    and xr.cod_usuario = a.cod_usuario
                    and xr.respuesta   ='A'
                    --> Agregado para que imprima solo en el caso de ambas autorizaciones
                    having count(*) = (Select count(*)
                                         From ge_aut_pedidos b
                                        Where b.fecha        = xr.fecha
                                          and b.hora         = xr.hora
                                          and b.cod_usuario  = xr.cod_usuario)
                   Group By xr.fecha, xr.hora, xr.cod_usuario);
    if v_cantidad = 0 then
       v_cod_respuesta := '001'; -- error
       v_msj_respuesta := 'ERROR: No existe comprobante a imprimir.';
    else
     select nro_documento, cod_moneda, nro_cuenta, monto, fecha
       into v_nro_operacion, v_cod_moneda, v_nro_cuenta, v_monto, v_fecha
       from cj_movimientos
      where nro_caja = to_number(p_nro_caja)
        and hora = p_hora
        and cod_tra_padre = p_cod_tra_padre
        and estado = 'N' -- normal
        and cod_usuario = v_cod_usuario
        and rownum = 1;

       if p_cod_tra_padre in (245, 246) then
          --reimpresion FIT -- CRO-JM-03/2015: CROGEFIT-3
           begin
             select (case -- aquí elegimos si existe una cuenta distinta a la cuenta de cambios del banco, sino elegimos esa cuenta de cambios:
                 when ((select count(a.nro_cuenta)
                          from ge_movimientos a
                         where a.fecha = g.fecha
                           and a.cod_usuario = g.cod_usuario
                           and a.hora = g.hora
                           and a.nro_cuenta is not null
                           and not exists
                         (select b.nro_cuenta
                                  from LC_CTA_CAMBIOS b
                                 where a.nro_cuenta = b.nro_cuenta)) > 0) then
                  (select a.nro_cuenta
                     from ge_movimientos a
                    where a.fecha = g.fecha
                      and a.cod_usuario = g.cod_usuario
                      and a.hora = g.hora
                      and a.nro_cuenta is not null
                      and a.nro_secuencia =
                          (select min(g.nro_secuencia) --elegimos la menor secuencia en caso que se repita
                             from ge_movimientos g
                            where a.fecha = g.fecha
                              and a.hora = g.hora
                              and a.cod_usuario = g.cod_usuario
                              and g.nro_cuenta is not null
                              and not exists
                            (select b.nro_cuenta
                                     from LC_CTA_CAMBIOS b
                                    where g.nro_cuenta = b.nro_cuenta))
                    group by a.nro_cuenta)
                 else
                  (select a.nro_cuenta
                     from ge_movimientos a
                    where a.fecha = g.fecha
                      and a.cod_usuario = g.cod_usuario
                      and a.hora = g.hora
                      and a.nro_cuenta is not null
                      and exists (select b.nro_cuenta
                             from LC_CTA_CAMBIOS b
                            where a.nro_cuenta = b.nro_cuenta)
                    group by a.nro_cuenta)
               end),g.cod_persona, g.hora
               into f_nro_cuenta, v_cod_persona, v_hora
               from ge_movimientos g
              where g.hora = p_hora
                and g.fecha = v_fecha
                and g.cod_usuario = v_cod_usuario
                and g.reversado = 'N'
                and g.cod_mod_padre = 7
                and g.nro_cuenta is not null
                and g.cod_persona is not null
              group by g.cod_persona, g.fecha, g.cod_usuario, g.hora;
           exception
             when others then
               f_nro_cuenta  := null;
               v_cod_persona := null;
           end;

        -- CRO-JM-03/2015: CROGEFIT-3
        if f_nro_cuenta is not null and
           v_cod_persona is not null then
             if fuj_ver_imp_formulario(f_nro_cuenta,
                                       v_cod_persona,
                                       0,
                                       p_cod_tra_padre,
                                       v_mto_calculado,
                                       'S', 	     --enviamos solo en la reimpresion
                                       v_fecha,    --enviamos solo en la reimpresion
                                       p_hora,     --enviamos solo en la reimpresion
                                       USER) then  --enviamos solo en la reimpresion
                  v_cod_respuesta := 'IMP';
                 v_msj_respuesta := 'Operacion Confirmada. Comprobante y Decl.Jurada impresos. Oper.Nro. '||p_nro_operacion||'~'||
                                     fuj_imp_comprobante_245(v_nro_operacion, v_cod_oficina, p_nro_caja)||
                                     fuj_imp_dec_jurada_40(v_fecha, v_hora, v_cod_usuario, 1, v_mto_calculado,p_cod_tra_padre,
                                                           null,null,null,null,null,'S');
                     -- CRO-JM-03/2015: CROGEFIT-3 actualizamos en la tabla como ya impreso:
                        prj_ins_form_transacciones(f_nro_cuenta,
                                                   v_cod_persona,
                                                   v_cod_modulo,
                                                   p_cod_tra_padre,
                                                   USER,
                                                   v_fecha,
                                                   v_hora,
                                                   pag_gen.fu_obt_mon_fuerte,
                                                   0,
                                                   'S',  --indicador de actualizacion impresion
                                                   'N',  --indicador de insercion
                                                   'S'); --indicador de reimpresion
              else
                 -- reimpresion de cambios
                  v_cod_respuesta := 'IMP'; -- para indicar que esta ok y se de imprimir
                  v_msj_respuesta := 'Operacion Confirmada. Imprimiendose Comprobante...'||'~'||
                  fuj_imp_comprobante_245(v_nro_operacion,
                                          v_cod_oficina,
                                          p_nro_caja);
              end if;
        else
              -- reimpresion de cambios
              v_cod_respuesta := 'IMP'; -- para indicar que esta ok y se de imprimir
              v_msj_respuesta := 'Operacion Confirmada. Imprimiendose Comprobante...'||'~'||
              fuj_imp_comprobante_245(v_nro_operacion,
                                      v_cod_oficina,
                                      p_nro_caja);
        end if;
       -- Impresion del Comprobante por el Cargo
       else
          v_cod_respuesta := '001'; -- para indicar que esta ok y se de imprimir
          v_msj_respuesta := 'Impresión de comprobante no previsto...';
       end if;
    end if;
 end if;
 /* armo finalmente el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 v_msj_respuesta;
 return(v_msj_salida);
exception
 when others then
     /* armo finalmente el mensaje de respuesta */
     v_msj_salida := p_nro_operacion||'~'||
                     '999'||'~'||
                     sqlerrm;
     return(v_msj_salida);
end FUJ_PRO_TRANSACCION_120;
/

