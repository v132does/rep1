create or replace package body it.pag_btw is


/*
Funcion que recibe datos de Cuenta/Cheque de IT desde Bantotal
Retornamos el estado / situacion del cheque / Cuenta
*/
function fu_val_che_recibidos(p_nro_cuenta in varchar2  default null, -- Nro de cuenta del cli
                              p_nro_cheque in varchar2  default null, -- Nro de cheque
                              p_cod_moneda in varchar2  default null, -- cod_moneda
                              p_mto_cheque in varchar2 default null,     -- Monto del cheque
                              p_modo in varchar2 default 'V')
RETURN typ_mapa IS
  -- Datos de la transaccion
v_cod_modulo number(3)      := 4;      -- 
v_cod_modalidad number(3)   := 41;     -- 
v_cod_transaccion number(4) := 345;    -- transaccion
v_cod_usuario varchar2(10) := upper(user); --usuario
v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
v_cod_oficina       number(3);         -- Codigo de oficina
v_est_cheque        varchar2(01);      -- estado del cheque

--
v_denominacion      varchar2(200);     -- Nombre de la cuenta
v_cod_mon_cta       varchar2(3);       -- moneda de la cuenta
v_cod_ofi_cta       number(3);         -- Codigo de oficina
v_est_cuenta        varchar2(1);       -- estado de la cuenta
v_tip_cuenta        number(3);         -- tipo de cuenta(modalidad)
v_nro_cheque        number(8);         -- para contener el nro de cheque
-- Datos de salida
v_cod_respuesta varchar2(30) := 'OP_APROBADA'; -- A=Aprobado P=Pendiente R=Rechazado E=Error
v_msj_respuesta varchar2(200) :='Validacion Exitosa'; -- sin errores
-- datos del movimiento
v_cod_moneda  varchar2(3);
v_nvo_estado         varchar2(1);
v_nro_che_inicial   number(10);        -- nro inicial del cheque
v_est_anterior      varchar2(1);       -- estado anterior del cheque
v_imp_movim   number(18,2) := 0;
-- 
v_error varchar2(4000);
v_insert BOOLEAN;
--
v_mto_cheque       number := fug_con_numero(nvl(p_mto_cheque,0));
v_ban_inhibidos      Varchar2(1) := fuc_ver_fir_inhibidos(p_nro_cuenta);
v_cod_cau_judicial  ge_causales.cod_causa%type := fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL');
v_cod_rubro ge_movimientos.cod_rubro%type := fug_obt_pardinamico('COD_RUB_DEP_BTW',null,null,p_cod_moneda,null,null);
v_sal_disponible     number;
v_procesa            varchar2(1) := 'S';
v_procesa_sob        varchar2(1);
v_msj_autorizacion   varchar2(300) := null;
v_sal_linea          cc_cta_corrientes.sal_total%type;
v_sal_combinada      cc_cta_corrientes.sal_total%type;
v_cod_persona        ba_personas.cod_persona%type := fug_obt_cli_principal(p_nro_cuenta);
--
v_respuesta typ_mensajerespuesta;
v_retorno           typ_mapa := typ_mapa();
--
begin
 -- validaciones de parametros recibidos
 if nvl(p_modo,'V')  in ('V','C') then
    if p_nro_cuenta is null then
       v_procesa       := 'B';
       v_cod_respuesta := 'CTA_DEB_INVALID'; -- error
       v_msj_respuesta := 'Nro.de Cuenta invalido.';
    end if;
    if v_cod_respuesta = 'OP_APROBADA' and p_nro_cheque is null then
        v_procesa       := 'B';
        v_cod_respuesta := 'NRO_CHE_INVALIDO'; -- error
        v_msj_respuesta := 'ERROR: Nro.del Cheque no puede ser nulo.';
    end if;

    if v_cod_respuesta = 'OP_APROBADA' and nvl(v_mto_cheque,0) <= 0 then
        v_procesa       := 'B';
        --v_cod_respuesta := 'E'; -- error
        v_cod_respuesta := 'MTO_INVALIDO';
        v_msj_respuesta := 'Monto Inválido';
    end if;

    -- validaciones con la cuenta libradora (debito) ---
    if v_cod_respuesta ='OP_APROBADA'  and p_nro_cuenta is not null then
       begin
         select substr(replace(denominacion,'~','N'),1,50), cod_moneda, estado, cod_modalidad, cod_oficina
            into v_denominacion, v_cod_mon_cta, v_est_cuenta, v_tip_cuenta, v_cod_ofi_cta
          from ge_cuentas a
         where a.nro_cuenta = p_nro_cuenta;

          if v_tip_cuenta not in (41,42,43,44,45) then
            --v_cod_respuesta := 'E';
            v_procesa       := 'B';
            v_cod_respuesta := 'MAD_CTA_DEB_INV';
            v_msj_respuesta := 'La modalidad de la cuenta no permite pago de Cheques';
          elsif v_est_cuenta in ('P','C')  then
            --v_cod_respuesta := 'E';
            v_procesa       := 'N';
            v_cod_respuesta := 'EST_CTA_DEB_CAN';
            v_msj_respuesta := 'La cuenta de débito está cancelada';
          elsif v_cod_mon_cta <> p_cod_moneda then   -- 
            --v_cod_respuesta := 'E';
            v_procesa       := 'B';
            v_cod_respuesta := 'MON_DEB_INVALID';
            v_msj_respuesta := 'Moneda no corresponde a la cuenta';
          elsif v_est_cuenta = 'T' then
            v_procesa       := 'B';
            v_cod_respuesta := 'CTA_BLO_TOTAL';
            v_msj_respuesta := 'Cuenta totalmente bloqueada';
          elsif v_est_cuenta = 'D'  then
            v_procesa       := 'B';
                -- Cuenta tiene bloqueo de debito, no puede ser debitado
            v_cod_respuesta := 'CTA_BLO_DEBITO';    
            v_msj_respuesta := 'Cuenta tiene bloqueo de Debito';  
          end if;
       exception
         when no_data_found then
             --v_cod_respuesta := 'E';
             v_procesa       := 'B';
             v_cod_respuesta := 'NRO_CTA_INEXIST'; -- error
             v_msj_respuesta := 'Nro de cuenta '||p_nro_cuenta||' no existe!';
       end;
       
      ---Verifica si el Cliente o un Vinculado a la Cuenta está inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
      if v_cod_respuesta ='OP_APROBADA' and fug_obt_inhibicion(v_cod_cau_judicial,v_cod_persona, p_nro_cuenta) Then
           v_procesa       := 'B';
           v_cod_respuesta := 'CTA_DEM_JUDICIAL';
           v_msj_respuesta := 'ERROR: Cliente Principal o Vinc. a la Cuenta con Demanda Judicial. Consulte con el asesor Jurídico';
      End If; 
          
      If  v_cod_respuesta ='OP_APROBADA' and  NVL(v_ban_inhibidos,'X') = 'S' Then
       -- cuenta tiene firmantes inhibidos
          --v_cod_respuesta    := 'R';  -- Se rechaza
          v_procesa          := 'S';
          v_cod_respuesta    := 'CTA_FIR_INHIBIDOS';
          v_msj_respuesta    := 'Cuenta con firmantes Inhibidos-Ley de Cheques';
      end if;

    end if; -- hasta aqui validaciones de la cuenta

    -- valido el estado del cheque
    if v_procesa = 'S' and p_nro_cheque is not null THEN -- sino hubo errores veo el cheque
        v_est_cheque := pac_che.fu_obt_est_che(p_nro_cuenta,
                                               p_nro_cheque,
                                               v_error,
                                               null); --

        -- verifico el estado del cheque
        if v_error is null then
            if v_est_cheque = 'A' then
                v_procesa       := 'B';
                v_cod_respuesta := 'EST_CHE_ANULADO';
                v_msj_respuesta := 'El cheque '||p_nro_cheque||' de la cuenta '||p_nro_cuenta||' ha sido anulado';
            elsif v_est_cheque = 'P' then
               v_procesa       := 'B';
               v_cod_respuesta := 'EST_CHE_PAGADO';
               v_msj_respuesta := 'El cheque '||p_nro_cheque||' de la cuenta '||p_nro_cuenta||' ya fue pagado';
            elsif v_est_cheque = 'S' then
               v_procesa       := 'B';
               v_cod_respuesta := 'EST_CHE_SOLICITADO';
               v_msj_respuesta := 'El cheque '||p_nro_cheque||' de la cuenta '||p_nro_cuenta||' no se ha Entregado';
            elsif v_est_cheque = 'O'  then
               v_procesa       := 'N';
               v_cod_respuesta := 'EST_CHE_CON_ONP';  -- Rechazo
               v_msj_respuesta := 'El cheque '||p_nro_cheque||' de la cuenta '||p_nro_cuenta||' tiene Orden de NO Pagar';
            elsif v_est_cheque not in ('E','C','G') then
               v_procesa       := 'B';
               v_cod_respuesta := 'EST_CHE_INVALIDO';
               v_msj_respuesta := 'El cheque '||p_nro_cheque||' de la cuenta '||p_nro_cuenta||' con estado incorrecto.';
            elsif v_est_cheque is null then
               v_procesa       := 'B';
               v_cod_respuesta:='CHE_INEXISTENTE';  
               v_msj_respuesta:= 'El Cheque '||to_char(p_nro_cheque)||' Inexistente para la cuenta '||p_nro_cuenta;   
            end if;
         else
           if v_est_cheque is null then
              v_procesa      := 'B';
              v_cod_respuesta:= 'CHE_INEXISTENTE';  
              v_msj_respuesta:= 'El Cheque '||to_char(p_nro_cheque)||' Inexistente para la cuenta '||p_nro_cuenta;
           else   
             v_procesa      := 'B';
             v_cod_respuesta:= 'OP_ERROR';
             v_msj_respuesta:= 'Ocurrió un error '||v_error;    
           end if;  
        end if;
    end if;  -- estado del cheque

    --- validar si no esta duplicado.
    if v_procesa = 'S' then
       begin
         select a.cod_moneda Moneda, nvl(a.monto,0)
            into v_cod_moneda, v_imp_movim
          from ge_movimientos a
         where a.nro_documento = to_number(p_nro_cheque)
           and a.nro_cuenta    = p_nro_cuenta
           and a.monto         = v_mto_cheque --
           and a.cod_moneda    = p_cod_moneda
           and a.cod_usuario   = user
           and nro_secuencia   = 1
           and reversado       = 'N' 
           and cod_tra_padre   = v_cod_transaccion;  --
           v_procesa       := 'B';
           v_cod_respuesta := 'MOV_DUPLICADO';
           v_msj_respuesta := 'Movimiento ya registrado para el cheque:'||p_nro_cheque||' Cuenta:'||p_nro_cuenta;
       exception
         when no_data_found then
           null;
      end;
    end if;  
    
    --- validamos el saldo de la cuenta de debito (cuenta libradora del cheque)
    if p_nro_cuenta is not null and v_est_cuenta not in ('P','C') and v_procesa ='S' then
       begin
          v_sal_linea := fuc_obt_mto_lin_sob(p_nro_cuenta);
          -- Si es depósito en Cta. y la Libradora tiene saldo suficiente debe liberar automáticamente.-
                 pag_cta.pr_ver_operacion(p_nro_cuenta,
                                           v_cod_transaccion, -- cod_tra_padre
                                           v_cod_modulo,      -- cod_mod_padre
                                           v_cod_modalidad,   -- cod_mad_padre
                                           'D',
                                           p_cod_moneda,
                                           v_mto_cheque,
                                           v_cod_oficina,
                                           v_cod_modulo,
                                           v_cod_modalidad,
                                           v_nvo_estado,
                                           v_sal_disponible,
                                           v_procesa_sob,
                                           503);
                 if pag_cta.g_ctas.cta_combinada = 'S' then
                    v_sal_combinada := pag_cta.g_ctas.sal_dis_combinada;
                 End If;
               
                IF v_est_cheque != 'O' THEN --DE-567 19/08/2015 solo verificar si es diferente a cheque con ONP
                   If ( (v_procesa_sob = 'N'
                         and pag_cta.g_cod_error in (25,29)
                          and (nvl(v_sal_disponible,0) + nvl(v_sal_linea,0) + nvl(v_sal_combinada,0)) < nvl(v_mto_cheque,0))
                          or (pag_cta.g_ctas.cod_autorizacion is null and (nvl(v_sal_disponible,0) + nvl(v_sal_linea,0) + nvl(v_sal_combinada,0)) < nvl(v_mto_cheque,0))) Then

                         -- problemas de saldo insuficiente
                         v_procesa_sob   := 'S';
                         v_procesa       := 'S';
                         
                         if v_cod_respuesta ='CTA_FIR_INHIBIDOS' then
                           v_msj_respuesta := v_msj_respuesta||'-'||'Cuenta '||p_nro_cuenta||' va generar Autorizacion por Sobregiro';
                         else
                           v_msj_respuesta := 'Cuenta '||p_nro_cuenta||' va generar Autorizacion por Sobregiro';
                         end if;  
                         v_cod_respuesta := 'SAL_CTA_INSUFIC';
                    End If;
                END IF;
         exception
           when others then
                null;
        end;
    end if;               
