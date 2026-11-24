CREATE OR REPLACE PROCEDURE IT.PRA_GEN_MOV_PLAZO
(p_nro_cta_deb cc_cta_corrientes.nro_cuenta%TYPE,
 p_nro_cta_cre cc_cta_corrientes.nro_cuenta%TYPE,
 p_monto       ge_movimientos.monto%type)
 IS
 R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
 v_cod_tra_deb         ge_transacciones.cod_transaccion%type := 503; --Débito
 v_cod_tra_cre         ge_transacciones.cod_transaccion%type := 2203;--Crédito
 v_hora                cj_movimientos.hora%type;
 v_hor_actual          ge_movimientos.hora%TYPE; 
 v_nro_secuencia       ge_movimientos.nro_secuencia%type;
 v_fec_proceso         date;
 v_fec_valor           date;
 v_cod_usuario         ge_movimientos.cod_usuario%type := user;
 v_es_nocturno         varchar2(1) := 'N';
 v_cod_moneda          ba_monedas.cod_moneda%type;
 v_cod_ofi_cta_deb     ge_movimientos.cod_oficina%type;
 v_denominacion        varchar2(200);
 v_est_cuenta_deb      varchar2(1);  
 v_cod_mod_cuenta_deb  number(4);
 v_cod_mad_cuenta_deb  number(4);
 v_cod_persona         ba_personas.cod_persona%type;
 v_ofi_origen          cj_movimientos.cod_oficina%type :=  fug_obt_ofi_matriz; --Oficina de Casa Matriz.
 v_nvo_estado          ge_cuentas.estado%type; 
 v_sal_disp            ge_cuentas.sal_contable%type;
 v_procesa             varchar2(1) := 'N';
 v_cod_moneda_cre      ba_monedas.cod_moneda%type;
 v_cod_ofi_cta_cre     ge_movimientos.cod_oficina%type;
 v_denominacion_cre    varchar2(200);
 v_est_cuenta_cre      varchar2(1);  
 v_cod_mod_cuenta_cre  number(4);
 v_cod_mad_cuenta_cre  number(4);
 Begin
   if p_nro_cta_deb is null then
      RAISE_APPLICATION_ERROR(-20000, 'Parametro Nro. Cta. Débito incorrecto.' );
   end if;
   if p_nro_cta_cre is null then
      RAISE_APPLICATION_ERROR(-20000, 'Parametro Nro. Cta. Crédito incorrecto.' );
   end if;  
   if p_monto is null then
      RAISE_APPLICATION_ERROR(-20000, 'Parametro Monto incorrecto.' );
   end if;
       v_fec_proceso := pag_cal.FU_OBT_FEC_ACTUAL(3);
       v_fec_valor   := trunc(sysdate); -- para que sea fecha la fecha real de la transaccion --v_fec_proceso;
       /*MOVIMIENTO DEBITO EN LA CTA ORIGEN*/
       v_hor_actual  := to_char(sysdate,'HH24:MI:SS');
       v_hora        := fug_obt_hor_disponible(v_fec_proceso, v_hor_actual, v_cod_usuario, v_es_nocturno);
       Begin
         -- obtengo datos de la cuenta débito ------------------------------------------
          select a.denominacion, a.cod_moneda, a.estado, a.cod_modalidad, a.cod_modulo,
                 a.cod_oficina, c.cod_persona
            into v_denominacion, v_cod_moneda, v_est_cuenta_deb, v_cod_mad_cuenta_deb,
                 v_cod_mod_cuenta_deb, v_cod_ofi_cta_deb, v_cod_persona
             from ge_cuentas a ,ge_cta_clientes c
             where a.nro_cuenta = p_nro_cta_deb
             and a.nro_cuenta = c.nro_cuenta
             and c.relacion = 'P';
           Exception
              When no_data_found then
                RAISE_APPLICATION_ERROR(-20000,'Cuenta inexistente');  
              When others then
                RAISE_APPLICATION_ERROR(-20000,'Cuenta invalida');   
       End; 
       Begin
         -- obtengo datos de la cuenta crédito ------------------------------------------
          select a.denominacion, a.cod_moneda, a.estado, a.cod_modalidad, a.cod_modulo,
                 a.cod_oficina, c.cod_persona
            into v_denominacion_cre, v_cod_moneda_cre, v_est_cuenta_cre, v_cod_mad_cuenta_cre,
                 v_cod_mod_cuenta_cre, v_cod_ofi_cta_cre, v_cod_persona
             from ge_cuentas a ,ge_cta_clientes c
             where a.nro_cuenta = p_nro_cta_cre
             and a.nro_cuenta = c.nro_cuenta
             and c.relacion = 'P';
           Exception
              When no_data_found then
                RAISE_APPLICATION_ERROR(-20000,'Cuenta inexistente');  
              When others then
                RAISE_APPLICATION_ERROR(-20000,'Cuenta invalida');   
       End;
        --Verificar la operacion
        pag_cta.pr_ver_operacion(p_nro_cta_deb,
                                 v_cod_tra_deb,
                                 v_cod_mod_cuenta_deb,
                                 v_cod_mad_cuenta_deb,
                                 'D',
                                 v_cod_moneda,
                                 nvl(p_monto,0),
                                 v_cod_ofi_cta_deb,
                                 v_cod_mod_cuenta_deb,
                                 v_cod_mad_cuenta_deb,
                                 v_nvo_estado,
                                 v_sal_disp,
                                 v_procesa);
       If v_procesa = 'N' then
            RAISE_APPLICATION_ERROR(-20000,'Error. PRA_GEN_MOV_CTA_AHO_PLZ_FIJO '||to_char(pag_cta.g_cod_error,'000'));
       Else                             
             --Cargo los valores para generar el movimiento.          
             r_gmovi.fecha               := v_fec_proceso;
             r_gmovi.hora                := v_hora;
             r_gmovi.cod_usuario         := v_cod_usuario;
             r_gmovi.nro_secuencia       := 1;
             r_gmovi.fec_valor           := v_fec_valor;
             r_gmovi.monto               := p_monto;
             r_gmovi.nro_cuenta          := p_nro_cta_deb;
             r_gmovi.cod_moneda          := v_cod_moneda;
             r_gmovi.cod_oficina         := v_cod_ofi_cta_deb;
             r_gmovi.estado              := 'N';
             r_gmovi.reversado           := 'N';
             r_gmovi.cod_ofi_origen      := v_cod_ofi_cta_deb;
             r_gmovi.concepto            := 'Debito por apertura Ahorro Plazo Fijo';
             r_gmovi.cod_tra_padre       := v_cod_tra_cre;
             r_gmovi.cod_mod_padre       := v_cod_mod_cuenta_cre;
             r_gmovi.cod_mad_padre       := v_cod_mad_cuenta_cre;
             r_gmovi.cod_transaccion     := v_cod_tra_deb;
             r_gmovi.cod_modulo          := v_cod_mod_cuenta_deb;
             r_gmovi.cod_modalidad       := v_cod_mad_cuenta_deb;
             r_gmovi.nro_documento       := p_nro_cta_cre;  -- Nro. documento nro cta nueva ahorro plazo fijo.
             -- inserto el registro de movimientos
             PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
             -- actualiza saldo cta
             PAG_CTA.PR_ACT_SAL_CTA(p_nro_cta_deb, v_cod_mad_cuenta_deb, 'D',
                                    v_fec_proceso, v_hora, p_monto, null, null, 'N');
       End If; 

       /*MOVIMIENTO POR EL CREDITO EN LA NUEVA CTA AHORRO PLAZO FIJO*/                            
             --Cargo los valores para generar el movimiento.          
             r_gmovi.fecha               := v_fec_proceso;
             r_gmovi.hora                := v_hora;
             r_gmovi.cod_usuario         := v_cod_usuario;
             r_gmovi.nro_secuencia       := 2;
             r_gmovi.fec_valor           := v_fec_valor;
             r_gmovi.monto               := p_monto;
             r_gmovi.nro_cuenta          := p_nro_cta_cre;
             r_gmovi.cod_moneda          := v_cod_moneda_cre;
             r_gmovi.cod_oficina         := v_cod_ofi_cta_cre;
             r_gmovi.estado              := 'N';
             r_gmovi.reversado           := 'N';
             r_gmovi.cod_ofi_origen      := v_cod_ofi_cta_deb;
             r_gmovi.concepto            := 'Crédito por apertura Ahorro Plazo Fijo';
             r_gmovi.cod_tra_padre       := v_cod_tra_cre;
             r_gmovi.cod_mod_padre       := v_cod_mod_cuenta_cre;
             r_gmovi.cod_mad_padre       := v_cod_mad_cuenta_cre;
             r_gmovi.cod_transaccion     := v_cod_tra_cre;
             r_gmovi.cod_modulo          := v_cod_mod_cuenta_cre;
             r_gmovi.cod_modalidad       := v_cod_mad_cuenta_cre;
             r_gmovi.nro_documento       := p_nro_cta_cre;  -- Nro. documento nro cta nueva ahorro plazo fijo.
             -- inserto el registro de movimientos
             PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
             -- actualiza saldo cta
             PAG_CTA.PR_ACT_SAL_CTA(p_nro_cta_cre, v_cod_mad_cuenta_cre, 'C',
                                    v_fec_proceso, v_hora, p_monto, null, null, 'N');
  EXCEPTION
     WHEN OTHERS THEN
          raise_application_error(-20000,'Error en PRA_GEN_MOV_PLAZO: ' || sqlerrm);                                    
 End;
/

