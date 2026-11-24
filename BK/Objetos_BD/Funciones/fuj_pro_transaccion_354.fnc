create or replace function it.FUJ_PRO_TRANSACCION_354(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_cheque in varchar2,      -- Nro de cheque
      p_nro_cuenta in varchar2,      -- Nro de cuenta del cliente
      P_importe in varchar2,         -- Importe de la extraccion
      p_opcion  in VARCHAR2)
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_transaccion number(4) := 354;  -- transaccion
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
  v_est_cheque        varchar2(01);      -- estado del cheque
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
   /*CROCLIJUD-5*/
  v_cod_persona        ba_personas.cod_persona%type;
  v_cod_cau_judicial   ge_causales.cod_causa%type := fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL');
  /*C.D. Fase III*/
  v_tip_operacion   ge_mov_autorizaciones.tip_operacion%type := 'O';-- Todos Tipos Operacional
  v_est_movimiento  ge_movimientos.estado%type;
  v_nro_pedido      ge_mov_autorizaciones.nro_pedido%type;
  --Notificaciones Fase 3
   v_ret          NUMBER(3) := 0;
   --Cheques Multiples
   v_che_multiple   VARCHAR2(1):= 'N';    
  --Rechazo automatico
  v_opcion          varchar2(10);
  v_opc_rta         varchar2(200);
  v_opc_importe     varchar2(30);
  v_opc_nro_cta     varchar2(50);
  v_cod_opcion      ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAJ_COD_OPC'); 
  v_rec_aut         varchar2(1);
  v_cod_cau_rechazo varchar2(10);
  v_des_cau_rechazo varchar2(100);
  v_sec_rechazados  number(10):= -999;
  v_sec_rechazados_out  number(10);
  v_nro_lote        number(10);
  v_tip_importe     varchar2(10);
  v_cod_ofi_cta     ge_cuentas.cod_oficina%TYPE;
  rp_rch_aut        cc_che_rec_automaticos%ROWTYPE;

  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion(p_estado varchar2)  is
  begin
      -- Actualizo el control de caja
      if p_estado <> 'P' then -- C.D.Fase III
        update cj_controles
           set sal_actual = nvl(sal_actual,0) - nvl(v_importe,0),
               tot_creditos = nvl(tot_creditos,0) + nvl(v_importe,0),
               can_creditos = nvl(can_creditos,0) + 1,
               estado = 1 -- abierto
         where nro_caja = to_number(p_nro_caja)
           and cod_moneda = v_cod_moneda
           and fecha = v_fec_caja;
       end if;
      -- genero el movimiento por la extraccion
      insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia,
          cod_tra_padre, cod_mod_padre, cod_mad_padre,
          cod_oficina, cod_moneda, nro_caja,
          nro_documento, nro_cuenta, monto, tip_monto, tipo, estado, -- C.D Fase III
          nro_ref_externo) --> CRO-FACPOD: Para Almacenar la respuesta de la Aplicación Externa.-
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 1,
          v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
          v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
          p_nro_cheque, nvl(v_nro_cta_certificado,p_nro_cuenta),
          v_importe,v_tip_monto /* efectivo */, v_tipo, p_estado, /* es credito */
          p_nro_operacion);
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
 else
  ---
  if p_nro_cuenta is not null then  -- valido la cuenta si es migrada
     v_msj_respuesta := fug_obt_nro_cta_bt(p_nro_cuenta);
     if v_msj_respuesta is not null then
        v_cod_respuesta := '012'; -- error
     end if;
  end if;
  -- se extrae la opcion SI/NO seleccionada
  v_opcion := substr(p_opcion, 1, 2);
  -- se extrae el nro de cta
  if (instr(p_opcion, '{', 1, 1) > 0) then
    v_opc_nro_cta := substr(p_opcion,
                            instr(p_opcion, '{', 1, 1) + 1,
                            (instr(p_opcion, '}', 1, 1) - 1) -
                            instr(p_opcion, '{', 1, 1));
  end if;
  -- se extrae el importe
  if (instr(p_opcion, '{', 1, 2) > 0) then
    v_opc_importe := substr(p_opcion,
                            instr(p_opcion, '{', 1, 2) + 1,
                            (instr(p_opcion, '}', 1, 2) - 1) -
                            instr(p_opcion, '{', 1, 2));
  end if;
      
  if v_cod_respuesta = '000' then   
    -- obtengo datos de la cuenta  ------------------------------------------
    begin
      select denominacion, cod_moneda, estado, cod_modalidad, a.cod_oficina
        into v_denominacion, v_cod_moneda, v_est_cuenta, v_tip_cuenta, v_cod_ofi_cta
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
          --Verificar si es cheque multiple
          BEGIN
            SELECT 'S' 
            INTO v_che_multiple
            FROM cc_che_tra_multiples c
            WHERE c.nro_cuenta = p_nro_cuenta
            AND   c.nro_cheque = p_nro_cheque;
          EXCEPTION
            WHEN no_data_found THEN
              v_che_multiple := 'N';
          END;
          --Solo verifica duplicacion si no es Cheque Multiple
          IF v_che_multiple = 'N' THEN
            -- Verifico la duplicacion del registro
            prj_val_duplicacion(p_nro_caja,
                                v_cod_transaccion,
                                v_cod_moneda,
                                p_nro_cheque,
                                v_cod_respuesta,
                                v_msj_respuesta);
          END IF;                    
        end if;
        if v_cod_respuesta = '000' then
           v_msj_respuesta := fuj_ver_impedimentos(p_nro_cuenta,
                                                   v_tip_cuenta,
                                                   v_cod_transaccion,
                                                   v_est_cuenta,
                                                   'D'); -- 'D'== DEBITO EN CUENTA
           if v_msj_respuesta is not null AND
              nvl(fug_obt_pardinamico('CC_ACT_REC_AUT'),'N') <> 'S' AND
              nvl(v_opcion, 'NO') <> 'SI' then
              v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
           end if;
        end if;
		if v_cod_respuesta = '000' then     
        ---Verifica si el Cliente o un Vinculado a la Cuenta está inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
          v_cod_persona := fug_obt_cli_principal(p_nro_cuenta);
          if fug_obt_inhibicion(v_cod_cau_judicial,v_cod_persona,p_nro_cuenta) Then
            v_cod_respuesta := '003';
            v_msj_respuesta := 'ERROR: Cliente Principal. o Vinc. a la Cuenta con Demanda Judicial.Consulte con el asesor Jurídico' ;
          End If;
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
    --Rechazo automático
    IF v_cod_respuesta = '000' AND
       nvl(fug_obt_pardinamico('CC_ACT_REC_AUT'),'N') = 'S' AND
       nvl(v_opcion, 'NO') = 'SI' THEN
        --ver rechazo automatico
        PRC_VER_CHE_REC_AUT(p_nro_cuenta, p_nro_cheque,v_est_cuenta, v_rec_aut,v_cod_cau_rechazo,v_des_cau_rechazo);
        IF nvl(v_rec_aut,'N') = 'S' THEN
          --obtener el ultimo numero de lote
          begin
           select nvl(max(a.nro_lote),0)
               into v_nro_lote
                from cc_che_rec_automaticos a;
          exception
            when others then
              v_nro_lote:=0;
          end;
          v_nro_lote:= nvl(v_nro_lote,0) + 1;
          --obtener tip_importe (Alto/Bajo Valor)
          if v_cod_moneda = pag_gen.fu_obt_mon_local then
           if v_importe >= nvl(fug_obt_pardinamico('MTO_CHE_RET_CERO',null,null,v_cod_moneda),0) then
             v_tip_importe:=1;
           else
             v_tip_importe:=0;
           end if;
         else
           v_tip_importe:=0;
         end if; 
         BEGIN
           --inserta rechazos automaticos
           rp_rch_aut.nro_cheque         := p_nro_cheque;
           rp_rch_aut.fec_proceso        := v_fec_actual;
           rp_rch_aut.nro_cuenta         := p_nro_cuenta; 
           rp_rch_aut.monto              := v_importe; 
           rp_rch_aut.cod_bco_receptor   := fug_obt_cod_banco; --nuestro banco
           rp_rch_aut.cod_ofi_camara     := FUG_OBT_OFI_CAMARA(v_cod_ofi_cta);
           rp_rch_aut.cod_oficina        := v_cod_ofi_cta; 
           rp_rch_aut.cod_cau_devolucion := v_cod_cau_rechazo; 
           rp_rch_aut.des_cau_devolucion := v_des_cau_rechazo; 
           rp_rch_aut.cod_usuario        := v_cod_usuario; 
           rp_rch_aut.tip_importe        := v_tip_importe; 
           rp_rch_aut.cod_moneda         := v_cod_moneda;
           rp_rch_aut.des_error          := v_msj_respuesta;
           rp_rch_aut.nro_lote           := v_nro_lote;
           rp_rch_aut.origen             := 'C';--Caja
           --inserta registro
           prc_ins_aut_rch_clearing(rp_rch_aut);
           --procesa rechazo automático
           prc_aut_rch_clearing(p_nro_cuenta,p_nro_cheque,v_cod_moneda, v_fec_actual, v_sec_rechazados,v_sec_rechazados_out);
           --salir de la operacion
           v_msj_salida := p_nro_operacion||'~'||
                           v_cod_respuesta||'~'||
                           'Operacion confirmada';
           return(v_msj_salida);              
         EXCEPTION 
           WHEN OTHERS THEN
            v_cod_respuesta := '012';
            v_msj_respuesta := 'ERROR' || sqlerrm;
         END;
       END IF;
    END IF;---hasta aqui rechazo automatico
          
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja   
       -- Obtengo los datos de la caja ---------------------------------------
       prj_obt_datos_caja(p_nro_caja,
                          v_cod_moneda,
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
       elsif v_sal_actual < v_importe then
          v_cod_respuesta := '006'; -- error
          v_msj_respuesta := 'Caja no tiene saldo para esta Operacion';
       end if;
    end if;
    
    if v_cod_respuesta = '000' THEN -- sino hubo errores veo el cheque
      v_est_anterior := pac_che.FU_CON_CAM_EST_CHE(p_nro_cuenta,
                                                    p_nro_cheque,
                                                    'P',  -- quiero pagar-- 
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
                                       590);
              -- Se agrega el código de error 30-Estado de la Cta.Combinada incorrecto 'X'- DYDMR-1587 - 13/02/2015
              if v_procesa = 'N' and pag_cta.G_COD_ERROR IN (25,29,30) and v_sal_disponible < v_importe then
                 -- problemas de saldo insuficiente
                 pag_cta.PR_SET_EST_MOVIMIENTO('X');
                 pag_cta.g_sobregira := 'S';
                 IF ((nvl(v_opcion, 'NO') = 'SI') and
                     (nvl(v_opc_nro_cta, 'N') = p_nro_cuenta) and
                     (nvl(v_opc_importe, 'N') = p_importe)) THEN
                    v_msj_autorizacion := 'Solicitud de Autorizacion por Sobregiro generada.';
                 ELSE
                    --v_msj_autorizacion := 'Cuenta '||nvl(v_nro_cta_certificado,p_nro_cuenta)||' requiere Autorizacion por Sobregiro';
                    -- a confirmar por el usuario.
                    v_opc_rta    := '¿?{'||p_nro_cuenta||'}{'||v_importe||'}';
                    v_cod_respuesta := v_cod_opcion;--'777';
                    v_msj_respuesta := 'Desea solicitar Autorizacion por Sobregiro para la Cuenta: '||
                                        nvl(v_nro_cta_certificado,p_nro_cuenta)||
                                        '?.{OPCION}'; -- entre {} el campo correspondiente al campo de opcion.
                 END IF;
              end if;
              if fuc_ver_fir_inhibidos(p_nro_cuenta) = 'S' then
                 -- cuenta tiene firmantes inhibidos
                 if v_msj_autorizacion is not null then
                    v_msj_autorizacion := v_msj_autorizacion||chr(10);
                 end if;
                 v_msj_autorizacion := v_msj_autorizacion||'Cuenta con firmantes Inhibidos-Ley de Cheques.';
                 PAG_CTA.PR_SET_EST_MOVIMIENTO('X');
              end if;
              if v_msj_autorizacion is null then
                -- Verifico el Monto Riesgo. C.D.Fase III -- Si no tiene Problemas de Saldo Insuficiente
                 PAG_RIE.PR_OPE_RIESGO( v_fec_actual,
                                        v_hor_actual,
                                        v_cod_usuario,
                                        v_cod_transaccion, -- transacción padre 
                                        v_cod_modulo,      -- Módulo
                                        v_cod_modalidad,   -- Modalidad
                                        p_nro_cuenta,      -- Nro_cuenta
                                        null,-- v_cod_persona,     -- Persona
                                        v_tip_operacion,   -- Tip_operacion 
                                        v_importe,         -- Monto
                                        null,              -- Número de Documento
                                        v_cod_moneda,      -- Moneda
                                        null,              -- Cotización                       
                                        v_nro_pedido); 
                   if v_nro_pedido > 0 then
                     v_est_movimiento := 'P'; 
                     pag_cta.PR_SET_EST_MOVIMIENTO ('P');
                   else
                     v_est_movimiento := 'N';   
                   end if; 
              end if; 
              
            if v_cod_respuesta = '000' then 
              -- Actualiza la operacion en la
              pag_cta.pr_act_operacion(nvl(v_nro_cta_certificado,p_nro_cuenta),
                                       v_hor_actual,
                                       'D', -- debito a la cuenta del cliente
                                       v_cod_moneda,
                                       v_importe,
                                       v_cod_transaccion,
                                       590, -- trans. hijo
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
                                       v_fec_actual, null, null, null, v_est_movimiento); -- C.D.Fase III
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
                       -- DYDMR-3524 - 15/04/2016 - se envia null como parametro de cuenta a la funcion pag_aut.fu_obt_usu_autorizador
                         (pag_aut.fu_obt_usu_autorizador(v_cod_transaccion,9,91,v_cod_oficina,p_importe/*,p_nro_cuenta*/),
                         v_fec_actual,v_hor_actual,v_cod_usuario, v_msj_autorizacion,'S','P',
                         pag_gen.FU_CON_MON_A_MONEDA(v_cod_moneda,'USD',v_importe));
                         --en el trigger se envia mail al autorizador
                     exception
                        when others then
                            v_cod_respuesta := '017';
                            v_msj_respuesta := 'Ins.Pedido Aut. '||substr(sqlerrm,1,400);
                     end;
                 end if;
                 /* Si se genera un Pedido de Autorización,no debe actualizar CJ_CONTROLES. C.D.Fase III*/
                 if nvl(v_nro_pedido,0)> 0 then
                   lp_gen_transaccion('P');
                 else
                   lp_gen_transaccion('N');
                 end if;
              end if;
              --Notificaciones Fase 3
              v_ret := paw_not.fu_che_pag_girado(p_nro_cuenta,p_nro_cheque,v_importe,v_cod_moneda,'S',v_fec_actual);
           end if;
           end if;
       end if;
    end if;
  end if; --> Condicion de cuenta migrada
 end if;
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    if v_msj_autorizacion is not null then
       v_msj_respuesta := '!'||v_msj_autorizacion||'.'||chr(10)||'Autorizacion Solicitada al Encargado.';
    else
      if nvl(v_nro_pedido,0) > 0 then 
        v_msj_respuesta := 'Se ha generado el Pedido de Autorización Nro:'|| v_nro_pedido;
      else
        v_msj_respuesta := 'Operacion confirmada';
      end if;
    end if;
 end if;
 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
end FUJ_PRO_TRANSACCION_354;
/