end if; -- fin validaciones
   
   -- logueo la respuesta --
   PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_mto_cheque, 'V', null /*nro_Caja*/, v_procesa,
                  ----'nroCuenta:'||p_nro_cuenta||'*p_nro_cheque:'||p_nro_cheque||'*p_cod_moneda:'||p_cod_moneda||'*p_monto:'||p_mto_cheque,              
                   null,
                   v_cod_respuesta,
                   v_msj_respuesta, null);
   -- 

   
    v_retorno.datosAdicionales := typ_listaclavevalor();
    paw_uti.pr_add_value(v_retorno.datosAdicionales, 'digitalCheckStatus', v_procesa, 'STRING');
    paw_uti.pr_add_value(v_retorno.datosAdicionales, 'responseCode', v_cod_respuesta, 'STRING');
    paw_uti.pr_add_value(v_retorno.datosAdicionales, 'messageCode', v_msj_respuesta, 'STRING');

        
   v_retorno.error := 'N';
   v_retorno.cantidad := v_retorno.datosAdicionales.count;
   RETURN v_retorno;

exception
  when others then
    v_error := sqlerrm;

    -- logueo la respuesta --
       PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_mto_cheque, 'V', null /*nro_Caja*/, v_procesa,
                   null,
                   'OP_ERROR',
                   null, v_error);
    --     
    v_retorno.error := 'S';
    v_retorno.nombreRespuesta := 'OP_ERROR';
    v_retorno.descripcionRespuesta := substr(v_Error,1,200);
    --
    RETURN v_retorno;

end;


/*
Funcion que recibe datos de Cuenta/Cheque de IT desde Bantotal y confirma la operativa
Retornamos el resultado de procesamiento
*/
function fu_pro_che_recibidos(p_nro_cuenta in varchar2  default null, -- Nro de cuenta del cli
                              p_nro_cheque in varchar2  default null, -- Nro de cheque
                              p_cod_moneda in varchar2  default null, -- cod_moneda
                              p_mto_cheque in varchar2 default null,     -- Monto del cheque
                              p_modo in varchar2 default 'C') 

return typ_mapa
is
v_cod_modulo number(3)      := 4;      -- 
v_cod_modalidad number(3)   := 41;     -- 
v_cod_transaccion number(4) := 345;    -- transaccion
v_cod_usuario varchar2(10) := upper(user); --usuario
v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
v_cod_oficina       number(3) := 31;   -- Codigo de oficina
v_estado            number(1);         -- estado de la caja
v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
v_sal_cheques        number(18,2);     -- saldo actual de la caja en cheques
v_est_cheque        varchar2(01);      -- estado del cheque

--
v_denominacion      varchar2(200);     -- Nombre de la cuenta
v_cod_mon_cta       varchar2(3);       -- moneda de la cuenta
v_cod_ofi_cta       number(3);         -- Codigo de oficina
v_est_cuenta        varchar2(1);       -- estado de la cuenta
v_cod_mad_cta        number(3);         -- tipo de cuenta(modalidad)
v_cod_mod_cta       varchar2(3);       -- moneda de la cuenta
v_nro_cheque        number(8);         -- para contener el nro de cheque
v_nro_cta_certificado varchar2(20) := null;      -- numero del cta certificacion
v_redondeo           number;
v_cotizacion         number(15,4);
-- Datos de salida
v_msj_salida    varchar2(8000);        -- mensaje final retornado
v_cod_respuesta varchar2(30) := 'OP_APROBADA'; -- A=Aprobado P=Pendiente R=Rechazado E=Error
v_msj_respuesta varchar2(200) :='Operacion Confirmada'; -- sin errores
--
-- datos del movimiento
v_cod_moneda  varchar2(3);
v_nro_secuencia number(3) := 0;  -- secuencia del mov.
v_nvo_estado         varchar2(1);
v_nro_che_inicial   number(10);        -- nro inicial del cheque
v_est_ant_cheque      varchar2(1);       -- estado anterior del cheque
v_imp_movim   number(18,2) := 0;
-- CD
v_tip_operacion   ge_mov_autorizaciones.tip_operacion%type := 'O';-- Todos Tipos Operacional
v_nro_pedido         ge_mov_autorizaciones.nro_pedido%type;

-- 
v_error varchar2(4000);
v_insert BOOLEAN;
--
v_mto_cheque       number := fug_con_numero(nvl(p_mto_cheque,0));
v_ban_inhibidos      Varchar2(1) := fuc_ver_fir_inhibidos(p_nro_cuenta);
v_cod_rubro ge_movimientos.cod_rubro%type;
v_sal_disponible     number;
v_procesa            varchar2(1) := 'N';
v_procesa_sob        varchar2(1);
v_msj_autorizacion   varchar2(300) := null;
v_sal_linea          cc_cta_corrientes.sal_total%type;
v_est_movimiento     ge_movimientos.estado%type;
v_sal_combinada      cc_cta_corrientes.sal_total%type;
v_usu_autorizador    ba_usuarios.cod_usuario%type;
r_gmovi ge_movimientos%rowtype;
--
v_respuesta         typ_mensajerespuesta;
v_retorno           typ_mapa := typ_mapa();
v_tip_cla_map       typ_clavevalor := typ_clavevalor();


procedure lp_ins_aut_pedidos is

begin
   INSERT INTO GE_AUT_PEDIDOS (COD_USU_AUTORIZADOR,
                                 FECHA              ,
                                 HORA               ,
                                 COD_USUARIO        ,
                                 MENSAJE            ,
                                 ESTADO             ,
                                 RESPUESTA          ,
                                 MTO_MON_FUERTE     ,
                                 TIP_AUTORIZACION)
                         VALUES (v_usu_autorizador /*pag_aut.fu_obt_usu_autorizador(v_cod_transaccion,9,91,v_cod_oficina,p_importe,p_nro_cuenta)*/,
                                 v_fec_actual,
                                 v_hor_actual,
                                 v_cod_usuario,
                                 v_msj_autorizacion,
                                 'S',
                                 'P',
                                 pag_gen.FU_CON_MON_A_MONEDA(v_cod_moneda,'USD',v_mto_cheque),
                                 'H');
 exception
   when others then
         v_procesa := 'N';
         v_cod_respuesta := 'OP_ERROR';
         v_msj_respuesta := 'Ins.Pedido Aut. '||substr(sqlerrm,1,400);
  
end; --- lp_ins_aut_pedidos
------------------------------
  /*   I N I C I O   */
