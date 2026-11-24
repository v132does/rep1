CREATE OR REPLACE FUNCTION IT.FUJ_VAL_TRANSACCION_362
 (P_NRO_OPERACION IN VARCHAR2
 ,P_NRO_CAJA IN VARCHAR2
 ,P_NRO_COMPROBANTE IN NUMBER default null --nro de comprobante manual
 ,P_NRO_CUENTA IN VARCHAR2
 )
 RETURN  LONG
 IS
Begin
    declare
  -- Datos de la transaccion
  v_cod_modulo         number(3) := 9;              -- modulo Caja
  v_cod_modalidad      number(3) := 91;             -- modalidad Caja
  v_cod_transaccion    number(4) := 362;            -- cod de transaccion
  v_cod_usuario        varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual         date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hora               varchar2(8);
  v_cod_oficina        number(3);         -- Codigo de oficina
  v_estado             number(1);         -- estado de la caja
  v_fec_caja           date;              -- fecha de la caja
  v_sal_actual         number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);      -- saldo actual de la caja en cheques
  -- Datos de la cuenta de préstamo
  v_denominacion       varchar2(100);     -- Nombre de la cuenta
  v_mto_cobrado        number(18,2);      -- Mto cobrado (no se despliega)
  v_tot_capital        number(18,2);      -- Capital (no se despliega )
  v_tot_interes        number(18,2);      -- Interés (no se despliega )
  v_tot_cap_int        number(18,2);      -- Capital + interés + int.adel (DESPLIEGA : importe )
  v_tot_int_adelantado number(18,2);      -- Interes adelantado (no despliega)
  v_tot_mora           number(18,2);      -- Mora s/capital (no despliega)
  v_tot_mora_interes   number(18,2);      -- Mora s/Interés (DESPLIEGA : Mora s/interés )
  v_tot_mora_int_adel  number(18,2);      -- Mora interés adelantado (no desp)
  v_tot_impuesto       number(18,2);      -- Total impuesto (DESPLIEGA : ley 125/91)
  v_tot_cargo          number(18,2);      -- Total cargo (DESPLIEGA : Cargo + IVA )
  v_tot_cargo_iva      number(18,2);      -- Total cargo IVA  (no desp)
  v_tot_int_descontado number(18,2);      -- Total interes descontado (no desp)
  v_tot_iva_descontado number(18,2);
  v_tot_seg_descontado number(18,2);
  v_tot_a_cobrar       number(18,2);      -- Total a cobrar (DESPLIEGA: cap+int+morai+morac+imp+cargo)
  v_tot_mora_cap       number(18,2);      -- Total mora s/capital (DESPLIEGA: v_tot_mora+v_tot_mora_int_adel)
  v_tot_punitorio      number(18,2);      -- Total monto punitorio (DESPLIEGA : Punitorio)
  v_tot_deb_cta        number(18,2);      -- Total pagado contra cuenta de ahorro
  v_tot_deb_cta_con    number(18,2);      -- Total pagado contra cuenta contable

  v_tip_cuenta         number(3);         -- modalidad cta
  v_mod_cuenta         ge_cuentas.cod_modalidad%type;
  v_cod_retencion      ge_movimientos.cod_retencion%type;
  v_fec_fin_retencion  ge_movimientos.fec_fin_retencion%type;
  v_cod_moneda         varchar2(3);       -- moneda de la cta
  v_est_cuenta         varchar2(1);       -- estado de la cuenta
  v_nro_cuota_desde    number(3);         -- nro. cuota a pagar desde
  v_nro_cuota_hasta    number(3);         -- nro. cuota a pagar hasta
  v_can_tot_cuotas     number(3);
  v_nro_documento      number(8);         -- nro. documento de la cuota

  -- Datos de salida
  v_msj_salida    long; --varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(4000) := 'OK'; -- sin errores

  -- Contenedor de la lista de valores a devolver
  v_val_posibles  varchar2(3000) := null;

  -- Datos de campos a devolver
  v_can_campos    number(3)      := 12;   -- cantidad de campos
  v_det_campos    varchar2(8000) :=       -- valores devueltos por defecto
           '[' || 'DES_CUENTA' ||'~ ]' ||
           '[' || 'NRO_CUOTA' ||'~ ]' ||
           '[' || 'TOT_CAP_INT' ||'~ ]' ||
           '[' || 'TOT_MORA_INTERES' ||'~ ]' ||
           '[' || 'TOT_MORA' ||'~ ]' ||
           '[' || 'TOT_PUNITORIO' ||'~ ]' ||
           '[' || 'TOT_IMPUESTO' ||'~ ]' ||
           '[' || 'TOT_CARGO_IVA' ||'~ ]' ||
           '[' || 'TOT_A_COBRAR' ||'~ ]' ||
           '[' || 'EFECTIVO' ||'~ ]' ||
           '[' || 'CHQ_OBCO' ||'~ ]' ||
           '[' || 'CHQ_NBCO' ||'~ ]' ;

  v_cod_tran_pend  number(4);    --- transaccion operacion pend.(efect 740 - cheq 607)
  v_monto_efectivo number(18,2) :=0; --- importe pagado operacion pendiente efectivo
  v_monto_cheque   number(18,2) :=0; --- importe pagado operacion pendiente cheque
  v_monto_cheque_n number(18,2) :=0; --- cheque cargo nuestro bco.

  v_tip_retencion  ge_movimientos.cod_retencion%type;
  
  cursor c_cobros is 
  select cod_transaccion, monto 
    from ge_movimientos 
   where cod_tra_padre = v_cod_transaccion 
     and fecha         = v_fec_actual 
     and hora          = v_hora
     and cod_usuario   = v_cod_usuario 
     and reversado     = 'N'
     and estado        = 'J';

