CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_242
 (p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
  p_nro_caja in varchar2,        -- Nro de Caja
  p_nro_boleta in varchar2       -- nro de operacion de cambios
 )
 RETURN LONG
 IS
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_transaccion number(4) := 242;  -- transaccion
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
  v_ope_cod_bcp       varchar2(4);
  v_ope_mto_mon_local number(18);
  v_ope_ofi_cambio    number(4);
  v_existe            varchar2(1) := 'N';
  v_cotizacion        ge_movimientos.cotizacion%type;
  v_cli_frecuente     varchar2(1) := 'N';
  v_cod_persona       ba_personas.cod_persona%type;
  v_cta_cambios       lc_cta_cambios.nro_cuenta%type;
  v_mto_calculado     number;
  v_cod_tip_operacion  lc_tip_operaciones.cod_tip_operacion%type;
  v_cod_per            ba_personas.cod_persona%type;
  -- Cursor de movimientos de la operacion
  cursor movimientos is
  Select a.nro_secuencia, a.cod_moneda, a.monto, a.estado, b.descripcion,
         decode(b.tip_valor,'E','E',decode(a.cod_transaccion,606,'C',607,'O',610,'T',632,'S',633,'X')) tip_valor,
         a.cod_ofi_origen, c.tip_movimiento,
         a.cod_usuario, a.fecha, a.hora,a.nro_cuenta, b.cod_tip_operacion, a.cod_persona
    from lc_tip_ope_oficinas c,lc_tip_operaciones b, ge_movimientos a
   where nro_documento = to_number(p_nro_boleta)
     and estado = 'J'
     and reversado = 'N'
     and b.caja = 'S' -- solo si pasa por caja
     and b.cod_tip_operacion = a.cod_tip_ope_cambio
     and c.cod_tip_operacion = a.cod_tip_ope_cambio
     and c.cod_oficina = a.cod_ofi_origen
     and c.cod_moneda = a.cod_moneda
     and a.cod_mad_padre = 72 -- venta
   order by nro_secuencia;
  mv movimientos%rowtype;
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion
    (p_tip_movimiento in varchar2,
     p_tip_monto      in varchar2,
     p_cod_moneda     in varchar2,
     p_importe        in number,
     p_nro_secuencia  in number)   is
  v_mto_cheque        number(18,2) := 0;
  v_mto_che_ntro_bco  number(18,2) := 0;
  v_mto_efectivo      number(18,2) := 0;
   v_cta_cam_global     lc_cta_cambios.nro_cuenta%type;
  begin
    -- evaluo el tipo de valor
    if p_tip_monto = 'E' then
      v_mto_efectivo := p_importe;
    elsif p_tip_monto ='C' then
      v_mto_che_ntro_bco := p_importe;
    else
      v_mto_cheque   := p_importe;
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
      --WA:10/09/2013 insertamos el Nro de Cuenta de Cambios, si es Cheque Otros Bancos
     --y no es cta bolsa
     v_cta_cam_global:= FUG_OBT_PARDINAMICO('CTA_CAM_CLI_TEMPORAL');
     --Buscamos la Cta de Cambio
     begin
       select a.nro_cuenta
        into v_cta_cambios
        from ge_movimientos a
         where a.nro_documento= p_nro_boleta
          and a.nro_secuencia=2;
     exception
      when no_data_found then
         v_cta_cambios:= null;
      when others then
         v_cta_cambios:= null;
     end;

     if p_tip_monto in ('T','S','O') and v_cta_cambios is not null
        and v_cta_cambios <> v_cta_cam_global then
        insert into cj_movimientos
               (fecha, hora, cod_usuario, nro_secuencia,
                cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_oficina, cod_moneda, nro_caja,
                nro_documento,  monto, tip_monto, tipo,nro_cuenta)
            values
               (v_fec_actual, v_hor_actual, v_cod_usuario, p_nro_secuencia,
                v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
                v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
                p_nro_boleta, p_importe,
                p_tip_monto, p_tip_movimiento, v_cta_cambios); /* es D-ebito o C-redito */
                /*E-fectivo/C-heq Ntro.Bco /O-Cheq.Otr.Bco(1) /T-Otr.Bco Tarde(2) /S-Otr.Bco(3) PLoc /X-Otr.Bco(3) PExt*/
      else
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
      end if;
   end lp_gen_transaccion;