------------------------------
begin
  
  if p_cod_moneda ='PYG' then
    v_cod_moneda := 'GS';
  else
    v_cod_moneda := p_cod_moneda;
  end if;    
   --  
   v_hor_actual := fug_obt_hor_disponible(v_fec_actual, v_hor_actual,v_cod_usuario,'N');
   v_cod_rubro  := fug_obt_pardinamico('COD_RUB_DEP_BTW',null,null,v_cod_moneda,null,null);
   --
  
   --1. validar nuevamente.
   v_retorno := fu_val_che_recibidos(p_nro_cuenta,p_nro_cheque,v_cod_moneda,p_mto_cheque,'V');     
   
   --2. extraer el dato adicional si procesa o No
   if v_retorno.cantidad > 0 then  
      v_tip_cla_map := v_retorno.datosAdicionales(1);
      IF v_tip_cla_map IS NOT NULL AND v_tip_cla_map.clave = 'digitalCheckStatus' THEN
        v_procesa := v_tip_cla_map.valor;
      END IF;  

      v_tip_cla_map := v_retorno.datosAdicionales(2);
      IF v_tip_cla_map IS NOT NULL AND v_tip_cla_map.clave = 'responseCode' THEN
        v_cod_respuesta := v_tip_cla_map.valor;
      END IF;  

      v_tip_cla_map := v_retorno.datosAdicionales(3);
      IF v_tip_cla_map IS NOT NULL AND v_tip_cla_map.clave = 'messageCode' THEN
        v_msj_respuesta := v_tip_cla_map.valor;
      END IF;  
   end if;  

   --3. si no hubo error en la validacion y procesa = Si, vamos a confirmar
   if v_retorno.error ='N' and v_procesa ='S' then
     
      select substr(replace(denominacion,'~','N'),1,50), cod_moneda, estado, cod_modalidad, cod_oficina, cod_modulo
          into v_denominacion, v_cod_mon_cta, v_est_cuenta, v_cod_mad_cta, v_cod_ofi_cta, v_cod_mod_cta
        from ge_cuentas a
       where a.nro_cuenta = p_nro_cuenta;
  
      pag_cta.PR_SET_EST_MOVIMIENTO('N'); -- Se Limpia Variable Global
      if v_est_cuenta not in ('P','C')  THEN
          -- saldo de linea 
          v_sal_linea := fuc_obt_mto_lin_sob(p_nro_cuenta);
          --- estado del cheque
          v_est_ant_cheque := pac_che.FU_CON_CAM_EST_CHE(p_nro_cuenta,
                                                  p_nro_cheque,
                                                  'P',  -- quiero pagar
                                                  p_mto_cheque,
                                                  v_nro_che_inicial,
                                                  v_msj_respuesta,
                                                  v_nro_cta_certificado,
                                                  null); -- nro serie
           if v_msj_respuesta is not null then
              if v_est_ant_cheque <> 'O' then
                 v_cod_respuesta :='EST_CHE_INVALIDO';
              end if;
           end if;      
           -- Si es depósito en Cta. y la Libradora tiene saldo suficiente debe liberar automáticamente.-
           pag_cta.pr_ver_operacion(p_nro_cuenta,
                                         v_cod_transaccion,
                                         v_cod_modulo,
                                         v_cod_modalidad,
                                         'D',
                                         v_cod_moneda,
                                         v_mto_cheque,
                                         v_cod_oficina,
                                         v_cod_modulo,
                                         v_cod_modalidad,
                                         v_nvo_estado,
                                         v_sal_disponible,
                                         v_procesa_sob,
                                         503);
           if pag_cta.g_ctas.cta_combinada = 'S' then
              v_sal_combinada := pag_cta.g_ctas.sal_dis_combinada;
           End If;
           
           IF  v_est_ant_cheque != 'O' THEN --verificar si es diferente a cheque con ONP
             If ( (v_procesa_sob = 'N'
                  and pag_cta.g_cod_error in (25,29)
                  and (nvl(v_sal_disponible,0) + nvl(v_sal_linea,0) + nvl(v_sal_combinada,0)) < nvl(v_mto_cheque,0))
                or (pag_cta.g_ctas.cod_autorizacion is null and (nvl(v_sal_disponible,0) + nvl(v_sal_linea,0) + nvl(v_sal_combinada,0)) < nvl(v_mto_cheque,0))) Then
                 -- problemas de saldo insuficiente
                 pag_cta.PR_SET_EST_MOVIMIENTO('X');
                 v_est_movimiento :='X';
                 pag_cta.g_sobregira := 'S';
                 v_procesa           := 'P';
                 v_cod_respuesta     := 'OP_APROBADA';
                 v_msj_autorizacion := 'Cuenta '||p_nro_cuenta||' requiere Autorizacion por Sobregiro Cheques Hibridos';
              end if; 
           End If;
           
           If v_procesa in ('S','P') Then
              -- actualiza el cheque
              v_msj_respuesta := pac_che.fu_act_pag_che(p_nro_cuenta,
                                                        p_nro_cheque,
                                                        v_mto_cheque,
                                                        v_cod_usuario,
                                                        v_fec_actual,
                                                        v_hor_actual,
                                                        null,  -- p_nro_caja
                                                        4, --v_cod_banco,
                                                        v_cod_transaccion,
                                                        v_cod_moneda,
                                                        v_cod_oficina,
                                                        v_cod_modulo,
                                                        v_cod_modalidad,
                                                        null);
               If v_msj_respuesta is not null AND v_msj_respuesta != 'Cuenta Cancelada' THEN 
                  v_procesa := 'N';
                  v_cod_respuesta := 'OP_ERROR';  -- error
                  v_retorno.error := 'S';
                  v_retorno.nombreRespuesta:= v_cod_respuesta;
                  v_retorno.descripcionRespuesta:= v_msj_respuesta;
                  --
                  --- seteamos respuesta del proceso
                  v_retorno.datosAdicionales := typ_listaclavevalor();
                  paw_uti.pr_add_value(v_retorno.datosAdicionales, 'status', v_procesa, 'STRING');
                  paw_uti.pr_add_value(v_retorno.datosAdicionales, 'responseCode', v_cod_respuesta, 'STRING');
                  paw_uti.pr_add_value(v_retorno.datosAdicionales, 'messageCode', v_msj_respuesta, 'STRING');
                  --
                  -- logueo la respuesta --
                  PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_mto_cheque, 'C',null, v_procesa,
                                'nroCuenta:'||p_nro_cuenta||'*p_nro_cheque:'||p_nro_cheque||'*p_cod_moneda:'||p_cod_moneda||'*p_monto:'||p_mto_cheque,              
                                 v_cod_respuesta, v_msj_respuesta,
                                 v_error);
                  --               
                  rollback;
                  return v_retorno;
               End If;
           End IF;
         end if;  --- pr_ver cuenta                       
         
         --- si esta inhibido el cliente debe queda pendiente de autorizacion
         If NVL(v_ban_inhibidos,'X') = 'S' and v_est_cuenta not in ('P','C')  Then
           --> Si el cheque tiene Orden de no pago debe procesar normalmente sin dejar pendiente
           if v_est_ant_cheque != 'O' then
              pag_cta.PR_SET_EST_MOVIMIENTO('X');
              v_est_movimiento := 'X';
              v_procesa  := 'P';
              if v_msj_autorizacion is null then
                 v_msj_autorizacion := 'Cuenta con firmantes Inhibidos. Requiere Autorizacion';
              else
                 v_msj_autorizacion := v_msj_autorizacion||chr(10);
                 v_msj_autorizacion := v_msj_autorizacion||' Cuenta con firmantes Inhibidos-Ley de Cheques.';
              end if;   
           End IF;
         End If;
        
        -- --CROEFEBCO-28: Cuando va sobregirar no debe ir al WorkFlow, solicitaron que sea confirmación de Sobregiro.-
        -- variable v_procesa = P cuando va ir a sobregiro o firmantes inhibidos por eso se pregunta por v_procesa =S
       if v_msj_autorizacion is null 
          and v_procesa = 'S' then
          --No debe insertar en el workflow si es una cuenta cancelada o el cheque tiene ONP
          IF v_est_ant_cheque != 'O' THEN
             IF v_est_cuenta not in ('P','C') THEN
               PAG_RIE.PR_OPE_RIESGO( v_fec_actual,
                                      v_hor_actual,
                                      v_cod_usuario,
                                      v_cod_transaccion, -- transacción padre 
                                      v_cod_modulo,      -- Módulo
                                      v_cod_modalidad,   -- Modalidad
                                      p_nro_cuenta,      -- Nro_cuenta
                                      null,-- v_cod_persona,     -- Persona
                                      v_tip_operacion,   -- Tip_operacion 
                                      p_mto_cheque,         -- Monto
                                      null,              -- Número de Documento
                                      v_cod_moneda,      -- Moneda
                                      null,              -- Cotización                       
                                      v_nro_pedido); 
                 if v_nro_pedido > 0 then
                   v_est_movimiento := 'P'; 
                   pag_cta.PR_SET_EST_MOVIMIENTO ('P');
                   v_procesa := 'P';
                 else
                   v_est_movimiento := 'N'; 
                 end if; 
             end if;    
          end if;             
      end if;
      --   
     If v_procesa in ('S','P') Then
          -- Debito en cuenta libradora
          --v_nro_secuencia := v_nro_secuencia +1;
            pag_cta.pr_act_operacion(p_nro_cuenta,
                                     v_hor_actual,
                                     'D', -- debito a la cuenta del cliente
                                     v_cod_moneda,
                                     v_mto_cheque,
                                     v_cod_transaccion,
                                     503, -- trans. hijo de debito
                                     p_nro_cheque,
                                     null, -- cotizacion
                                     v_cod_oficina,
                                     v_cod_modulo,
                                     v_cod_modalidad,
                                     null, -- tasa
                                     null, -- valor de tasa
                                     'Detalle de Cheque en GNBPY', --concepto
                                     'N', -- emitir aviso
                                     v_nro_secuencia, -- nro de secuencia
                                     v_fec_actual, null, null, null, 
                                     v_est_movimiento);-- C.D.Fase III
              -- actualizacion con problemas
             if pag_cta.g_cod_error <> 0 then
                  v_procesa:='N';
                  v_cod_respuesta := 'OP_ERROR'; --ltrim(to_char(pag_cta.g_cod_error,'000'));
                  v_msj_respuesta := pag_cta.g_msj_error;
                  v_retorno.error := 'S';
                  v_retorno.nombreRespuesta:= v_cod_respuesta;
                  v_retorno.descripcionRespuesta:= v_msj_respuesta;
                  ---
                   --- seteamos respuesta del proceso
                  v_retorno.datosAdicionales := typ_listaclavevalor();
                  paw_uti.pr_add_value(v_retorno.datosAdicionales, 'status', v_procesa, 'STRING');
                  paw_uti.pr_add_value(v_retorno.datosAdicionales, 'responseCode', v_cod_respuesta, 'STRING');
                  paw_uti.pr_add_value(v_retorno.datosAdicionales, 'messageCode', v_msj_respuesta, 'STRING');
                  --
                  
                     -- logueo la respuesta --
                   PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_mto_cheque,'C', null /*nro_Caja*/, v_procesa,
                  ----'nroCuenta:'||p_nro_cuenta||'*p_nro_cheque:'||p_nro_cheque||'*p_cod_moneda:'||p_cod_moneda||'*p_monto:'||p_mto_cheque,              
                   'Al debitar de la cuenta',
                   v_cod_respuesta,
                   v_msj_respuesta, null);
                  -- 
                  rollback;
                  --
                  return v_retorno;
              end if;
           
       -- lado credito
           v_nro_secuencia := v_nro_secuencia +1;
           -- la secuencia 2 del movimiento queda en P, solo la sec 1 queda en X
           if v_est_movimiento in ('X','P') then 
              v_est_movimiento :='P';
           else
              v_est_movimiento :='N';
           end if;
           ---   
            begin
              r_gmovi.cod_usuario     := v_cod_usuario;
              r_gmovi.hora            := v_hor_actual;
              r_gmovi.fecha           := v_fec_actual;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := v_cod_mod_cta;
              r_gmovi.cod_modalidad   := v_cod_mad_cta;
              r_gmovi.cod_oficina     := v_cod_ofi_cta;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.fec_valor       := v_fec_actual;
              r_gmovi.cod_tra_padre   := 345;
              r_gmovi.cod_mod_padre   := v_cod_modulo;
              r_gmovi.cod_mad_padre   := v_cod_modalidad;
              --
              r_gmovi.cod_transaccion := null;
              r_gmovi.cod_rubro       := v_cod_rubro;
              r_gmovi.tip_mov_rubro   := 'C';
              --
              r_gmovi.monto           := v_mto_cheque;
              r_gmovi.nro_documento   := p_nro_cheque;
              r_gmovi.cod_ofi_origen  := 31;  -- confirmar
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'Detalle de Cheque GNBPY';
              r_gmovi.estado          := v_est_movimiento;
              r_gmovi.reversado       := 'N';
              r_gmovi.nro_cuenta      := null; --p_nro_cuenta;
              ---
              if v_cod_moneda <>  pag_gen.FU_OBT_MON_LOCAL then
                 v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo,v_cod_modalidad,v_cod_moneda);
                 v_cotizacion := nvl(pag_gen.FU_OBT_COTIZACION(v_cod_moneda,v_fec_actual),2);
                 -- 
                 r_gmovi.cotizacion := v_cotizacion;
                 r_gmovi.mto_equ_local := round(nvl(v_mto_cheque,0) * nvl(v_cotizacion,0),0);   
              else
                 r_gmovi.mto_equ_local := null;
              end if;
              ---
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
           exception
             when others then
               v_error := sqlerrm;
               v_procesa :='N';
               v_cod_respuesta := 'OP_ERROR'; --ltrim(to_char(pag_cta.g_cod_error,'000'));
               v_retorno.error := 'S';
               v_retorno.nombreRespuesta:= v_cod_respuesta;
               v_retorno.descripcionRespuesta:= substr(v_error,1,200);
                --- seteamos respuesta del proceso
                v_retorno.datosAdicionales := typ_listaclavevalor();
                paw_uti.pr_add_value(v_retorno.datosAdicionales, 'status', v_procesa, 'STRING');
                paw_uti.pr_add_value(v_retorno.datosAdicionales, 'responseCode', v_cod_respuesta, 'STRING');
                paw_uti.pr_add_value(v_retorno.datosAdicionales, 'messageCode', v_msj_respuesta, 'STRING');
                --
               -- logueo la respuesta --
               PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_mto_cheque,'C', null /*nro_Caja*/, v_procesa,
                  'Insertar Mov. Rub.Transitorio',
                  v_cod_respuesta,
                  v_msj_respuesta, v_error);
               --
               rollback;
               return v_retorno;
           end;       
       end if;    
       pag_cta.PR_SET_EST_MOVIMIENTO('N'); --> DYDMR-3194: Se Limpia Variable Global
 end if;     

 -- los cheques con ONP o cuenta cancelada se registran como devuelto
 if v_procesa ='N' and v_cod_respuesta in ('EST_CHE_CON_ONP','EST_CTA_DEB_CAN') then -- sino hubo problemas, se carga mensaje por defecto
   begin
        -- inserta tabla de cheques hibridos
        pag_btw.pr_ins_che_hibridos(v_fec_actual, v_hor_actual, v_cod_usuario, 
                                 p_nro_cuenta, p_nro_cheque, v_cod_moneda, 
                                 v_mto_cheque, null, v_procesa);

        --- ACA INSERTA EL MOVIMIENTO DE LA DEVOLUCION
          if v_cod_respuesta ='EST_CHE_CON_ONP' then   -- cod_causa 128 = ONP
             v_retorno := pag_btw.fu_pro_che_devueltos(p_nro_cuenta, p_nro_cheque,v_cod_moneda, v_mto_cheque, 128, v_hor_actual);
          else  --cod_causa 107 = cta cancelada
             v_retorno := pag_btw.fu_pro_che_devueltos(p_nro_cuenta, p_nro_cheque,v_cod_moneda, v_mto_cheque, 107, v_hor_actual);
          end if; 
          
           if v_retorno.cantidad > 0 then  
              v_tip_cla_map := v_retorno.datosAdicionales(1);
              IF v_tip_cla_map IS NOT NULL AND v_tip_cla_map.clave = 'status' THEN
                v_procesa := v_tip_cla_map.valor;
              END IF;  
              -- solo si responde N obtenemos el error, para que no pise el cod_respuesta original
              if v_procesa = 'N' then
                v_tip_cla_map := v_retorno.datosAdicionales(2);
                IF v_tip_cla_map IS NOT NULL AND v_tip_cla_map.clave = 'responseCode' THEN
                  v_cod_respuesta := v_tip_cla_map.valor;
                END IF;  

                v_tip_cla_map := v_retorno.datosAdicionales(3);
                IF v_tip_cla_map IS NOT NULL AND v_tip_cla_map.clave = 'messageCode' THEN
                  v_msj_respuesta := v_tip_cla_map.valor;
                END IF;  
              end if;  
           end if;  

        if v_cod_respuesta = 'EST_CHE_CON_ONP' then
          v_msj_respuesta := '!Cheque se encuentra con Orden de No Pago. Fue registrado como Devuelto!';
        end if;
        if v_cod_respuesta = 'EST_CTA_DEB_CAN' then
          v_msj_respuesta := '!Cuenta Cancelada. El Cheque fue registrado como devuelto';
        end if;
        v_procesa :='N';
   exception     
      when others then
         v_error := sqlerrm;
         v_procesa :='N';
         v_cod_respuesta := 'OP_ERROR'; --ltrim(to_char(pag_cta.g_cod_error,'000'));
         v_retorno.error := 'S';
         v_retorno.nombreRespuesta:= v_cod_respuesta;
         v_retorno.descripcionRespuesta:= substr(v_error,1,200);
         --- seteamos respuesta del proceso
         v_retorno.datosAdicionales := typ_listaclavevalor();
         paw_uti.pr_add_value(v_retorno.datosAdicionales, 'status', v_procesa, 'STRING');
         paw_uti.pr_add_value(v_retorno.datosAdicionales, 'responseCode', v_cod_respuesta, 'STRING');
         paw_uti.pr_add_value(v_retorno.datosAdicionales, 'messageCode', v_msj_respuesta, 'STRING');
         --
         -- logueo la respuesta --
         PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_mto_cheque,'C', null /*nro_Caja*/, v_procesa,
            'Insertar Mov. Che ONP/Cta Can.',
            v_cod_respuesta,
            v_msj_respuesta, v_error);
         --   
         rollback;
         --
         return v_retorno;
   end;       
 end if; --- op aprobada
 
  --
 IF v_msj_autorizacion is not null and v_procesa ='P' then -- Pend. debe insertar ge_aut_pedidos
     begin
       v_usu_autorizador := pag_aut.fu_obt_usu_autorizador(v_cod_transaccion,4,41,v_cod_oficina,v_mto_cheque,p_nro_cuenta);
     Exception
       When others then
         If v_cod_oficina in (7,1) Then
           Begin
               select a.cod_usuario
               into v_usu_autorizador
               from ge_autorizadores a, ba_usuarios u, ba_usu_roles b
               where a.cod_usuario = u.cod_usuario
                 and u.cod_oficina = v_cod_oficina
                 and nvl(a.monto,nvl(v_mto_cheque,-1)) >= nvl(v_mto_cheque,-1)
                 and rownum        = 1
                 and u.cod_usuario = b.cod_usuario
                 and b.cod_rol     = fug_obt_pardinamico('ROL_AUT_SOB_MATRIZ')
               order by fue_ver_sesion(cod_usuario);
           Exception
              When no_data_found then
                   Begin
                       select a.cod_usuario
                       into v_usu_autorizador
                       from ge_autorizadores a, ba_usuarios u, ba_usu_roles b
                       where a.cod_usuario = u.cod_usuario
                         and u.cod_oficina = v_cod_oficina
                         and nvl(a.monto,nvl(v_mto_cheque,-1)) >= nvl(v_mto_cheque,-1)
                         and rownum        = 1
                         and u.cod_usuario = b.cod_usuario
                         --and b.cod_rol     = 'TESORERO_NW'
                         order by fue_ver_sesion(cod_usuario);
                   Exception
                      When others then
                         lp_ins_aut_pedidos;
               End;
              When others then
                 lp_ins_aut_pedidos;
            End;
         ELSE
           Begin
             select a.cod_usuario
             into v_usu_autorizador
             from ge_autorizadores a, ba_usuarios u
             where a.cod_usuario = u.cod_usuario
               and u.cod_oficina = v_cod_oficina
               and nvl(a.monto,nvl(v_mto_cheque,-1)) >= nvl(v_mto_cheque,-1)
               and rownum        = 1
               order by fue_ver_sesion(cod_usuario);
           Exception
            When no_data_found then
               Begin
                 select a.cod_usuario
                 into v_usu_autorizador
                 from ge_autorizadores a, ba_usuarios u
                 where a.cod_usuario = u.cod_usuario
                   and u.cod_oficina = 7
                   and nvl(a.monto,nvl(v_mto_cheque,-1)) >= nvl(v_mto_cheque,-1)
                   and rownum        = 1
                   order by fue_ver_sesion(cod_usuario);
               Exception
                When others then
                     lp_ins_aut_pedidos;
                End;
            When others then
              lp_ins_aut_pedidos;
            End;
         end if;  -- cod_oficina 7, 1    
       end;  
      ----        
      if v_usu_autorizador is not null then
         lp_ins_aut_pedidos;
      end if;         
   end if; -- msj_autorizacion is not null    
   
   if v_nro_pedido > 0 then -- C.D.Fase III
      v_msj_respuesta:= 'Se ha generado el Pedido de Autorización Nro:'||v_nro_pedido||' por Riesgo Operacional';
   end if;

    --- seteamos respuesta del proceso
    v_retorno.datosAdicionales := typ_listaclavevalor();
    paw_uti.pr_add_value(v_retorno.datosAdicionales, 'status', v_procesa, 'STRING');
    paw_uti.pr_add_value(v_retorno.datosAdicionales, 'responseCode', v_cod_respuesta, 'STRING');
    paw_uti.pr_add_value(v_retorno.datosAdicionales, 'messageCode', v_msj_respuesta||' '||v_msj_autorizacion, 'STRING');
    --
    
    v_retorno.error:='N'; --- sin error
    v_retorno.cantidad := v_retorno.datosAdicionales.count;
    ---
    -- inserta tabla de cheques hibridos
    pag_btw.pr_ins_che_hibridos(v_fec_actual, v_hor_actual, v_cod_usuario, 
                                 p_nro_cuenta, p_nro_cheque, v_cod_moneda, 
                                 v_mto_cheque, null, v_procesa);
    
    ---
    
    -- logueo la respuesta --
    PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_mto_cheque,'C', null /*nro_Caja*/, v_procesa,
      null,
      v_cod_respuesta,
      v_msj_respuesta, v_error);
   --   

   -- si se procesó todo Ok o queda Pend de aut. entonces comiteamos la transaccion
   if (v_procesa in ('S','P') or (v_procesa ='N' and v_cod_respuesta in ('EST_CHE_CON_ONP','EST_CTA_DEB_CAN'))) then 
      commit;
      ---
   else
      rollback;
   end if;      
   -- retornamos
   return v_retorno;
   --
