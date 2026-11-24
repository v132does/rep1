CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_110 (
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_cod_tra_padre   in varchar2, -- Codigo de transaccion
      p_hora            in varchar2 default null, -- hora de la transaccion a reimprimir
      p_nro_boleta      in varchar2 default null)
return long is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;               -- Caja
  v_cod_modalidad number(3) := 91;           -- Caja
  v_cod_transaccion number(3) := 110;        -- Transaccion
  --
  v_nro_operacion cj_movimientos.nro_documento%type := p_nro_boleta; --x defecto
  v_nro_recibo cj_movimientos.nro_documento%type;
  --v_nro_factura ge_movimientos.nro_documento2%type;
  v_nro_factura cb_lib_ventas.nro_factura%type; -- P.V.
  v_nro_cuenta  cj_movimientos.nro_cuenta%type;
  v_mod_cobro number(3);               -- Caja
  v_mad_cobro number(3);           -- Caja
  v_mad_padre number(3);
  v_cod_tra_cambios number(3);
  --
  v_cod_ofi_origen number(3); -- oficina de la caja

  v_cod_usuario varchar2(10) := upper(user); -- usuario
  --
  v_cod_moneda        varchar2(3);           -- moneda de la operacion
  --
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta long := 'Operacion Confirmada'; -- sin errores
  --
  v_tipo          varchar2(01);  -- Debito para la caja (ingreso)
  v_tip_monto     varchar2(01);  -- E/efectivo C-cheq
--  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  --
  v_cantidad      number(3) := 0;
    -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);          -- saldo actual de la caja en cheques
  v_mon_fuerte        ge_movimientos.cod_moneda%type := pag_gen.FU_OBT_MON_FUERTE;
  v_monto             cj_movimientos.monto%type;--importe del movimiento
  v_cotizacion        ge_movimientos.cotizacion%type;--cotización de la moneda
  v_fecha             ge_movimientos.fecha%type;
--  r_gmovi             ge_movimientos%rowtype;
  v_cli_frecuente     cr_inf_fondos.cli_frecuente%type;
  v_cod_persona       ge_cta_clientes.cod_persona%type;
  f_cod_persona       cj_acu_imp_transacciones.cod_persona%type;
  f_nro_cuenta        cj_acu_imp_transacciones.nro_cuenta%type;
  v_mto_calculado     number;
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo el control de caja // OJO, VER PARA Q SE HACE ESTO? //
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
          v_nro_operacion, v_nro_cuenta, 0,v_tip_monto /* cheq.otros bcos */, v_tipo,
          null); /* no es debito ni credito */
  end lp_gen_transaccion;

  procedure lp_act_can_impresion is
  begin
    update cj_movimientos c
       set c.can_impresion = nvl(c.can_impresion, 0) + 1
     where c.fecha = v_fec_actual
       and c.cod_usuario = v_cod_usuario
       and c.hora = p_hora
       and c.cod_tra_padre = to_number(p_cod_tra_padre);
  exception
    when no_data_found then
      v_cod_respuesta := '006'; -- error
      v_msj_respuesta := 'ERROR: Al actualizar movimiento de Caja.';
    when others then
      v_cod_respuesta := '006'; -- error
      v_msj_respuesta := 'ERROR: Al actualizar movimiento de Caja.';
  end lp_act_can_impresion;
  --
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido los datos ingresados
 if p_cod_tra_padre is  null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Transaccion a reimprimir.';
 elsif p_cod_tra_padre in (201,202,203,204,240,352,354,355,247) then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Transaccion no se puede reimprimir.';
 elsif p_hora is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la hora de la Operacion. Presione F9 para ver Lista de Operaciones';
 else

    -- Datos del movimiento a reimprimir
    select count(*)
      into v_cantidad
      from cj_movimientos a
     where nro_caja = to_number(p_nro_caja)
       and hora = p_hora
       and cod_tra_padre = p_cod_tra_padre
       and estado = 'N' -- normal
       --and cod_usuario = v_cod_usuario; --no sirve si se retomó en caja la operación
        and not exists (select 0 --para q no traiga los mov pendientes de autorización
                from ge_movimientos b
                where hora = p_hora
                --and cod_usuario = v_cod_usuario
                and a.cod_usuario = b.cod_usuario
                and estado in ('P','X')
                and reversado ='N');
       --VER SI DEBE GRABAR EMI_AVISO