begin
 -- Valido la boleta
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta de Cambios.';
 else
    -- tomo los datos de la operacion principal
    declare
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
         and cod_mad_padre = 72 -- venta
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
    end;
    if v_cod_respuesta = '000' then
      -- Inicializacion de la aplicacion y el modulo
      BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
      v_existe := 'N';
      for mv in movimientos loop
         v_existe := 'S';
         v_cod_tip_operacion := mv.cod_tip_operacion;
         v_cod_per           := mv.cod_persona;
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
            v_msj_respuesta := 'Realice la Apertura de Caja previamente';
         elsif v_fec_caja <> v_fec_actual then
            v_cod_respuesta := '005'; -- error
            v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
         --elsif v_cod_oficina <> mv.cod_ofi_origen then
        --    v_cod_respuesta := '006'; -- error
         --   v_msj_respuesta := 'Operacion no corresponde a esta Oficina';
         end if;
         if v_sal_actual < mv.monto and mv.tip_movimiento = 'C' then
            v_cod_respuesta := '006'; -- error
            v_msj_respuesta := 'Caja no tiene saldo para esta Operacion';
         end if;
         ---Verifica Monto Superior USD (Solo Clientes - Venta Efectivo)
         if v_cod_tip_operacion = 26 and
            v_cod_per is not null then
            --Valida el monto y tipo de Persona
            if fuj_val_mto_max_efe_cam(v_cod_per,
                                       pal_cam.FU_CON_MON_A_MONEDA(v_ope_cod_moneda,pag_gen.fu_obt_mon_fuerte,v_ope_monto,v_cotizacion)
                                       ) = 'N' then
               v_cod_respuesta := '003'; -- error
               v_msj_respuesta := '! Operacion Supera Monto Efectivo, debe ser ingresada como Depósito en Cta.';
            end if;
         end if;
      
         if v_cod_respuesta <> '000' then
            exit; -- sale cuando ya hay error
         end if;
         -- genero el movimiento en caja
         lp_gen_transaccion(mv.tip_movimiento,
                             mv.tip_valor,
                             mv.cod_moneda,
                             mv.monto,
                             mv.nro_secuencia);

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
        -- actualizo la posición
        pal_cam.pr_act_posiciones(v_ope_tip_operacion,
                                  v_ope_cod_moneda,
                                  v_ope_ofi_cambio,
                                  v_ope_monto,
                                  v_ope_mto_mon_local,
                                  v_ope_cod_bcp);
      end if;
      --
    end if;
    --
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
     --si la operación es superior avisar q se imprima la declaración x gestión
       --CRO-JM-03/2015: CROGEFIT-3 Validacion de formularios F.I.T
       /*if pal_Cam.FU_CON_MON_A_MONEDA(v_ope_cod_moneda,pag_gen.fu_obt_mon_fuerte,v_ope_monto,v_cotizacion)
      >= fug_obt_pardinamico('OPE_SUP_MON_FUERTE') then*/
       if fuj_ver_imp_formulario(v_cta_cambios,
                                 v_cod_persona,
                                 pal_Cam.FU_CON_MON_A_MONEDA(v_ope_cod_moneda,
                                                            pag_gen.fu_obt_mon_fuerte,
                                                            v_ope_monto,
                                                            v_cotizacion),
                                 v_cod_transaccion,
                                 v_mto_calculado) then
            if v_cli_frecuente = 'N' then -- Solo si no es cliente frecuente imprime.  V.O. 25/11/2009
               v_msj_respuesta := 'Operación Confirmada. Comprobante y Decl.Jurada impresos. Oper.Nro. '||p_nro_boleta||'~'||
                           fuj_imp_comprobante_245(p_nro_boleta, v_cod_oficina, p_nro_caja)||
                           fuj_imp_dec_jurada_40(v_ope_fecha, v_ope_hora, v_ope_cod_usuario, 1, v_mto_calculado, v_cod_transaccion);
              -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como ya impreso:
                          prj_ins_form_transacciones(v_cta_cambios,
                                                     v_cod_persona,
                                                      v_cod_modulo,
                                                      v_cod_transaccion,
                                                      USER,
                                                      v_fec_actual,
                                                      v_hor_actual,
                                                      pag_gen.fu_obt_mon_fuerte,
                                                      pal_Cam.FU_CON_MON_A_MONEDA(v_ope_cod_moneda,
                                                                                pag_gen.fu_obt_mon_fuerte,
                                                                                v_ope_monto,
                                                                                v_cotizacion),
                                                      'S');
            else
              v_msj_respuesta := 'Operación Confirmada. Comprobante de operación ha sido impreso.'||'~'||
              fuj_imp_comprobante_245(to_number(p_nro_boleta), v_cod_oficina, p_nro_caja);
              -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como no impreso:
                          prj_ins_form_transacciones(v_cta_cambios,
                                                     v_cod_persona,
                                                      v_cod_modulo,
                                                      v_cod_transaccion,
                                                      USER,
                                                      v_fec_actual,
                                                      v_hor_actual,
                                                      pag_gen.fu_obt_mon_fuerte,
                                                      pal_Cam.FU_CON_MON_A_MONEDA(v_ope_cod_moneda,
                                                                  pag_gen.fu_obt_mon_fuerte,
                                                                  v_ope_monto,
                                                                  v_cotizacion),
                                                      'N');
            end if;
     else
       v_msj_respuesta := 'Operación Confirmada. Comprobante de operación ha sido impreso.'||'~'||
       fuj_imp_comprobante_245(to_number(p_nro_boleta), v_cod_oficina, p_nro_caja);
       -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como no impreso:
                    prj_ins_form_transacciones(v_cta_cambios,
                                               v_cod_persona,
                                                v_cod_modulo,
                                                v_cod_transaccion,
                                                USER,
                                                v_fec_actual,
                                                v_hor_actual,
                                                pag_gen.fu_obt_mon_fuerte,
                                                pal_Cam.FU_CON_MON_A_MONEDA(v_ope_cod_moneda,
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