exception
  when others then
   v_error := sqlerrm;
   v_retorno.error:='S';
   v_retorno.nombreRespuesta:='OP_ERROR';
   v_retorno.descripcionRespuesta:= substr(v_error, 1,200);
    --- seteamos respuesta del proceso
    v_retorno.datosAdicionales := typ_listaclavevalor();
    paw_uti.pr_add_value(v_retorno.datosAdicionales, 'status', 'N', 'STRING');
    paw_uti.pr_add_value(v_retorno.datosAdicionales, 'responseCode', 'OP_ERROR', 'STRING');
    paw_uti.pr_add_value(v_retorno.datosAdicionales, 'messageCode', substr(v_error, 1,200), 'STRING');
    --
   return v_retorno;
end;

/*
Procedimiento invocado desde la funcion val_355 de ItCaja que ejecuta el servicio en Runes y
obtiene el estado / situacion de una cuenta / cheque de Bantotal
*/
procedure pr_val_che_btw(p_nro_cuenta in varchar2,
                        p_nro_cheque in number,
                        p_cod_moneda in varchar2,
                        p_monto      in number,
                        p_tipo       in varchar2 default 'V',
                        p_nro_caja   in number,
                        p_cod_respuesta out varchar2,
                        p_msg_respuesta out varchar2,
                        p_procesa       out varchar2)
IS                        
result typ_postRespuesta; --:= typ_postRespuesta();
p_headers typ_listaetiquetavalor := typ_listaetiquetavalor();
v_cod_moneda VARCHAR2(3);
v_modo char(1)                   := p_tipo; -- 'V';
v_api_path  VARCHAR2(50) := fug_obt_pardinamico('API_URL_DOM_RUNES'); --'runes.work.py.igrupobbva/apis';
v_api_ser_validacion    VARCHAR2(250) := fug_obt_pardinamico('API_SER_VAL_RUNES'); -- '/integration/internal-digital-checks/internal-digital-checks/v0/internal-digital-checks/validations?';
v_api_key               varchar2(100) := fug_obt_pardinamico('API_KEY_RUNES'); ---'944a0178c79811ebb8bc0242ac130003'
v_url     VARCHAR2(1000);
v_dat_response VARCHAR2(8000);
v_ws_respuesta paw_json.JSONStructObj;
v_ws_res_data paw_json.JSONStructObj;
v_msj_bantotal varchar2(250);
v_cod_respuesta varchar2(50);
v_procesa varchar2(1);
v_error     varchar2(3000);
v_cod_ofi_itgf  ba_oficinas.cod_oficina%type := fug_obt_ofi_usuario(upper(user));
v_cod_ofi_btw number(5);
begin

-- convierto la moneda local al formato que acepta runes.
if p_cod_moneda =pag_gen.FU_OBT_MON_LOCAL then
   v_cod_moneda := 'PYG';
else 
   v_cod_moneda := p_cod_moneda;   
end if;
--   
--obtenemos la sucursal bantotal
v_cod_ofi_btw := fu_obt_ofi_btw(v_cod_ofi_itgf);
--


paw_uti.pr_add_value(p_headers, 'Runes-Api-Key', v_api_key);
--
v_url := v_api_path||v_api_ser_validacion||'accountNumber='||p_nro_cuenta||'&digitalCheckNumber='||p_nro_cheque||'&amount='||nvl(p_monto,1) ||'&currency='||v_cod_moneda|| '&branch='||v_cod_ofi_btw;

