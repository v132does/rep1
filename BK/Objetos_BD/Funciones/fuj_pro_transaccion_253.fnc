CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_253(
      p_nro_operacion    in varchar2,  -- Nro de referencia de la operacion
      p_nro_caja         in varchar2,  -- Nro de Caja
      p_nro_boleta       in varchar2,  -- Nro de la boleta
      p_cod_moneda       in varchar2,  -- codigo de la moneda
    --  p_mto_che_nue_bco  in varchar2,  -- Importe del ingreso en cheques cargo BBVA      
    --  p_mto_cheque       in varchar2,  -- Importe del ingreso en cheques 
    --  p_cod_retencion    in varchar2,  -- tipo de retencion     
      p_mto_efectivo     in varchar2,  -- importe en efectivo
    -- p_cod_rubro        in varchar2,  -- cod_rubro contable 
      p_concepto         in varchar2)  -- concepto de la operacion    
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_tra_padre number(4)   := 253;  -- Transación Padre
  v_cod_tra_efectivo number(4);  -- Transaccion 
  v_cod_tra_cheque number(4);  -- Transaccion   
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
  v_tipo          varchar2(01) := 'D';  -- Debito para la caja (ingreso)
  v_tip_monto     varchar2(01) := 'O';  -- Cheq. Otros Bancos 
