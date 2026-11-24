CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_243
 (p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
  p_nro_caja in varchar2,        -- Nro de Caja
  p_nro_boleta in varchar2    -- nro de operacion de cambios
 )
 RETURN LONG
 IS
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_transaccion number(4) := 243;  -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);      -- saldo actual de la caja en cheques
  -- Datos de salida
  v_msj_salida    long;        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta long := ''; -- sin errores
  -- variables para guardar los datos de la operacion principal
  v_ope_cod_usuario   varchar2(10);
  v_ope_hora          varchar2(10);
  v_ope_fecha         date;
  v_ope_cod_moneda    varchar2(3);
  v_ope_monto         number(18,2);
  v_ope_tip_operacion varchar2(3);
--  v_ope_cod_bcp       varchar2(4);
--  v_ope_mto_mon_local number(18);
--  v_ope_ofi_cambio    number(4);
  v_existe            varchar2(1) := 'N';
  v_cotizacion ge_movimientos.cotizacion%type;
  v_nro_cheque        ge_movimientos.nro_documento3%type;
  v_cod_banco         ge_movimientos.cod_banco%type;
  v_cod_tra_compra    ge_movimientos.cod_transaccion%type;
  v_cod_retencion     ge_movimientos.cod_retencion%type;
  v_cli_frecuente   varchar2(1) := 'N';
  v_cod_persona      ba_personas.cod_persona%type;
  v_nro_cuenta       ge_movimientos.nro_cuenta%type;
  v_mto_calculado  number;
  -- Cursor de movimientos de la operacion
  cursor movimientos is
  Select a.nro_secuencia, a.cod_moneda, a.monto, a.estado, b.descripcion,
         decode(b.tip_valor,'E','E',decode(a.cod_transaccion,607,'O',610,'T',632,'S',633,'X')) tip_valor,
         a.cod_ofi_origen, c.tip_movimiento,
         a.cod_usuario, a.fecha, a.hora, a.mto_equ_local, a.cod_tip_ope_cambio, a.cod_bco_central,
         b.caja, -- para saber si pasa x caja
         a.cod_banco, a.nro_documento3, a.cod_transaccion, a.cod_retencion
    from lc_tip_ope_oficinas c,lc_tip_operaciones b, ge_movimientos a
   where nro_documento = to_number(p_nro_boleta)
     and estado = 'J'
     and reversado = 'N'
     and (b.caja = 'S' or a.cod_transaccion <> 760)--solo si pasa por caja,puede pasar 1solo
     and b.cod_tip_operacion = a.cod_tip_ope_cambio
     and c.cod_tip_operacion = a.cod_tip_ope_cambio
     and c.cod_oficina = a.cod_ofi_origen
     and c.cod_moneda = a.cod_moneda
     and a.cod_mad_padre in (73) -- arb
   order by nro_secuencia;
   --for update of a.cod_oficina;--ver!!
  mv movimientos%rowtype;
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion
    (p_tip_movimiento in varchar2,
     p_tip_monto      in varchar2,
     p_cod_moneda     in varchar2,
     p_importe        in number,
     p_nro_secuencia  in number)   is
  v_mto_cheque     number(18,2) := 0;
  v_mto_che_ntro_bco  number(18,2) := 0;
  v_mto_efectivo   number(18,2) := 0;
  begin
    -- evaluo el tipo de valor
    if p_tip_monto = 'E' then
      v_mto_efectivo := p_importe;
      v_mto_cheque   := 0;
    elsif p_tip_monto ='C' then
      v_mto_che_ntro_bco := p_importe;
    else
      v_mto_cheque   := p_importe;
      v_mto_efectivo := 0;
    end if;
    if p_tip_movimiento = 'D' then  -- compra
      -- sumar a los saldos  -- Actualizo el control de caja
      update cj_controles
         set tot_che_otr_bco = nvl(tot_che_otr_bco,0) + nvl(v_mto_cheque,0),
             tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(v_mto_che_ntro_bco,0),
             sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_mto_cheque,0),
             sal_actual = nvl(sal_actual,0) + nvl(v_mto_efectivo,0),
             tot_debitos = nvl(tot_debitos,0) + nvl(v_mto_efectivo,0),
             can_debitos = nvl(can_debitos,0) + decode(v_mto_efectivo,0,0,1),
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = p_cod_moneda
         and fecha = v_fec_caja;
     else
      -- se resta del saldo del cajero -- Actualizo el control de caja
      update cj_controles
         set sal_actual = nvl(sal_actual,0) - nvl(v_mto_efectivo,0),
             tot_creditos = nvl(tot_creditos,0) + nvl(v_mto_efectivo,0),
             can_creditos = nvl(can_creditos,0) + 1,
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = p_cod_moneda
         and fecha = v_fec_caja;
     end if;
      -- genero el movimiento por la extraccion
      insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia,
          cod_tra_padre, cod_mod_padre, cod_mad_padre,
          cod_oficina, cod_moneda, nro_caja,
          nro_documento,  monto, tip_monto, tipo)
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, p_nro_secuencia,
          v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
          v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
          p_nro_boleta, p_importe,p_tip_monto /* efec/cheq */, p_tip_movimiento); /* es debito */
  exception
     when dup_val_on_index then
        --v_cod_respuesta := '022'; -- error
        --v_msj_respuesta := 'ERROR: No puede retomar operacion ya reversada.';
        --para q quede el registro de la reversion
        update cj_movimientos
           set estado = 'N'
         where fecha = v_fec_actual
           and hora = v_ope_hora
           and cod_usuario = v_ope_cod_usuario;
  end lp_gen_transaccion;