--dbms_output.put_line('URL '||v_url);
---------------------------- Call the function -----------------------------------
result := fue_env_http(p_url => v_url, p_metodo => 'GET', p_headers => p_headers);
----------------------------------------------------------------------------------
/* dbms_output.put_line('error: '||result.error);
dbms_output.put_line('codigoError: '||result.codigoError);
dbms_output.put_line('descripcionRespuesta: '||result.descripcionRespuesta);
dbms_output.put_line('status_code: '||result.status_code);
dbms_output.put_line('respuesta: '||result.respuesta);
*/
 v_error:= result.error;           
 -- si no hubo error    
 if upper(v_error) = 'N' then
     
    v_ws_respuesta := paw_json.String2JSON(result.respuesta, '"');
    -- se obtiene el tag "data"
    v_dat_response := paw_json.getAttrValue(v_ws_respuesta, 'data');
    -- se convierete el tag "data" a json para leer los atributos
    v_ws_res_data := paw_json.String2JSON(v_dat_response, '"');
    
    -- extraemos los valores necesarios para retornar 
    v_procesa := substr(trim(paw_json.getAttrValue(v_ws_res_data, 'digitalCheckStatus')), 1, 1);
    v_cod_respuesta := substr(trim(paw_json.getAttrValue(v_ws_res_data, 'responseCode')), 1, 10);
    v_msj_bantotal :=substr(trim(paw_json.getAttrValue(v_ws_res_data, 'responseMessage')), 1, 100); 

    ---- Convertimos lo recibido de BT al chartset de la BD de IT
    v_msj_bantotal := fu_val_charset(v_msj_bantotal, 'BT2ITGF');   
    ---
  --  dbms_output.put_line('digitalCheckStatus: '||v_procesa);
   -- dbms_output.put_line('responseMessage: '||v_msj_bantotal);
 else
    v_procesa := 'N';
    v_msj_bantotal := nvl(result.descripcionRespuesta, 'Ha ocurrido un error inesperado.');
 end if;   
 
 
  -- logueo la respuesta recibida a nuestra consulta --
  PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_monto,'V',p_nro_caja /*nro_Caja*/, v_procesa,
                v_url,              
                v_cod_respuesta,
                v_msj_bantotal, 'Status_Code:'||result.status_code||' codigoError: '||result.codigoError|| '--'|| result.respuesta);
-- 
  v_ws_res_data.delete;
  v_ws_respuesta.delete;
  p_headers.delete;
--
-- retornamos
if v_procesa = 'S' and result.status_code= 200 then
  p_cod_respuesta := 'OP_CONFIRMADA';
else
  p_cod_respuesta := 'OP_ERROR';
end if;
    
p_msg_respuesta := v_msj_bantotal;
p_procesa    := v_procesa;

--  
exception
 when others then  
     v_error := sqlerrm;
     p_cod_respuesta := 'OP_ERROR';
     p_msg_respuesta := nvl(v_msj_bantotal,v_error);
     p_procesa       := 'N';
     -- logueamos
     PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_monto,'V',p_nro_caja /*nro_Caja*/, nvl(v_procesa,'N'),
                v_url,              
                nvl(v_cod_respuesta,'OP_ERROR'),
                result.respuesta, 
                v_error);

--
end;

/*
Procedimiento invocado desde la funcion pro_355 de ItCaja que ejecuta el servicio en Runes y
confirma la operacion en Bantotal
*/
procedure pr_pro_che_btw(p_nro_cuenta in varchar2,
                        p_nro_cheque in number,
                        p_cod_moneda in varchar2,
                        p_monto      in number,
                        p_tipo       in varchar2,
                        p_nro_caja   in number,
                        p_cod_respuesta out varchar2,
                        p_msg_respuesta out varchar2,
                        p_procesa    out varchar2,
                        p_cod_causa  in number default null)
is                        

  
result typ_postRespuesta; --:= typ_postRespuesta();
--v_nro_doc_bts VARCHAR2(20) := '8668601';
v_api_path  VARCHAR2(50) := fug_obt_pardinamico('API_URL_DOM_RUNES'); --'runes.work.py.igrupobbva/apis';
v_api_ser_confirmacion  VARCHAR2(250) := fug_obt_pardinamico('API_SER_CON_RUNES'); -- '/integration/internal-digital-checks/internal-digital-checks/v0/internal-digital-checks/validations?';
v_api_ser_devolucion  VARCHAR2(250) := fug_obt_pardinamico('API_SER_RCH_RUNES'); --'/integration/internal-digital-checks/internal-digital-checks/v0/internal-digital-checks/rejections'; 
v_api_key               varchar2(100) := fug_obt_pardinamico('API_KEY_RUNES'); ---'944a0178c79811ebb8bc0242ac130003'
v_url     VARCHAR2(500);
v_dat_response VARCHAR2(3000);
v_ws_respuesta paw_json.JSONStructObj;
v_ws_res_data paw_json.JSONStructObj;
v_msj_bantotal varchar2(250);
v_cod_respuesta varchar2(50);
v_procesa varchar2(1);
v_error     varchar2(3000);
v_cod_moneda varchar2(3);
v_headers         typ_listaEtiquetaValor := typ_listaEtiquetaValor();
v_contenido       VARCHAR2(5000);
v_des_causa       varchar2(50); 
v_cod_ofi_itgf    ba_oficinas.cod_oficina%type := fug_obt_ofi_usuario(upper(user));   
v_cod_ofi_btw     number(5);

begin
  -- convierto la moneda local al formato que acepta runes.
if p_cod_moneda =pag_gen.FU_OBT_MON_LOCAL then
   v_cod_moneda := 'PYG';
else 
   v_cod_moneda := p_cod_moneda;   
end if;
--   
v_cod_ofi_btw := fu_obt_ofi_btw(v_cod_ofi_itgf);

--dbms_output.put_line('URL:'||v_url);
-- si es una confirmacion
if p_tipo ='C' then
  v_url := v_api_path||v_api_ser_confirmacion;
----
  -- creamos el body
  v_contenido := '{ "accountNumber": "'||p_nro_cuenta||'",'||
                 ' "digitalCheckNumber": "'||p_nro_cheque||'",'||
                 ' "amount": "'||p_monto||'",'||
                 ' "currency": "'||v_cod_moneda||'",'||
                 ' "branch": "'||v_cod_ofi_btw||'" }';

end if;

-- si es devolucion de cheque
if p_tipo ='D' then
  v_url := v_api_path||v_api_ser_devolucion;
 -- causa del rechazo
 v_des_causa := case p_cod_causa
                   when 106 then 'INSUFICIENCIA_FONDOS'
                   when 108 then 'FIRMA_DEFICIENTE' 
                   when 109 then 'ENDOSO_DEFICIENTE'
                   when 110 then 'FECHA_DEFICIENTE' 
                   when 111 then 'TEXTO_DEFICIENTE' 
                   when 128 then 'ORDEN_NOPAGO'
                   when 129 then 'PRESENTACION_EXTEMPORANEA'
                   when 130 then 'NO_VALIDO'
                   when 239 then 'INHAB_OPE_CTA_CTE'
                   when 263 then 'FIRM_INHAB_EN_CTA_CTE'
                   else 'NO_PARAMETRIZADO'
                 end;


  -- creamos el body
  v_contenido := '{ "accountNumber": "'||p_nro_cuenta||'",'||
                 ' "digitalCheckNumber": "'||p_nro_cheque||'",'||
                 ' "amount": "'||p_monto||'",'||
                 ' "currency": "'||v_cod_moneda||'",'||
                 ' "rejectionCause": "'||v_des_causa||'",'||
                 ' "branch": "'||v_cod_ofi_btw||'" }';
end if;

    -- agregamos los headers para enviar el post
    paw_uti.pr_add_value(v_headers, 'Content-Type', 'application/json');
    paw_uti.pr_add_value(v_headers, 'Runes-Api-Key', v_api_key);
    paw_uti.pr_add_value(v_headers, 'Content-Length', length(v_contenido));
---------------------------- Call the function -----------------------------------
    result := fue_env_http(v_url, 'POST', v_headers, v_contenido);
----------------------------------------------------------------------------------

/*dbms_output.put_line('error: '||result.error);
dbms_output.put_line('codigoError: '||result.codigoError);
dbms_output.put_line('descripcionRespuesta: '||result.descripcionRespuesta);
dbms_output.put_line('status_code: '||result.status_code);
dbms_output.put_line('respuesta: '||result.respuesta);*/
 
  v_ws_respuesta := paw_json.String2JSON(result.respuesta, '"');
  -- se obtiene el tag "data" 
  v_dat_response := paw_json.getAttrValue(v_ws_respuesta, 'data');
  -- se convierete el tag "data" a json para leer los atributos
  v_ws_res_data := paw_json.String2JSON(v_dat_response, '"');

 if result.status_code = 200 and result.error ='N' then
 -- si no hubo error
--- if result.error ='N' then  
  -- extraemos los valores necesarios para retornar 
  v_procesa := substr(trim(paw_json.getAttrValue(v_ws_res_data, 'status')), 1, 1);
  v_cod_respuesta := substr(trim(paw_json.getAttrValue(v_ws_res_data, 'responseCode')), 1, 10);
  v_msj_bantotal :=substr(trim(paw_json.getAttrValue(v_ws_res_data, 'responseMessage')), 1, 100); 
  --- Convertimos la respuesta recibida de BT al charset de la bd de IT
  v_msj_bantotal := fu_val_charset(v_msj_bantotal, 'BT2ITGF');
    ---
   /*dbms_output.put_line('Status: '||v_procesa);
     dbms_output.put_line('responseCode: '||v_cod_respuesta);
     dbms_output.put_line('responseMessage: '||v_msj_bantotal);*/
 else
    v_procesa := 'N';
    v_msj_bantotal :=nvl(result.descripcionRespuesta, 'Ha ocurrido un error inesperado.');
 end if;   
---
v_ws_res_data.delete;
v_ws_respuesta.delete;
v_headers.delete;
---
  p_cod_respuesta := v_cod_respuesta;
  p_msg_respuesta := v_msj_bantotal;
  --p_es_che_btw := 'S';
  p_procesa    := nvl(v_procesa,'N');  
---  
  -- logueo la respuesta recibida a nuestra consulta --
  PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_monto, p_tipo,p_nro_caja /*nro_Caja*/, nvl(v_procesa,'N'),
                v_url,              
                v_cod_respuesta,
                v_msj_bantotal, 'Status_Code:'||result.status_code||' codigoError: '||result.codigoError||'-' ||result.respuesta);
--
exception
  when others then
    v_error := sqlerrm;
    p_procesa := 'N';
    p_cod_respuesta := 'OP_ERROR';
    p_msg_respuesta := substr(v_error, 1, 200);
    -- logueo la respuesta recibida a nuestra consulta --
    PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_monto, p_tipo,p_nro_caja /*nro_Caja*/, nvl(v_procesa,'N'),
                v_url,              
                v_cod_respuesta,
                result.respuesta, v_error);

    
end;


/*
FUNCION que procesa los cheques devueltos en caja de BanTotal
*/
function fu_pro_che_devueltos(p_nro_cuenta in varchar2  default null, -- Nro de cuenta del cli
                              p_nro_cheque in varchar2  default null, -- Nro de cheque
                              p_cod_moneda in varchar2  default null, -- cod_moneda
                              p_mto_cheque in varchar2 default null,     -- Monto del cheque
                              p_cod_causa in number,
                              p_hora in varchar2 default null) 
return typ_mapa
IS
v_cod_modulo number(3)      := 4;      -- 
v_cod_modalidad number(3)   := 41;     -- 
v_cod_transaccion number(4) := 345;    -- transaccion
v_cod_usuario varchar2(10) := upper(user); --usuario
v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
v_cod_oficina       number(3) := 31;   -- Codigo de oficina
v_estado            number(1);         -- estado de la caja
v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
v_sal_cheques        number(18,2);     -- saldo actual de la caja en cheques
v_est_cheque        varchar2(01);      -- estado del cheque