--  v_mto_che_nue_bco    number := nvl(to_number(p_mto_che_nue_bco),0); -- importe  en cheques
--  v_mto_cheque    number := nvl(to_number(p_mto_cheque),0); -- importe  en cheques
  v_mto_efectivo  number := nvl(to_number(p_mto_efectivo),0); -- importe  en efectivo
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  --
  v_tip_caja       cj_cajas.tipo%type;
     -- C.D. Fase III--
  v_tip_operacion  ge_mov_autorizaciones.tip_operacion%type := 'O';-- Todos Tipos Operacional
  v_est_movimiento  ge_movimientos.estado%type;
  v_nro_pedido		  ge_mov_autorizaciones.nro_pedido%type;
  v_tot_monto       ge_movimientos.monto%type;
  
  v_cod_rubro       cb_rubros.cod_rubro%type ;
  v_nro_boleta      cj_movimientos.nro_documento%type;
  
  -- Registro de movimientos diarios
  R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion (p_estado varchar2) is
  begin
      -- Actualizo el control de caja
      if p_estado <> 'P' then -- C.D.Fase III
        update cj_controles 
           set --tot_che_otr_bco = nvl(tot_che_otr_bco,0) + nvl(v_mto_cheque,0), 
             --  sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_mto_cheque,0),
              -- tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(v_mto_che_nue_bco,0),
               sal_actual = nvl(sal_actual,0) + nvl(v_mto_efectivo,0),
               tot_debitos = nvl(tot_debitos,0) + nvl(v_mto_efectivo,0),
               can_debitos = nvl(can_debitos,0) + decode(v_mto_efectivo,0,0,1),             
               estado = 1 -- abierto
         where nro_caja = to_number(p_nro_caja)
           and cod_moneda = p_cod_moneda
           and fecha = v_fec_caja;
       end if;
      v_nro_secuencia := 0;   
      if v_mto_efectivo > 0 then   
        -- genero el movimiento por el ingreso en efectivo
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia, 
            cod_tra_padre, cod_mod_padre, cod_mad_padre, 
            cod_oficina, cod_moneda, nro_caja, 
            nro_documento, nro_cuenta, monto, tip_monto, tipo, cod_rubro,cod_ofi_rubro, estado) -- C.D.Fase III
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 1
            v_cod_tra_padre, v_cod_modulo, v_cod_modalidad, 
            v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
            p_nro_boleta, null, v_mto_efectivo,'E' /* efectivo */, v_tipo, v_cod_rubro,v_cod_oficina, p_estado); /* es debito */
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
 /*elsif v_mto_cheque is null or v_mto_cheque < 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Cheques.';*/
 elsif v_mto_efectivo is null or v_mto_efectivo < 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Efectivo.';
 elsif /*v_mto_cheque = 0 and */v_mto_efectivo = 0 /*and v_mto_che_nue_bco= 0*/ then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese por lo menos uno de los importes.';
 /*elsif p_cod_rubro is  null then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese Rubro contable';*/
 /*elsif nvl(p_cod_retencion,1) not in (1,2,3) then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Tipo de Retencion (1,2,3).';*/      
 else 
    -- Valido la moneda ingresada
    prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
    if p_cod_moneda = 'GS' then
       v_cod_rubro := '240402600210899' ;
    elsif p_cod_moneda = 'EUR' then
       v_cod_rubro := '240402600210817' ;
    elsif p_cod_moneda = 'USD' then
       v_cod_rubro := '240402600210805' ;
    elsif p_cod_moneda = 'BRL' then
       v_cod_rubro := '240402600210803' ;
    elsif p_cod_moneda = 'ARS' then
       v_cod_rubro := '240402600210815' ;
    end if ;
  end if;
 if v_cod_respuesta = '000' then -- sin errores  
    v_tip_caja := fuj_obt_tip_caja(p_nro_caja);
    -- Si la caja de tipo P(Prosegur) usa la transacción 1205
    if nvl(v_tip_caja,'x') = 'P' then
      if v_mto_efectivo > 0 then
        v_cod_tra_efectivo := 1690;
      end if;
      
    else
      if v_mto_efectivo > 0 then
        v_cod_tra_efectivo := 690;
      end if;
      
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
       elsif v_sal_actual > 0 then
          v_cod_respuesta := '006'; -- error
          v_msj_respuesta := 'Caja tiene saldo positivo, no puede realizar esta Operacion';
      /* else
          if v_cod_respuesta = '000' then
                begin
                    v_nro_boleta := fuj_obt_num_documento(p_nro_caja, v_cod_oficina, p_cod_moneda, v_fec_actual, v_hor_actual, v_cod_tra_padre);
                 exception
                    when others then
                         if sqlcode <= -20000 then
                            v_cod_respuesta := '015';
                            v_msj_respuesta := 'Error en Asigna Nro.Operación '||sqlerrm;
                         end if;
                 end;
            end if ;  */          
       end if;
    end if;  
    if v_cod_respuesta = '000' then
             v_msj_respuesta := fuj_val_importe(v_tipo, 'E',p_cod_moneda,v_mto_efectivo, v_cod_tra_padre);
        if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       else
          -- valido el rubro contable
          begin 
             select descripcion
               into v_descripcion
               from cb_rubros
              where imputable = 'S'
                and cod_rubro = v_cod_rubro
                and cod_moneda = p_cod_moneda ;
         exception
              when no_data_found then
                  v_cod_respuesta := '005'; -- error
                  v_msj_respuesta := 'Rubro contable no valido. Presione F9 para lista de Valores';  
              when others then
                  v_cod_respuesta := '005'; -- error
                  v_msj_respuesta := 'Rubro contable '||sqlerrm;  
          end;  
          /*if v_cod_respuesta = '000' then
             v_tot_monto := nvl(v_mto_efectivo,0) ;
             -- Verifico el Monto Riesgo. C.D.Fase III --
                PAG_RIE.PR_OPE_RIESGO( v_fec_actual,
                                       v_hor_actual,
                                       v_cod_usuario,
                                       v_cod_tra_padre, -- transacción padre 
                                       v_cod_modulo,    -- Módulo
                                       v_cod_modalidad, -- Modalidad
                                       null,            -- Nro_cuenta
                                       null,            -- Persona
                                       v_tip_operacion, -- Tip_operacion 
                                       v_tot_monto,     -- Monto Total
                                       null,            -- Número de Documento
                                       p_cod_moneda,    -- Moneda
                                       null,            -- Cotización                       
                                       v_nro_pedido); 
                 if nvl(v_nro_pedido,0) > 0 then
                    v_est_movimiento := 'P'; 
                 else
                    v_est_movimiento := 'N'; 
                 end if; 
            end  if;*/
          
          if v_cod_respuesta = '000' then
              begin
                -- Acualizo la cuenta con el efectivo 
                if v_mto_efectivo > 0 then
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
                   r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                   r_gmovi.cod_mod_padre   := v_cod_modulo;
                   r_gmovi.cod_mad_padre   := v_cod_modalidad;
                   r_gmovi.cod_transaccion := v_cod_tra_efectivo; -- 690 transaccion de efectivo
                   r_gmovi.monto           := v_mto_efectivo;
                   r_gmovi.nro_documento   := to_number(p_nro_boleta);
                   r_gmovi.cod_tasa        := null;
                   r_gmovi.val_tasa        := null;
                   r_gmovi.cotizacion      := null;
                   r_gmovi.cod_ofi_origen  := v_cod_oficina;
                   r_gmovi.emi_aviso       := 'N';
                   r_gmovi.concepto        := substr(p_concepto,1,35);
                   -- C.D.Fase III
                   r_gmovi.estado          := 'N';
                   --r_gmovi.estado          := v_est_movimiento;
                   r_gmovi.reversado       := 'N';
                   r_gmovi.nro_caja        := to_number(p_nro_caja);
                   r_gmovi.cod_rubro       := v_cod_rubro;
                   r_gmovi.tip_mov_rubro   := 'C' ; -- credito
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
            -- C.D.Fase III -- Insertar Pendiente en CJ_MOVIMIENTOS
            /*if nvl(v_nro_pedido,0) > 0 then 
               lp_gen_transaccion('P'); 
            else*/
               lp_gen_transaccion('N'); 
           -- end if;
         end if;   
      end if;   
    end if;   
 end if;
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
   if nvl(v_nro_pedido,0) = 0 then
      v_msj_respuesta := 'Operacion confirmada';
   else
       v_msj_respuesta := 'Se ha generado el Pedido de Autorización Nro.:'|| v_nro_pedido;
   end if;
 end if;
 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
end FUJ_PRO_TRANSACCION_253 ;
/