begin
  -- Valido la boleta
  if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta de Cambios.';
  else
    -- tomo los datos de la operacion principal, no hace falta,trae todo en el cursor
    /*declare
       v_nro_caja number(4);
    begin
      Select cod_usuario,  hora,  fecha,  cod_moneda,   monto,
             cod_tip_ope_cambio,  cod_bco_central,  mto_equ_local,
             b.cod_ofi_cambio, nro_caja, cotizacion
        into v_ope_cod_usuario,  v_ope_hora,  v_ope_fecha,  v_ope_cod_moneda,
             v_ope_monto, v_ope_tip_operacion, v_ope_cod_bcp,
             v_ope_mto_mon_local, v_ope_ofi_cambio, v_nro_caja, v_cotizacion
        from ba_oficinas b, ge_movimientos a
       where nro_documento = to_number(p_nro_boleta)
         and cod_mod_padre = 7
         and cod_mad_padre = 73
         and reversado = 'N'
         and a.cod_ofi_origen = b.cod_oficina
         and a.nro_secuencia = 1;
      if v_nro_caja is not null then
         v_cod_respuesta := '008';
         v_msj_respuesta := 'Operacion ya fue retomada en la Caja '||v_nro_caja;
      end if;
    exception
       when no_data_found then
          v_cod_respuesta := '001';
          v_msj_respuesta := 'Operacion no registrada';
    end;   */
    if v_cod_respuesta = '000' then
      -- Inicializacion de la aplicacion y el modulo
      BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
      v_existe := 'N';
      for mv in movimientos loop
         --solo si pasa x caja, hace lo pertinente
         if mv.caja ='S' then
            v_existe := 'S';
            -- Obtengo los datos de la caja en las monedas intervinientes --
            prj_obt_datos_caja(p_nro_caja,
                               mv.cod_moneda,
                               v_cod_oficina,
                               v_fec_caja,
                               v_estado,
                               v_sal_actual,
                               v_sal_cheques);
            if v_estado = -1 then
               v_cod_respuesta := '006'; -- error, no existe registro de caja
               v_msj_respuesta := 'Caja inexistente!!';
            elsif v_estado in (0,2) then
               v_cod_respuesta := '004'; -- error
               v_msj_respuesta := 'Caja no esta habilitada en '||mv.cod_moneda||' para esta Operacion';
            elsif v_fec_caja <> v_fec_actual then
               v_cod_respuesta := '005'; -- error
               v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
           -- elsif v_cod_oficina <> mv.cod_ofi_origen then
           --    v_cod_respuesta := '006'; -- error
            --   v_msj_respuesta := 'Operacion no corresponde a esta Oficina';
            end if;
            if v_sal_actual < mv.monto and mv.tip_movimiento = 'C' then
               v_cod_respuesta := '006'; -- error
               v_msj_respuesta := 'Caja no tiene saldo para esta Operacion';
            end if;
            if v_cod_respuesta = '000' then
                -- verifico los decimales del importe y autorizacion -- solo por el credito
                if mv.tip_movimiento ='C' then
                   v_msj_respuesta := fuj_val_importe(mv.tip_movimiento, mv.tip_valor,mv.cod_moneda,mv.monto,245);
                   if v_msj_respuesta is not null then
                      v_cod_respuesta := '005';  -- error
                   end if;
                end if;
            end if;

            --asignar fecha y usuario del movimiento iniciado en GF en ge_movimientos
            if v_cod_respuesta <> '000' then
               exit; -- sale cuando ya hay error
            end if;
            --guardo datos para actualizar movimientos,cj_movimientos y la impresion
            if v_ope_hora is null then
               v_ope_cod_usuario := mv.cod_usuario;
               v_ope_hora        := mv.hora;
               v_ope_fecha       := mv.fecha;
            end if;
            -- genero el movimiento en caja
            lp_gen_transaccion(mv.tip_movimiento,
                                mv.tip_valor,
                                mv.cod_moneda,
                                mv.monto,
                                mv.nro_secuencia);
            if v_cod_respuesta <> '000' then
               exit; -- sale cuando ya hay error
            end if;
