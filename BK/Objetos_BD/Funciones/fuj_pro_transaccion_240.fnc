create or replace function it.FUJ_PRO_TRANSACCION_240(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_cod_moneda  in varchar2,     -- codigo de la moneda
      p_mto_efectivo in varchar2 default null, -- Efectivo
      p_mto_cheque in varchar2  default null  -- Importe del ingreso en cheques
      )    -- importe en efectivo
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_transaccion number(4) := 240;  -- transaccion
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
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(1000) := 'Operacion Confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'D';  -- Debito para la caja (ingreso)
  v_tip_monto     varchar2(01) := 'O';  -- Cheq. Otros Bancos
  v_mto_cheque    number := nvl(to_number(p_mto_cheque),0); -- importe  en cheques
  v_mto_efectivo  number := nvl(to_number(p_mto_efectivo),0); -- importe  en efectivo
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  -- Registro de movimientos diarios
  R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
  --
  v_ok     varchar2(1);
  v_pedido varchar2(400);
  v_respuesta varchar2(4000);
  v_nro_operacion varchar2(10);
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo el control de caja
      update cj_controles
         set sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_mto_cheque,0),
             sal_actual = nvl(sal_actual,0) + nvl(v_mto_efectivo,0)
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = p_cod_moneda
         and fecha = v_fec_caja;
      --
      v_nro_secuencia := 0;
      if v_mto_efectivo <> 0 then
        -- genero el movimiento por el ingreso en efectivo
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 1
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
            null, null, v_mto_efectivo, 'E' /* efectivo */, v_tipo); /* es debito */
      end if;
      if v_mto_cheque <> 0 then
        -- genero el movimiento por el ingreso en cheques
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 2
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
            null, null, v_mto_cheque, v_tip_monto /* cheq.otros bcos */, v_tipo); /* es debito */
      end if;
  end lp_gen_transaccion;
  --
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido la moneda
 if p_cod_moneda is null then
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Moneda de la Operacion.';
/* elsif v_mto_efectivo is null and v_mto_cheque is null then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese uno de los Importes.';
 elsif v_mto_cheque is null  then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Cheques.';
 elsif v_mto_efectivo is null  then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Efectivo.'; */
 else
    -- Valido la moneda ingresada
    prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
 end if;
 if v_cod_respuesta = '000' then -- sin errores
    -- Verifico la duplicacion del registro
    prj_val_duplicacion(p_nro_caja,
                        v_cod_transaccion,
                        p_cod_moneda,
                        null,
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
       if p_mto_efectivo is null then
          v_mto_efectivo := v_sal_actual * -1;
       end if;
       if p_mto_cheque is null then
          v_mto_cheque := v_sal_cheques * -1;
       end if;
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
       -- verifico los decimales del importe en cheques
       -- v_msj_respuesta := fuj_val_importe(v_tipo, v_tip_monto,p_cod_moneda,v_mto_cheque);
       --if v_msj_respuesta is null then -- valido el efectivo
       --   v_msj_respuesta := fuj_val_importe(v_tipo, 'E',p_cod_moneda,v_mto_efectivo);
       --end if;
       v_msj_respuesta := null;
       if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       else
          if v_cod_respuesta = '000' then
              begin
                -- Acualizo la cuenta con el efectivo
                if v_mto_efectivo <> 0 then
                   -- Aumento la secuencia
                   v_nro_secuencia         := v_nro_secuencia + 1;
                   -- Carga los parametros de movimientos de efectivo
                   r_gmovi.cod_modulo      := v_cod_modulo;
                   r_gmovi.cod_modalidad   := v_cod_modalidad;
                   r_gmovi.cod_oficina     := v_cod_oficina;
                   r_gmovi.nro_cuenta      := null;
                   r_gmovi.cod_moneda      := p_cod_moneda;
                   r_gmovi.cod_usuario     := v_cod_usuario;
                   r_gmovi.hora            := v_hor_actual;
                   r_gmovi.fecha           := v_fec_actual;
                   r_gmovi.nro_secuencia   := v_nro_secuencia;
                   --
                   r_gmovi.fec_valor       := v_fec_actual;
                   r_gmovi.cod_tra_padre   := v_cod_transaccion;
                   r_gmovi.cod_mod_padre   := v_cod_modulo;
                   r_gmovi.cod_mad_padre   := v_cod_modalidad;
                   r_gmovi.cod_transaccion := 1590; -- transaccion de efectivo
                   r_gmovi.monto           := v_mto_efectivo;
                   r_gmovi.nro_documento   := null;
                   r_gmovi.cod_tasa        := null;
                   r_gmovi.val_tasa        := null;
                   r_gmovi.cotizacion      := null;
                   r_gmovi.cod_ofi_origen  := v_cod_oficina;
                   r_gmovi.emi_aviso       := 'N';
                   r_gmovi.concepto        := 'Traspaso de Efectivo a Sist.Principal';
                   r_gmovi.estado          := 'N';
                   r_gmovi.reversado       := 'N';
                   r_gmovi.nro_caja        := to_number(p_nro_caja);
                   r_gmovi.cod_rubro       := null;
                   r_gmovi.tip_mov_rubro   := null;
                   PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
               end if;
               -- Acualizo la cuenta con el cheque depositado sino hubo errores
               if v_mto_cheque <> 0 then
                   -- Aumento la secuencia
                   v_nro_secuencia         := v_nro_secuencia + 1;
                   -- Carga los parametros de movimientos de cheques
                   r_gmovi.cod_modulo      := v_cod_modulo;
                   r_gmovi.cod_modalidad   := v_cod_modalidad;
                   r_gmovi.cod_oficina     := v_cod_oficina;
                   r_gmovi.nro_cuenta      := null;
                   r_gmovi.cod_moneda      := p_cod_moneda;
                   r_gmovi.cod_usuario     := v_cod_usuario;
                   r_gmovi.hora            := v_hor_actual;
                   r_gmovi.fecha           := v_fec_actual;
                   r_gmovi.nro_secuencia   := v_nro_secuencia;
                   --
                   r_gmovi.fec_valor       := v_fec_actual;
                   r_gmovi.cod_tra_padre   := v_cod_transaccion;
                   r_gmovi.cod_mod_padre   := v_cod_modulo;
                   r_gmovi.cod_mad_padre   := v_cod_modalidad;
                   r_gmovi.cod_transaccion := 1595; -- transaccion de cheques
                   r_gmovi.monto           := v_mto_cheque;
                   r_gmovi.nro_documento   := null;
                   r_gmovi.cod_tasa        := null;
                   r_gmovi.val_tasa        := null;
                   r_gmovi.cotizacion      := null;
                   r_gmovi.cod_ofi_origen  := v_cod_oficina;
                   r_gmovi.emi_aviso       := 'N';
                   r_gmovi.concepto        := 'Traspaso de Cheques a Sist.Principal';
                   r_gmovi.estado          := 'N';
                   r_gmovi.reversado       := 'N';
                   r_gmovi.nro_caja        := to_number(p_nro_caja);
                   r_gmovi.cod_rubro       := null;
                   r_gmovi.tip_mov_rubro   := null;
                   PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
               end if;
             exception
                when others then
                   -- hubo error en la insercion de registros ge_movimientos
                   v_msj_respuesta := sqlerrm;
                   v_cod_respuesta := '007';
             end;
         end if;
         if v_cod_respuesta = '000' then
             -- no hubo problemas hasta aqui, genero la transaccion en caja
             lp_gen_transaccion();
             -- as/400
             /*
             NRO_OPERACION  Numero secuencial generado  el ORACLE    N  10
             TIPO  Tipo de Operación: V-Verificacion, C-Confirmacion de operación, T-Traspaso entre Cajas  T  C  1
             COD_OPERACION  Fijo 091210, para indicar el traspaso del cajero  091210  N  6
             COD_USUARIO  Código del usuario que solicita la operación    C  10
             HORA  Hora de la operación registrada    C  8
             COD_OFICINA  Código de la oficina origen de la consulta    N  3
             TIPO_MOVIMIENTO  Indica si se quiere hacer un D-Debito o C-Crédito    C  1
             COD_MONEDA  Moneda de la operación solicitada    C  3
             MONTO  Monto de la operación    N  16   Long  58
             NRO_OPERACION  Nro de operación generado por el ORACLE    N  10
             COD_RESPUESTA  Cod. de respuesta. Ver TABLA DE RESPUESTAS    N  3
             MENSAJE  Mensaje de error, si el COD_RESPUESTA<>000    C  100
             */
/*             v_nro_operacion  := '0000'||to_char(sysdate,'HH24MISS');
             v_pedido := v_nro_operacion||   -- NRO OPERACION
                    'T' || -- FIJO PARA INDICAR LA CONFIRMACION
                    TRIM(TO_CHAR(v_cod_modulo,'000'))||TRIM(TO_CHAR(v_cod_transaccion,'000'))||
                    RPAD(USER,10,' ')|| -- USUARIO
                    v_hor_actual||
                    TRIM(TO_CHAR(v_cod_oficina,'000'))||
                    'C'||
                    RPAD(P_COD_MONEDA,3,' ')||
                    TRIM(TO_CHAR(V_MTO_EFECTIVO,'S000000000000.00'));
            v_pedido := rpad(v_pedido,300,' ');
            --v_pedido := '1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890   ';
            v_ok := fue_env_tcp_mensajes('167.100.1.1',20300,10, v_pedido, v_respuesta);

            if v_ok = 'S' and substr(v_respuesta,11,3) = '000' then
               v_cod_respuesta := '000';
               ---
            else
               if substr(v_respuesta,1,10) = v_nro_operacion then
                  v_cod_respuesta := substr(v_respuesta,11,3);
                  v_msj_respuesta := 'AS/400 '||substr(v_respuesta,31);
               else
                  v_cod_respuesta := 999;
                  v_msj_respuesta := 'AS/400 '||v_respuesta;
               end if;
            end if;*/
           -- agregado por as/400


         end if;
      end if;
    end if;
 end if;
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    v_msj_respuesta := 'Operacion confirmada';
 end if;
 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
end FUJ_PRO_TRANSACCION_240;
/

