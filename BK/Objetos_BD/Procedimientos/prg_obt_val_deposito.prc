create or replace procedure it.prg_obt_val_deposito(p_nro_cuenta    in varchar2,
                                                    p_cod_moneda    in varchar2,
                                                    p_monto         in number,
                                                    p_mto_loa       in out number,
                                                    p_mto_acumulado in out number,
                                                    p_mto_total     in out number,
                                                    p_deposita      in out varchar2)  is
  v_cod_persona       ba_personas.cod_persona%type;
  v_cod_moneda        ba_monedas.cod_moneda%type;
  v_cod_mon_local     ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_cod_mon_fuerte    ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_fuerte;
  v_cod_mon_umbral    ba_monedas.cod_moneda%type;
  v_mto_limite        cr_per_tip_operaciones.mto_limite%type;
  v_mto_limite_usd    cr_per_tip_operaciones.mto_limite%type;
  v_monto_usd         cr_per_tip_operaciones.mto_limite%type := 0;
  v_mto_mov           cr_per_tip_operaciones.mto_limite%type := 0;
  v_acumulado         cr_per_tip_operaciones.mto_limite%type := 0;
  v_tot_credito       cr_per_tip_operaciones.mto_limite%type := 0;
  --Parámetros USD
  v_cod_gru_trx       ge_gru_transacciones.cod_gru_transaccion%type := fug_obt_pardinamico('COD_GRU_TRA_UMBRAL');
  v_cod_gru_trx_j     ge_gru_transacciones.cod_gru_transaccion%type := fug_obt_pardinamico('COD_GRU_TRA_UMBRAL_J');
  v_umbral_fisica     number(18,2) := to_number(fug_obt_pardinamico('IMP_MAX_DEP_FIS')); --Val: 10.000USD
  v_umbral_juridica   number(18,2) := to_number(fug_obt_pardinamico('IMP_MAX_DEP_JUR')); --Val: 50.000USD
  --Parámetros GS
  v_cod_gru_trx_gs    ge_gru_transacciones.cod_gru_transaccion%type := fug_obt_pardinamico('COD_GRU_TRA_UMBRAL_GS');
  v_cod_gru_trx_gs_j  ge_gru_transacciones.cod_gru_transaccion%type := fug_obt_pardinamico('COD_GRU_TRA_UMBRAL_GS_J');
  v_umbral_fisica_gs  number(18,2) := to_number(fug_obt_pardinamico('IMP_MAX_DEP_F_GS')); --Val: 20.000USD
  v_umbral_jur_gs     number(18,2) := to_number(fug_obt_pardinamico('IMP_MAX_DEP_J_GS')); --Val: 50.000USD
  
  v_tip_persona       varchar2(1);
  v_fec_actual        date;
  v_fec_ini           date;
  v_fec_fin           date;
  
  Cursor c_acumulado is
  SELECT SUM(tot_credito) tot_credito
        FROM (SELECT SUM(decode(fug_obt_tra_tipo(b.cod_transaccion,b.tipo,b.afecta),'C',nvl(a.monto, 0),0)) tot_credito
                FROM ge_transacciones b, ge_gru_transacciones_det d, ge_movimientos a,ge_cta_clientes c,ge_cuentas x
               WHERE a.cod_modulo = b.cod_modulo
                 AND a.cod_modalidad = b.cod_modalidad
                 AND a.cod_transaccion = b.cod_transaccion
                 AND d.cod_gru_transaccion = v_cod_gru_trx--grupo transaccion
                 AND a.cod_modulo = d.cod_modulo
                 AND a.cod_modalidad = d.cod_modalidad
                 AND a.cod_transaccion = d.cod_transaccion
                 AND a.estado in ('N','P') --Normal y Pendientes
                 AND a.reversado = 'N'
                 AND b.ve_cliente = 'S'
                 AND b.tipo IN ('C', 'D')
                 AND nvl(b.afecta, 'XX') != 'B'
                 AND c.nro_cuenta = a.nro_cuenta
                 AND c.relacion   = 'P'
                 AND x.cod_moneda = v_cod_mon_umbral--COD_MONEDA
                 AND x.nro_cuenta = c.nro_cuenta
                 AND x.nro_cuenta = a.nro_cuenta
                 AND c.cod_persona = v_cod_persona
                 AND a.fecha = v_fec_actual
               GROUP BY c.cod_persona
              UNION
              SELECT SUM(decode(fug_obt_tra_tipo(b.cod_transaccion,b.tipo,b.afecta),'C',nvl(a.monto, 0),0)) tot_credito
                FROM ge_transacciones b, ge_gru_transacciones_det d, ah_movimientos_his a, ge_cta_clientes c, ge_cuentas x
               WHERE a.cod_modulo = b.cod_modulo
                 AND a.cod_modalidad = b.cod_modalidad
                 AND a.cod_transaccion = b.cod_transaccion
                 AND d.cod_gru_transaccion = v_cod_gru_trx--grupo transaccion
                 AND a.cod_modulo = d.cod_modulo
                 AND a.cod_modalidad = d.cod_modalidad
                 AND a.cod_transaccion = d.cod_transaccion
                 AND a.estado = 'N'
                 AND a.reversado = 'N'
                 AND b.ve_cliente = 'S'
                 AND b.tipo IN ('C', 'D')
                 AND nvl(b.afecta, 'XX') != 'B'
                 AND c.nro_cuenta = a.nro_cuenta
                 AND c.relacion   = 'P'
                 AND x.cod_moneda = v_cod_mon_umbral--COD_MONEDA
                 AND x.nro_cuenta = c.nro_cuenta
                 AND x.nro_cuenta = a.nro_cuenta
                 AND c.cod_persona = v_cod_persona
                 AND a.fecha BETWEEN v_fec_ini AND v_fec_fin
               GROUP BY c.cod_persona
              UNION
              SELECT SUM(decode(fug_obt_tra_tipo(b.cod_transaccion,b.tipo,b.afecta),'C',nvl(a.monto, 0),0)) tot_credito
                FROM ge_transacciones b, ge_gru_transacciones_det d, cc_movimientos_his a, ge_cta_clientes c, ge_cuentas x
               WHERE a.cod_modulo = b.cod_modulo
                 AND a.cod_modalidad = b.cod_modalidad
                 AND a.cod_transaccion = b.cod_transaccion
                 AND d.cod_gru_transaccion = v_cod_gru_trx--grupo transaccion
                 AND a.cod_modulo = d.cod_modulo
                 AND a.cod_modalidad = d.cod_modalidad
                 AND a.cod_transaccion = d.cod_transaccion
                 AND a.estado = 'N'
                 AND a.reversado = 'N'
                 AND b.ve_cliente = 'S'
                 AND b.tipo IN ('C', 'D')
                 AND nvl(b.afecta, 'XX') != 'B'
                 AND c.nro_cuenta = a.nro_cuenta
                 AND c.relacion   = 'P'
                 AND x.cod_moneda = v_cod_mon_umbral--COD_MONEDA
                 AND x.nro_cuenta = c.nro_cuenta
                 AND x.nro_cuenta = a.nro_cuenta
                 AND c.cod_persona = v_cod_persona
                 AND a.fecha BETWEEN v_fec_ini AND v_fec_fin
               GROUP BY c.cod_persona);
  BEGIN
    --obtener fechas
    pag_cal.pr_obt_dat_calendar(3);
    v_fec_actual := pag_cal.g_fec_actual;
    v_fec_ini    := pag_cal.g_pri_dia_mes_habil;
    v_fec_fin    := pag_cal.g_ult_dia_mes_habil;

    --Recuperar el LOA por cod_persona
    BEGIN
      --recupera persona principal de la cuenta
      v_cod_persona := fug_obt_cli_principal(p_nro_cuenta, 'P');
      --recuperamos la moneda y monto del LOA (el registro más reciente)
      SELECT b.cod_moneda, b.mto_limite
        INTO v_cod_moneda, v_mto_limite
        FROM cr_per_tip_operaciones b
       WHERE b.cod_moneda IS NOT NULL
         AND b.cod_persona = v_cod_persona
       ORDER BY b.fec_insercion DESC
       FETCH FIRST 1 rows ONLY;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000,'En obtener datos del LOA. '||SQLERRM);
    END;
 
    --Valido Moneda de la operacion
    if p_cod_moneda = v_cod_mon_local THEN
      --cambiar a dolares
      v_monto_usd := pag_gen.fu_con_mon_a_moneda(v_cod_mon_local,v_cod_mon_fuerte,nvl(p_monto, 0)); 
    elsif p_cod_moneda = v_cod_mon_fuerte THEN
      v_monto_usd := nvl(p_monto, 0);
    end if;     
    
    --Validamos si es persona Fisica o Juridica
    IF pag_gen.fu_es_per_fisica(v_cod_persona) = 'S' THEN
      v_tip_persona := 'F';
    ELSE
      v_tip_persona := 'J';
    END IF;  
    
    --Validar moneda y tipo persona GS
    IF p_cod_moneda = v_cod_mon_local THEN
      IF v_tip_persona = 'F' then
        v_umbral_fisica := v_umbral_fisica_gs;
        v_cod_gru_trx   := v_cod_gru_trx_gs;
      ELSIF v_tip_persona = 'J' then
        v_umbral_juridica := v_umbral_jur_gs;
        v_cod_gru_trx   := v_cod_gru_trx_gs_j;
      END IF;
      
    ELSIF p_cod_moneda = v_cod_mon_fuerte THEN
      IF v_tip_persona = 'J' then
        v_cod_gru_trx   := v_cod_gru_trx_j;
      END IF;
    END IF;

   --Total de creditos en el mes de cuentas donde la persona sea Principal (AHORROS/CTA CORRIENTE)
    BEGIN
      --setear moneda de la operacion para obtener movimientos
      v_cod_mon_umbral := p_cod_moneda;
      --Cursor de movimientos de la persona Principal
      FOR reg1 IN c_acumulado LOOP
        if v_cod_mon_umbral = v_cod_mon_fuerte then
          v_mto_mov := reg1.tot_credito;
        --convertir guaranies a dolares
        elsif v_cod_mon_umbral = v_cod_mon_local then
          v_mto_mov := pag_gen.fu_con_mon_a_moneda(v_cod_mon_local,v_cod_mon_fuerte,reg1.tot_credito);
        end if;
        v_acumulado := v_acumulado + nvl(v_mto_mov,0);
      END LOOP;
      
    EXCEPTION
      WHEN OTHERS THEN
        v_acumulado := 0;
    END;

    --Moneda configurada en LOA - Dolares
    IF v_cod_moneda = v_cod_mon_fuerte THEN
      --total creditos del mes + monto a depositar (operacion)
      v_tot_credito := nvl(v_acumulado, 0) + nvl(v_monto_usd, 0);

      p_mto_loa       := v_mto_limite;
      p_mto_acumulado := v_acumulado;
      p_mto_total     := v_tot_credito;                                            

      IF v_tip_persona = 'F' THEN
        --total creditos + operacion > LOA + UMBRAL
        IF v_tot_credito >  v_mto_limite + v_umbral_fisica THEN
          p_deposita := 'N'; --No Deposita (supera el límite + umbral)
        ELSE
          p_deposita := 'S'; --Si Deposita
        END IF;

      ELSIF v_tip_persona = 'J' THEN
        --total creditos + operacion > LOA + UMBRAL
        IF v_tot_credito > v_mto_limite + v_umbral_juridica THEN
          p_deposita := 'N'; --No Deposita (supera el límite + umbral)
        ELSE
          p_deposita := 'S'; --Si Deposita
        END IF;
      END IF;
    --Guaranies
    ELSIF v_cod_moneda = v_cod_mon_local THEN
      --convertir a moneda fuerte
      v_mto_limite_usd := it.pag_gen.fu_con_mon_a_moneda(v_cod_mon_local,v_cod_mon_fuerte,v_mto_limite);
      --total creditos del mes + monto a depositar (operacion)
      v_tot_credito := nvl(v_acumulado, 0) + nvl(v_monto_usd, 0);

      p_mto_loa       := v_mto_limite_usd;
      p_mto_acumulado := v_acumulado;
      p_mto_total     := v_tot_credito;

      IF v_tip_persona = 'F' THEN
        --total creditos + operacion > LOA + UMBRAL
        IF v_tot_credito >  v_mto_limite_usd + v_umbral_fisica THEN
          p_deposita := 'N'; --No Deposita (supera el límite + umbral)
        ELSE
          p_deposita := 'S'; --Si Deposita
        END IF;

      ELSIF v_tip_persona = 'J' THEN
        --total creditos + operacion > LOA + UMBRAL
        IF v_tot_credito > v_mto_limite_usd + v_umbral_juridica THEN
          p_deposita := 'N'; --No Deposita (supera el límite + umbral)
        ELSE
          p_deposita := 'S'; --Si Deposita
        END IF;
      END IF;
    END IF;

EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20001,'ERROR prg_obt_val_deposito: '||SQLERRM);
END;
/
