CREATE OR REPLACE PROCEDURE IT.PRA_CAN_AHO_PLAZO
/*Proceso que calcula el monto por cancelación anticipada de Ahorro Plazo Fijo Digital y CDA*/
(p_nro_cuenta  cc_cta_corrientes.nro_cuenta%TYPE,
 p_mto_cargo       OUT ge_movimientos.monto%type,
 p_imp_cargo       OUT ge_movimientos.monto%type)
 IS
v_mto_plazo                ah_cta_plazos.capital%type;
v_ini_plazo                ah_cta_plazos.fec_apertura%type;
v_vto_plazo                ah_cta_plazos.fec_vencimiento%type;
v_can_dia_plazo            number;
v_tasa                     number;
v_cod_tas_cta              ge_tasas.cod_tasa%type;
v_aux_tasa                 ge_tas_fechas.val_tasa%type;
v_fec_cancelacion          ah_cta_plazos.fec_vencimiento%type;
v_dia_transcurrido         number;
v_dia_vencer               number;
v_enc_bcp                  number;
v_enc_leg_exigido          ge_movimientos.monto%type;
v_tas_act_dia_trans        number;
v_tas_pas_dia_vencer       number;
v_gas_enc_legal            ge_movimientos.monto%type;
v_cos_financiero           ge_movimientos.monto%type;
v_mto_minimo               ge_movimientos.monto%type;
v_est_cuenta               ah_cta_plazos.estado%type;
v_cod_modulo               ah_cta_plazos.cod_modulo%type;
v_cod_modalidad            ah_cta_plazos.cod_modalidad%type;
v_cod_moneda               ah_cta_plazos.cod_moneda%type;
v_cod_tas_cancelacion      number:= fug_obt_pardinamico('COD_TAS_MTO_MIN_CANCELACION'); --Tasa donde se guarda el monto minimo p/ cancelación.
v_val_min_cargo            ge_tas_fechas.val_minimo%type;
v_cod_tas_encaje_bcp       number := fug_obt_pardinamico('COD_TAS_ENC_LEG_ESPECIAL');--Tasa donde se almacena el % de provision de encaje legal especial BCP.
v_por_enc_bcp              ge_tas_fechas.val_tasa%type;
v_redondeo                 number;
v_monto                    ge_movimientos.monto%type;    
v_tip_capitalizacion       ah_cta_certificados.tip_capitalizacion%type;
v_por_impuesto             number;  
Begin 

    --Obtener modulo Y modalidad de la cuenta
         Begin
            select g.cod_modulo, g.cod_modalidad, g.estado
              into v_cod_modulo, v_cod_modalidad, v_est_cuenta
              from ge_cuentas g
             where g.nro_cuenta = p_nro_cuenta;
         Exception
            When NO_DATA_FOUND Then
               raise_application_error(-20000, 'Error: Cuenta Inexistente!!!');
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error Obt.Cuenta ' || SQLERRM);
         End;
    --Valida Estado Normal de la Cta.     
    If v_est_cuenta <> 'N' then 
       raise_application_error(-20000, 'CTA: '||p_nro_cuenta||' ESTADO INVALIDO!!!');
    End If;     
    
    --Fecha de Cancelación
    v_fec_cancelacion:= pag_cal.FU_OBT_FEC_ACTUAL(v_cod_modulo);
    
    --Porcentaje IVA
    v_por_impuesto := fug_obt_val_tasa(null,null,
                              null,null,null,null,
                              'N',323,null,v_fec_cancelacion);
    If v_cod_modulo = 3 and v_cod_modalidad = 37 then 
        --Obtener datos de la Cta Plazo Fijo. 
         Begin
           Select c.capital,c.fec_apertura,
                   c.fec_vencimiento,c.estado,
                   c.cod_moneda,c.val_tasa,
                  (c.fec_vencimiento - c.fec_apertura),
                  (v_fec_cancelacion - c.fec_apertura),
                  (c.fec_vencimiento - v_fec_cancelacion)
           Into  v_mto_plazo,v_ini_plazo,
                 v_vto_plazo,v_est_cuenta,
                 v_cod_moneda,v_tasa,
                 v_can_dia_plazo,v_dia_transcurrido,v_dia_vencer
           From ah_cta_plazos c
           Where c.nro_cuenta = p_nro_cuenta;
           Exception
             When no_data_found then
                RAISE_APPLICATION_ERROR(-20000,'Cuenta inexistente');
             When others then
                RAISE_APPLICATION_ERROR(-20000,'Cuenta invalida');
         End;
     Else IF v_cod_modulo = 3 and v_cod_modalidad = 33 then
           --Obtener datos de la Cta CDA.
           Begin
               Select c.capital,c.fec_apertura,
                      c.fec_vencimiento,c.estado,
                      c.cod_moneda,c.cod_tasa,
                      (c.fec_vencimiento - c.fec_apertura),
                      (v_fec_cancelacion - c.fec_apertura),
                      (c.fec_vencimiento - v_fec_cancelacion),
                      c.tip_capitalizacion
               Into  v_mto_plazo,v_ini_plazo,
                     v_vto_plazo,v_est_cuenta,
                     v_cod_moneda,v_cod_tas_cta,
                     v_can_dia_plazo,v_dia_transcurrido,v_dia_vencer,
                     v_tip_capitalizacion
               From ah_cta_certificados c
               Where c.nro_cuenta = p_nro_cuenta;
               Exception
                 When no_data_found then
                    RAISE_APPLICATION_ERROR(-20000,'Cuenta inexistente');
                 When others then
                    RAISE_APPLICATION_ERROR(-20000,'Cuenta invalida');
           End;
           -- Recuperar Tasa del CDA
           v_tasa:= fug_obt_val_tas_aplicada(p_nro_cuenta);
     End If;
     End If;
    --Redondeo
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo,v_cod_modalidad,v_cod_moneda);
    
    --Auxiliar Tasa p/ obtener montos minimos
    v_aux_tasa:= fug_obt_val_tasa(v_cod_modulo,null,
                              null,null,v_cod_moneda,null,
                              'N',v_cod_tas_cancelacion,null,v_fec_cancelacion);
    --Valor Minimo
    v_val_min_cargo := pag_gen.FU_OBT_VAL_MINIMO;
    
    --Encaje BCP %
    v_por_enc_bcp:=fug_obt_val_tasa(v_cod_modulo,null,
                              null,null,v_cod_moneda,null,
                              'N',v_cod_tas_encaje_bcp,null,v_fec_cancelacion);
    
    --Encaje Legal Exigido
    If v_can_dia_plazo > 360 then
       v_enc_leg_exigido := (v_mto_plazo*(v_por_enc_bcp/100));
    Else    
       v_enc_leg_exigido := 0;
    End If;
    
    --Tasa Activa tarifario actual Plazo: días transcurridos toma de la pizarra del modulo 6 modalidad 61
    v_tas_act_dia_trans  := fug_obt_val_tas_act(6,61,v_mto_plazo,
                                               v_dia_transcurrido,v_cod_moneda);
    
    --Tasa Pasiva tarifario actual Plazo: días hasta el vencimiento toma de la pizarra del modulo y modalidad de la Cta.
    v_tas_pas_dia_vencer := fug_obt_val_tas_act(v_cod_modulo,v_cod_modalidad,v_mto_plazo,
                                                v_dia_vencer,v_cod_moneda);
    
    --Gasto Encaje Legal
    v_gas_enc_legal := +((v_enc_leg_exigido*v_dia_transcurrido*(v_tas_act_dia_trans/100))/365);
    
    --Costo Financiero
    v_cos_financiero:= -(v_mto_plazo*v_dia_vencer*((v_tas_pas_dia_vencer-v_tasa)/100))/365; 
    
    --Monto Minimo
    If (nvl(v_gas_enc_legal,0)+nvl(v_cos_financiero,0)) < v_val_min_cargo then
       v_mto_minimo := v_val_min_cargo;
    Else
       v_mto_minimo := 0;
    End If;       
    
    --Monto Total Penalización
    If v_mto_minimo = v_val_min_cargo then
       v_monto := v_mto_minimo;
    Else
       v_monto := Round((nvl(v_gas_enc_legal,0)+nvl(v_cos_financiero,0)),v_redondeo);
    End If; 
    
    --Valida Monto no sea negativo
    If v_monto >= 0 then
       p_mto_cargo := v_monto;
       p_imp_cargo := Round(((v_monto*v_por_impuesto)/100),v_redondeo);       
    Else
       raise_application_error(-20000,'Error Calculo de Monto de Cancelación,monto no puede ser negativo: ' || sqlerrm);    
    End If;
         
EXCEPTION
     WHEN OTHERS THEN
        raise_application_error(-20000,'Error en PRA_CAN_AHO_PLAZO: ' || sqlerrm);                                         
End;
/