/*       and exists (select 0
                   from ge_movimientos
                  where hora = p_hora --fecha = b.fecha and
                    and cod_usuario = v_cod_usuario
                    and emi_aviso ='S'); --comprobante manual
*/
    if v_cantidad = 0 then
       v_cod_respuesta := '001'; -- error
       v_msj_respuesta := 'ERROR: No existe comprobante a reimprimir.';
    else
       --Obtener la moneda de la operacion
       select nro_documento, cod_moneda, nro_cuenta, monto, fecha
         into v_nro_operacion, v_cod_moneda, v_nro_cuenta, v_monto, v_fecha
         from cj_movimientos
        where nro_caja = to_number(p_nro_caja)
          and hora = p_hora
          and cod_tra_padre = p_cod_tra_padre
          and estado = 'N' -- normal
          and rownum = 1;
       --Obtener la cotización de la moneda de la operación
       /*select cotizacion
         into
         from ge_movimientos
        where cod_usuario = v_cod_usuario
          and hora = p_hora
          and fecha = v_fec_actual
          and nro_secuencia = 1;*/

        -- Obtengo los datos de la caja ---------------------------------------
       prj_obt_datos_caja(p_nro_caja,
                             v_cod_moneda,
                             v_cod_oficina,
                             v_fec_caja,
                             v_estado,
                             v_sal_actual,
                             v_sal_cheques);
       if v_estado in (0,2) then  -- error, la caja no esta abierta
          v_cod_respuesta := '003'; -- error
          v_msj_respuesta := 'Caja aun no fue abierta en esta Moneda';
       end if;

       -- Impresion del Comprobante
       if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto

          If p_cod_tra_padre = 351 then
             -- genero el movimiento por la reimpresion
             /*insert into cj_movimientos
               (fecha, hora, cod_usuario, nro_secuencia,
                cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_oficina, cod_moneda, nro_caja, nro_doc_referencia,
                nro_documento, nro_cuenta, monto, tip_monto, tipo)
             values
               (v_fec_actual, v_hor_actual, v_cod_usuario, 1,
                110, 9, 91,
                v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),null,
                p_nro_boleta, null,0,'O' , null); */
             v_tip_monto := 'O';
             lp_gen_transaccion;
             v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso...'||'~'||
             fuj_imp_comprobante_351(p_nro_boleta,
                                     v_cod_oficina,
                                     p_nro_caja);
             v_cod_respuesta := 'IMP';
          elsif p_cod_tra_padre = 353 then
             -- genero el movimiento por la reimpresion
             /*insert into cj_movimientos
               (fecha, hora, cod_usuario, nro_secuencia,
                cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_oficina, cod_moneda, nro_caja, nro_doc_referencia,
                nro_documento, nro_cuenta, monto, tip_monto, tipo)
             values
               (v_fec_actual, v_hor_actual, v_cod_usuario, 1,
                110, 9, 91,
                v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),null,
                p_nro_boleta, null,0,'O' , null);*/
             v_tip_monto := 'O';
             lp_gen_transaccion;
             v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso...'||'~'||
             fuj_imp_comprobante_353(p_nro_boleta,
                                     v_cod_oficina,
                                     p_nro_caja);
             v_cod_respuesta := 'IMP';
          elsif p_cod_tra_padre = 250 then
             -- genero el movimiento por la reimpresion
             /*insert into cj_movimientos
               (fecha, hora, cod_usuario, nro_secuencia,
                cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_oficina, cod_moneda, nro_caja, nro_doc_referencia,
                nro_documento, nro_cuenta, monto, tip_monto, tipo)
             values
               (v_fec_actual, v_hor_actual, v_cod_usuario, 1,
                110, 9, 91,
                v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),null,
                p_nro_boleta, null,0,'O' , null);*/
             v_tip_monto := 'O';
             lp_gen_transaccion;
             v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso...'||'~'||
             fuj_imp_comprobante_250(p_nro_boleta,
                                     v_cod_oficina,
                                     p_nro_caja);
             v_cod_respuesta := 'IMP';
          elsif p_cod_tra_padre in (241, 242, 245, 246, 221, 243, 244) then
             --recuperar los datos
             Select g.cod_moneda,  g.cod_mad_padre, g.cod_tra_padre, g.cod_oficina, g.cotizacion,
              -- CROGEFIT-3: JUANMA 04/2015
                   (case -- aquí elegimos si existe una cuenta distinta a la cuenta de cambios del banco, sino elegimos esa cuenta de cambios:
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
                   end), g.cod_persona
               into v_cod_moneda,  v_mad_padre, v_cod_tra_cambios, v_cod_oficina,v_cotizacion, f_nro_cuenta, f_cod_persona
               from ge_movimientos g
              where --hora =p_hora--LA HORA NO ES LA MISMA PARA 241,242
                    g.nro_caja= p_nro_caja --tuvo q haber pasado x caja
                and g.nro_documento =v_nro_operacion
                and g.nro_secuencia =1
                and g.cod_mod_padre=7--para q no traiga la 110
                and g.estado ='N'
                AND g.REVERSADO ='N';--reversadas no

             --generar movimiento para registrar las impresiones
             /*v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
             r_gmovi.cod_usuario     := v_cod_usuario;
             r_gmovi.hora            := v_hor_actual;
             r_gmovi.fecha           := v_fec_actual;
             r_gmovi.nro_secuencia   := v_nro_secuencia;
             r_gmovi.cod_modulo      := 7;
             r_gmovi.cod_modalidad   := v_mad_padre;--modal d operacion cpra/vta/etc
             r_gmovi.cod_oficina     := v_cod_oficina;
             r_gmovi.cod_moneda      := v_cod_moneda;
             r_gmovi.fec_valor       := v_fec_actual;
             r_gmovi.cod_tra_padre   := 110;
             r_gmovi.cod_mod_padre   := v_cod_modulo;--9
             r_gmovi.cod_mad_padre   := v_cod_modalidad;--91
             r_gmovi.nro_caja        := to_number(p_nro_caja);
             r_gmovi.cod_transaccion := v_cod_tra_cambios;
             r_gmovi.monto           := 0;
             r_gmovi.nro_documento   := v_nro_operacion;
             r_gmovi.nro_documento2  := p_cod_tra_padre;
             r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
             r_gmovi.emi_aviso       := 'N';
             r_gmovi.concepto        := 'Reimpresion Compr. :'||v_nro_operacion;
             r_gmovi.estado          := 'N';
             r_gmovi.reversado       := 'N';
             r_gmovi.cod_rubro       := NULL;
             r_gmovi.nro_cuenta      := null;
             r_gmovi.tip_mov_rubro   := NULL;
             PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);*/
             -- no hubo problemas hasta aqui, genero la transaccion en caja
             v_tip_monto := 'E';
             lp_gen_transaccion();

             -- reimpresion de cambios
             begin
               select cod_persona
               into v_cod_persona
               from ge_cta_clientes
               where nro_cuenta = v_nro_cuenta
               and relacion = 'P';
             exception
               when no_data_found then
                 v_cod_persona := null;
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

             v_cod_respuesta := 'IMP'; -- para indicar que esta ok y se de imprimir
             if p_cod_tra_padre = 221 then
                v_msj_respuesta := 'Operacion Confirmada. Comprobante ha sido impreso...'||'~'||
                fuj_imp_comprobante_221(v_nro_operacion,
                                        v_cod_oficina,
                                        p_nro_caja,
                                        v_mad_padre);
             elsif p_cod_tra_padre in (243, 244) then
                --if pal_Cam.FU_CON_MON_A_MONEDA(v_cod_moneda,v_mon_fuerte,v_monto,v_cotizacion) >= fug_obt_pardinamico('OPE_SUP_MON_FUERTE') then
                -- CRO-JM-03/2015: CROGEFIT-3
               if fuj_ver_imp_formulario(f_nro_cuenta,
                                         f_cod_persona,
                                         0,
                                         p_cod_tra_padre,
                                         v_mto_calculado,
                                         'S',        --enviamos solo en la reimpresion
                                         v_fecha,    --enviamos solo en la reimpresion
                                         p_hora,     --enviamos solo en la reimpresion
                                         USER) then  --enviamos solo en la reimpresion
                      if v_cli_frecuente = 'N' then
                        -- CRO-JM-03/2015: CROGEFIT-3 no se inserta ningún registro, solo se actualiza como ya impreso:
                                      prj_ins_form_transacciones(f_nro_cuenta,
                                                                 f_cod_persona,
                                                                 v_cod_modulo,
                                                                 p_cod_tra_padre,
                                                                 USER,
                                                                 v_fecha,
                                                                 p_hora,
                                                                 pag_gen.fu_obt_mon_fuerte,
                                                                 0,
                                                                 'S',   --impreso
                                                                 'N',   --insertar
                                                                 'S');  --REIMPRESION
                                   v_msj_respuesta := 'Operación Confirmada. Comprobante y Decl.Jurada impresos. Oper.Nro. '||v_nro_operacion||'~'||
                                                   fuj_imp_comprobante_243(v_nro_operacion, v_cod_oficina, p_nro_caja)||
                                                   fuj_imp_dec_jurada_40(v_fecha, p_hora, user, 1, v_mto_calculado,p_cod_tra_padre,
                                                   null,null,null,null,null,'S');
                      else
                         v_msj_respuesta := 'Operación Confirmada. Comprobante impreso. Oper.Nro. '||v_nro_operacion||'~'||
                                         fuj_imp_comprobante_243(v_nro_operacion, v_cod_oficina, p_nro_caja);

                      end if;

                else
                    v_msj_respuesta := 'Operacion Confirmada. Comprobante ha sido impreso...'||'~'||
                    fuj_imp_comprobante_243(v_nro_operacion,
                                        v_cod_oficina,
                                        p_nro_caja);
                end if;

             else
                --if pal_Cam.FU_CON_MON_A_MONEDA(v_cod_moneda,v_mon_fuerte,v_monto,v_cotizacion) >= fug_obt_pardinamico('OPE_SUP_MON_FUERTE') then
                if fuj_ver_imp_formulario(f_nro_cuenta,
                                         f_cod_persona,
                                         0,
                                         p_cod_tra_padre,
                                         v_mto_calculado,
                                         'S',        --enviamos solo en la reimpresion
                                         v_fecha,    --enviamos solo en la reimpresion
                                         p_hora,     --enviamos solo en la reimpresion
                                         USER) then  --enviamos solo en la reimpresion
                          if v_cli_frecuente = 'N' then
                          -- CRO-JM-03/2015: CROGEFIT-3 no se inserta ningún registro, solo se actualiza como ya impreso:
                                      prj_ins_form_transacciones(f_nro_cuenta,
                                                                 f_cod_persona,
                                                                 v_cod_modulo,
                                                                 p_cod_tra_padre,
                                                                 USER,
                                                                 v_fecha,
                                                                 p_hora,
                                                                 pag_gen.fu_obt_mon_fuerte,
                                                                 0,
                                                                 'S',  --impreso
                                                                 'N',  --insertar
                                                                 'S'); --REIMPRESION
                                     v_msj_respuesta := 'Operación Confirmada. Comprobante y Decl.Jurada impresos. Oper.Nro. '||v_nro_operacion||'~'||
                                                     fuj_imp_comprobante_245(v_nro_operacion, v_cod_oficina, p_nro_caja,v_mad_padre)||
                                                     fuj_imp_dec_jurada_40(v_fecha, p_hora, user, 1, v_mto_calculado, p_cod_tra_padre,
                                                                           null,null,null,null,null,'S');
                          else
                           v_msj_respuesta := 'Operación Confirmada. Comprobante impreso. Oper.Nro. '||v_nro_operacion||'~'||
                                           fuj_imp_comprobante_245(v_nro_operacion, v_cod_oficina, p_nro_caja,v_mad_padre);
                          end if;

                 else
                    v_msj_respuesta := 'Operacion Confirmada. Comprobante ha sido impreso...'||'~'||
                    fuj_imp_comprobante_245(v_nro_operacion,
                                            v_cod_oficina,
                                            p_nro_caja,
                                            v_mad_padre);
                 end if;
             end if;
          elsif p_cod_tra_padre = 215 then --cobro servicios
             v_tip_monto := 'O';
             lp_gen_transaccion;
             v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso...'||'~'||
             fuj_imp_comprobante_215(p_nro_boleta,
                                     v_cod_oficina,
                                     p_nro_caja);
             v_cod_respuesta := 'IMP';
          elsif p_cod_tra_padre = 219 then --cobro servicios
             v_tip_monto := 'O';
             lp_gen_transaccion;
             v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso...'||'~'||
             fuj_imp_comprobante_219(p_nro_boleta,
                                     v_cod_oficina,
                                     p_nro_caja);
             v_cod_respuesta := 'IMP';
          elsif p_cod_tra_padre in (/*250,*/ 359, 360, 362) then
             --- Recupero el recibo de la forma de pago
             BEGIN
               Select nro_documento, referencia -- P.V. nro_documento2
                 into v_nro_recibo, v_nro_factura
                 from ge_movimientos
                where hora    = p_hora
                  and nro_caja  = p_nro_caja --tuvo q haber pasado x caja
                  and fecha     = v_fec_actual
                  --and rownum    = 1
                  AND REVERSADO ='N';--reversadas no
             EXCEPTION
               WHEN no_data_found THEN
                 v_nro_recibo  := NULL;
                 v_nro_factura := NULL;
               WHEN too_many_rows THEN
                 --obtener el nro_documento de la secuencia máxima
                 Select nro_documento, referencia
                 into v_nro_recibo, v_nro_factura
                 from ge_movimientos
                where hora    = p_hora
                  and nro_caja  = p_nro_caja --tuvo q haber pasado x caja
                  and fecha     = v_fec_actual
                  AND REVERSADO ='N'--reversadas no
                  AND nro_secuencia IN (Select MAX(g.nro_secuencia)
                                       from ge_movimientos g
                                      where g.hora    = p_hora
                                        and g.nro_caja  = p_nro_caja --tuvo q haber pasado x caja
                                        and g.fecha     = v_fec_actual
                                        AND g.REVERSADO ='N');
             END;

             -- Grabo la transaccion 110 para la cuenta.
             Select p.cod_moneda,  p.cod_modulo, p.cod_modalidad--, p.cod_oficina
               into v_cod_moneda, v_mod_cobro, v_mad_cobro--, v_cod_oficina
               from ge_cuentas p
              where p.nro_cuenta = v_nro_cuenta;

