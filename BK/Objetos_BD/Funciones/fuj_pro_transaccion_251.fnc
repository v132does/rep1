CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_251 (
      p_nro_operacion in varchar2,            -- Nro de referencia de la operacion
      p_nro_caja in varchar2,                 -- Nro de Caja
      p_nro_boleta in varchar2 default null,  -- Nro de la boleta
      --p_nombre in varchar2,                 -- Nombre
      p_nro_documento in varchar2,            -- Nro de Documento
      p_nro_tarjeta   in varchar2,            -- Nro de cuenta del cliente
      --p_cod_comercio  in varchar2 default null,
      p_can_cuotas in varchar2 default null,
      p_mto_efectivo in varchar2 default null -- importe en efectivo
      )        -- Importe del deposito en cheques (plaza local)
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_tra_cargo    ge_movimientos.cod_transaccion%type:= 1779; -- Solo para pruebas
  v_cod_tas_cargo    ge_movimientos.cod_tasa%type;
  v_val_tas_cargo    ge_movimientos.val_tasa%type;
  v_val_cargo        ge_movimientos.val_tasa%type;
  v_cod_tra_impuesto ge_movimientos.cod_transaccion%type;
  v_cod_tas_impuesto ge_movimientos.cod_tasa%type;
  v_val_tas_impuesto ge_movimientos.val_tasa%type;
  v_val_impuesto     ge_movimientos.val_tasa%type; 
  v_cargo            number;
  v_total            number;
  v_sal_disponible   number;
  
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_transaccion number(4) := 251;  -- transaccion
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
  v_nro_cuenta        varchar2(15);      -- Numero de la cuenta
  v_denominacion      varchar2(200);     -- Nombre de la cuenta
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  v_tip_cuenta        number(3);         -- tipo de cuenta(modalidad)
  -- Datos de salida
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(2000) := 'Operacion Confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'C';  -- Credito para la caja (Egreso)
  v_mto_efectivo     number := nvl(to_number(p_mto_efectivo),0); -- importe del deposito en efectivo
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  v_dia_mora number := 0;
  v_can_cuotas     number := nvl(to_number(p_can_cuotas),0); -- importe del deposito en efectivo
  v_nro_boleta   number  := to_number(p_nro_boleta); --Numbero de boleta

  --para la retención de cheques
  r_gmovi                ge_movimientos%rowtype;
  v_cod_ofi_cta          ba_oficinas.cod_oficina%type;
  v_mod_tar              ge_cuentas.cod_modulo%type;
  --v_cod_comercio         varchar2(10);
  v_cod_persona          ba_personas.cod_persona%type;--CROCLIJUD-5
  v_cod_cau_judicial	   ge_causales.cod_causa%type := fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL'); 
  -- Procedimiento interno para generar movimiento y act. de control de caja
  -- C.D Fase III -- 
  v_tip_operacion   ge_mov_autorizaciones.tip_operacion%type := 'O';-- Todos Tipos Operacional
  v_est_movimiento  ge_movimientos.estado%type;
  v_nro_pedido		  ge_mov_autorizaciones.nro_pedido%type;
  
  procedure lp_gen_transaccion(p_estado varchar2)  is 
  begin
      -- Actualizo el control de caja
      if p_estado <> 'P' then -- C.D Fase III
        update cj_controles
           set sal_actual = nvl(sal_actual,0) - nvl(v_total,0), 
               tot_creditos = nvl(tot_creditos,0) + nvl(v_total,0),
               can_creditos = nvl(can_creditos,0) + 1,
               estado = 1 -- abierto
         where nro_caja = to_number(p_nro_caja)
           and cod_moneda = v_cod_moneda
           and fecha = v_fec_caja;
       end if;
      v_nro_secuencia := 0;
      if v_mto_efectivo > 0 then
        -- genero el movimiento por el efectivo
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo,
            nro_doc_referencia, estado)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 1
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            v_nro_boleta, v_nro_cuenta, v_total/*v_mto_efectivo*/,'E' /* efectivo */, v_tipo,
            p_nro_documento, p_estado);  --es debito -- C.D Fase III
      end if;
  end lp_gen_transaccion;

  function lp_obt_sal_disponible(p_nro_cuenta in varchar2)
  return number is
    v_sal_dis_return number default 0;
    begin
      select (nvl(lin_credito,0) - (nvl(sal_facturar,0) + nvl(sal_facturado,0) 
             + nvl(sal_financiado,0))) sal_disponible
        into v_sal_dis_return
        from ta_cta_tarjetas
       where nro_cuenta = p_nro_cuenta;
      return v_sal_dis_return;
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'ERROR: Nro de cuenta no existe!';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR' || sqlerrm;
    end;
  --
  procedure lp_act_can_impresion is  -- C.D.Fase III--

  begin
    update cj_movimientos c
       set c.can_impresion = nvl(c.can_impresion, 0) + 1
     where c.fecha = v_fec_actual
       and c.cod_usuario = v_cod_usuario
       and c.hora = v_hor_actual
       and c.cod_tra_padre = v_cod_transaccion;
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
  --v_sal_disponible := lp_obt_sal_disponible(
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido la moneda
 if p_nro_documento is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese Nro.de Documento del Cliente.';
 elsif p_nro_tarjeta is null then  -- valido la cuenta
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Tarjeta del cliente.';
 elsif length(p_nro_tarjeta) <> 16 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro.de Tarjeta Correcto (16 Digitos).';
/* elsif p_cod_comercio is null then  -- valido la cuenta
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese Codigo de Comercio.';*/
 elsif v_can_cuotas is null or v_can_cuotas <= 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Cantidad de Cuotas.';
 elsif v_mto_efectivo is null or v_mto_efectivo <= 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Monto del Adelanto.';
 else
    -- obtengo datos de la cuenta  ------------------------------------------
    begin
      select a.nom_embozar, c.cod_moneda, 'N', c.cod_modulo, 
             c.cod_modalidad, c.nro_cuenta, c.dia_mora, c.cod_oficina
        into v_denominacion, v_cod_moneda, v_est_cuenta, v_mod_tar, 
             v_tip_cuenta, v_nro_cuenta, v_dia_mora, v_cod_ofi_cta
        from ta_cta_tarjetas c, ta_tarjetas a
       where c.nro_cuenta = a.nro_cuenta
         and a.nro_tarjeta = p_nro_tarjeta;

        If v_nro_boleta is not null then
          -- Verifico la duplicacion del registro
          prj_val_duplicacion(p_nro_caja,
                              v_cod_transaccion,
                              v_cod_moneda,
                              v_nro_boleta,
                              v_cod_respuesta,
                              v_msj_respuesta);
        End if;
        if v_cod_respuesta = '000' then
           v_msj_respuesta := fuj_ver_impedimentos(v_nro_cuenta,
                                                   v_tip_cuenta,
                                                   v_cod_transaccion,
                                                   v_est_cuenta,
                                                  'C'); -- 'C'== CREDITO
           if v_msj_respuesta is not null then
              v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
           end if;
        end if;
        v_sal_disponible := lp_obt_sal_disponible(v_nro_cuenta);
        if v_mto_efectivo > (v_sal_disponible * 1.1) then -- saldo disponible mas 10%
          v_cod_respuesta := '004'; -- error
          v_msj_respuesta := 'ERROR: Monto supera al Saldo Disponible.';
        end if;
        dbms_output.put_line('1)Respuesta '||v_cod_respuesta);
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'ERROR: Nro de cuenta no existe!';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR' || sqlerrm;
    end;

    dbms_output.put_line('2)Respuesta '||v_cod_respuesta);

/*    if v_cod_respuesta = '000' then
       begin
         select a.val_minimo
           into v_cod_comercio
           from ba_cod_referencias a
          where a.dominio = 'COD_COMERCIO'
            and a.val_minimo = p_cod_comercio;
       exception
         when no_data_found then
           v_cod_respuesta := '002';
           v_msj_respuesta := 'ERROR: Codigo de Comercio No existe!';
         when others then
           v_cod_respuesta := '003';
           v_msj_respuesta := 'ERROR' || sqlerrm;
       end;
    end if;*/
    /** Ajuste -CROCLIJUD-5**/
   ---Verifica si el Cliente o un Vinculado a la Cuenta está inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
    v_cod_persona := fug_obt_cli_principal(v_nro_cuenta);
	  if fug_obt_inhibicion(v_cod_cau_judicial,v_cod_persona,v_nro_cuenta) Then
         v_cod_respuesta := '007';
         v_msj_respuesta := 'ERROR: Cliente Principal o Vinc. a la Cuenta con Demanda Judicial. Consulte con el asesor Jurídico';
    End If;    
    
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
       elsif v_sal_actual < v_mto_efectivo then
          v_cod_respuesta := '006'; -- error
          v_msj_respuesta := 'Caja no tiene saldo para esta Operacion';
       end if;
    end if;
    if v_cod_respuesta = '000' then
      begin
        select nro_cuenta
          into v_nro_cuenta
          from ta_tarjetas
         where nro_tarjeta = p_nro_tarjeta;
      exception
        when others then
          v_cod_respuesta := '006'; -- error
          v_msj_respuesta := 'Error al Buscar la Cuenta de la Tarjeta. '||sqlerrm;           
      end;
      --
      if v_cod_respuesta = '000' then
         prg_obt_cargos( v_cod_oficina,
                         v_nro_cuenta,
                         v_cod_moneda,
                         p_mto_efectivo,
                         5, -- Módulo Tarjeta
                         v_tip_cuenta, -- Modalidad Tarjeta
                         v_cod_tra_cargo,--Transaccion para el cobro de cargos por extraccion 
                         v_cod_tas_cargo,
                         v_val_tas_cargo,
                         v_val_cargo,
                         v_cod_tra_impuesto,
                         v_cod_tas_impuesto,
                         v_val_tas_impuesto,
                         v_val_impuesto);
         --
         v_cargo  := nvl(V_VAL_CARGO,0)+ nvl(V_VAL_IMPUESTO,0);
         v_total  := v_mto_efectivo - nvl(v_cargo,0);
       end if;
    
       -- verifico los decimales del importe en cheques
       if v_msj_respuesta is null then -- valido el efectivo
          v_msj_respuesta := fuj_val_importe(v_tipo, 'E',v_cod_moneda,v_mto_efectivo);
       end if;
       if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       else
         -- Verifico el Monto de Riesgo -- C.D Fase III
          PAG_RIE.PR_OPE_RIESGO( v_fec_actual,
                                    v_hor_actual,
                                    v_cod_usuario,
                                    v_cod_transaccion, -- transacción padre 
                                    v_cod_modulo,      -- Módulo
                                    v_cod_modalidad,   -- Modalidad
                                    v_nro_cuenta,      -- Nro_cuenta
                                    v_cod_persona,     -- Persona
                                    v_tip_operacion,   -- Tip_operacion 
                                    v_mto_efectivo,       -- Monto
                                    null,              -- Número de Documento
                                    v_cod_moneda,      -- Moneda
                                    null,              -- Cotización                       
                                    v_nro_pedido);  
                                    
             if nvl(v_nro_pedido,0) > 0 then
                v_est_movimiento := 'P';
              else
                v_est_movimiento := 'N';
             end if;
          -- Asigno el nro de caja a los movimientos
          pag_cta.pr_nro_caja(to_number(p_nro_caja));
          -- Acualizo la cuenta con el efectivo depositado
          v_nro_secuencia := 0;
          if v_mto_efectivo > 0 then
              --generar movimiento
              v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
              r_gmovi.cod_usuario     := v_cod_usuario;
              r_gmovi.hora            := v_hor_actual;
              r_gmovi.fecha           := v_fec_actual;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := v_mod_tar;
              r_gmovi.cod_modalidad   := v_tip_cuenta;
              r_gmovi.cod_oficina     := v_cod_ofi_cta;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.fec_valor       := v_fec_actual;
              r_gmovi.cod_tra_padre   := 251;
              r_gmovi.cod_mod_padre   := v_cod_modulo;--9
              r_gmovi.cod_mad_padre   := v_cod_modalidad;--91
              r_gmovi.nro_caja        := to_number(p_nro_caja);
              r_gmovi.cod_transaccion := 1251;
              r_gmovi.monto           := v_mto_efectivo;
              r_gmovi.nro_documento   := to_number(p_nro_boleta);
              --r_gmovi.nro_documento2  := to_number(p_cod_comercio);
              r_gmovi.nro_documento3  := v_can_cuotas;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'Adel.Efectivo.TC:'||p_nro_tarjeta;
              r_gmovi.referencia      := p_nro_tarjeta;
              --------------------------------------------
              -- C.D Fase III --
              --r_gmovi.estado          := 'N';
              r_gmovi.estado          := v_est_movimiento;
              --------------------------------------------
              r_gmovi.reversado       := 'N';
              r_gmovi.cod_ofi_origen  := v_cod_oficina;
              r_gmovi.cod_rubro       := NULL;
              r_gmovi.nro_cuenta      := v_nro_cuenta;
              r_gmovi.tip_mov_rubro   := NULL;
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
           if v_can_cuotas > 1 and nvl(v_val_cargo,0) <> 0 then
              -- Movimiento por Cargo.
              v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
              r_gmovi.cod_usuario     := v_cod_usuario;
              r_gmovi.hora            := v_hor_actual;
              r_gmovi.fecha           := v_fec_actual;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := v_mod_tar;
              r_gmovi.cod_modalidad   := v_tip_cuenta;
              r_gmovi.cod_oficina     := v_cod_ofi_cta;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.fec_valor       := v_fec_actual;
              r_gmovi.cod_tra_padre   := 251;
              r_gmovi.cod_mod_padre   := v_cod_modulo;
              r_gmovi.cod_mad_padre   := v_cod_modalidad;
              r_gmovi.nro_caja        := to_number(p_nro_caja);
              r_gmovi.cod_transaccion := v_cod_tra_cargo; -- 1779
              r_gmovi.monto           := v_val_cargo;
              r_gmovi.nro_documento   := to_number(p_nro_boleta);
              --r_gmovi.nro_documento2  := to_number(p_cod_comercio);
              r_gmovi.nro_documento3  := v_can_cuotas;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'Cargo por Adel.Efectivo.TC:'||p_nro_tarjeta;
              r_gmovi.referencia      := p_nro_tarjeta;
              --------------------------------------------
               -- C.D Fase III--
              --r_gmovi.estado          := 'N';
              r_gmovi.estado          := v_est_movimiento;
              --------------------------------------------
              r_gmovi.reversado       := 'N';
              r_gmovi.cod_ofi_origen  := v_cod_oficina;
              r_gmovi.cod_rubro       := NULL;
              r_gmovi.nro_cuenta      := v_nro_cuenta;
              r_gmovi.tip_mov_rubro   := NULL;
              r_gmovi.cod_tasa        := v_cod_tas_cargo;
              r_gmovi.val_tasa        := v_val_cargo;
              --
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
              --
              if nvl(v_val_impuesto,0) <> 0 then
                -- Movimiento por Impuesto.
                v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
                r_gmovi.cod_usuario     := v_cod_usuario;
                r_gmovi.hora            := v_hor_actual;
                r_gmovi.fecha           := v_fec_actual;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.cod_modulo      := v_mod_tar;--5;
                r_gmovi.cod_modalidad   := v_tip_cuenta;--v_tip_cuenta;
                r_gmovi.cod_oficina     := v_cod_ofi_cta;
                r_gmovi.cod_moneda      := v_cod_moneda;
                r_gmovi.fec_valor       := v_fec_actual;
                r_gmovi.cod_tra_padre   := 251;
                r_gmovi.cod_mod_padre   := v_cod_modulo;
                r_gmovi.cod_mad_padre   := v_cod_modalidad;
                r_gmovi.nro_caja        := to_number(p_nro_caja);
                r_gmovi.cod_transaccion := v_cod_tra_impuesto;
                r_gmovi.monto           := v_val_impuesto;
                r_gmovi.nro_documento   := to_number(p_nro_boleta);
                --r_gmovi.nro_documento2  := to_number(p_cod_comercio);
                r_gmovi.nro_documento3  := v_can_cuotas;
                r_gmovi.emi_aviso       := 'N';
                r_gmovi.concepto        := 'Impuesto por Adel.Efectivo.TC:'||p_nro_tarjeta;
                r_gmovi.referencia      := p_nro_tarjeta;
                --------------------------------------------
                  -- C.D Fase III--
                  --r_gmovi.estado          := 'N';
                r_gmovi.estado          := v_est_movimiento;
                --------------------------------------------
                r_gmovi.reversado       := 'N';
                r_gmovi.cod_ofi_origen  := v_cod_oficina;
                r_gmovi.cod_rubro       := NULL;
                r_gmovi.nro_cuenta      := v_nro_cuenta;
                r_gmovi.tip_mov_rubro   := NULL;
                r_gmovi.cod_tasa        := v_cod_tas_impuesto;
                r_gmovi.val_tasa        := v_val_tas_impuesto;
                --              
                PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
             end if;
           else
             v_total  := v_mto_efectivo;
           end if;
              -- Movimiento de Caja.
              v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
              r_gmovi.cod_usuario     := v_cod_usuario;
              r_gmovi.hora            := v_hor_actual;
              r_gmovi.fecha           := v_fec_actual;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := v_mod_tar;
              r_gmovi.cod_modalidad   := v_tip_cuenta;
              r_gmovi.cod_oficina     := v_cod_ofi_cta;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.fec_valor       := v_fec_actual;
              r_gmovi.cod_tra_padre   := 251;
              r_gmovi.cod_mod_padre   := v_cod_modulo;
              r_gmovi.cod_mad_padre   := v_cod_modalidad;
              r_gmovi.nro_caja        := to_number(p_nro_caja);
              r_gmovi.cod_transaccion := 251;
              r_gmovi.monto           := v_total;
              r_gmovi.nro_documento   := to_number(p_nro_boleta);
              --r_gmovi.nro_documento2  := to_number(p_cod_comercio);
              r_gmovi.nro_documento3  := v_can_cuotas;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'Total por Adel.Efectivo.TC:'||p_nro_tarjeta;
              r_gmovi.referencia      := p_nro_tarjeta;
              --------------------------------------------
               -- C.D Fase III--
              --r_gmovi.estado          := 'N';
              r_gmovi.estado          := v_est_movimiento;
              --------------------------------------------
              r_gmovi.reversado       := 'N';
              r_gmovi.cod_ofi_origen  := v_cod_oficina;
              r_gmovi.cod_rubro       := null;
              r_gmovi.nro_cuenta      := v_nro_cuenta;
              r_gmovi.tip_mov_rubro   := null;
              r_gmovi.cod_tasa        := null;
              r_gmovi.val_tasa        := null;
              --
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
          end if;
          -- Actualizo la cuenta con el cheque depositado plaza local sino hubo errores
          if pag_cta.g_cod_error <> 0 then
            -- actualizacion con problemas
            v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
            
            v_msj_respuesta := pag_cta.g_msj_error;
          else -- genero la transaccion en caja
             if nvl(v_nro_pedido,0) > 0 then -- C.D. Fase III
               lp_gen_transaccion('P');
             else
               lp_gen_transaccion('N'); 
             end if;
          end if;
          --
          if v_cod_respuesta = '000' then
            if nvl(v_nro_pedido,0) = 0 then -- Si se genera un Pedido de Autorización no se debe imprimir el comprobante--
              lp_act_can_impresion; -- C.D.Fase III--
              v_cod_respuesta := 'IMP';
              v_msj_respuesta := 'Operación Confirmada. Comprobante impreso.'||'~'||
                               fuj_imp_comprobante_251(p_nro_boleta, v_cod_oficina, p_nro_caja);
            else
             v_msj_respuesta := 'Se ha generado el Pedido de Autorización Nro.'||'-'|| v_nro_pedido ;  
            end if;
          end if;
      end if;
    end if;
 end if;
 

 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
 exception
    when others then
       v_cod_respuesta := '999';
       v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,SQLERRM);
       return(v_msj_salida);
end FUJ_PRO_TRANSACCION_251;
/

