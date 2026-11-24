CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_346 (
      p_nro_operacion in varchar2,---------------- Nro de referencia de la operacion
      p_nro_caja      in varchar2,---------------- Nro de Caja
      p_cod_ente      in varchar2,---------------- Codigo del Ente
      p_orden         in varchar2,---------------- Nro de orden
      p_fec_pago      in varchar2,---------------- Fecha de Pago al proveedor
      p_cod_moneda    in varchar2,---------------- Codigo de la Moneda
      p_mto_pago      in varchar2,---------------- Monto del Pago
      p_fec_ingreso   in varchar2,---------------- Fecha de ingreso de la factura
      p_nro_factura   in varchar2,---------------- Nro de la factura
      p_des_proveedor in varchar2)---------------- Descricpion del Proveedor
return VARCHAR2 is
	-- defino por defecto el modulo y modalidad a utilizar
	v_cod_modulo             number(3) := 9;------- Caja
	v_cod_modalidad          number(3) := 91;------ Caja
	v_cod_transaccion        number(4) := 346;----- transaccion
	v_cod_usuario            varchar2(10) := upper(user);-- Usuario
	v_rubro_contable         ge_parametros.parametro%type := fug_obt_parentes(p_cod_ente, 'COD_RUB_PPROV');
  v_cta_debito             ge_parametros.parametro%type := fug_obt_parentes(p_cod_ente, 'CTA_DEB_PPROV');
	-- Datos de la caja
	v_fec_actual             date := pag_cal.fu_obt_fec_actual(v_cod_modulo);-- Fecha de hoy
	v_hor_actual             varchar2(08) := to_char(sysdate,'HH24:MI:SS');---- Hora actual
	v_cod_oficina            number(3);------------ Codigo de oficina
	v_estado                 number(1);------------ estado de la caja
	v_fec_caja               date;----------------- Fecha de la caja
	v_sal_actual             number(18,2);--------- Saldo actual de la caja en efectivo
	v_sal_cheques            number(18,2);--------- Saldo actual de la caja en cheques
	-- Datos de salida
	v_msj_salida             varchar2(8000);------- Mensaje final retornado
	v_cod_respuesta          varchar2(03) := '000';-- Sin errores
	v_msj_respuesta          varchar2(1000) := 'Operacion Confirmada';-- Sin errores
	-- datos de la operacion convertidos
	v_tipo                   varchar2(01) := 'C';-- Credito para la caja (egreso)
	v_cdmoneda               varchar2(3);---------- Moneda del Rubro
	v_nro_secuencia          number(3) := 0;------- Secuencia del mov.
  -- Variables de la Cuenta
  v_cod_mod_cta            ge_cuentas.cod_modulo%type;
  v_cod_mad_cta            ge_cuentas.cod_modalidad%type;
  v_cod_mon_cta            ge_cuentas.cod_moneda%type;
  v_cod_ofi_cta            ge_cuentas.cod_oficina%type;
  v_sal_disponible         ge_movimientos.monto%type;
  v_procesa                varchar2(1);
  v_est_cta                varchar2(1);
  v_monto_retencion        ge_ret_proveedores.monto_retencion%type;
  v_proveedor              ge_entes.cod_ente%type;
  v_nro_factura            ge_pag_proveedores.nro_factura%type;
  v_referencia             ge_pag_proveedores.referencia%type;
  v_cod_compra             pv_compras.cod_compra%type;
	-- Registro de movimientos diarios
	R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
	-- Procedimiento interno para generar movimiento y act. de control de caja
	procedure lp_gen_transaccion  is
	begin
		-- Actualizo el control de caja
		update cj_controles
			set sal_actual = nvl(sal_actual,0) - nvl(p_mto_pago,0),
			tot_creditos = nvl(tot_creditos,0) + nvl(p_mto_pago,0),
			can_creditos = nvl(can_creditos,0) + decode(p_mto_pago,0,0,1),
			estado = 1 -- abierto
		where nro_caja = to_number(p_nro_caja)
			and cod_moneda = p_cod_moneda
			and fecha = v_fec_caja;
		v_nro_secuencia := 0;
		-- genero el movimiento por el egreso en efectivo
		v_nro_secuencia := v_nro_secuencia + 1;
		insert into cj_movimientos
			(fecha, hora, cod_usuario, nro_secuencia,
			cod_tra_padre, cod_mod_padre, cod_mad_padre,
			cod_oficina, cod_moneda, nro_caja,
			nro_documento, nro_cuenta, monto, tip_monto, tipo, cod_rubro,cod_ofi_rubro)
		values
			(v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 1
			v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
			v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
			/*CRO-FACPOD-04/11/2014; Se cambia la variable porque debe genera diferencia entre 
			registros de GE_MOVIMIENTOS Y CJ_MOVIMEINTOS, actualmente existe esta incidencia en 
			produccion, nos vimos obligados a cambiar esto y solucionar de paso la inciencia ya 
			que en la variable P_NRO_OPERACION, de ahora en adelante se va recibir la respuesta 
			de FACPOD para estas transacciones*/
			p_cod_ente, null, p_mto_pago,'E' /* efectivo */, v_tipo, v_rubro_contable,v_cod_oficina); /* es credito */
	end lp_gen_transaccion;
  --