--             v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;

             /*r_gmovi.cod_usuario     := v_cod_usuario;
             r_gmovi.hora            := v_hor_actual;
             r_gmovi.fecha           := v_fec_actual;
             r_gmovi.nro_secuencia   := v_nro_secuencia;
             r_gmovi.cod_modulo      := v_mod_cobro;
             r_gmovi.cod_modalidad   := v_mad_cobro;
             r_gmovi.cod_oficina     := v_cod_oficina;
             r_gmovi.cod_moneda      := v_cod_moneda;
             r_gmovi.fec_valor       := v_fec_actual;
             r_gmovi.cod_tra_padre   := 110;
             r_gmovi.cod_mod_padre   := v_cod_modulo;
             r_gmovi.cod_mad_padre   := v_cod_modalidad;
             r_gmovi.nro_caja        := to_number(p_nro_caja);
             r_gmovi.cod_transaccion := null; --- Efectivo
             r_gmovi.monto           := 0;
             r_gmovi.nro_documento   := v_nro_operacion;
             r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
             r_gmovi.emi_aviso       := 'N';
             r_gmovi.concepto        := 'Reimpresion Compr. :'||v_nro_operacion;
             r_gmovi.estado          := 'N';
             r_gmovi.reversado       := 'N';
             r_gmovi.cod_rubro       := NULL;
             r_gmovi.nro_cuenta      := v_nro_cuenta;
             r_gmovi.tip_mov_rubro   := NULL;
             PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);*/
             -- no hubo problemas hasta aqui, genero la transaccion en caja
             v_tip_monto := 'E';
             lp_gen_transaccion();
             -- Hasta aqui es la grabación del movimiento por reimpresion
             v_cod_respuesta := 'IMP'; -- para indicar que esta ok y se de imprimir

             if p_cod_tra_padre = 250 then
                v_msj_respuesta := 'Operacion Confirmada. Comprobante ha sido impreso...'||'~'||
                FUJ_IMP_TRANSACCION_250(v_cod_ofi_origen, -- oficina
                               v_nro_operacion,
                               p_nro_caja, -- Caja
                               v_cod_moneda, -- Moneda
                               v_nro_cuenta, -- cuenta
                               v_fec_actual,
                               p_hora -- hora
                               );
             else
                v_msj_respuesta := 'Operacion Confirmada. Comprobante ha sido impreso...'||'~'||
                fuj_imp_transaccion_360(v_cod_oficina, --v_cod_ofi_origen,
                                        v_nro_recibo, -- P.V. nvl(v_nro_recibo,v_nro_factura),
                                        v_nro_factura,
                                        p_nro_caja,
                                        v_cod_moneda,
                                        v_nro_cuenta,
                                        v_fec_actual,
                                        p_hora);
             end if;
          elsif p_cod_tra_padre = 222 then
            v_tip_monto := 'O';
             lp_gen_transaccion;
             v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso...'||'~'||
             fuj_imp_comprobante_222(p_nro_boleta,
                                     v_cod_oficina,
                                     p_nro_caja);
             v_cod_respuesta := 'IMP';
          elsif p_cod_tra_padre = 220 then
            v_tip_monto := 'O';
             lp_gen_transaccion;
             v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso...'||'~'||
             fuj_imp_comprobante_220(p_nro_boleta,
                                     v_cod_oficina,
                                     p_nro_caja);
             v_cod_respuesta := 'IMP';
          elsif p_cod_tra_padre = 226 then
            v_tip_monto := 'O';
             lp_gen_transaccion;
             v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso...'||'~'||
             fuj_imp_comprobante_226(p_nro_boleta,
                                     v_cod_oficina,
                                     p_nro_caja);
             v_cod_respuesta := 'IMP';
          elsif p_cod_tra_padre = 369 then -- Cobro de Caja de Seguridad
             v_tip_monto := 'O';
             lp_gen_transaccion;
             v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso...'||'~'||
             fuj_imp_comprobante_369(p_nro_boleta,
                                     v_cod_oficina,
                                     p_nro_caja);
             v_cod_respuesta := 'IMP';
          elsif p_cod_tra_padre = 251 then -- ADELANTO EN EFECTIVO - tARJ CRED
             v_tip_monto := 'O';
             lp_gen_transaccion;
             v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso...'||'~'||
             fuj_imp_comprobante_251(p_nro_boleta,
                                     v_cod_oficina,
                                     p_nro_caja);
             v_cod_respuesta := 'IMP';
          else
             v_cod_respuesta := '001'; -- para indicar que esta ok y se de imprimir
             v_msj_respuesta := 'Impresion de comprobante no previsto para la transacción...';
          end if;
          lp_act_can_impresion;
      End if;
    end if;
 end if;
 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
exception
 when others then
     /* armo finalmente el mensaje de respuesta */
     v_msj_salida := p_nro_operacion||'~'||
                     '999'||'~'||
                     sqlerrm;
     return(v_msj_salida);
end FUJ_PRO_TRANSACCION_110;
/

