create or replace function it.FUJ_PRO_TRANSACCION_304(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caj_origen in varchar2,  -- Nro de Caja
      p_nro_cheque in varchar2,      -- Nro de cheque
      p_nro_cuenta in varchar2,      -- Nro de cuenta del cliente
      p_nro_caj_afecta  in varchar2 default null, -- Número de Caja a la que debe Afectar
      p_importe in varchar2)         -- Importe de la extraccion
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  p_nro_caja  varchar2(3) ; --
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_transaccion number(4) := 304;  -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);          -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_denominacion      varchar2(200);     -- Nombre de la cuenta
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  v_tip_cuenta        number(3);         -- tipo de cuenta(modalidad)
  v_cod_banco         number(3);         -- codigo del banco
  -- Datos del cheque
  v_nro_che_inicial   number(10);        -- nro inicial del cheque
  v_est_anterior      varchar2(1);       -- estado anterior del cheque
  v_nro_cta_certificado varchar2(20) := null;      -- numero del cta certificacion
  -- Datos de salida
  v_msj_salida    varchar2(4000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(1000) := 'Operacion Confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'C';  -- credito para la caja (egreso)
  v_tip_monto     varchar2(01) := 'E';  -- efectivo
  v_importe       number := to_number(p_importe); -- importe del cheque
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  --
  v_cod_mod_cuenta number(6);
  v_cod_mad_cuenta number(6);
  v_nvo_estado varchar2(1);
  v_sal_disponible number;
  v_procesa varchar2(1);
  v_msj_autorizacion varchar2(300) := null;
  --
  v_nro_caj_afecta cj_cajas.nro_caja%type;
  v_des_caj_afecta cj_cajas.descripcion%type;
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo el control de caja
      update cj_controles
         set sal_actual = nvl(sal_actual,0) - nvl(v_importe,0),
             tot_creditos = nvl(tot_creditos,0) + nvl(v_importe,0),
             can_creditos = nvl(can_creditos,0) + 1,
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = v_cod_moneda
         and fecha = v_fec_caja;
      -- genero el movimiento por la extraccion
      insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia,
          cod_tra_padre, cod_mod_padre, cod_mad_padre,
          cod_oficina, cod_moneda, nro_caja,
          nro_documento, nro_cuenta, monto, tip_monto, tipo)
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 1,
          v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
          v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
          p_nro_cheque, nvl(v_nro_cta_certificado,p_nro_cuenta),
          v_importe,v_tip_monto, --efectivo 
          v_tipo); -- es credito 
       -- Obtiene datos de la Caja Origen.
       prj_obt_datos_caja(p_nro_caj_origen,
                          v_cod_moneda,
                          v_cod_oficina,
                          v_fec_caja,
                          v_estado,
                          v_sal_actual,
                          v_sal_cheques,
                          'N');
      -- genero el movimiento para la caja origen
      insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia,
          cod_tra_padre, cod_mod_padre, cod_mad_padre,
          cod_oficina, cod_moneda, nro_caja,
          nro_documento, nro_cuenta, monto, tip_monto, tipo)
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 2,
          v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
          v_cod_oficina, v_cod_moneda, to_number(p_nro_caj_origen),
          p_nro_cheque, nvl(v_nro_cta_certificado,p_nro_cuenta),
          v_importe,v_tip_monto, --efectivo 
          'N'); -- No Afecta          
  end lp_gen_transaccion;
  --
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido la moneda
 if p_nro_cheque is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de cheque.';
 elsif p_nro_cuenta is null then  -- valido la cuenta
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Cuenta Corriente del cliente.';
 elsif v_importe is null or v_importe <= 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe del cheque.';
 elsif p_nro_caj_afecta is not null and nvl(fuj_obt_tip_caja(p_nro_caj_afecta),'x') <> 'P' then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese un Nro. de Caja válido.';
 else
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
       --
       v_cod_oficina := fuj_obt_cod_oficina(p_nro_caj_origen);
       --
       if v_cod_respuesta = '000' then
         begin
           select c.nro_caja, c.descripcion 
             into v_nro_caj_afecta, v_des_caj_afecta
             from cj_cajas c
            where c.tipo = 'P'
              and c.cod_oficina = v_cod_oficina;
         exception
           when no_data_found then
             if p_nro_caj_afecta is not null then
               -- Sino tiene caja prosegur en su oficina, verifica que la caja ingresada sea correcta.
               v_nro_caj_afecta := p_nro_caj_afecta;
               --
               begin
                 select descripcion
                   into v_des_caj_afecta
                   from cj_cajas 
                  where tipo = 'P'
                    and nro_caja = v_nro_caj_afecta;
               exception
                 when no_data_found then
                   v_cod_respuesta := '004';
                   v_msj_respuesta := 'Debe ingresar un Número de Caja válido.';
                 when others then
                   v_cod_respuesta := '004';
                   v_msj_respuesta := substr(sqlerrm,1,100);  
               end;
             end if;
           when others then
              v_cod_respuesta := '005';
              v_msj_respuesta := substr(sqlerrm,1,100);       
         end;
       end if;
       p_nro_caja := v_nro_caj_afecta;
    end if;
    -- obtengo datos de la cuenta  ------------------------------------------
    begin
      select denominacion, cod_moneda, estado, cod_modalidad
        into v_denominacion, v_cod_moneda, v_est_cuenta, v_tip_cuenta
        from ge_cuentas a
       where a.nro_cuenta = p_nro_cuenta;
      if v_tip_cuenta not in (41,42,43,44,45) then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Tipo de cuenta no permite pago de Cheques';
      else
        if FUG_VER_ESCANEO(p_nro_cuenta) = 'N' then
          v_cod_respuesta := '003';
          v_msj_respuesta := 'ERROR: Cuenta no tiene sus firmas escaneadas. Verificar';
        else
          -- Verifico la duplicacion del registro
          prj_val_duplicacion(p_nro_caja,
                              v_cod_transaccion,
                              v_cod_moneda,
                              p_nro_cheque,
                              v_cod_respuesta,
                              v_msj_respuesta);
        end if;
        if v_cod_respuesta = '000' then
           v_msj_respuesta := fuj_ver_impedimentos(p_nro_cuenta,
                                                   v_tip_cuenta,
                                                   v_cod_transaccion,
                                                   v_est_cuenta,
                                                   'D'); -- 'D'== DEBITO EN CUENTA
           if v_msj_respuesta is not null then
              v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
           end if;
        end if;
      end if;
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'ERROR: Nro de cuenta no existe!';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR' || sqlerrm;
    end;
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
       -- Obtengo los datos de la caja ---------------------------------------
       prj_obt_datos_caja(p_nro_caja,
                          v_cod_moneda,
                          v_cod_oficina,
                          v_fec_caja,
                          v_estado,
                          v_sal_actual,
                          v_sal_cheques,
                          'N');
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
    if v_cod_respuesta = '000' THEN -- sino hubo errores veo el cheque
       v_est_anterior := pac_che.FU_CON_CAM_EST_CHE(p_nro_cuenta,
                                                  p_nro_cheque,
                                                  'P',  -- quiero pagar
                                                  v_importe,
                                                  v_nro_che_inicial,
                                                  v_msj_respuesta,
                                                  v_nro_cta_certificado);
       if v_msj_respuesta is not null then
          v_cod_respuesta := '009';
       end if;
    end if;
    if v_cod_respuesta = '000' then
       -- verifico los decimales del importe
       v_msj_respuesta := fuj_val_importe(v_tipo, v_tip_monto,v_cod_moneda,v_importe,v_cod_transaccion,p_nro_cuenta);
       if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       else
          -- Asigno el nro de caja a los movimientos
          pag_cta.pr_nro_caja(to_number(p_nro_caja));
          pag_cta.G_COD_ERROR := 0;
          pag_cta.PR_SET_EST_MOVIMIENTO('N');
          pag_cta.g_sobregira := 'N';
          --Obtener codido del banco
          begin
            select substr(cod_entidad,3,2)
              into v_cod_banco
              from ge_par_generales ;
          exception
            when no_data_found then
              v_cod_respuesta := '010';
              v_msj_respuesta := 'ERROR: Codigo del banco no encontrado!';
            when others then
              v_cod_respuesta := '011';
              v_msj_respuesta := 'ERROR' || sqlerrm;
          end;
          -- actualiza el cheque
          v_msj_respuesta := pac_che.fu_act_pag_che(p_nro_cuenta,
                                                    p_nro_cheque,
                                                    v_importe,
                                                    v_cod_usuario,
                                                    v_fec_actual,
                                                    v_hor_actual,
                                                    to_number(p_nro_caja),
                                                    v_cod_banco,
                                                    v_cod_transaccion,
                                                    v_cod_moneda,
                                                    v_cod_oficina,
                                                    v_cod_modulo,
                                                    v_cod_modalidad);
          if v_msj_respuesta is not null then
              v_cod_respuesta := '005';  -- error
          else
              -- Asigno el nro de caja a los movimientos
              pag_cta.pr_nro_caja(to_number(p_nro_caja));
              -- verifico el saldo
              pag_cta.pr_ver_operacion(nvl(v_nro_cta_certificado,p_nro_cuenta),
                                       v_cod_transaccion,
                                       v_cod_modulo,
                                       v_cod_modalidad,
                                       'D',
                                       v_cod_moneda,
                                       v_importe,
                                       v_cod_oficina,
                                       v_cod_mod_cuenta,
                                       v_cod_mad_cuenta,
                                       v_nvo_estado,
                                       v_sal_disponible,
                                       v_procesa,
                                       1590);
              if v_procesa = 'N' and pag_cta.G_COD_ERROR = 25 and v_sal_disponible < v_importe then
                 -- problemas de saldo insuficiente
                 pag_cta.PR_SET_EST_MOVIMIENTO('X');
                 pag_cta.g_sobregira := 'S';
                 v_msj_autorizacion := 'Cuenta '||nvl(v_nro_cta_certificado,p_nro_cuenta)||' requiere Autorizacion por Sobregiro';
              end if;
              -- Actualiza la operacion en la base
              pag_cta.pr_act_operacion(nvl(v_nro_cta_certificado,p_nro_cuenta),
                                       v_hor_actual,
                                       'D', -- debito a la cuenta del cliente
                                       v_cod_moneda,
                                       v_importe,
                                       v_cod_transaccion,
                                       1590, -- trans. hijo
                                       p_nro_cheque,
                                       null, -- cotizacion
                                       v_cod_oficina,
                                       v_cod_modulo,
                                       v_cod_modalidad,
                                       null, -- tasa
                                       null, -- valor de tasa
                                       'Pago de Cheque en Caja', --concepto
                                       'N', -- emitir aviso
                                       v_nro_secuencia, -- nro de secuencia
                                       v_fec_actual);
              if pag_cta.g_cod_error <> 0 then
                 -- actualizacion con problemas
                 v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
                 v_msj_respuesta := pag_cta.g_msj_error;
              else -- genero la transaccion en caja
                 IF v_msj_autorizacion is not null then

                     begin
                       INSERT INTO GE_AUT_PEDIDOS
                         (COD_USU_AUTORIZADOR,
                         FECHA,HORA,COD_USUARIO, MENSAJE,ESTADO,RESPUESTA, mto_mon_fuerte)
                       VALUES
                         (pag_aut.fu_obt_usu_autorizador(v_cod_transaccion,9,91,v_cod_oficina,null),
                         v_fec_actual,v_hor_actual,v_cod_usuario, v_msj_autorizacion,'S','P',
                         pag_gen.FU_CON_MON_A_MONEDA(v_cod_moneda,'USD',v_importe));
                         --en el trigger se envia mail al autorizador
                     exception
                        when others then
                            v_cod_respuesta := '017';
                            v_msj_respuesta := 'Ins.Pedido Aut. '||substr(sqlerrm,1,400);
                     end;
                 end if;
                 lp_gen_transaccion();
              end if;
           end if;
       end if;
    end if;
 end if;
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    if v_msj_autorizacion is not null then
       v_msj_respuesta := '!'||v_msj_autorizacion||'.'||chr(10)||'Autorizacion Solicitada al Encargado.';
    else
       v_msj_respuesta := 'Operacion confirmada';
    end if;
 end if;
 -- falta armar el mensaje de respuesta 
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
end FUJ_PRO_TRANSACCION_304;
/