begin
	-- Inicializacion de la aplicacion y el modulo
	begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=v_cod_modulo; end;
	-- Valido la moneda
	if p_cod_ente is null then
		v_cod_respuesta := '001'; -- error
		v_msj_respuesta := 'ERROR: Ingrese el Codigo de Ente.';
  elsif p_orden is null then
		v_cod_respuesta := '002'; -- error
		v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
	elsif p_cod_moneda is null then
		v_cod_respuesta := '003'; -- error
		v_msj_respuesta := 'ERROR: Ingrese la Moneda de la Operacion.';
	elsif p_mto_pago is null or p_mto_pago < 0 then
		v_cod_respuesta := '004'; -- error
		v_msj_respuesta := 'ERROR: Ingrese el importe en Cheques.';
	elsif v_rubro_contable is not null and v_cta_debito is not null then
		v_cod_respuesta := '006'; -- error
		v_msj_respuesta := 'ERROR: Tiene definido Rubro Contable y Cta. Debito.';  
  else
		-- Valido la moneda ingresada
		prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
	end if;
	if v_cod_respuesta = '000' then -- sin errores
		if v_rubro_contable is null and v_cta_debito is null then
		  begin
        select nro_cta_debito
          into v_cta_debito
          from ge_pag_proveedores p
         where p.nro_orden = p_orden
            and p.cod_ente = p_cod_ente
            and p.cod_moneda = p_cod_moneda; ---KF 
      exception
        when others then
          v_cod_respuesta := '007'; -- error
          v_msj_respuesta := 'ERROR: Al Buscar la Orden de Pago. '||sqlerrm; 
      end;
      if  v_cod_respuesta = '000' and v_cta_debito is null then
        v_cod_respuesta := '008'; -- error
        v_msj_respuesta := 'ERROR: La Operacion no tiene Definida una Cta Debito. ';
      end if;
    end if;
    -- Verifico la duplicacion del registro
		prj_val_duplicacion(p_nro_caja,
		v_cod_transaccion,
		p_cod_moneda,
		p_nro_operacion,
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
			-- verifico los decimales del importe en cheques
			v_msj_respuesta := fuj_val_importe(v_tipo, 'E',p_cod_moneda,p_mto_pago);
		end if;
		if v_cod_respuesta = '000' then
			begin
        
        ---KF          
         --- Para obtener los Datos de la Retencion KF
        
        begin
         select  a.cod_proveedor, a.nro_factura, a.referencia, a.cod_compra
          into v_proveedor, v_nro_factura, v_referencia, v_cod_compra
            from GV_QRY_PAG_PROVEEDORES a
          where a.nro_orden= p_orden 
            and a.cod_empresa = p_cod_ente 
            and a.cod_moneda = p_cod_moneda; 
        exception
          when others then 
              v_proveedor := null;
              v_nro_factura := null;
              v_referencia := null;
        end ;    
         ---       
        if v_proveedor is not null and v_nro_factura is not null and v_referencia is not null then 
           PAG_PRV.PR_GEN_RETENCION(p_cod_ente, v_proveedor, v_nro_factura,	v_fec_actual, v_procesa, v_monto_retencion);      
        end if;          
        if v_procesa = 'N' then
           v_monto_retencion := 0;
        end if;
         
         -- Inserta el Movimiento de la Retencion KF
          if NVL(v_monto_retencion,0) > 0 then
     	
               v_nro_secuencia         := v_nro_secuencia + 1;
                       	     
               r_gmovi.cod_transaccion := 2903;
               r_gmovi.cod_modulo      := 28;  
               r_gmovi.cod_modalidad   := 281; 
               r_gmovi.cod_tra_padre   := v_cod_transaccion;
               r_gmovi.cod_mod_padre   := v_cod_modulo;
               r_gmovi.cod_mad_padre   := v_cod_modalidad;
               r_gmovi.monto           := v_monto_retencion; 
               r_gmovi.cod_moneda      := p_cod_moneda;
               --
               r_gmovi.nro_cuenta      := null; -- debe estar nulo para la retencion
               r_gmovi.cod_oficina     := v_cod_oficina;
               r_gmovi.cod_usuario     := v_cod_usuario;
               r_gmovi.hora            := v_hor_actual;
               r_gmovi.fecha           := v_fec_actual;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.fec_valor       := v_fec_actual;
               r_gmovi.nro_documento   := to_number(p_orden);
               r_gmovi.nro_documento2  := v_referencia;
               r_gmovi.nro_documento3  := p_cod_ente;
               r_gmovi.cod_tasa        := null;
               r_gmovi.val_tasa        := null;
               r_gmovi.cotizacion      := null;
               r_gmovi.emi_aviso       := 'N';
               r_gmovi.cod_ofi_origen  := v_cod_oficina;
               r_gmovi.concepto        := 'Rentenciones IVA'||p_cod_ente; 
               r_gmovi.estado          := 'N';
               r_gmovi.est_cuenta      := 'N';
               r_gmovi.reversado       := 'N';
               r_gmovi.emi_aviso       := 'N';
               --
               r_gmovi.nro_caja        := null;
               r_gmovi.cod_rubro       := null; 
               r_gmovi.tip_mov_rubro   := null;  
        	
               --
        	     PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,'N'); 
               -- inserta en ge_ret_proveedores es para la retencion  
	       end if;     
          
        -- Fin de Mov de Retencion
        ---
         
				-- Acualizo la cuenta con el efectivo
				if p_mto_pago > 0 then
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
					r_gmovi.cod_transaccion := 346; -- transaccion de efectivo
					r_gmovi.monto           := p_mto_pago - nvl(v_monto_retencion,0); -- Agregado Monto de Retencion
					r_gmovi.nro_documento   := p_cod_ente;--ente
                                        r_gmovi.nro_documento2  := to_number(p_orden);--orden de pago
					r_gmovi.cod_tasa        := null;
					r_gmovi.val_tasa        := null;
					r_gmovi.cotizacion      := null;
					r_gmovi.cod_ofi_origen  := v_cod_oficina;
					r_gmovi.emi_aviso       := 'N';
					r_gmovi.concepto        := 'Orden '||p_orden||' Ente '||p_cod_ente;
					r_gmovi.estado          := 'N';
					r_gmovi.reversado       := 'N';
					r_gmovi.nro_caja        := to_number(p_nro_caja);
					r_gmovi.cod_rubro       := null;
					r_gmovi.tip_mov_rubro   := null;
					PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
				end if;
				--
				if v_cod_respuesta = '000' then
					v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
					--
          if v_rubro_contable is not null then
            -- debitar la cuenta contable 
            begin
               select c.cod_moneda
                 into v_cdmoneda
                 from cb_rubros c
                where c.cod_rubro = v_rubro_contable;
            exception
               when no_data_found then
                  v_cod_respuesta := '005';
                  v_msj_respuesta := 'Rubro contable no posee moneda';
            end;
            --
            if v_cod_respuesta = '000' then
              --
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.nro_cuenta      := null; 
              r_gmovi.cod_oficina     := v_cod_oficina;
              --
              r_gmovi.cod_transaccion := null;
              r_gmovi.cod_modulo      := v_cod_modulo;
              r_gmovi.cod_modalidad   := v_cod_modalidad;
              --
              r_gmovi.cod_tra_padre   := v_cod_transaccion;
              r_gmovi.cod_mod_padre   := v_cod_modulo;
              r_gmovi.cod_mad_padre   := v_cod_modalidad;
              --
              r_gmovi.monto           := p_mto_pago;
              r_gmovi.cod_moneda      := v_cdmoneda;
              --
              r_gmovi.cod_usuario     := user;
              r_gmovi.hora            := v_hor_actual;
              r_gmovi.fecha           := v_fec_actual;
              r_gmovi.fec_valor       := v_fec_actual;
              r_gmovi.nro_documento   := p_cod_ente;--ente
              r_gmovi.nro_documento2  := p_orden;--orden de pago
              r_gmovi.cod_tasa        := null;
              r_gmovi.val_tasa        := null;
              r_gmovi.cotizacion      := null;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.cod_ofi_origen  := v_cod_oficina;
              r_gmovi.concepto        := 'Orden '||p_orden||' Ente '||p_cod_ente;
              r_gmovi.estado          := 'N';
              r_gmovi.est_cuenta      := 'N';
              r_gmovi.reversado       := 'N';
              r_gmovi.emi_aviso       := 'N';
              --
 					    r_gmovi.nro_caja        := to_number(p_nro_caja);
              r_gmovi.cod_rubro       := v_rubro_contable;
              r_gmovi.tip_mov_rubro   := 'D'; -- Debito
              --
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,'N');
            end if;
          elsif v_cta_debito is not null then
            -- Debitar de la Cuenta
            begin
              select cod_modulo, cod_modalidad, cod_moneda, cod_oficina
                into v_cod_mod_cta, v_cod_mad_cta, v_cod_mon_cta, v_cod_ofi_cta
                from ge_cuentas
               where nro_cuenta = v_cta_debito;
            exception
              when no_data_found then
                v_cod_respuesta := '006';
                v_msj_respuesta := 'Cuenta Nro. '||v_cta_debito||' no existe o no esta Activa.';
              when others then
                v_cod_respuesta := '006';
                v_msj_respuesta := 'Error al buscar la Cta. '||v_cta_debito;
            end;
            --
            if v_cod_respuesta = '000' then
               --
               if v_cod_respuesta = '000' then
                 pag_cta.pr_nro_caja(p_nro_caja);
                 pag_cta.pr_set_nro_documento2(p_orden);
                 -- debitar a la cuenta de debito 
                 pag_cta.pr_act_operacion(v_cta_debito,
                            v_hor_actual,
                            'D',
                            v_cod_mon_cta,
                            p_mto_pago,
                            v_cod_transaccion,--COD_TRA_PADRE 
                            503,    -- COD_TRA_HIJO 
                            p_cod_ente, 
                            null, --COTIZACION
                            v_cod_oficina,    --cod_ofi_origen
                            v_cod_modulo,    --cod_mod_padre
                            v_cod_modalidad, --cod_mad_padre
                            null, --cod_tasa
                            null, --val_tasa
                            'Debito x pago a proveedores',
                            'S', --emi_aviso
                            v_nro_secuencia,
                            v_fec_actual);
          	    						
                 if pag_cta.fu_obt_cod_error() <> 0 then
                   v_cod_respuesta := '007';
                   v_msj_respuesta := pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error();
                 end if;
               end if;
              --
            end if;
          end if;
				end if;
			exception
				when others then
				-- hubo error en la insercion de registros ge_movimientos
				v_msj_respuesta := sqlerrm;
				v_cod_respuesta := '007';
			end;
		end if;
    --
		if v_cod_respuesta = '000' then
			-- no hubo problemas hasta aqui, genero la transaccion en caja
			lp_gen_transaccion();
		end if;
	end if;
	--
  if v_cod_respuesta = '000' then
    update ge_pag_proveedores
       set estado        = 'N',
           fec_pago      = v_fec_actual,
           usu_insercion = user,
           cod_oficina   = v_cod_oficina
    where nro_orden   = p_orden
      and cod_ente    = p_cod_ente
      and nro_factura = p_nro_factura;
    --
    if sql%notfound then
      v_msj_respuesta := 'Error al actualizar GE_PAG_PROVEEDORES !!!';
      v_cod_respuesta := '008';
    end if;
    --actualizamos el estado de la factura
    update pv_compras
       set fec_pago = v_fec_actual,
           ind_pagado = 'S',
           estado    = 'P'
     where nro_factura = p_nro_factura
       and cod_ent_proveedor = v_proveedor
       and cod_compra= v_cod_compra;     
     --
    if sql%notfound then
      v_msj_respuesta := 'Error al actualizar PV_COMPRAS !!!';
      v_cod_respuesta := '009';
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
end FUJ_PRO_TRANSACCION_346;
/

