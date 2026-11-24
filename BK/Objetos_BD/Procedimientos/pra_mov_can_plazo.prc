CREATE OR REPLACE PROCEDURE IT.PRA_MOV_CAN_PLAZO
/*Proceso que genera los movimientos por cancelación anticipada de Ahorro Plazo Fijo Digital*/
(p_nro_cuenta  cc_cta_corrientes.nro_cuenta%TYPE,
 p_mto_cargo   ge_movimientos.monto%type,
 p_imp_cargo   ge_movimientos.monto%type) 
 IS
  R_GMOVI            GE_MOVIMIENTOS%ROWTYPE;
  v_hora             cj_movimientos.hora%type;
  v_hor_actual       ge_movimientos.hora%TYPE;
  v_fec_proceso      date;
  v_fec_valor        date;
  v_cod_modulo       ba_modulos.cod_modulo%type;
  v_cod_modalidad    ge_modalidades.cod_modalidad%type;
  v_cod_usuario      ge_movimientos.cod_usuario%type := user;
  v_es_nocturno      varchar2(1) := 'N';
  v_mto_plazo        ah_cta_plazos.capital%type;
  v_sal_total        ah_cta_plazos.sal_total%type;
  v_ini_plazo        ah_cta_plazos.fec_apertura%type;
  v_vto_plazo        ah_cta_plazos.fec_vencimiento%type;
  v_can_dia_plazo    number;
  v_tasa             number;
  v_cod_tasa         ge_tasas.cod_tasa%TYPE := 323;
  v_est_cuenta       ah_cta_plazos.estado%type;
  v_cod_moneda       ah_cta_plazos.cod_moneda%type;
  v_dia_transcurrido number;
  v_dia_vencer       number;
  v_nro_secuencia    ge_movimientos.nro_secuencia%type;
  v_cod_oficina      ba_oficinas.cod_oficina%type;
  v_ofi_origen       cj_movimientos.cod_oficina%type := fug_obt_ofi_matriz; --Oficina de Casa Matriz.
  v_redondeo         number(1);
  v_cta_origen       ge_cuentas.nro_cuenta%type;
  v_lugar            varchar2(300) :=null;
  v_mod_cta_origen   ba_modulos.cod_modulo%type; 
  v_mad_cta_origen   ge_modalidades.cod_modalidad%type;
  v_tra_cta_credito  ge_transacciones.cod_transaccion%type := 602; -- Transacción Crédito a Cta. Origen
  v_nvo_estado          ge_cuentas.estado%type; 
  v_sal_disp            ge_cuentas.sal_contable%type;
  v_procesa             varchar2(1) := 'N';
  --- Cursor de cupones no vencidos
  cursor c_cupon is
    select NRO_CUENTA,
           NRO_CUPON,
           NVL(MTO_INTERES, 0) MTO_INTERES,
           FEC_VENCIMIENTO,
           ROWID linea
      from AH_CUPONES
     where ESTADO IN ('E', 'C')
       and nro_cuenta = p_nro_cuenta;