-------------------------PROCESO PRINCIPAL-------------------------
Begin
 -- Inicializacion de la aplicacion y el modulo
 Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; End;

  if p_nro_cuenta is null then

    -- Obtengo el select de la lista de valores para el documento
    v_val_posibles  := fuj_obt_val_posibles(v_cod_transaccion,'NRO_CUENTA');

    if v_cod_respuesta = '000' then
      v_det_campos := v_det_campos ||
                      '[' ||
                      'NRO_CUENTA~X~'||
                      fuj_pro_val_posibles(v_val_posibles) ||
                      ']';
      v_can_campos := v_can_campos + 1;
    end if;

  else

    -- obtengo datos de la cuenta  --
    begin
      select denominacion, cod_modulo, cod_moneda, a.cod_modalidad
        into v_denominacion, v_tip_cuenta, v_cod_moneda, v_mod_cuenta
        from ge_cuentas a
       where a.nro_cuenta = p_nro_cuenta;

       -- Obtengo los datos de la caja --
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
      
      --verificar comprobante
      if v_cod_respuesta = '000' then
        If p_nro_comprobante is not null then
          -- Verifico la duplicacion del registro
          prj_val_duplicacion(p_nro_caja,
                              v_cod_transaccion,
                              v_cod_moneda,
                              p_nro_comprobante,
                              v_cod_respuesta,
                              v_msj_respuesta);
        End if;
      end if;

      -- Busco la cantidad de cuotas.
      if v_cod_respuesta = '000' then
        Select max(nro_cuota)
          into v_can_tot_cuotas
          from pr_cuotas
         where nro_cuenta = p_nro_cuenta
           and nro_cuota > 0;
        if v_tip_cuenta <> 6 then
          v_cod_respuesta := '003';
          v_msj_respuesta := 'ERROR: Tipo de cuenta no es de Préstamos ';
        else
          -- AQUI LA VALIDACION DE SI ES PARA RETOMAR EN CAJA
          prj_ver_pen_caja(p_nro_cuenta,
                           v_cod_transaccion,
                           v_fec_actual,
                           v_cod_usuario,
                           v_hora,
                           v_cod_tran_pend,
                           v_cod_respuesta,
                           v_msj_respuesta);

         if v_cod_respuesta = '000' then  ---- NO HAY PENDIENTE --ERROR
            v_cod_respuesta := '003';
            v_msj_respuesta := 'ERROR: No hay operaciones pendientes para esta cta.';
         else
            v_cod_respuesta := '000';
            if v_cod_tran_pend in (607, 610, 632) Then
                pag_cta.PR_OBT_RETENCION(v_fec_actual,
                                         p_nro_cuenta,
                                         v_tip_cuenta, 
                                         v_mod_cuenta, 
                                         v_cod_tran_pend, 
                                         v_cod_moneda,
                                         v_cod_retencion, 
                                         v_fec_fin_retencion);
            End IF;
            prj_obt_dat_pend(p_nro_cuenta,
                            v_nro_cuota_desde,
                            v_nro_cuota_hasta,
                            nvl(v_fec_fin_retencion,v_fec_actual),
                            v_hora,
                            v_tot_capital,
                            v_tot_interes,
                            v_tot_int_adelantado,
                            v_tot_mora,
                            v_tot_mora_interes,
                            v_tot_mora_int_adel,
                            v_tot_impuesto,
                            v_tot_cargo,
                            v_tot_cargo_iva,
                            v_tot_int_descontado,
                            v_tot_iva_descontado,
                            v_tot_seg_descontado,
                            v_tot_punitorio,
                            v_tot_deb_cta,
                            v_tot_deb_cta_con,
                            v_cod_transaccion,
                            v_cod_respuesta,
                            v_msj_respuesta);
            v_tot_cap_int  := nvl(v_tot_capital,0) +
                              nvl(v_tot_interes,0) +
                              nvl(v_tot_int_adelantado,0);
            v_tot_mora_cap := nvl(v_tot_mora,0) +
                              nvl(v_tot_mora_int_adel,0);

            v_tot_a_cobrar:= nvl(v_tot_cap_int,0) +
                           nvl(v_tot_mora_interes,0) +
                           nvl(v_tot_mora_cap,0) +
                           nvl(v_tot_punitorio,0) +
                           nvl(v_tot_impuesto,0) +
                           nvl(v_tot_cargo,0) - nvl(v_tot_iva_descontado,0) ;

            -- busca las operaciones pendientes para actualizar
            for reg in c_cobros loop
              if reg.cod_transaccion = 740 then
                 v_monto_efectivo := reg.monto;
              elsif reg.cod_transaccion in (607, 610, 632) then
                 v_monto_cheque   := reg.monto;
                 v_tip_retencion  := v_cod_retencion;
                 /*if reg.cod_transaccion = 607 then
                   v_tip_retencion := 1;
                 elsif reg.cod_transaccion = 610 then
                   v_tip_retencion := 2;
                 elsif reg.cod_transaccion = 632 then
                   v_tip_retencion := 3;
                 end if;*/
              elsif reg.cod_transaccion = 606 then
                 v_monto_cheque_n := reg.monto;
              end if;
            end loop;

              v_det_campos :=
                '[' || 'DES_CUENTA' ||'~'||v_denominacion||'~ ]' ||
                '[' || 'COD_MONEDA' ||'~'||v_cod_moneda||'~ ]' ||
                '[' || 'NRO_CUOTA' ||'~'||ltrim(to_char(v_nro_cuota_hasta))||'~ ]' ||
                '[' || 'NRO_CUOTA_DESDE' ||'~'||ltrim(to_char(v_nro_cuota_desde))||'~ ]' ||
                '[' || 'NRO_CUOTA_HASTA' ||'~'||ltrim(to_char(v_nro_cuota_hasta))||'~ ]' ||
                '[' || 'CAN_TOT_CUOTAS' ||'~'||ltrim(to_char(v_can_tot_cuotas))||'~ ]' ||
                '[' || 'TOT_CAP_INT' ||'~'||ltrim(to_char(v_tot_cap_int))||'~ ]' ||
                '[' || 'TOT_MORA_INTERES' ||'~'||ltrim(to_char(v_tot_mora_interes))||'~ ]' ||
                '[' || 'TOT_MORA' ||'~'||ltrim(to_char(v_tot_mora_cap))||'~ ]' ||
                '[' || 'TOT_PUNITORIO' ||'~'||ltrim(to_char(v_tot_punitorio))||'~ ]' ||
                '[' || 'TOT_IMPUESTO' ||'~'||ltrim(to_char(v_tot_impuesto))||'~ ]' ||
                '[' || 'TOT_CARGO_IVA' ||'~'||ltrim(to_char(v_tot_cargo))||'~ ]' ||
                '[' || 'TOT_A_COBRAR' ||'~'||ltrim(to_char(v_tot_a_cobrar))||'~ ]' ||
                '[' || 'EFECTIVO' ||'~'||ltrim(to_char(v_monto_efectivo))||'~ ]' ||
                '[' || 'CHQ_OBCO' ||'~'||ltrim(to_char(v_monto_cheque))||'~ ]' ||
                '[' || 'CHQ_NBCO' ||'~'||ltrim(to_char(v_monto_cheque_n))||'~ ]' ||
                '[' || 'CTA_AHORRO' ||'~'||ltrim(to_char(v_tot_deb_cta))||'~ ]' ||
                '[' || 'CTA_CONTAB' ||'~'||ltrim(to_char(v_tot_deb_cta_con))||'~ ]'||
                fuj_des_campo('TIP_RETEN', ltrim(to_char(v_tip_retencion)), null, 'D');
         end if;
        end if;
      end if;
    exception
       when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'Nro de cuenta no existe!';
       when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := sqlerrm;
    end;

  end if;
  --- Verificar montos a cobrar contra detallado
  if nvl(v_tot_deb_cta,0)+nvl(v_tot_deb_cta_con,0)+nvl(v_monto_efectivo,0)+nvl(v_monto_cheque,0)++nvl(v_monto_cheque_n,0)
     <> nvl(v_tot_a_cobrar,0) then
     v_cod_respuesta := '005';
     v_msj_respuesta := 'Monto a cobrar y detallar no coinciden';
  end if;
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
end ;
end;
/

