CREATE OR REPLACE PROCEDURE IT.PRJ_OBT_DAT_PEND
 (P_NRO_CUENTA IN VARCHAR2
 ,P_NRO_CUOTA_DESDE IN OUT NUMBER
 ,P_NRO_CUOTA_HASTA IN OUT NUMBER
 ,P_FECHA  IN DATE
 ,P_HORA IN VARCHAR2
 ,P_TOT_CAPITAL OUT NUMBER
 ,P_TOT_INTERES OUT NUMBER
 ,P_TOT_INT_ADELANTADO OUT NUMBER
 ,P_TOT_MORA OUT NUMBER
 ,P_TOT_MORA_INTERES OUT NUMBER
 ,P_TOT_MORA_INT_ADEL OUT NUMBER
 ,P_TOT_IMPUESTO OUT NUMBER
 ,P_TOT_CARGO OUT NUMBER
 ,P_TOT_CARGO_IVA OUT NUMBER
 ,P_TOT_INT_DESCONTADO OUT NUMBER
 ,P_TOT_IVA_DESCONTADO OUT NUMBER
 ,P_TOT_SEG_DESCONTADO OUT NUMBER
 ,P_TOT_PUNITORIO OUT NUMBER
 ,P_TOT_CTA_AHO OUT NUMBER
 ,P_TOT_CTA_CON OUT NUMBER
 ,P_COD_TRA_PADRE IN NUMBER
 ,P_COD_RESPUESTA OUT VARCHAR2
 ,P_MSJ_RESPUESTA OUT VARCHAR2
 )
 IS
-- Datos del COBRO
 v_tot_capital           number(18,2);      -- Capital (MTO_CAPITAL)
 v_tot_interes           number(18,2);      -- Interés (MTO_INTERES)
 v_tot_int_adelantado    number(18,2);      -- Interes adelantado (MTO_INT_DOCUMENTADO)
 v_tot_mora              number(18,2);      -- Mora s/capital (MTO_INT_MORATORIO)
 v_tot_mora_interes      number(18,2);      -- Mora s/Interés (MTO_INT_MOR_INTERES)
 v_tot_mora_int_adel     number(18,2);      -- Mora interés adelantado (MTO_INT_MOR_ADELANTADO)
 v_tot_impuesto          number(18,2);      -- Total impuesto (MTO_IMPUESTO)
 v_impuesto              number(18,2);
 v_tot_cargo             number(18,2);      -- Total cargo (MTO_CARGO)
 v_tot_cargo_iva         number(18,2);      -- Total cargo IVA (MTO_CARGO_IVA)
 v_tot_int_descontado    number(18,2);      -- Total interes descontado (MTO_INT_DESCONTADO)
 v_tot_punitorio         number(18,2);      -- Total monto punitorio (MTO_INT_PUNITORIO)
 v_tot_cta_aho           number(18,2);      -- Total pagado contra cuenta de ahorro
 v_tot_cta_con           number(18,2);      -- Total pagado contra cuenta contable
--- v_nro_cuota             number(3);

 v_nro_cuota_desde       number(3);  -- cuota desde
 v_nro_cuota_hasta       number(3);  -- cuota hasta
 v_cod_usuario           varchar2(10);
 
 v_che_otr_bco           varchar2(1) := 'N';
