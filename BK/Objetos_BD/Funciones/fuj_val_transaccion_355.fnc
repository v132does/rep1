create or replace function it.FUJ_VAL_TRANSACCION_355(
      p_nro_operacion in varchar2,            -- Nro de referencia de la operacion
      p_nro_caja in varchar2,                 -- Nro de Caja
      p_nro_boleta in varchar2,               -- Nro de boleta de deposito
      p_nro_cheque in varchar2  default null, -- Nro de cheque
      p_nro_cuenta in varchar2  default null, -- Nro de cuenta del cli
      --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
	    p_importe in varchar2 default null,     -- Importe de la extraccion
      p_serie in cc_chequeras.serie%type default null, -- Nro de serie del cheque
      p_hora in varchar2 default null,        --hora del movimiento
      --RE  DE-567 25/06/2015
      p_insert in boolean default false,     -- parametro para controlar si ya se insertó en cj_movimientos durante este mismo proceso.
      p_estado in varchar2 default 'N', --PCCDEEVO-554
      p_opcion in varchar2 default NULL)


return VARCHAR2 is
  -- Datos de la transaccion
  v_cod_modulo number(3)      := 9;      -- Caja
  v_cod_modalidad number(3)   := 91;     -- Caja
  v_cod_transaccion number(4) := 355;    -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);     -- saldo actual de la caja en cheques
  --
  v_denominacion      varchar2(200);     -- Nombre de la cuenta
  v_cod_mon_cta       varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  v_tip_cuenta        number(3);         -- tipo de cuenta(modalidad)
  v_est_cheque        varchar2(01);      -- estado del cheque
  v_nro_cheque        number(8);         -- para contener el nro de cheque
  -- Datos de salida
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(100) := '  '; -- sin errores
  -- Datos de campos a devolver
  v_can_campos    number(3) := 2;        -- cantidad de campos
  v_det_campos    varchar2(8000) :=      -- valores devueltos por defecto
           '[' || 'COD_MONEDA' ||'~ ]' ||
           '[' || 'IMP_TOTAL' ||'~ ]'  ||
           '[' || 'IMP_DETALLE' ||'~ ]'||
           '[' || 'DIF_CHEQUE' ||'~ ]';
  -- datos del movimiento
  v_imp_total   number(18,2) := 0;
  v_imp_detalle number(18,2) := 0;
  v_cod_moneda  varchar2(3);

  -- RE DE-567
  v_error varchar2(4000);
  v_texto VARCHAR2(100);
  --
  v_can_ope     number(3):=0; 
  v_cod_res_btw varchar2(30);
  v_msj_res_btw varchar2(100);
  v_es_che_btw  char(1):= 'N';
  v_hab_che_hib char(1):= nvl(fug_obt_pardinamico('HAB_CHE_HIBRIDOS'),'N');
  v_procesa     char(1):= 'N';
  --Sobregiro de Cta.
  v_opcion              varchar2(10);
  v_opc_rta             varchar2(200);
  v_cod_opcion          ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAJ_COD_OPC');                                 
  v_cod_cus_opcion      ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAJ_COD_OPC_CUSTOM'); 
  v_importe             NUMBER := fug_con_numero(nvl(p_importe,0));-- importe del cheque
  v_cod_mod_cuenta      number(6);
  v_cod_mad_cuenta      number(6);
  v_nvo_estado          varchar2(1);
  v_sal_disponible      number; 
  v_nro_che_inicial     number(10);        -- nro inicial del cheque
  v_est_anterior        varchar2(1);       -- estado anterior del cheque
  v_nro_cta_certificado varchar2(20) := null;      -- numero del cta certificacion
  v_cod_tra_padre       ge_transacciones.cod_transaccion%type;
  v_sal_linea           cc_cta_corrientes.sal_total%type;
  v_sal_combinada       cc_cta_corrientes.sal_total%type;
