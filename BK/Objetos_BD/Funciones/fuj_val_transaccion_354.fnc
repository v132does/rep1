CREATE OR REPLACE FUNCTION IT."FUJ_VAL_TRANSACCION_354" (
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_cheque in varchar2,      -- Nro de cheque 
      p_nro_cuenta in varchar2  default null, -- Nro de cuenta del cliente 
      p_imp_cheque in varchar2  default null,         -- Importe de la extraccion
      p_opcion  in varchar2 default NULL)
return VARCHAR2 is
  -- Datos de la transaccion
  v_cod_modulo number(3)      := 9;      -- Caja
  v_cod_modalidad number(3)   := 91;     -- Caja
  v_cod_transaccion number(4) := 354;    -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);     -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_nro_cuenta        varchar2(20);      -- contiene el nro de cuenta
  v_denominacion      varchar2(200);     -- Nombre de la cuenta
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  v_tip_cuenta        number(3);         -- tipo de cuenta(modalidad)
  v_est_cheque        varchar2(01);      -- estado del cheque  
  v_nro_cheque        number(8);         -- para contener el nro de cheque
  -- Datos de salida
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(100) := 'OK'; -- sin errores
  -- Datos de campos a devolver
  v_can_campos    number(3) := 2;        -- cantidad de campos
  v_det_campos    varchar2(4000) :=      -- valores devueltos por defecto
           '[' || 'DES_CUENTA' ||'~ ]' || 
           '[' || 'COD_MONEDA' ||'~ ]'; 
   /*CROCLIJUD-5*/
  v_cod_persona        ba_personas.cod_persona%type;
  v_cod_cau_judicial	 ge_causales.cod_causa%type := fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL'); 
  --Cheques Multiples
  v_che_multiple   VARCHAR2(1):= 'N';  
  --Rechazo automatico
  v_opcion         varchar2(10);
  v_opc_rta        varchar2(200);
  v_cod_opcion     ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAJ_COD_OPC');                                 
  v_cod_cus_opcion ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAJ_COD_OPC_CUSTOM'); 
  v_rec_aut         varchar2(1) := 'N'; 
  v_cod_cau_rechazo varchar2(10);
  v_des_cau_rechazo varchar2(100);
  v_importe         NUMBER;
  --Sobregiro de Cta.
  v_nro_che_inicial   number(10);        -- nro inicial del cheque
  v_est_anterior      varchar2(1);       -- estado anterior del cheque
  v_nro_cta_certificado varchar2(20) := null;      -- numero del cta certificacion
  v_cod_mod_cuenta  number(6);
  v_cod_mad_cuenta  number(6);
  v_nvo_estado      varchar2(1);
  v_sal_disponible  number;
  v_procesa         varchar2(1);   