--
v_denominacion      varchar2(200);     -- Nombre de la cuenta
v_cod_mon_cta       varchar2(3);       -- moneda de la cuenta
v_cod_ofi_cta       number(3);         -- Codigo de oficina
v_est_cuenta        varchar2(1);       -- estado de la cuenta
v_cod_mad_cta        number(3);         -- tipo de cuenta(modalidad)
v_cod_mod_cta       varchar2(3);       -- moneda de la cuenta
v_nro_cheque        number(8);         -- para contener el nro de cheque
v_nro_cta_certificado varchar2(20) := null;      -- numero del cta certificacion
v_redondeo           number;
v_cotizacion         number(15,4);
-- Datos de salida
v_msj_salida    varchar2(8000);        -- mensaje final retornado
v_cod_respuesta varchar2(30) := 'OK_CHE_DEVUELTO'; -- A=Aprobado P=Pendiente R=Rechazado E=Error
v_msj_respuesta varchar2(200) :='Cheque Devuelto Confirmado'; -- sin errores
--
-- datos del movimiento
v_cod_moneda  varchar2(3);
v_nro_secuencia number(3) := 0;  -- secuencia del mov.
v_nvo_estado         varchar2(1);
v_nro_che_inicial   number(10);        -- nro inicial del cheque
v_imp_movim   number(18,2) := 0;
v_poscheque number;
-- 
v_lugar varchar2(4000);
v_error varchar2(4000);
v_insert BOOLEAN;
v_count number := 0;

--
v_mto_cheque       number := fug_con_numero(nvl(p_mto_cheque,0));
v_cod_rubro ge_movimientos.cod_rubro%type;
v_sal_disponible     number;
v_procesa            varchar2(1) := 'S';
v_est_movimiento     ge_movimientos.estado%type;
v_sal_combinada      cc_cta_corrientes.sal_total%type;
v_usu_autorizador    ba_usuarios.cod_usuario%type;
r_gmovi ge_movimientos%rowtype;
--
v_respuesta         typ_mensajerespuesta;
v_retorno           typ_mapa := typ_mapa();
v_tip_cla_map       typ_clavevalor := typ_clavevalor();
v_cod_causa         number(3);

begin

BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;

  -- VALIDACIONES
   if p_cod_moneda = 'PYG' then
      v_cod_moneda := 'GS';
   else
      v_cod_moneda := p_cod_moneda;
   end if;      
   
   if p_hora is not null then
     v_hor_actual := p_hora;
   else
     v_hor_actual := fug_obt_hor_disponible(v_fec_actual, v_hor_actual,v_cod_usuario,'N');  
   end if;  
   
   if p_cod_causa is not null then
     begin
       select cod_causa into v_cod_causa
        from ge_causales where cod_causa = p_cod_causa;
     exception
       when no_data_found then   
          v_procesa := 'N';
          v_cod_respuesta :='COD_CAU_INEXISTENTE';    
          v_msj_respuesta := 'Causal de devolucion inexistente';
      end;    
   end if;
     
   begin
     Select cod_moneda, cod_oficina, estado
       into v_cod_mon_cta, v_cod_ofi_cta, v_est_cuenta
     from ge_cuentas
     where nro_cuenta = p_nro_cuenta; 
     
     if v_cod_mon_cta <> v_cod_moneda then
       v_procesa := 'N';
       v_cod_respuesta :='MON_DEB_INVALID';    
       v_msj_respuesta := 'La moneda de la cuenta es invalida';
     end if;  
   exception
     when no_data_found then
       v_procesa := 'N';
       v_cod_respuesta :='NRO_CTA_INEXIST';    
       v_msj_respuesta := 'Nro de cuenta inexistente';
   end;      

  
   v_est_cheque := pac_che.FU_CON_CAM_EST_CHE(p_nro_cuenta,p_nro_cheque,
                                         null,null,v_nro_che_inicial,
                                         v_error,v_nro_cta_certificado);

  if v_est_cheque = 'O' then
    v_msj_respuesta := 'Cheque se encuentra con estado orden de no pagar';

  elsif v_est_cheque not in ('C','G','P','E') then
    v_procesa := 'N';
    v_cod_respuesta :='OP_ERROR';    
    v_msj_respuesta := 'Cheque no se puede devolver, estado invalido';
  end if;

  If instr(v_error,'Inexistente') <> 0 then
    v_procesa := 'N';
    v_cod_respuesta :='OP_ERROR';
	  v_msj_respuesta := v_error;
	End if;

  
  --Verificar que no se haya registrado la misma devolucion en la fecha
  select count(1)
    into v_count
    from cc_che_devueltos d
   where d.fecha = v_fec_actual
     and d.nro_cuenta = p_nro_cuenta
     and d.nro_cheque = p_nro_cheque;
     
  if nvl(v_count,0) > 0 then
    v_procesa := 'N';
    v_cod_respuesta:='OP_ERROR';
  	v_msj_respuesta := 'Ya se registro la devolución de este Nro. de Cheque en la fecha.';
  end if;
  

  if v_procesa ='S' and v_est_cheque ='P' then 
  --obtener los datos del movimiento registrado
     begin
	     select m.monto, m.estado
	       into v_imp_movim, v_est_movimiento
	       from ge_movimientos m
	      where cod_tra_padre = v_cod_transaccion
	        and reversado = 'N'
	        and fecha     =  v_fec_actual
	        and nro_documento = p_nro_cheque
          and cod_moneda    = p_cod_moneda
	        and monto is not null  --Por si hubo movimiento de cambio de estado de la cuenta, 28/01/2010
	        and nro_cuenta   = p_nro_cuenta;
          
	     if nvl(v_imp_movim,0) <> nvl(v_mto_cheque,0) then
		     v_procesa := 'N';
         v_cod_respuesta:='OP_ERROR';
         v_msj_respuesta := 'Importe del cheque no coincide con lo procesado';
	     end if;
       
 	     if v_est_movimiento in ('X','P') then
		     v_procesa := 'N';
         v_cod_respuesta:='OP_ERROR';
         v_msj_respuesta := 'Movimiento se encuentra Pendiente. Favor autorice previamente';
	     end if;

	   exception
	     when no_data_found then
   	     v_procesa := 'N';
         v_cod_respuesta:='OP_ERROR';
         v_msj_respuesta := 'Los datos del cheque no coincide con lo procesado';
	   end;
  end if;   
   --2. acreditamos de vuelta a la cuenta libradora si es un cheque ya pagado
   if v_procesa = 'S' and v_est_cheque = 'P' then
      v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
       -- se le acredita a la cuenta de debito o cuenta libradora  
      pag_cta.PR_ACT_OPERACION
                       (p_nro_cuenta,
                         v_hor_actual
                         ,'C'
                         ,p_cod_moneda
                         ,v_mto_cheque
                         ,132
                         ,602
                         ,p_nro_cheque
                         ,NULL
                         ,31
                         ,4
                         ,41
                         ,null
                         ,null
                         ,'DEVOLUCION CHEQUE NRO. '||p_nro_cheque
                         ,'N'
                         ,v_nro_secuencia
                         ,null
                         ,null
                         ,null); 														 
      if pag_cta.fu_obt_cod_error() <> 0 then
          v_procesa :='N';
          v_cod_respuesta:='OP_ERROR';
          v_msj_respuesta:=pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error();
 
          --- seteamos respuesta del proceso
          v_retorno.datosAdicionales := typ_listaclavevalor();
          paw_uti.pr_add_value(v_retorno.datosAdicionales, 'status', v_procesa, 'STRING');
          paw_uti.pr_add_value(v_retorno.datosAdicionales, 'responseCode', v_cod_respuesta, 'STRING');
          paw_uti.pr_add_value(v_retorno.datosAdicionales, 'messageCode', v_msj_respuesta, 'STRING');
          --
          -- logueo la respuesta --
         PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_mto_cheque, 'D', null /*nro_Caja*/, v_procesa,
         'Al acreditar monto cheque Devuelto',
         v_cod_respuesta,
         v_msj_respuesta, null);
        -- 
        rollback;
        --
        return v_retorno;

      end if;
	end if;

  --- 3.inserto el movimiento que afecta el rubro transitorio 
  if v_procesa ='S' then
     begin
       v_nro_secuencia := v_nro_secuencia + 1 ;

       if v_est_cheque = 'P' then
          v_lugar:= 'Devolucion Cheque Depositado';
          r_gmovi.nro_cuenta      := p_nro_cuenta;            
          r_gmovi.cod_rubro       := fug_obt_pardinamico('COD_RUB_DEP_BTW',null,null,v_cod_moneda,null,null); 
          r_gmovi.nro_documento   := p_nro_cheque;
          r_gmovi.cod_tra_padre			:= 132;
          r_gmovi.tip_mov_rubro			:= 'D';
          r_gmovi.cod_transaccion   := null;
          r_gmovi.monto							:= v_mto_cheque;
          r_gmovi.concepto					:= 'DEVOLUCION CHEQUE NRO. '||p_nro_cheque||' - CUENTA: '||p_nro_cuenta;
       elsif (v_est_cheque ='E' or v_est_cuenta in ('C','P')) then -- transaccion 131
          v_lugar:= 'Devolucion por defecto de forma';
          r_gmovi.cod_rubro         := null; 
          r_gmovi.nro_documento     := p_nro_cheque; 
          r_gmovi.cod_tra_padre			:= 132;
          r_gmovi.tip_mov_rubro			:= null;
          r_gmovi.cod_transaccion   := 132;
          r_gmovi.concepto					:= 'Devolución de cheq.: '||p_nro_cheque;
          r_gmovi.nro_cuenta      := p_nro_cuenta;
       elsif (v_est_cheque = 'O' or v_est_cuenta in ('C','P')) then -- transaccion 131           
          v_lugar:= 'Devolucion Ch. ONP o Cta.Cancelada';
          r_gmovi.cod_tra_padre   := 131;
          r_gmovi.nro_caja        := null;
          r_gmovi.cod_transaccion := 131;
          r_gmovi.monto           := p_mto_cheque;
          r_gmovi.nro_documento   := p_nro_cheque;
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.concepto        := 'Devolucion de Cheque '||p_nro_cheque;
          r_gmovi.estado          := 'N';
          r_gmovi.reversado       := 'N';
          r_gmovi.cod_rubro       := NULL;
          r_gmovi.tip_mov_rubro   := NULL;
          r_gmovi.nro_cuenta      := p_nro_cuenta;              
       end if;
      r_gmovi.fecha          		:= v_fec_actual;
      r_gmovi.fec_valor         := v_fec_actual; 
      r_gmovi.hora     	     		:= v_hor_actual;
      r_gmovi.nro_secuencia     := v_nro_secuencia;
      r_gmovi.cod_usuario  			:= user;
      r_gmovi.monto							:= v_mto_cheque;
      r_gmovi.cod_moneda        := v_cod_moneda; 
      r_gmovi.cod_oficina       := v_cod_ofi_cta; 
      r_gmovi.cod_ofi_origen    := fug_obt_ofi_usuario(upper(user));
      r_gmovi.cod_modulo        := 4; 
      r_gmovi.cod_modalidad     := 41;
      r_gmovi.cod_mod_padre     := 4;
      r_gmovi.cod_mad_padre     := 41;
      r_gmovi.emi_aviso  				:= 'N';
      r_gmovi.estado 						:= 'N';
      r_gmovi.reversado 				:= 'N';
      r_gmovi.protegido 				:= 'N';
      r_gmovi.cod_causa         := v_cod_causa;
          
      if v_cod_moneda <>  pag_gen.FU_OBT_MON_LOCAL then
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo,v_cod_modalidad,v_cod_moneda);
         v_cotizacion := nvl(pag_gen.FU_OBT_COTIZACION(v_cod_moneda,v_fec_actual),2);
         -- 
         r_gmovi.cotizacion := v_cotizacion;
         r_gmovi.mto_equ_local := round(nvl(v_mto_cheque,0) * nvl(v_cotizacion,0), 0);   
      else
         r_gmovi.mto_equ_local := null;

      end if;
    
      PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,'N');
   exception
        when others then
          v_error := sqlerrm;
          v_procesa :='N';
          v_msj_respuesta:='Al insertar movim. Cheques Hibridos';
          v_cod_respuesta:='OP_ERROR';

          v_retorno.error := 'S';
          v_retorno.nombreRespuesta:= v_cod_respuesta;
          v_retorno.descripcionRespuesta:= v_msj_respuesta;
          --
          --- seteamos respuesta del proceso
          v_retorno.datosAdicionales := typ_listaclavevalor();
          paw_uti.pr_add_value(v_retorno.datosAdicionales, 'status', v_procesa, 'STRING');
          paw_uti.pr_add_value(v_retorno.datosAdicionales, 'responseCode', v_cod_respuesta, 'STRING');
          paw_uti.pr_add_value(v_retorno.datosAdicionales, 'messageCode', v_msj_respuesta, 'STRING');
          --
                      
          -- logueo la respuesta --
           PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_mto_cheque, 'D', null /*nro_Caja*/, v_procesa,
          ----'nroCuenta:'||p_nro_cuenta||'*p_nro_cheque:'||p_nro_cheque||'*p_cod_moneda:'||p_cod_moneda||'*p_monto:'||p_mto_cheque,              
           v_lugar,
           v_cod_respuesta,
           v_msj_respuesta, v_error);
          -- 
          rollback;
          --
          return v_retorno;
    	
     end;

 end if; 
  
 if v_procesa ='S' and v_est_cheque ='P' then
   begin
      -- se elimina de la tabla cc_che_pagados ya que pueden volver a pagar en el mismo dia (Efrain Salomon)
      v_lugar:= 'Update cc_che_pagados ';
      delete from cc_che_pagados
       where nro_cuenta = p_nro_cuenta
         and nro_cheque = p_nro_cheque
         and monto = v_mto_cheque
         and fecha = (select max(fecha) from cc_che_pagados b
                       where b.nro_cheque = p_nro_cheque
                       and b.nro_cuenta = p_nro_cuenta
                       and b.monto = v_mto_cheque);
   

     -- cambio de estado el estado del cheque a E
        v_lugar:= 'Update cc_chequeras ';
       --Actualizar el estado del cheque en cc_chequeras
        v_poscheque := p_nro_cheque - v_nro_che_inicial + 1;
        UPDATE cc_chequeras
           set est_cheques = substr(est_cheques,1,v_poscheque-1)||'E'||substr(est_cheques,v_poscheque+1,length(est_cheques))
        where nro_cuenta = p_nro_cuenta
          and nro_che_inicial = v_nro_che_inicial;
        If sql%notfound then
           v_msj_respuesta := 'Al actualizar el estado del cheque';

        End if;
        
   exception
     when others then
          v_error := sqlerrm;
          v_procesa :='N';
          v_msj_respuesta:=substr(v_lugar||sqlerrm,200);
          v_cod_respuesta:='OP_ERROR';

          v_retorno.error := 'S';
          v_retorno.nombreRespuesta:= v_cod_respuesta;
          v_retorno.descripcionRespuesta:= v_msj_respuesta;
          --- seteamos respuesta del proceso
          v_retorno.datosAdicionales := typ_listaclavevalor();
          paw_uti.pr_add_value(v_retorno.datosAdicionales, 'status', v_procesa, 'STRING');
          paw_uti.pr_add_value(v_retorno.datosAdicionales, 'responseCode', v_cod_respuesta, 'STRING');
          paw_uti.pr_add_value(v_retorno.datosAdicionales, 'messageCode', v_msj_respuesta, 'STRING');
          --
                  
          -- logueo la respuesta --
           PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_mto_cheque, 'D', null /*nro_Caja*/, v_procesa,
           v_lugar,
           v_cod_respuesta,
           v_msj_respuesta, v_error);
          -- 
          rollback;
            --
            return v_retorno;     
      END;           
   end if; 
   -- onp y cta cancelada no se inserta, lo haran por la pantalla
   if v_procesa ='S' and p_cod_causa not in (128, 107) then
     begin
           -- inserto en cc_che_devueltos
        v_lugar:= 'Insert cc_che_devueltos ';
        insert into CC_CHE_DEVUELTOS(FECHA, HORA, COD_USUARIO,
                          NRO_Cuenta, NRO_CHEQUE, COD_MONEDA, MONTO,
                          COD_CAUSA, MULTA, SAL_MULTA,
                          COD_BCO_RECEPTOR, NRO_CAJA, COD_OFI_CAMARA,TIPO)
                   values(v_fec_actual, v_hor_actual, USER,
                          p_nro_cuenta, p_nro_cheque,
                          v_cod_moneda,v_mto_cheque, 
                          v_cod_causa, 0,  /*multa*/
                          0, -- nvl(val_multa,0),
                          null,null,
                          31, -- ofi camara
                          FUG_OBT_PARCAUSALES(v_cod_causa,'TIP_DEVOLUCION'));
      exception
        when others then          
          v_error := sqlerrm;
          v_procesa :='N';
          v_msj_respuesta:=substr(v_lugar||sqlerrm,200);
          v_cod_respuesta:='OP_ERROR';

          v_retorno.error := 'S';
          v_retorno.nombreRespuesta:= v_cod_respuesta;
          v_retorno.descripcionRespuesta:= v_msj_respuesta;
          --- seteamos respuesta del proceso
          v_retorno.datosAdicionales := typ_listaclavevalor();
          paw_uti.pr_add_value(v_retorno.datosAdicionales, 'status', v_procesa, 'STRING');
          paw_uti.pr_add_value(v_retorno.datosAdicionales, 'responseCode', v_cod_respuesta, 'STRING');
          paw_uti.pr_add_value(v_retorno.datosAdicionales, 'messageCode', v_msj_respuesta, 'STRING');
          --
                  
          -- logueo la respuesta --
           PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_mto_cheque,'D', null /*nro_Caja*/, v_procesa,
           v_lugar,
           v_cod_respuesta,
           v_msj_respuesta, v_error);
          -- 
          rollback;
            --
            return v_retorno;               
      end;    
   end if;
   
   begin
     select 1 into v_count
        from cc_che_hibridos h
      where h.fecha      = v_fec_actual
        and h.hora       = v_hor_actual
        and h.nro_cuenta = p_nro_cuenta
        and h.nro_cheque = p_nro_cheque
        and h.monto      = p_mto_cheque;
      
      if v_count > 0 then
              -- actualizo cc_che_hibridos a Devuelto            
         pag_btw.pr_upd_che_hibridos(v_fec_actual,v_hor_actual, v_cod_usuario,
                                  p_nro_cuenta, p_nro_cheque, p_mto_cheque, 'D', v_cod_causa);   
      else
          pag_btw.pr_ins_che_hibridos(v_fec_actual, 
                              v_hor_actual,
                              v_cod_usuario, 
                              p_nro_cuenta,
                              p_nro_cheque,
                              p_cod_moneda,
                              p_mto_cheque,
                              null,
                              'D');
      end if;
     exception
       when no_data_found then
          pag_btw.pr_ins_che_hibridos(v_fec_actual, 
                              v_hor_actual,
                              v_cod_usuario, 
                              p_nro_cuenta,
                              p_nro_cheque,
                              p_cod_moneda,
                              p_mto_cheque,
                              null,
                              'D');
     end;    
                             
 -- logueo la respuesta --
     PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_mto_cheque, 'D', null /*nro_Caja*/, v_procesa,
     NULL,
     v_cod_respuesta,
     v_msj_respuesta, v_error);
 
    v_retorno.datosAdicionales := typ_listaclavevalor();
    paw_uti.pr_add_value(v_retorno.datosAdicionales, 'status', v_procesa, 'STRING');
    paw_uti.pr_add_value(v_retorno.datosAdicionales, 'responseCode', v_cod_respuesta, 'STRING');
    paw_uti.pr_add_value(v_retorno.datosAdicionales, 'messageCode', v_msj_respuesta, 'STRING');


   -- si se procesó todo Ok o queda Pend de aut. entonces comiteamos la transaccion
   if v_procesa ='S' then 
      commit;
      ---
   else
      rollback;
   end if;      
   -- retornamos
   v_retorno.error := 'N';
   v_retorno.cantidad := v_retorno.datosAdicionales.count;
   RETURN v_retorno; 
   