Begin
  v_lugar:= '1-Obtener Modulo/Modalidad Cta.';
  --Obtener modulo y modalidad de la cuenta
  Begin
    select g.cod_modulo, g.cod_modalidad
      into v_cod_modulo, v_cod_modalidad
      from ge_cuentas g
     where g.nro_cuenta = p_nro_cuenta;
  Exception
    When NO_DATA_FOUND Then
      raise_application_error(-20000, 'Error: Cuenta Inexistente!!!');
    WHEN OTHERS THEN
      raise_application_error(-20000, 'Error Obt.Cuenta. '|| SQLERRM);
  End;

  v_fec_proceso := pag_cal.FU_OBT_FEC_ACTUAL(v_cod_modulo);
  v_fec_valor   := trunc(sysdate); -- para que sea fecha la fecha real de la transaccion --v_fec_proceso;

  v_hor_actual := to_char(sysdate, 'HH24:MI:SS');
  v_hora       := fug_obt_hor_disponible(v_fec_proceso,
                                         v_hor_actual,
                                         v_cod_usuario,
                                         v_es_nocturno);
  v_lugar:= '2-Obtener datos de la Cta.';
  --Obtener datos de la Cta Plazo Fijo.
  Begin
    Select c.capital,
           c.sal_total,
           c.fec_apertura,
           c.fec_vencimiento,
           c.estado,
           c.cod_moneda,
           c.val_tasa,
           c.cod_oficina,
           (c.fec_vencimiento - c.fec_apertura),
           (v_fec_proceso - c.fec_apertura),
           (c.fec_vencimiento - v_fec_proceso),
           c.nro_cta_capitalizacion
      Into v_mto_plazo,
           v_sal_total,
           v_ini_plazo,
           v_vto_plazo,
           v_est_cuenta,
           v_cod_moneda,
           v_tasa,
           v_cod_oficina,
           v_can_dia_plazo,
           v_dia_transcurrido,
           v_dia_vencer,
           v_cta_origen
      From ah_cta_plazos c
     Where c.nro_cuenta = p_nro_cuenta;
  Exception
    When no_data_found then
      RAISE_APPLICATION_ERROR(-20000, 'Cuenta inexistente');
    When others then
      RAISE_APPLICATION_ERROR(-20000, 'Cuenta invalida');
  End;
  
  --Valida Estado Normal de la Cta.     
  If v_est_cuenta <> 'N' then 
     raise_application_error(-20000, 'CTA: '||p_nro_cuenta||' ESTADO INVALIDO!!!');
  End If;  

  --Redondeo
  v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                    v_cod_modulo,
                                    v_cod_modalidad,
                                    v_cod_moneda);

  --Actualizar Estado/Motivo Cancelación/Fecha Pago = Fecha Cancelación de la Cta. Plazo
  --Primero pasa a P (Pendiente de Cancelación para generar los movimientos)
  v_lugar:= '3-Actualizar estado de la Cta. Plazo';
  update ah_cta_plazos 
       set estado = 'P',fec_cam_estado = v_fec_proceso,
           fec_pago = v_fec_proceso,
           cod_cau_cancelacion = 131 
     where nro_cuenta = p_nro_cuenta;                        

  v_lugar:= '4-Insertar movimiento de Cambio estado a vencido de la Cta';
  --- Insertar movimiento de Cambio estado a vencido de la Cta.
  v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
  r_gmovi.cod_usuario     := v_cod_usuario;
  r_gmovi.hora            := v_hora;
  r_gmovi.nro_secuencia   := v_nro_secuencia;
  r_gmovi.cod_mod_padre   := v_cod_modulo;
  r_gmovi.cod_mad_padre   := v_cod_modalidad;
  r_gmovi.cod_oficina     := v_cod_oficina;
  r_gmovi.cod_modulo      := v_cod_modulo;
  r_gmovi.cod_modalidad   := v_cod_modalidad;
  r_gmovi.nro_cuenta      := p_nro_cuenta;
  r_gmovi.cod_moneda      := v_cod_moneda;
  r_gmovi.cod_tra_padre   := 301;
  r_gmovi.cod_transaccion := 403;
  r_gmovi.concepto        := 'CAMBIO DE ESTADO-PLAZO FIJO DIGITAL';
  r_gmovi.est_cuenta      := 'V';
  r_gmovi.estado          := 'N';
  r_gmovi.reversado       := 'N';
  r_gmovi.emi_aviso       := 'N';
  r_gmovi.protegido       := 'N';
  r_gmovi.nro_documento   := p_nro_cuenta;
  r_gmovi.cod_ofi_origen  := v_ofi_origen;
  r_gmovi.fecha           := v_fec_proceso;
  r_gmovi.fec_valor       := v_fec_valor;
  pag_gen.pr_ins_ge_movimiento(r_gmovi);

  /*v_lugar:= '5-Insertar movimiento de traslado contable a Vencido.';
  --- Insertar movimiento de traslado contable a Vencido.
  v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
  r_gmovi.cod_usuario     := v_cod_usuario;
  r_gmovi.hora            := v_hora;
  r_gmovi.nro_secuencia   := v_nro_secuencia;
  r_gmovi.cod_mod_padre   := v_cod_modulo;
  r_gmovi.cod_mad_padre   := v_cod_modalidad;
  r_gmovi.cod_modulo      := v_cod_modulo;
  r_gmovi.cod_modalidad   := v_cod_modalidad;
  r_gmovi.cod_oficina     := v_cod_oficina;
  r_gmovi.nro_cuenta      := p_nro_cuenta;
  r_gmovi.cod_moneda      := v_cod_moneda;
  r_gmovi.cod_tra_padre   := 301;
  r_gmovi.cod_transaccion := 604;
  r_gmovi.concepto        := 'TRASLADO CONTABLE CAPITAL A VENCIDO';
  r_gmovi.estado          := 'N';
  r_gmovi.reversado       := 'N';
  r_gmovi.emi_aviso       := 'N';
  r_gmovi.protegido       := 'N';
  r_gmovi.monto           := v_sal_total;
  r_gmovi.nro_documento   := p_nro_cuenta;
  r_gmovi.cod_ofi_origen  := v_ofi_origen;
  r_gmovi.fecha           := v_fec_proceso;
  r_gmovi.fec_valor       := v_fec_valor;
  pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');*/

  v_lugar:= '6-Incio de Recorrer cupones';
  ---- Recorrer cupones
  for r_cup in c_cupon loop
    v_lugar:= '7-Insertar mvto de cambio estado cupon';
    --- Insertar mvto de cambio estado cupon
    v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
    r_gmovi.cod_usuario     := v_cod_usuario;
    r_gmovi.hora            := v_hora;
    r_gmovi.nro_secuencia   := v_nro_secuencia;
    r_gmovi.cod_mod_padre   := v_cod_modulo;
    r_gmovi.cod_mad_padre   := v_cod_modalidad;
    r_gmovi.cod_modulo      := v_cod_modulo;
    r_gmovi.cod_modalidad   := v_cod_modalidad;
    r_gmovi.cod_oficina     := v_cod_oficina;
    r_gmovi.nro_cuenta      := p_nro_cuenta;
    r_gmovi.cod_moneda      := v_cod_moneda;
    r_gmovi.monto           := null;
    r_gmovi.cod_tra_padre   := 301;
    r_gmovi.cod_transaccion := 407;
    r_gmovi.concepto        := 'CAMBIO DE ESTADO-PAGO DE CUPON (P)';
    r_gmovi.est_cuenta      := 'P';
    r_gmovi.estado          := 'N';
    r_gmovi.reversado       := 'N';
    r_gmovi.emi_aviso       := 'N';
    r_gmovi.protegido       := 'N';
    r_gmovi.nro_documento   := r_cup.nro_cupon;
    r_gmovi.cod_ofi_origen  := v_ofi_origen;
    r_gmovi.monto           := null;
    r_gmovi.fecha           := v_fec_proceso;
    r_gmovi.fec_valor       := v_fec_valor;
    pag_gen.pr_ins_ge_movimiento(r_gmovi);
  
    v_lugar:= '8-Insertar mvto de descuento contable de devengado del cupon.';  
    --- Insertar mvto de descuento contable de devengado del cupon             
    v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
    r_gmovi.cod_usuario     := v_cod_usuario;
    r_gmovi.hora            := v_hora;
    r_gmovi.nro_secuencia   := v_nro_secuencia;
    r_gmovi.cod_mod_padre   := v_cod_modulo;
    r_gmovi.cod_mad_padre   := v_cod_modalidad;
    r_gmovi.cod_modulo      := v_cod_modulo;
    r_gmovi.cod_modalidad   := v_cod_modalidad;
    r_gmovi.cod_oficina     := v_cod_oficina;
    r_gmovi.nro_cuenta      := p_nro_cuenta;
    r_gmovi.cod_moneda      := v_cod_moneda;
    r_gmovi.cod_tra_padre   := 301;
    r_gmovi.cod_transaccion := 657; --- Traslado contable
    r_gmovi.concepto        := 'TRASLADO CONTABLE DEL INTERES';
    r_gmovi.estado          := 'N';
    r_gmovi.reversado       := 'N';
    r_gmovi.emi_aviso       := 'N';
    r_gmovi.protegido       := 'N';
    r_gmovi.nro_documento   := r_cup.nro_cupon;
    r_gmovi.monto           := r_cup.mto_interes;
    r_gmovi.cod_ofi_origen  := v_ofi_origen;
    r_gmovi.fecha           := v_fec_proceso;
    r_gmovi.fec_valor       := v_fec_valor;
    pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
  
    v_lugar:= '9-Update AH_CUPONES';   
    update AH_CUPONES
       set ESTADO = 'P', fec_pago = v_fec_proceso
     where rowid = r_cup.linea;
  
  end loop;
  
    v_lugar:= '10-Inserta Movimiento Debito Cta. Plazo Fijo Digital';
  --Verificar la operacion
   pag_cta.pr_ver_operacion(p_nro_cuenta,
                            301,
                            v_cod_modulo,
                            v_cod_modalidad,
                            'D',
                            v_cod_moneda,
                            v_mto_plazo,
                            v_cod_oficina,
                            v_cod_modulo,
                            v_cod_modalidad,
                            v_nvo_estado,
                            v_sal_disp,
                            v_procesa,
                            503);
    If v_procesa = 'N' then
       RAISE_APPLICATION_ERROR(-20000,'Error. PRA_MOV_CAN_PLAZO. '||v_lugar||'-'||to_char(pag_cta.g_cod_error,'000'));
    Else                        
        --Movimiento Debito Cta. Plazo Fijo Digital 503
        v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
        r_gmovi.cod_usuario     := v_cod_usuario;
        r_gmovi.hora            := v_hora;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.cod_mod_padre   := v_cod_modulo;
        r_gmovi.cod_mad_padre   := v_cod_modalidad;
        r_gmovi.cod_modulo      := v_cod_modulo;
        r_gmovi.cod_modalidad   := v_cod_modalidad;
        r_gmovi.cod_oficina     := v_cod_oficina;
        r_gmovi.nro_cuenta      := p_nro_cuenta;
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.cod_tra_padre   := 301;
        r_gmovi.cod_transaccion := 503;
        r_gmovi.concepto        := 'DEBITO EN CUENTA AHORRO PLAZO FIJO';
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.nro_documento   := p_nro_cuenta;
        r_gmovi.monto           := v_mto_plazo;
        r_gmovi.cod_ofi_origen  := v_ofi_origen;
        r_gmovi.fecha           := v_fec_proceso;
        r_gmovi.fec_valor       := v_fec_valor;
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
        v_lugar:= '11-Actualiza saldo Cta. Plazo Fijo Digital'; 
        -- actualiza saldo cta
        PAG_CTA.PR_ACT_SAL_CTA(p_nro_cuenta, v_cod_modalidad, 'D',
                               v_fec_proceso, v_hora,v_mto_plazo,null, null, 'N');
  End If;  
  
  v_lugar:= '12-Obtener modulo/modalidad Cta. Origen'; 
  --Obtengo modulo y modalidad de la Cta. Origen 
  Begin
    select g.cod_modulo, g.cod_modalidad
      into v_mod_cta_origen, v_mad_cta_origen
      from ge_cuentas g
     where g.nro_cuenta = v_cta_origen;
  Exception
    When NO_DATA_FOUND Then
      raise_application_error(-20000, 'Error: Cuenta Origen Inexistente!!!');
    WHEN OTHERS THEN
      raise_application_error(-20000, 'Error Obt.Cuenta Origen. '|| SQLERRM);
  End;
  
  v_lugar:= '13-Inserta Movimiento Crédito Cta. Origen.';
  --Verificar la operacion
   pag_cta.pr_ver_operacion(v_cta_origen,
                            v_tra_cta_credito,
                            v_mod_cta_origen,
                            v_mad_cta_origen,
                            'C',
                            v_cod_moneda,
                            v_mto_plazo,
                            v_cod_oficina,
                            v_mod_cta_origen,
                            v_mad_cta_origen,
                            v_nvo_estado,
                            v_sal_disp,
                            v_procesa);
    If v_procesa = 'N' then
       RAISE_APPLICATION_ERROR(-20000,'Error. PRA_MOV_CAN_PLAZO. '||v_lugar||'-'||to_char(pag_cta.g_cod_error,'000'));
    Else            
        --Movimiento Crédito Cta. Origen  v_cta_origen
        v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
        r_gmovi.cod_usuario     := v_cod_usuario;
        r_gmovi.hora            := v_hora;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.cod_mod_padre   := v_cod_modulo;
        r_gmovi.cod_mad_padre   := v_cod_modalidad;
        r_gmovi.cod_modulo      := v_mod_cta_origen;
        r_gmovi.cod_modalidad   := v_mad_cta_origen;
        r_gmovi.cod_oficina     := v_cod_oficina;
        r_gmovi.nro_cuenta      := v_cta_origen;
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.cod_tra_padre   := 301;
        r_gmovi.cod_transaccion := v_tra_cta_credito;
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.nro_documento   := p_nro_cuenta;
        r_gmovi.monto           := v_mto_plazo;
        r_gmovi.concepto        := 'Crédito Saldo Cancelación Cta. Ahorro Plazo Fijo';
        r_gmovi.cod_ofi_origen  := v_ofi_origen;
        r_gmovi.fecha           := v_fec_proceso;
        r_gmovi.fec_valor       := v_fec_valor;
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
        v_lugar:= '14-Actualiza saldo Cta. Origen.'; 
       -- actualiza saldo cta
       PAG_CTA.PR_ACT_SAL_CTA(v_cta_origen, v_mad_cta_origen, 'C',
                              v_fec_proceso, v_hora,v_mto_plazo, null, null, 'N');
    End If;  
  
  
  if p_mto_cargo > 0 then
          v_lugar:= '15-Inserta movimientos por el Cargo.'; 
          --Verificar la operacion
          pag_cta.pr_ver_operacion(v_cta_origen,
                                   301,
                                   v_mod_cta_origen,
                                   v_mad_cta_origen,
                                   'D',
                                   v_cod_moneda,
                                   nvl(p_mto_cargo,0),
                                   v_cod_oficina,
                                   v_mod_cta_origen,
                                   v_mad_cta_origen,
                                   v_nvo_estado,
                                   v_sal_disp,
                                   v_procesa,
                                   501);
          If v_procesa = 'N' then
             RAISE_APPLICATION_ERROR(-20000,'Error. PRA_MOV_CAN_PLAZO. '||v_lugar||'-'||to_char(pag_cta.g_cod_error,'000'));
          Else                            
              --Inserta movimientos por el Cargo
              v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
              r_gmovi.cod_usuario     := v_cod_usuario;
              r_gmovi.hora            := v_hora;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_mod_padre   := v_mod_cta_origen;
              r_gmovi.cod_mad_padre   := v_mad_cta_origen;
              r_gmovi.cod_modulo      := v_mod_cta_origen;
              r_gmovi.cod_modalidad   := v_mad_cta_origen;
              r_gmovi.cod_oficina     := v_cod_oficina;
              r_gmovi.nro_cuenta      := v_cta_origen;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.cod_tra_padre   := 301;
              r_gmovi.cod_transaccion := 501;
              r_gmovi.concepto        := 'CARGO CANCELACIÓN DE CUENTAS BANCARIAS';
              r_gmovi.estado          := 'N';
              r_gmovi.reversado       := 'N';
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.protegido       := 'N';
              r_gmovi.nro_documento   := p_nro_cuenta;
              r_gmovi.monto           := p_mto_cargo;
              r_gmovi.cod_ofi_origen  := v_ofi_origen;
              r_gmovi.fecha           := v_fec_proceso;
              r_gmovi.fec_valor       := v_fec_valor;
              pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
              v_lugar:= '16-Actualiza saldo Cta. Plazo Fijo Digital Mto. Cargo'; 
              -- actualiza saldo cta
              PAG_CTA.PR_ACT_SAL_CTA(v_cta_origen, v_mad_cta_origen, 'D',
                                     v_fec_proceso, v_hora,p_mto_cargo,null, null, 'N');
          End If;
  End if;
  
  If p_imp_cargo > 0 then
     v_lugar:= '17-Inserta IVA por el Cargo'; 
     --Verificar la operacion
     pag_cta.pr_ver_operacion(v_cta_origen,
                              301,
                              v_mod_cta_origen,
                              v_mad_cta_origen,
                              'D',
                              v_cod_moneda,
                              nvl(p_imp_cargo,0),
                              v_cod_oficina,
                              v_mod_cta_origen,
                              v_mad_cta_origen,
                              v_nvo_estado,
                              v_sal_disp,
                              v_procesa,
                              502);
      If v_procesa = 'N' then
         RAISE_APPLICATION_ERROR(-20000,'Error. PRA_MOV_CAN_PLAZO. '||v_lugar||'-'||to_char(pag_cta.g_cod_error,'000'));
      Else                       
          --Inserta IVA por el Cargo
          v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
          r_gmovi.cod_usuario     := v_cod_usuario;
          r_gmovi.hora            := v_hora;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          r_gmovi.cod_mod_padre   := v_mod_cta_origen;
          r_gmovi.cod_mad_padre   := v_mad_cta_origen;
          r_gmovi.cod_modulo      := v_mod_cta_origen;
          r_gmovi.cod_modalidad   := v_mad_cta_origen;
          r_gmovi.cod_oficina     := v_cod_oficina;
          r_gmovi.nro_cuenta      := v_cta_origen;
          r_gmovi.cod_moneda      := v_cod_moneda;
          r_gmovi.cod_tra_padre   := 301;
          r_gmovi.cod_transaccion := 502;
          r_gmovi.val_tasa        := fug_obt_val_tasa(3, NULL, NULL,NULL,v_cod_moneda,NULL,'N',v_cod_tasa,NULL,v_fec_proceso);
          r_gmovi.concepto        := 'DB. IVA S/CARGO P/CANCELACION CTA.';
          r_gmovi.estado          := 'N';
          r_gmovi.reversado       := 'N';
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.protegido       := 'N';
          r_gmovi.nro_documento   := p_nro_cuenta;
          r_gmovi.monto           := p_imp_cargo;
          r_gmovi.cod_ofi_origen  := v_ofi_origen;
          r_gmovi.fecha           := v_fec_proceso;
          r_gmovi.fec_valor       := v_fec_valor;
          pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
          v_lugar:= '18-Actualiza saldo Cta. Plazo Fijo Digital Mto. Cargo'; 
          -- actualiza saldo cta
          PAG_CTA.PR_ACT_SAL_CTA(v_cta_origen, v_mad_cta_origen, 'D',
                                 v_fec_proceso, v_hora,p_imp_cargo,null, null, 'N');
      End If;                             
  End If;  
      --Actualizar Estado/Motivo Cancelación/Fecha Pago = Fecha Cancelación de la Cta. Plazo
  v_lugar:= '19-Actualizar estado a Cancelado de la Cta. Plazo';
  update ah_cta_plazos 
       set estado = 'C'
     where nro_cuenta = p_nro_cuenta;                               
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,
                            'Error en PRA_MOV_CAN_PLAZO: '||v_lugar||' - ' || sqlerrm);
End;
/