begin
 -- Valido la moneda

 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta de Extraccion.';
 else
    -- obtengo datos de la operacion de deposito -------------------------
    begin
        select a.cod_moneda Moneda, nvl(a.monto,0), nvl(a.tot_detallado,0), cod_tra_padre
          into v_cod_moneda, v_imp_total, v_imp_detalle, v_cod_tra_padre
          from cj_movimientos a
         where a.estado = p_estado -- estado normal por defecto.
           and a.tip_monto in ('C') -- tipo cheque ntro.bco
           and a.tipo = 'D' -- ingreso a la caja
           ---and a.cod_usuario = v_cod_usuario -- ingresado por el usuario
           and a.nro_caja = to_number(p_nro_caja)
           and a.nro_documento = to_number(p_nro_boleta)
           and nvl(monto,0) > nvl(tot_detallado,0) -- que no fue totalmente detallado
           and rownum = 1;  -- por si hay duplicaciones
        if v_imp_total <= v_imp_detalle then
           v_cod_respuesta := '002';
           v_msj_respuesta := 'ERROR: Boleta ya fue totalmente detallada!';
        else
           if v_cod_respuesta = '000' then -- sino hubo problemas se arma los datos de la cuenta
              v_det_campos := '[' || 'COD_MONEDA' ||'~'||v_cod_moneda|| ']' ||
                              '[' || 'IMP_TOTAL' ||'~'||to_char(v_imp_total)|| ']'||
                              '[' || 'IMP_DETALLE' ||'~'||to_char(v_imp_detalle)|| ']'||
                              '[' || 'DIF_CHEQUE' ||'~'||to_char(v_imp_total-v_imp_detalle)||']';

           end if;
        end if;
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'ERROR: Boleta no registrada en el sistema o ya fue detallada!';
      when too_many_rows then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Boleta duplicada!';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := sqlerrm;
    end;
    -- obtengo datos de la cuenta  ------------------------------------------
    if v_cod_respuesta = '000' and p_nro_cuenta is not null then
        begin
          select substr(replace(denominacion,'~','N'),1,50), cod_moneda, estado, cod_modalidad
            into v_denominacion, v_cod_mon_cta, v_est_cuenta, v_tip_cuenta
            from ge_cuentas a
           where a.nro_cuenta = p_nro_cuenta;
          if v_tip_cuenta not in (41,42,43,44,45) then
            v_cod_respuesta := '003';
            v_msj_respuesta := 'ERROR: Tipo de cuenta no permite pago de Cheques';
          elsif v_cod_mon_cta <> v_cod_moneda then
            v_cod_respuesta := '004';
            v_msj_respuesta := 'ERROR: Moneda del Cheque no corresponde al del Deposito';
          else
            -- Verifico la duplicacion del registro
            prj_val_duplicacion(p_nro_caja,
                                v_cod_transaccion,
                                v_cod_moneda,
                                p_nro_cheque,
                                v_cod_respuesta,
                                v_msj_respuesta);
            if v_cod_respuesta = '000' then
               v_msj_respuesta := fuj_ver_impedimentos(p_nro_cuenta,
                                                       v_tip_cuenta,
                                                       v_cod_transaccion,
                                                       v_est_cuenta,
                                                      'D'); -- 'D'== debito en cuenta
               if v_msj_respuesta is not null and v_est_cuenta NOT IN ('P','C','T') THEN --RE  DE-567 25/06/2015
                  v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
               end if;
            end if;
          end if;
          if v_cod_respuesta = '000' then -- sino hubo problemas se arma los datos de la cuenta
           --RE DE-567 25/06/2015 -------------------------
            v_est_cheque := pac_che.fu_obt_est_che(p_nro_cuenta,
                                                   p_nro_cheque,
                                                   v_error,
                                                   p_serie);
           --------------------------------------------------
           IF v_est_cheque = 'O' OR v_est_cuenta IN ('P','C','T') THEN --RE DE-567 25/06/2015
            IF v_est_cuenta = 'T' THEN
              v_texto := 'Bloqueada';
            ELSE
              v_texto := 'Cancelada';
            END IF;
            v_det_campos := v_det_campos ||
                            '[' || 'DES_MENSAJE' ||'~'||'Cheque con ONP ó Cta.'||v_texto|| ']' ||
                            '[' || 'DES_CUENTA' ||'~'||v_denominacion|| ']' ||
                            '[' || 'COD_MONEDA2' ||'~'||v_cod_moneda|| ']';
           ELSE
             v_det_campos := v_det_campos ||
                            '[' || 'DES_MENSAJE' ||'~'||' '|| ']' ||
                            '[' || 'DES_CUENTA' ||'~'||v_denominacion|| ']' ||
                            '[' || 'COD_MONEDA2' ||'~'||v_cod_moneda|| ']';
           END IF;
          end if;
        exception
          when no_data_found then
            -- si no existe en ge_cuentas va y busca en BT
            if v_hab_che_hib ='S' then
              begin
                Select COUNT(*) into v_can_ope
                    from cj_movimientos
                  where nro_caja = p_nro_caja
                    and cod_tra_padre = v_cod_transaccion
                    and cod_moneda = v_cod_moneda
                    and nro_documento = p_nro_cheque
                    and nro_doc_referencia = p_nro_boleta
                    and estado <> 'R';
                if v_can_ope = 0 then
                   --- valido el cuenta / cheque en bantotal
                   pag_btw.PR_VAL_CHE_BTW(p_nro_cuenta, p_nro_cheque, v_cod_moneda, p_importe, 'V',
                            p_nro_caja, v_cod_res_btw, v_msj_res_btw, v_procesa);
                  ---
                   if v_procesa ='S' then
                     --if v_cod_res_btw ='OP_APROBADA' then
                       v_es_che_btw := 'S';
                       v_det_campos := v_det_campos ||
                                '[' || 'DES_MENSAJE' ||'~'||v_msj_res_btw|| ']' ||
                                '[' || 'DES_CUENTA' ||'~'||'Cuenta/Cheque validado'|| ']' ||
                                '[' || 'COD_MONEDA2' ||'~'||v_cod_moneda|| ']';
                     -- end if;
                   else
                       v_det_campos := v_det_campos ||
                                '[' || 'DES_MENSAJE' ||'~'||v_msj_res_btw|| ']' ||
                                '[' || 'DES_CUENTA' ||'~'||'Cuenta/Cheque validado'|| ']' ||
                                '[' || 'COD_MONEDA2' ||'~'||v_cod_moneda|| ']';
                       v_cod_respuesta := '011';
                       v_msj_respuesta := 'ERROR:Respuesta: '||v_msj_res_btw;
                   end if;
                 else
                   v_cod_respuesta := '012';
                   v_msj_respuesta := 'El Cheque '||p_nro_cheque ||' ya fue detallado.';
                 end if;        
              exception
                 when others then
                    v_cod_respuesta := '015';
                    v_msj_respuesta := sqlerrm;
              end;
            else
              v_es_che_btw := 'N';
              v_cod_respuesta := '016';
              v_msj_respuesta := 'ERROR: Nro de cuenta no existe!';
            end if;  
          when others then
            v_cod_respuesta := '003';
            v_msj_respuesta := sqlerrm;
        end;
        if v_cod_respuesta = '000' and v_es_che_btw ='N' THEN -- sino hubo errores veo el cheque
            v_est_cheque := pac_che.fu_obt_est_che(p_nro_cuenta,
                                                   p_nro_cheque,
                                                   v_msj_respuesta,
                                                   p_serie); --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
            -- verifico el estado del cheque
            if v_msj_respuesta is null then
                if v_est_cheque = 'A' then
                    v_msj_respuesta := 'El cheque '||p_nro_cheque||' de la cuenta '||p_nro_cuenta||' ha sido anulado';
                elsif v_est_cheque = 'P' then
                   v_msj_respuesta := 'El cheque '||p_nro_cheque||' de la cuenta '||p_nro_cuenta||' ya fue pagado';
                elsif v_est_cheque = 'S' then
                   v_msj_respuesta := 'El cheque '||p_nro_cheque||' de la cuenta '||p_nro_cuenta||' no se ha Entregado';
                elsif v_est_cheque = 'O'  then
                  -- Verifico la duplicacion del registro
                  IF NOT p_insert THEN -- RE  DE-567 25/06/2015 aqui utiliza el parametro de control, si es FALSE entra a verificar la duplicacion.
                   prj_val_duplicacion(p_nro_caja,
                                       131,
                                       v_cod_moneda,
                                       p_nro_cheque,
                                       v_cod_respuesta,
                                       v_msj_respuesta);

                   --v_msj_respuesta := 'El cheque '||p_nro_cheque||' de la cuenta '||p_nro_cuenta||' tiene Orden de NO Pagar';
                   END IF;
                elsif v_est_cheque not in ('E','C','G') then
                   v_msj_respuesta := 'El cheque '||p_nro_cheque||' de la cuenta '||p_nro_cuenta||' con estado incorrecto.';
                end if;
            end if;
            if v_msj_respuesta is not null then
              v_cod_respuesta := '009';
            end if;
        end if;
    end if;
    ---
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
       end if;
     end if;
     
     -----Sobregiro de Ctas.
     if v_cod_respuesta = '000' and v_est_cuenta not in ('P','C','T') and v_importe is not null then
       --estado del cheque
       v_est_anterior := pac_che.FU_CON_CAM_EST_CHE(p_nro_cuenta,
                                                    p_nro_cheque,
                                                    'P',  -- quiero pagar
                                                    v_importe,
                                                    v_nro_che_inicial,
                                                    v_msj_respuesta,
                                                    v_nro_cta_certificado,
                                                    p_serie);
       v_sal_linea := fuc_obt_mto_lin_sob(nvl(v_nro_cta_certificado,p_nro_cuenta));
       -- Si es deposito en Cta. y la Libradora tiene saldo suficiente debe liberar automaticamente.-
       pag_cta.pr_ver_operacion( nvl(v_nro_cta_certificado,p_nro_cuenta),
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
                                 591);
         if pag_cta.g_ctas.cta_combinada = 'S' then
            v_sal_combinada := pag_cta.g_ctas.sal_dis_combinada;
         end if;
         
         if v_cod_tra_padre not in (219,220,222) then -- Para aduanas se mantiene el proceso actual
            if v_est_anterior != 'O' then --DE-567 19/08/2015 solo verificar si es diferente a cheque con ONP
              if ( (v_procesa = 'N' and pag_cta.g_cod_error in (25,29) and 
                   (nvl(v_sal_disponible,0) + nvl(v_sal_linea,0) + nvl(v_sal_combinada,0)) < nvl(v_importe,0))
                   or (pag_cta.g_ctas.cod_autorizacion is null and 
                      (nvl(v_sal_disponible,0) + nvl(v_sal_linea,0) + nvl(v_sal_combinada,0)) < nvl(v_importe,0))) then
                 -- problemas de saldo insuficiente (sobregira)
                 v_opc_rta    := '¿?{'||p_nro_cuenta||'}{'||v_importe||'}';
                 v_det_campos := v_det_campos ||
                                 '[' || 'OPCION' ||'~'||v_opc_rta|| ']';
                 v_cod_respuesta := v_cod_opcion; -- codigo de respuesta para levantar en caja la opcion.
                 v_msj_respuesta := 'Desea solicitar Autorizacion por Sobregiro para la Cuenta: '||nvl(v_nro_cta_certificado,p_nro_cuenta)||'?.{OPCION}'; -- entre {} el campo correspondiente al campo de opcion.
              else
                 v_opc_rta    := '__{'||p_nro_cuenta||'}{'||v_importe||'}';
                 v_det_campos := v_det_campos ||
                                 '[' || 'OPCION' ||'~'||v_opc_rta|| ']';
              end if;
            end if;
         end if;
      end if; --fin sobregiro
  end if;
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'  ')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_355;
/