exception
when others then
  
    v_error := sqlerrm;
   v_retorno.error:='S';
   v_retorno.nombreRespuesta:='OP_ERROR';
   v_retorno.descripcionRespuesta:= substr(v_error, 1,200);
   --- seteamos respuesta del proceso
    v_retorno.datosAdicionales := typ_listaclavevalor();
    paw_uti.pr_add_value(v_retorno.datosAdicionales, 'status', 'N', 'STRING');
    paw_uti.pr_add_value(v_retorno.datosAdicionales, 'responseCode', 'OP_ERROR', 'STRING');
    paw_uti.pr_add_value(v_retorno.datosAdicionales, 'messageCode', substr(v_error, 1,200), 'STRING');
    --
   --
   PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_mto_cheque, 'D', null /*nro_Caja*/, v_procesa,
     NULL,
     v_cod_respuesta,
     v_msj_respuesta, v_error);
     --
   return v_retorno;
end;                              


/*Procedimiento que rechaza un cheque BT pendiente de autorizacion 
actualiza boleta de deposito y saldo retenido */
procedure pr_rch_pen_che_btw(p_nro_cuenta in varchar2  default null, -- Nro de cuenta del cli
                             p_nro_cheque in number  default null, -- Nro de cheque
                             p_cod_moneda in varchar2  default null, -- cod_moneda
                             p_mto_cheque in number default null,     -- Monto del cheque
                             p_cod_causa in number,
                             p_msj_respuesta out varchar2)
is
  v_nro_cuenta     cc_cta_bancarias.nro_cuenta%type;
  v_nro_secuencia  ge_movimientos.nro_secuencia%type := 1; 
  v_cod_tra_padre  ge_movimientos.cod_tra_padre%type;
  v_cod_modulo		 ge_cuentas.nro_cuenta%type;
  v_cod_modalidad  ge_modalidades.cod_modalidad%type;
  r_gmovi 				 ge_movimientos%rowtype;
  v_nro_boleta     ge_movimientos.nro_documento%type;
  v_cta_deposito   ge_movimientos.nro_cuenta%type;
  v_mon_deposito   ge_movimientos.cod_moneda%type;
  v_mto_deposito   ge_movimientos.monto%type;
  v_cod_ofi_origen ge_movimientos.cod_ofi_origen%type := fug_obt_ofi_usuario(upper(user));
  v_msg_respuesta  varchar2(2000);
  v_error          varchar2(2000);  
  v_fec_actual     date := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_hor_actual     varchar2(10) := to_char(sysdate,'hh24:mi:ss');
  v_procesa        varchar2(1) := 'S';