BEGIN
    Begin
        Select distinct('S')
          into v_che_otr_bco
          from ge_movimientos a
         where a.hora            = P_HORA
           and a.nro_cuenta      = P_NRO_CUENTA
           and a.cod_transaccion in (607,610,632);
    Exception
        When Others Then
             v_che_otr_bco := 'N';
    End;
    If v_che_otr_bco = 'N' Then
        Begin
         select min(nro_cuota), max(nro_cuota), min(usu_insercion)
          into v_nro_cuota_desde, v_nro_cuota_hasta, v_cod_usuario
           from pr_cobros where
              nro_cuenta = p_nro_cuenta and
              fecha      = p_fecha and
              hora       = p_hora;

              p_nro_cuota_desde := v_nro_cuota_desde;
              p_nro_cuota_hasta := v_nro_cuota_hasta;

        exception
            when no_data_found then
               v_nro_cuota_desde := p_nro_cuota_desde;
               v_nro_cuota_hasta := p_nro_cuota_hasta;
        end;

        Begin
           Select sum(nvl(mto_capital,0)), sum(nvl(mto_interes,0)), sum(nvl(mto_int_documentado,0)),
           sum(nvl(mto_int_moratorio,0)), sum(nvl(mto_int_mor_interes,0)), sum(nvl(mto_int_mor_adelantado,0)),
           sum(nvl(mto_int_punitorio,0)), sum(nvl(mto_cargo,0)), sum(nvl(mto_cargo_iva,0)), sum(nvl(mto_impuesto,0)),
           sum(nvl(mto_int_descontado,0))
            into
            v_tot_capital, v_tot_interes, v_tot_int_adelantado, v_tot_mora,
            v_tot_mora_interes, v_tot_mora_int_adel, v_tot_punitorio ,
            v_tot_cargo, v_tot_cargo_iva, v_tot_impuesto, v_tot_int_descontado
            from pr_cobros where
                nro_cuenta = p_nro_cuenta
            and nro_cuota  between v_nro_cuota_desde and v_nro_cuota_hasta
            and fecha      = p_fecha
            and hora       = p_hora;

            p_tot_capital        := nvl(v_tot_capital,0);
            p_tot_interes        := nvl(v_tot_interes,0);
            p_tot_int_adelantado := nvl(v_tot_int_adelantado,0);
            p_tot_mora           := nvl(v_tot_mora,0);
            p_tot_mora_interes   := nvl(v_tot_mora_interes,0);
            p_tot_mora_int_adel  := nvl(v_tot_mora_int_adel,0);
            p_tot_punitorio      := nvl(v_tot_punitorio,0);
            p_tot_cargo          := nvl(v_tot_cargo,0);
            p_tot_cargo_iva      := nvl(v_tot_cargo_iva,0);
            p_tot_impuesto       := nvl(v_tot_impuesto,0);
            p_tot_int_descontado := nvl(v_tot_int_descontado,0);
            
            IF fug_obt_pardinamico('PRE_CAR_DEV_SEGURO') = 'S' THEN
              prp_obt_mto_seg_descontado(p_nro_cuenta, p_tot_seg_descontado, v_impuesto);
            ELSE
              p_tot_seg_descontado := 0;
            End IF;


              p_cod_respuesta := '000';
              p_msj_respuesta := null;
        Exception
           when no_data_found then
              p_cod_respuesta := '007';
              p_msj_respuesta := 'No encontro COBRO '||sqlerrm;
           when others then
              p_cod_respuesta := '999';
              p_msj_respuesta := 'Error al buscar en PR_COBROS:'||sqlerrm;
        End;
        if p_cod_respuesta = '000' THEN
           --- Recuperar formas de cobro
           BEGIN
              select nvl(sum(decode(cod_transaccion,503,nvl(monto,0),0)),0),
                     nvl(sum(decode(cod_transaccion,842,nvl(monto,0),0)),0),
                     nvl(sum(decode(cod_transaccion,1708,nvl(monto,0),0)),0) +
                     nvl(sum(decode(cod_transaccion,1709,nvl(monto,0),0)),0)
              into p_tot_cta_aho, p_tot_cta_con, p_tot_iva_descontado
              from ge_movimientos m
              where fecha = p_fecha
              and hora = p_hora
              and cod_usuario = v_cod_usuario
              and cod_transaccion in (503,842, 1708, 1709)
              and exists (select 1 from ge_movimientos o
                           where o.fecha = m.fecha
                             and o.hora = m.hora
                             and o.cod_usuario = m.cod_usuario
                             and o.nro_cuenta = p_nro_cuenta);

           END;
        end if;
    Else -- Si el cobro se realiza con cheuqe cargo otros bancos y es retomado en CAJA.-
        Begin
         select min(nro_cuota)   , max(nro_cuota)   , min(usu_insercion)
           into v_nro_cuota_desde, v_nro_cuota_hasta, v_cod_usuario
           from pr_cobros_tmp a
          where nro_cuenta   = p_nro_cuenta 
            and a.fec_valor  = p_fecha
            and exists(Select 1
                         from pr_cob_cuo_otr_bco ax
                        where ax.nro_cuenta  = a.nro_cuenta
                          and ax.nro_cuota   = a.nro_cuota
                          --and ax.fec_proceso = a.fec_vencimiento -- Se filtra por FEC_VENCIMIENTO porque se retoma en el día y en este campo siempre va insertar la fecha en que se realizó el cobro
                          and ax.estado      = 'C'
                          );

              p_nro_cuota_desde := v_nro_cuota_desde;
              p_nro_cuota_hasta := v_nro_cuota_hasta;

        exception
            when no_data_found then
               v_nro_cuota_desde := p_nro_cuota_desde;
               v_nro_cuota_hasta := p_nro_cuota_hasta;
        end;

        Begin
           Select sum(nvl(mto_capital,0)), sum(nvl(mto_interes,0)), sum(nvl(mto_int_documentado,0)),
                  sum(nvl(mto_int_moratorio,0)), sum(nvl(mto_int_mor_interes,0)), sum(nvl(mto_int_mor_adelantado,0)),
                  sum(nvl(mto_int_punitorio,0)), sum(nvl(mto_cargo,0)), sum(nvl(mto_cargo_iva,0)), sum(nvl(mto_impuesto,0)),
                  sum(nvl(mto_int_descontado,0))
             into v_tot_capital, v_tot_interes, v_tot_int_adelantado, v_tot_mora,
                  v_tot_mora_interes, v_tot_mora_int_adel, v_tot_punitorio ,
                  v_tot_cargo, v_tot_cargo_iva, v_tot_impuesto, v_tot_int_descontado
            from pr_cobros_tmp a
            where nro_cuenta    = p_nro_cuenta
              and nro_cuota     between v_nro_cuota_desde and v_nro_cuota_hasta
              and a.fec_valor   = p_fecha
              and exists(Select 1
                         from pr_cob_cuo_otr_bco ax
                        where ax.nro_cuenta  = a.nro_cuenta
                          and ax.nro_cuota   = a.nro_cuota
                          and ax.fec_cobro   = a.fec_valor -- Se filtra por FEC_VENCIMIENTO porque se retoma en el día y en este campo siempre va insertar la fecha en que se realizó el cobro
                          and ax.estado      = 'C'
                          );

            p_tot_capital        := nvl(v_tot_capital,0);
            p_tot_interes        := nvl(v_tot_interes,0);
            p_tot_int_adelantado := nvl(v_tot_int_adelantado,0);
            p_tot_mora           := nvl(v_tot_mora,0);
            p_tot_mora_interes   := nvl(v_tot_mora_interes,0);
            p_tot_mora_int_adel  := nvl(v_tot_mora_int_adel,0);
            p_tot_punitorio      := nvl(v_tot_punitorio,0);
            p_tot_cargo          := nvl(v_tot_cargo,0);
            p_tot_cargo_iva      := nvl(v_tot_cargo_iva,0);
            p_tot_impuesto       := nvl(v_tot_impuesto,0);
            p_tot_int_descontado := nvl(v_tot_int_descontado,0);


              p_cod_respuesta := '000';
              p_msj_respuesta := null;
        Exception
           when no_data_found then
              p_cod_respuesta := '007';
              p_msj_respuesta := 'No encontro COBRO '||sqlerrm;
           when others then
              p_cod_respuesta := '999';
              p_msj_respuesta := 'Error al buscar en PR_COBROS:'||sqlerrm;
        End;
        if p_cod_respuesta = '000' THEN
           --- Recuperar formas de cobro
           BEGIN
              select nvl(sum(decode(cod_transaccion,503,nvl(monto,0),0)),0),
                     nvl(sum(decode(cod_transaccion,842,nvl(monto,0),0)),0)
              into p_tot_cta_aho, p_tot_cta_con
              from ge_movimientos m
              where hora = p_hora
              and cod_usuario = v_cod_usuario
              and cod_transaccion in (503,842)
              and exists (select 1 from ge_movimientos o
                           where o.hora = m.hora
                             and o.cod_usuario = m.cod_usuario
                             and o.nro_cuenta = p_nro_cuenta);

           END;
        end if;
    End If;
END;
/