begin
 -- Valido la moneda 
 if p_nro_cheque is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Cheque a pagar.';
 else
   if length(p_nro_cheque) > 8 then
       -- se leyo directamente el cheque a traves de la lectora
       v_can_campos := 4;        -- cantidad de campos
       -- formato: "C 2800E016101070079E07961910A"
       --          "C 1700E000700213425E04866772A"
       if  substr(p_nro_cheque,3,2) <> substr(pag_gen.fu_obt_cod_entidad,3,2) then
           v_cod_respuesta := '002'; -- error
           v_msj_respuesta := 'ERROR: Cheque no pertenece al Banco. ';
           v_det_campos := '[' || 'NRO_CHEQUE' ||'~ ]'||
                           '[' || 'NRO_CUENTA' ||'~ ]'||
                           '[' || 'DES_CUENTA' ||'~ ]' || 
                           '[' || 'COD_MONEDA' ||'~ ]';           
       else
           v_nro_cuenta := to_number(substr(p_nro_cheque,13,7)); -- tomo el nro de cuenta
           v_nro_cheque := substr(p_nro_cheque,21,8); -- tomo el nro de cheque
           v_det_campos := '[' || 'NRO_CHEQUE' ||'~'||ltrim(to_char(v_nro_cheque))|| ']' ||     -- valores devueltos por defecto
                           '[' || 'NRO_CUENTA' ||'~'||v_nro_cuenta||']';
       end if;    
   --elsif p_nro_cuenta is null then
   --    v_cod_respuesta := '002'; -- error
   --    v_msj_respuesta := 'ERROR: Ingrese la Cuenta Corriente del cliente.';
   else
       -- asigno directamente los datos de parametros, es un ingreso manual
       v_nro_cheque := p_nro_cheque;
       v_nro_cuenta := p_nro_cuenta;    
   end if;   
 end if;
 ---
 IF p_imp_cheque IS NOT NULL THEN
   v_importe := to_number(p_imp_cheque);
 END IF;
 v_can_campos := v_can_campos + 1;
 v_det_campos := v_det_campos ||'[' || 'IMP_CHEQUE' ||'~'||nvl(v_importe,p_imp_cheque)|| ']';
 ---
  if v_nro_cuenta is not null then  -- valido la cuenta si es migrada
     v_msj_respuesta := fug_obt_nro_cta_bt(v_nro_cuenta);
     if v_msj_respuesta is not null then
        v_cod_respuesta := '012'; -- error
     end if;
  end if;
 -- sino tiene errores
 if v_cod_respuesta = '000' and v_nro_cuenta is not null then   
    -- obtengo datos de la cuenta  ------------------------------------------
    begin
      select substr(replace(denominacion,'~','N'),1,50), cod_moneda, estado, cod_modalidad
        into v_denominacion, v_cod_moneda, v_est_cuenta, v_tip_cuenta
        from ge_cuentas a
       where a.nro_cuenta = v_nro_cuenta;
      if v_tip_cuenta not in (41,42,43,44,45) then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Tipo de cuenta no permite pago de Cheques';  
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
                                v_nro_cheque,
                                v_cod_respuesta,
                                v_msj_respuesta);
          END IF;     
        /*if v_cod_respuesta = '000' then         
           v_msj_respuesta := fuj_ver_impedimentos(v_nro_cuenta,
                                                   v_tip_cuenta,
                                                   v_cod_transaccion,
                                                   v_est_cuenta,
                                                  'D'); -- 'D'== debito en cuenta
           if v_msj_respuesta is not null then
              v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
           end if;
        end if;*/  
      end if;
      if v_cod_respuesta = '000' then
       ---Verifica si el Cliente o un Vinculado a la Cuenta está inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
        v_cod_persona := fug_obt_cli_principal(p_nro_cuenta);
        if fug_obt_inhibicion(v_cod_cau_judicial,v_cod_persona,p_nro_cuenta) Then
          v_cod_respuesta := '003';
          v_msj_respuesta := 'ERROR: Cliente Principal. o Vinc. a la Cuenta con Demanda Judicial.Consulte con el asesor Jurídico' ;
        End If;
      end if;
      if v_cod_respuesta = '000' then -- sino hubo problemas se arma los datos de la cuenta
        v_det_campos := v_det_campos ||
                        '[' || 'DES_CUENTA' ||'~'||v_denominacion|| ']' || 
                        '[' || 'COD_MONEDA' ||'~'||v_cod_moneda|| ']';
      end if;
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'ERROR: Nro de cuenta '||v_nro_cuenta||' no existe!';  
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := sqlerrm;
    end;
    -- se extrae la opcion SI/NO seleccionada
    v_opcion := substr(p_opcion,1,2);   
    if v_cod_respuesta = '000' THEN -- sino hubo errores veo el cheque
        v_est_cheque := pac_che.fu_obt_est_che(v_nro_cuenta,
                                              v_nro_cheque,
                                              v_msj_respuesta);                                    
        -- verifico el estado del cheque
        if v_msj_respuesta is null THEN
            if v_est_cheque = 'A' then
      	     	 v_msj_respuesta := 'El cheque '||v_nro_cheque||' de la cuenta '||v_nro_cuenta||' ha sido anulado';
            elsif v_est_cheque = 'P' then
               v_msj_respuesta := 'El cheque '||v_nro_cheque||' de la cuenta '||v_nro_cuenta||' ya fue pagado';
            elsif v_est_cheque = 'S' then
               v_msj_respuesta := 'El cheque '||v_nro_cheque||' de la cuenta '||v_nro_cuenta||' no se ha Entregado';
            elsif v_est_cheque = 'O'  THEN
               v_msj_respuesta := 'El cheque '||v_nro_cheque||' de la cuenta '||v_nro_cuenta||' tiene Orden de NO Pagar';
            elsif v_est_cheque not in ('E','C','G') then
               v_msj_respuesta := 'El cheque '||v_nro_cheque||' de la cuenta '||v_nro_cuenta||' con estado incorrecto.';
            end if;
            ----Rechazo Automatico
            IF nvl(fug_obt_pardinamico('CC_ACT_REC_AUT'),'N') = 'S' AND
               (v_est_cheque = 'O' OR  v_est_cuenta in ('P','C','T')) THEN
              --ver rechazo automatico
              PRC_VER_CHE_REC_AUT(v_nro_cuenta, v_nro_cheque,v_est_cuenta, v_rec_aut,v_cod_cau_rechazo,v_des_cau_rechazo);
              if v_rec_aut = 'S' AND
                 v_importe IS NOT NULL then
                 v_opc_rta := '¿?{'||p_nro_cuenta||'}{'||v_importe||'}';
                 v_det_campos := v_det_campos ||
                  '[' || 'OPCION' ||'~'||v_opc_rta|| ']';
                 v_cod_respuesta := v_cod_opcion; -- codigo de respuesta para levantar en caja la opcion.
                 IF v_est_cheque = 'O' THEN
                   v_msj_respuesta := 'El cheque tiene Orden de NO Pagar. Desea rechazar de Forma automática?.{OPCION}'; -- entre {} el campo correspondiente al campo de opcion.
                 ELSIF v_est_cuenta in ('P','C') THEN
                   v_msj_respuesta := 'Cuenta Cancelada. Desea rechazar el cheque de Forma automática?.{OPCION}'; -- entre {} el campo correspondiente al campo de opcion.
                 ELSIF v_est_cuenta in ('T') THEN
                   IF fuc_ver_inh_che_devueltos(p_nro_cuenta) = 'S' THEN
                     v_msj_respuesta := 'Cuenta Bloqueada. Desea rechazar el cheque de Forma automática?.{OPCION}'; -- entre {} el campo correspondiente al campo de opcion.
                   ELSE --no cumple condicion de personas inhibidas
                     v_rec_aut := 'N';
                   END IF;
                 END IF;  
               else
                 v_opc_rta := '__{'||p_nro_cuenta||'}{'||v_importe||'}';
                 v_det_campos := v_det_campos ||
                  '[' || 'OPCION' ||'~'||v_opc_rta|| ']';
               end if;  
            END IF;----
            
        end if;
        if v_msj_respuesta is not null AND v_rec_aut <> 'S'then
          v_cod_respuesta := '009';  
        end if;
        
        if v_cod_respuesta = '000' then         
           v_msj_respuesta := fuj_ver_impedimentos(v_nro_cuenta,
                                                   v_tip_cuenta,
                                                   v_cod_transaccion,
                                                   v_est_cuenta,
                                                  'D'); -- 'D'== debito en cuenta
           if v_msj_respuesta is not null AND v_rec_aut <> 'S' then
              v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
           end if;
        end if;   
    end if;
    
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
    ---Verifica Autorizacion por Sobregiro
    if v_cod_respuesta = '000' and v_importe is not null then
       --validar el cheque
       v_est_anterior := pac_che.FU_CON_CAM_EST_CHE(p_nro_cuenta,
                                                    p_nro_cheque,
                                                    'P',  -- quiero pagar-- 
                                                    v_importe,
                                                    v_nro_che_inicial,
                                                    v_msj_respuesta,
                                                    v_nro_cta_certificado);
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
           -- problemas de saldo insuficiente (sobregira)
           v_opc_rta := '¿?{'||p_nro_cuenta||'}{'||v_importe||'}';
           v_det_campos := v_det_campos ||
                           '[' || 'OPCION' ||'~'||v_opc_rta|| ']';
           v_cod_respuesta := v_cod_opcion; -- codigo de respuesta para levantar en caja la opcion.
           v_msj_respuesta := 'Desea solicitar Autorizacion por Sobregiro para la Cuenta: '||nvl(v_nro_cta_certificado,p_nro_cuenta)||'?.{OPCION}'; -- entre {} el campo correspondiente al campo de opcion.
        end if;
    end if;      
  end if;         
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  if v_cod_respuesta = '000' and v_nro_cuenta is not null then
     -- dejo en el campo de importe
     v_msj_salida := v_msj_salida||'5'; -- indicador del campo importe
  end if;                     
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_354;
/
