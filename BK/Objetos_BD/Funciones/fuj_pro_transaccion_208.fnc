create or replace function it.FUJ_PRO_TRANSACCION_208(
      p_nro_operacion in varchar2, -- Nro de referencia de la operacion
      p_nro_caja      in varchar2, -- Nro de Caja
      p_nro_boleta    in varchar2, -- Nro de la boleta
      p_cod_moneda    in varchar2, -- codigo de la moneda
      p_mto_efectivo  in varchar2, -- importe en efectivo
      p_nro_cuenta    in varchar2, -- Número de Cuenta
      p_concepto      in varchar2 )-- concepto de la operacion
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_tra_padre number(4)  := 208;
  v_cod_transaccion number(4) := 208;  -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);      -- saldo actual de la caja en cheques
  v_descripcion       varchar2(200);
  -- Datos de salida
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(1000) := 'Operacion Confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'C';  -- Credito para la caja (Egreso)
  v_mto_efectivo  number := nvl(to_number(p_mto_efectivo),0); -- importe  en efectivo
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  --
  v_cod_mon_cta ba_monedas.cod_moneda%type;
  --
  v_tip_caja       cj_cajas.tipo%type;
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo el control de caja
      update cj_controles
         set sal_actual = nvl(sal_actual,0) - nvl(v_mto_efectivo,0),
             tot_creditos = nvl(tot_creditos,0) + nvl(v_mto_efectivo,0),
             can_creditos = nvl(can_creditos,0) + decode(v_mto_efectivo,0,0,1),
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = p_cod_moneda
         and fecha = v_fec_caja;
      v_nro_secuencia := 0;
      if v_mto_efectivo > 0 then
        -- genero el movimiento por el ingreso en efectivo
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, 
            tipo)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 1
            v_cod_tra_padre, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
            p_nro_boleta, p_nro_cuenta, v_mto_efectivo,'E', --efectivo 
            v_tipo); -- es debito 
      end if;
  end lp_gen_transaccion;
  --
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido la moneda
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 elsif p_cod_moneda is null then
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Moneda de la Operacion.';
 elsif v_mto_efectivo is null or v_mto_efectivo < 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Efectivo.';
 elsif p_nro_cuenta is  null then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese Cuenta ATM';
 else
    -- Valido la moneda ingresada
    prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
 end if;
 if v_cod_respuesta = '000' then -- sin errores
    v_tip_caja := fuj_obt_tip_caja(p_nro_caja);
    -- Si la caja de tipo P(Prosegur) usa la transacción 1205
    if nvl(v_tip_caja,'x') = 'P' then
      v_cod_transaccion := 1208;
    end if;
    -- Verifico la duplicacion del registro
    prj_val_duplicacion(p_nro_caja,
                        v_cod_tra_padre,
                        p_cod_moneda,
                        p_nro_boleta,
                        v_cod_respuesta,
                        v_msj_respuesta);
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
       -- Obtengo los datos de la caja ---------------------------------------
       prj_obt_datos_caja(p_nro_caja,
                          p_cod_moneda,
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
       end if;
    end if;
    if v_cod_respuesta = '000' then
       -- verifico los decimales del importe en efectivo
       v_msj_respuesta := fuj_val_importe(v_tipo, 'E',p_cod_moneda,v_mto_efectivo);
       --
       if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       else
          -- valido el rubro contable
          begin
                 select denominacion, cod_moneda
                   into v_descripcion, v_cod_mon_cta
                   from cc_cta_bancarias
                  where cod_modulo = 4
                    and cod_modalidad = 46
                    and nro_cuenta = p_nro_cuenta
                    and estado <> 'C';
          exception
              when no_data_found then
                  v_cod_respuesta := '005'; -- error
                  v_msj_respuesta := 'Cuenta ATM no valida. Presione F9 para lista de Valores.';
              when others then
                  v_cod_respuesta := '005'; -- error
                  v_msj_respuesta := 'Cuenta ATM. '||sqlerrm;
          end;
          --
          if v_cod_respuesta = '000' and v_cod_mon_cta <> p_cod_moneda then
            v_cod_respuesta := '005'; -- error
            v_msj_respuesta := 'Moneda ingresada no Corresponde con la Cta..'; 
          end if;
          if v_cod_respuesta = '000' then
            -- Acualizo la cuenta con el efectivo
            if v_mto_efectivo > 0 then
              -- Asigno el nro de caja a los movimientos
              pag_cta.pr_nro_caja(to_number(p_nro_caja));
              --
              pag_cta.pr_act_operacion(p_nro_cuenta,--P_NRO_CUENTA,
                                       v_hor_actual, --P_HORA,
                                       'D', --P_TIP_MOVIMIENTO,
                                       p_cod_moneda, --P_COD_MONEDA,
                                       p_mto_efectivo, --P_MONTO,
                                       v_cod_tra_padre, --P_COD_TRA_PADRE,
                                       v_cod_transaccion, --P_COD_TRANSACCION,
                                       p_nro_boleta, -- P_NRO_DOCUMENTO
                                       null, --P_COTIZACION,
                                       v_cod_oficina, --P_COD_OFI_ORIGEN,
                                       v_cod_modulo, --P_COD_MOD_PADRE,
                                       v_cod_modalidad, --P_COD_MAD_PADRE,
                                       null, --P_COD_TASA,
                                       null, --P_VAL_TASA,
                                       p_concepto, --P_CONCEPTO,
                                       'S', --P_EMI_AVISO,
                                       v_nro_secuencia, --P_NRO_SECUENCIA,
                                       v_fec_actual );--P_FEC_VALOR
           end if;
           --
           if pag_cta.g_cod_error <> 0 then
           -- actualizacion con problemas
             v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
             v_msj_respuesta := pag_cta.g_msj_error;
           end if;
         end if;
         if v_cod_respuesta = '000' then
            -- no hubo problemas hasta aqui, genero la transaccion en caja
           lp_gen_transaccion();
         end if;
      end if;
    end if;
 end if;
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    v_msj_respuesta := 'Operacion confirmada';
 end if;
 -- falta armar el mensaje de respuesta 
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
end FUJ_PRO_TRANSACCION_208;
/