/*            --actualizar la oficina del movimiento q pasa x caja, si retoma en otra
            --para q la forma de pago se registre en la oficina q se retoma,(salvo q afecte a cuentas)
            if v_cod_oficina <> mv.cod_ofi_origen then
               update ge_movimientos
                  set cod_oficina = v_cod_oficina --la oficina q retoma
                where current of movimientos;
            end if;*/
         end if;
         if v_cod_respuesta = '000' then
            -- actualizo la posicion x la compra y/o venta si corresponde
            pal_cam.pr_act_posiciones(mv.cod_tip_ope_cambio,
                                     mv.cod_moneda,
                                     pal_cam.FU_OBT_OFI_CAMBIO(mv.cod_ofi_origen),
                                     mv.monto,
                                     mv.mto_equ_local,
                                     mv.cod_bco_central);
         end if;
         if mv.nro_secuencia = 1 then
            v_ope_tip_operacion := mv.cod_tip_ope_cambio;
            v_cod_banco := mv.cod_banco;
            v_nro_cheque := mv.nro_documento3;
            v_cod_tra_compra := mv.cod_transaccion;
            v_cod_retencion := mv.cod_retencion;
            v_ope_monto := mv.monto;
            v_ope_cod_moneda := mv.cod_moneda;
         end if;
      end loop;
      if v_existe = 'N' and v_cod_respuesta = '000' then
         v_cod_respuesta := '007'; -- error
         v_msj_respuesta := 'Operacion no debe ser ingresada a Caja.';
      end if;
      if v_cod_respuesta = '000'  then
        -- actualizo los movimientos a 'N' y las cuentas asociadas a cada movimiento
        pal_cam.pr_act_movimientos(v_ope_cod_usuario,
                                   v_ope_fecha,
                                   v_ope_hora,
                                   'N',  -- pasa a 'N-normal el movimiento
                                   to_number(p_nro_caja),
                                   v_cod_oficina);
      end if;
      --
    end if;
    --
  end if;
  --si es compra de cheque detallar el cheque,
  if v_cod_respuesta = '000' then
    if v_ope_tip_operacion in (57) then -- es compra de cheque
      --si el banco es local -> 133
      if v_nro_cheque is not null then
        if v_cod_tra_compra = 632 then
          v_msj_salida := fuj_pro_transaccion_133(p_nro_operacion,
                                               p_nro_caja,
                                               p_nro_boleta,
                                               v_cod_retencion,
                                               v_cod_banco,
                                               v_nro_cheque,
                                               v_ope_monto);
          --return (v_msj_salida); -- retorna directamente el mensaje
          if v_msj_salida NOT LIKE '%~000~%' THEN
             return v_msj_salida;
          END IF;
        elsif v_cod_tra_compra = 633 then --si es extranjero -> 134, solo en compra se puede dar plaza ext.
          v_msj_salida := fuj_pro_transaccion_134(p_nro_operacion,
                                               p_nro_caja,
                                               p_nro_boleta,
                                               v_cod_banco,
                                               null,
                                               v_nro_cheque,
                                               v_ope_monto);
          --return (v_msj_salida); -- retorna directamente el mensaje
          if v_msj_salida NOT LIKE '%~000~%' THEN
             return v_msj_salida;
          END IF;
        end if;
     end if;
    end if;
  end if;

  --imprimir comprobante de operaciones
    begin
    select nro_documento2
      into v_cod_persona
      from ge_movimientos
     where nro_documento = to_number(p_nro_boleta)
       and reversado = 'N'
       and cod_mod_padre = 7
       and cod_transaccion = 760;
 exception
   when others then
      v_cod_persona := null;
 end;
  begin
    select nvl(cli_frecuente,'N')
     into v_cli_frecuente
     from cr_inf_fondos
    where cod_persona = v_cod_persona;
 exception
   when no_data_found then
   null;
   when others then
   null;
 end;
 if v_cli_frecuente is null then
   v_cli_frecuente := 'N';
 end if;
  if v_cod_respuesta = '000' then
     v_cod_respuesta := 'IMP';
     --si la operacion es superior avisar q se imprima la declaracion x gestion
     /*if pal_Cam.FU_CON_MON_A_MONEDA(v_ope_cod_moneda,
                                      pag_gen.fu_obt_mon_fuerte,
                                      v_ope_monto,
                                      v_cotizacion)
      >= fug_obt_pardinamico('OPE_SUP_MON_FUERTE') then*/
      -- CRO-JM-03/2015: CROGEFIT-3
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
             end) as nro_cuenta
           into v_nro_cuenta
           from ge_movimientos g
          where nro_documento = to_number(p_nro_boleta)
            and reversado = 'N'
            and cod_mod_padre = 7
            and g.nro_cuenta is not null
            group by g.fecha, g.cod_usuario, g.hora;
      exception
        when others then
           v_nro_cuenta := null;
      end;

     if fuj_ver_imp_formulario(v_nro_cuenta,
                               v_cod_persona,
                               pal_cam.fu_con_mon_a_moneda(v_ope_cod_moneda,
                                                           pag_gen.fu_obt_mon_fuerte,
                                                           v_ope_monto,
                                                           v_cotizacion),
                               v_cod_transaccion,
                               v_mto_calculado) then
      if v_cli_frecuente = 'N' then -- Solo si no es cliente frecuente imprime.  V.O. 25/11/2009
         v_msj_respuesta := 'Operacion Confirmada. Comprobante y Decl.Jurada impresos. Oper.Nro. '||p_nro_boleta||'~'||
                     fuj_imp_comprobante_243(p_nro_boleta, v_cod_oficina, p_nro_caja)||
                     fuj_imp_dec_jurada_40(v_ope_fecha, v_ope_hora, v_ope_cod_usuario, 1, v_mto_calculado, v_cod_transaccion);
          -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como ya impreso:
                prj_ins_form_transacciones(v_nro_cuenta,
                                           v_cod_persona,
                                            v_cod_modulo,
                                            v_cod_transaccion,
                                            USER,
                                            v_ope_fecha,
                                            v_ope_hora,
                                            pag_gen.fu_obt_mon_fuerte,
                                            pal_cam.fu_con_mon_a_moneda(v_ope_cod_moneda,
                                                                       pag_gen.fu_obt_mon_fuerte,
                                                                       v_ope_monto,
                                                                       v_cotizacion),
                                            'S');
      else
        v_msj_respuesta := 'Operacion Confirmada. Comprobante de operacion ha sido impreso.'||'~'||
        fuj_imp_comprobante_243(to_number(p_nro_boleta), v_cod_oficina, p_nro_caja);
        -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como ya impreso:
                prj_ins_form_transacciones(v_nro_cuenta,
                                           v_cod_persona,
                                           v_cod_modulo,
                                           v_cod_transaccion,
                                           USER,
                                           v_ope_fecha,
                                           v_ope_hora,
                                           pag_gen.fu_obt_mon_fuerte,
                                           pal_cam.fu_con_mon_a_moneda(v_ope_cod_moneda,
                                                                       pag_gen.fu_obt_mon_fuerte,
                                                                       v_ope_monto,
                                                                       v_cotizacion),
                                           'N');
      end if;
     else
       v_msj_respuesta := 'Operacion Confirmada. Comprobante de operacion ha sido impreso.'||'~'||
       fuj_imp_comprobante_243(to_number(p_nro_boleta), v_cod_oficina, p_nro_caja);
       -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como ya impreso:
                prj_ins_form_transacciones(v_nro_cuenta,
                                           v_cod_persona,
                                           v_cod_modulo,
                                           v_cod_transaccion,
                                           USER,
                                           v_ope_fecha,
                                           v_ope_hora,
                                           pag_gen.fu_obt_mon_fuerte,
                                           pal_cam.fu_con_mon_a_moneda(v_ope_cod_moneda,
                                                                       pag_gen.fu_obt_mon_fuerte,
                                                                       v_ope_monto,
                                                                       v_cotizacion),
                                           'N');
     end if;
     -- retorno de la rutina de impresion
     v_msj_salida := p_nro_operacion||'~'||
                     v_cod_respuesta||'~'||
                     v_msj_respuesta;
     return(v_msj_salida);
  end if;

  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'Operacion confirmada');
  return(v_msj_salida);
exception
   when others then
     v_cod_respuesta := '999';
     v_msj_salida := p_nro_operacion||'~'||
                     v_cod_respuesta||'~'||
                     nvl(v_msj_respuesta,SQLERRM);
     return(v_msj_salida);
end;
/