BEGIN
   v_hor_actual := fug_obt_hor_disponible(v_fec_actual,v_hor_actual, user,'N');
   --Obtener datos del deposito
    begin
      select dep.nro_documento, dep.nro_cuenta,
             dep.cod_moneda,    dep.monto,
             cta.cod_modulo,    cta.cod_modalidad,
             dep.cod_tra_padre
        into v_nro_boleta,  v_cta_deposito,
             v_mon_deposito,v_mto_deposito,
             v_cod_modulo,  v_cod_modalidad,
             v_cod_tra_padre
        from cj_movimientos det,
             cj_movimientos dep,
             ge_cuentas cta
       where det.nro_cuenta is null
         and det.nro_documento = p_nro_cheque
         and det.monto         = p_mto_cheque
  --       and det.hora          = p_hora
  --       and det.cod_usuario   = p_cod_usuario
         and det.cod_tra_padre = 355
         and det.cod_moneda = dep.cod_moneda
         and det.nro_doc_referencia = dep.nro_documento
         and det.estado = 'N'
         and dep.estado = 'N'
         and dep.nro_cuenta = cta.nro_cuenta
         and dep.tip_monto = 'C'; --Tipo de Monto Cargo Nuestro Banco. 
    exception
      when others then 
       -----------------------------------------------------------------------------------------------------------
       v_procesa :='N';
       v_error   := substr(sqlerrm,1,1500);
       v_msg_respuesta := 'Al buscar datos del depósito, Cuenta: '||p_nro_cuenta||', Cheque Nro.: '||p_nro_cheque||'-'||v_error;
       PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_mto_cheque, 'D', null /*nro_Caja*/, v_procesa,
                       NULL,     'OP_ERROR',     v_msg_respuesta, v_error);
 
    end;

   if v_procesa ='S' then
      --Libera antes el deposito para no tener problemas (Para Cámara Interna)...
      update ah_retenciones
         set lib_posterior = 'S'
       where nro_cuenta = v_cta_deposito
         and nro_documento = v_nro_boleta
         and liberado = 'N';
  		  
      PRA_LIB_RETENCION( V_CTA_DEPOSITO, V_CTA_DEPOSITO, 'S','S',v_nro_boleta,p_mto_cheque);
  			
      --Debitar a la Cta. del depósito
      pag_cta.PR_ACT_OPERACION(v_cta_deposito
                                ,v_hor_actual
                                ,'D'
                                ,v_mon_deposito
                                ,p_mto_cheque
                                ,132
                                ,503
                                ,p_nro_cheque -- 10/10/09 V.O.
                                ,NULL
                                ,v_cod_ofi_origen  --- oficina camara
                                ,4
                                ,41
                                ,null
                                ,null
                                ,null
                                ,'N'
                                ,v_nro_secuencia--,v_secuencia
                                ,v_fec_actual
                                ,null
                                ,null);
        if pag_cta.fu_obt_cod_error() <> 0 then
          v_msg_respuesta :=(pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
          v_procesa :='N';
          --
          PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_mto_cheque, 'D', null /*nro_Caja*/, v_procesa,
               NULL,     'OP_ERROR',     v_msg_respuesta, 'Al Debitar Cuenta Deposito');
          --     

        end if;
		 end if;
     
     if v_procesa = 'S' then 	
       r_gmovi := null;
  		  
       -- cheque hibridos debitamos del rubro transitorio
        begin
          select a.cod_moneda, 
                   a.cod_oficina, 
                   a.nro_documento, 
                   a.referencia
              into r_gmovi.cod_moneda, 
                   r_gmovi.cod_oficina, 
                   r_gmovi.nro_documento, 
                   r_gmovi.referencia     
              from ge_movimientos a
             where a.nro_documento = p_nro_cheque
               and a.monto = p_mto_cheque
               and a.reversado = 'N'
               and a.cod_mod_padre = 9
               and a.cod_mad_padre = 91 
               and a.cod_tra_padre = 355 --
               and a.cod_transaccion = 691;
               
         	  v_nro_secuencia      		:= v_nro_secuencia + 1;
			  
            r_gmovi.nro_secuencia     := v_nro_secuencia;
            r_gmovi.tip_mov_rubro			:= 'C';
            r_gmovi.cod_rubro         := fug_obt_pardinamico('COD_RUB_DEP_BTW',null,null,v_mon_deposito,null,null); 
            r_gmovi.cod_transaccion   := null;
            r_gmovi.fecha          		:= v_fec_actual;
            r_gmovi.fec_valor         := v_fec_actual; 
            r_gmovi.hora     	     		:= v_hor_actual;
            r_gmovi.cod_usuario  			:= user;
            r_gmovi.monto							:= p_mto_cheque;
            r_gmovi.cod_ofi_origen    := v_cod_ofi_origen;
            r_gmovi.concepto					:= 'DEVOLUCION CHEQUE NRO. '||p_nro_cheque||' - CUENTA: '||v_nro_cuenta;
            r_gmovi.emi_aviso  				:= 'N';
            r_gmovi.estado 						:= 'N';
            r_gmovi.reversado 				:= 'N';
            r_gmovi.protegido 				:= 'N';
    	      r_gmovi.cod_tra_padre     := 132;
            r_gmovi.cod_mod_padre     := 4; 
            r_gmovi.cod_mad_padre     := 41;
            r_gmovi.cod_modulo        := 4; 
            r_gmovi.cod_modalidad     := 41;
            PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,'N');
               
          exception
            when others then
              v_error := substr(sqlerrm,1,1800);
              v_msg_respuesta := 'Al ins mov Transitorio'||'-'||v_error;
              v_procesa :='N';
              --
              PR_INS_LOG_BTW(p_nro_cuenta, p_nro_cheque, p_mto_cheque, 'D', null /*nro_Caja*/, v_procesa,
                             NULL,     'OP_ERROR',     v_msg_respuesta, v_error);
              --               
          end;

	    end if;

      p_msj_respuesta := v_msg_respuesta;      
  
exception
	when others then
	  p_msj_respuesta := 'Error al procesar Devolución de Depósito.'||sqlerrm;

end;                                


/*
PROCEDIMIENTO que loguea los datos enviados y recibidos a/desde Runes
*/
PROCEDURE pr_ins_log_btw(p_nro_cuenta in varchar2,
                        p_nro_cheque in varchar2,
                        p_monto      in number,
                        p_tipo       in varchar2,
                        p_nro_caja   in number,
                        p_procesa in varchar2,
                        p_mensaje    in varchar2,
                        p_cod_respuesta in varchar2,
                        p_msg_respuesta in varchar2,
                        p_error         in varchar2)
IS PRAGMA AUTONOMOUS_TRANSACTION;
v_Error varchar2(4000);
BEGIN
  insert into ge_bitacora(nro_cuenta, nro_cheque, monto, nro_caja,
                          tipo, procesa, mensaje, 
                          cod_respuesta,respuesta, error)
                  values (p_nro_cuenta, p_nro_cheque, p_monto, p_nro_caja, 
                         p_tipo, p_procesa, p_mensaje, 
                         p_cod_respuesta,substr(p_msg_respuesta,1,4000), substr(p_error,1,4000));
  commit;
exception
  when others then   
    v_Error := sqlerrm;
    insert into ge_bitacora(nro_cuenta, nro_cheque, monto, nro_caja,
                           tipo, procesa, mensaje, 
                          cod_respuesta,respuesta, error)
                  values (p_nro_cuenta, p_nro_cheque, p_monto, p_nro_caja, 
                          p_tipo, p_procesa, p_mensaje, 
                         null,null, substr(nvl(p_error,v_error),1,4000));
    commit;                     
END;

/*
PROCEDIMIENTO que inserta en la tabla para seguimiento o conciliacion de datos
*/                        
PROCEDURE pr_ins_che_hibridos(p_fecha in date, 
                              p_hora in varchar2,
                              p_cod_usuario in varchar2, 
                              p_nro_cuenta in varchar2,
                              p_nro_cheque in number,
                              p_cod_moneda in varchar2,
                              p_monto      in number,
                              p_nro_caja   in number,
                              p_situacion  in varchar2)
is
v_error varchar2(4000);
v_situacion varchar2(1):='N';
begin
  --
  if p_situacion ='S' then
   v_situacion :='C'; -- confirmado
  else
   v_situacion := p_situacion;
  end if;
  --   
  insert into cc_che_hibridos(fecha, hora, cod_usuario, nro_cuenta, nro_cheque,
                              cod_moneda, monto, nro_caja, situacion)
                      values (p_fecha, p_hora, p_cod_usuario, p_nro_cuenta, p_nro_cheque,
                             p_cod_moneda, p_monto, p_nro_caja, v_situacion);
exception
  WHEN DUP_VAL_ON_INDEX THEN
    NULL;
  when others then     
       v_error := sqlerrm;                        
       pr_ins_log_btw(p_nro_cuenta,p_nro_cheque,p_monto,'C',p_nro_caja,v_situacion,null, NULL,'Error al insertar en CC_CHE_HIBRIDOS', v_error);
end; 


procedure pr_upd_che_hibridos(p_fecha in date, 
                              p_hora in varchar2,
                              p_cod_usuario in varchar2, 
                              p_nro_cuenta in varchar2,
                              p_nro_cheque in number,
                              p_monto in number,
                              p_situacion  in varchar2,
                              p_cod_causa  in number)
is  
v_error varchar2(2000);
v_count number :=0;
begin
  update cc_che_hibridos a
       set a.situacion = p_situacion, -- seteamos como devuelto
           a.cod_causa =  p_cod_causa
     where a.fecha = p_fecha
       and a.hora = p_hora
       and a.nro_cuenta = p_nro_cuenta
       and a.nro_cheque = p_nro_cheque
       and a.monto      = p_monto;
exception
  when others then     
       v_error := sqlerrm;                        
       pr_ins_log_btw(p_nro_cuenta,p_nro_cheque,0,'C',null,p_situacion,null, NULL,'Error al actualizar CC_CHE_HIBRIDOS', v_error);
end;  

/*
Funcion que convierte la cadena de caracteres segun el origen
-- Para mensajes recibidos de Runes (BT) convertimos de UTF8 al charset de la BD
-- Para mensajes enviados a Runes convertimos del charset de la BD a UTF8
*/
function fu_val_charset(p_cadena in varchar2, p_origen in varchar2) 
  return varchar2
is

v_charset VARCHAR2(40);--contendrá el juego de carecteres de la base de datos.
v_mensaje varchar2(200);
begin

--buscamos el juego de caracteres de la base de datos
  begin
    select t.value
       into v_charset
    from nls_database_parameters t
    where t.parameter = 'NLS_CHARACTERSET';
  exception
     when others then
       return p_cadena;  -- si no se pudo obtener el charset de la BD retorna la cadena original
  end;
  
  --- si estamos enviando a runes el mensaje, convertimos a UTF8
  if p_origen ='ITGF2BT' then
      --convertimos a UTF8
      begin
        v_mensaje := convert(p_cadena,'UTF8',V_CHARSET);
        return v_mensaje;
      EXCEPTION
         WHEN OTHERS THEN
           null;
           -- RAISE_APPLICATION_ERROR(-20000,'Error al convertir a UTF8 los datos a enviar: '||SQLERRM);
      end;
  end if;
  
  --- si estamos recibiendo un mensaje de runes, convertimos al charset de la base
  if p_origen ='BT2ITGF' then  
      begin
        v_mensaje := convert(p_cadena,V_CHARSET, 'UTF8');
        return v_mensaje;
      EXCEPTION
         WHEN OTHERS THEN
             null;
            --RAISE_APPLICATION_ERROR(-20001,'Error al convertir a '||V_CHARSET||' los datos recibidos: '||SQLERRM);
      end;
   end if;
   --- si no pudo convertir retorna el mismo mensaje y no para el proceso.
   return p_cadena;
 end;  -- fin funcion de val charset
-----    

/*
Funcion para obtener la oficina de BanTotal
*/
function fu_obt_ofi_btw(p_cod_oficina in number) 
  return number
is
v_cod_suc_btw mi_tab_parametricas.val_cod_bantotal%type;
begin
  select val_cod_bantotal into v_cod_suc_btw
   from mi_tab_parametricas m
  where m.nom_tab_itgf='BA_OFICINAS'
   and m.nom_col_codigo ='COD_OFICINA'
   and to_number(m.val_cod_itgf) = p_cod_oficina;
   
   return to_number(v_cod_suc_btw);
exception
  when others then
    return -99;   
end;  -- fin fu_obt_ofi_btw

end;
/

