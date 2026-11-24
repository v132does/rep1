CREATE OR REPLACE PROCEDURE IT.PRP_GEN_SOL_OPE_RES4(
p_nro_cta_ori in varchar2 default null,
p_nro_cuo_desde number,
p_nro_cuo_hasta number,
p_cod_persona varchar2,
p_cod_mad_base in number,
p_cod_sub_mad_base in number,
p_cod_mon_base in varchar2,
p_mto_pre_nuevo in number,
p_mto_capital in number,
p_mto_interes in number,
p_mto_mor_capital in number,
p_mto_mor_interes in number,
p_mto_punitorio in number,
p_mto_impuesto in number,
p_mto_cargo in number,
p_mto_iva_interes in number,
p_mto_deu_neto in number,
p_cot_mon_fuerte in number,
p_resultado out varchar2,
p_nro_sol_nueva out number
)
is
  --Proyecto SDRES4COVI-6---29.04.20--
  --Procedimiento para validar y llamar al programa de --
  --generacion de solicitud de propuesta--

  --Variables--
  v_lugar varchar2(3000);
  v_nro_solicitud number (30);
  v_nro_cta_ori varchar2(300);
  v_fec_pri_vto date;
  v_dia_vto varchar2(10);
  v_mes_vto number(2);
  v_ano_vto number(4);
  v_fec_pri_vto_cal varchar2(20);
  v_fec_inicio date:= pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_mto_prestamo number(18,4);
  v_sub_mad_tas_abierta varchar2(10):=p_cod_sub_mad_base;
  v_can_cuotas number(10):=18;
  v_nro_cta_nueva varchar2(100);
  v_nro_cta_proc  varchar2(100);
  v_cod_per_proc  varchar2(100);
  v_nro_cuenta_debito varchar2(20);
  v_nro_linea   varchar(100);
  v_deb_automatico varchar2(1);
  v_resultado    varchar2(3000):='OK';
  v_cod_gar_pre_ant varchar2(10);
  v_nro_gar_pre_ant varchar2(10);
  v_mto_mor_interes pr_cta_prestamos.sal_interes%type;
  v_mto_mor_int_ade pr_cta_prestamos.sal_interes%type;
  v_tot_deuda number(18,4);
  v_tot_descuento number(18,4);
  v_fec_actual date;
  v_cod_sec_credito pr_solicitudes.cod_sec_credito%type;
  v_cod_rub_economico pr_solicitudes.cod_rub_economico%type;
  v_exi_rub_eco_modal varchar2(1);
  v_pre_nue_cal_seguros varchar2(1);
  v_cod_tra_padre ge_transacciones.cod_transaccion%type;
  v_tip_can_rrr pr_cta_pre_ref_res4.tip_can_rrr%type;
  v_nro_cta_max pr_cta_prestamos.nro_cuenta%type;

  cursor cur_datos is
  --Prestamos--
  select b.cod_rub_economico, b.cod_sec_credito, a.nro_cuenta, a.nro_cta_debito,
         a.nro_cta_renovada, a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.cod_moneda,
         b.deb_automatico, a.tip_interes, a.dia_atraso, a.dev_no_cobrado, t.nro_cuo_desde, t.nro_cuo_hasta,
         a.dev_suspenso, t.mto_deu_neto, t.sal_capital, t.sal_interes, t.mto_cargo,
         t.mto_impuesto, t.mto_mora, t.mto_mor_int, t.mto_punitorio, t.mto_iva_interes
    from pr_cta_prestamos a, pr_solicitudes b, pr_cta_pre_res4_tmp t
   where t.cod_persona = p_cod_persona
     and a.nro_cuenta = t.nro_cuenta
     and nvl(a.nro_sol_renovada,a.nro_solicitud)= b.nro_solicitud
  union all
  --Tarjetas Vencidas--
  select  nvl(a.cod_rub_economico,x.cod_rub_economico) cod_rub_economico, null cod_sec_credito, a.nro_cuenta, null nro_cta_debito,
          a.nro_cta_renovada, a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.cod_moneda,
          null deb_automatico, null tip_interes, a.dia_atraso, 0 dev_no_cobrado, t.nro_cuo_desde, t.nro_cuo_hasta,
          0 dev_suspenso, t.mto_deu_neto, t.sal_capital, t.sal_interes, t.mto_cargo,
          t.mto_impuesto, t.mto_mora, t.mto_mor_int, t.mto_punitorio, t.mto_iva_interes
     from ov_cta_vencidas a, ta_cta_tarjetas x, pr_cta_pre_res4_tmp t
    where t.cod_persona = p_cod_persona
      and a.nro_cuenta = t.nro_cuenta
      and a.nro_cta_origen = x.nro_cuenta
  union all
  --Sobregiros Vencidos--
  select  nvl(a.cod_rub_economico, nvl(fug_obt_pardinamico('COD_RUB_ECO_PRE_APR_ATM', 6), '970108')) cod_rub_economico,
          null cod_sec_credito, a.nro_cuenta, null nro_cta_debito,
          a.nro_cta_renovada, a.cod_modulo, a.cod_modalidad, a.cod_oficina,a.cod_moneda,
          null deb_automatico, null tip_interes, a.dia_atraso, 0 dev_no_cobrado, t.nro_cuo_desde, t.nro_cuo_hasta,
          0 dev_suspenso, t.mto_deu_neto, t.sal_capital, t.sal_interes, t.mto_cargo,
          t.mto_impuesto, t.mto_mora, t.mto_mor_int, t.mto_punitorio, t.mto_iva_interes
     from ov_cta_vencidas a, cc_cta_corrientes x, pr_cta_pre_res4_tmp t
    where t.cod_persona = p_cod_persona
      and a.nro_cuenta = t.nro_cuenta
      and a.nro_cta_origen = x.nro_cuenta
    order by 17 desc, 3 desc;

  FUNCTION fu_obt_cod_actividad(p_cod_persona IN ge_clientes.cod_persona%TYPE)
      RETURN NUMBER IS
      v_cod_actividad ba_personas.cod_actividad%type;
  BEGIN
    SELECT (CASE WHEN NVL(ba.cod_actividad,701) = 702 THEN 701 ELSE NVL(ba.cod_actividad,701) END)
      INTO v_cod_actividad
      FROM ba_personas ba
     WHERE ba.cod_persona = p_cod_persona;

    RETURN v_cod_actividad;
  EXCEPTION
    WHEN OTHERS THEN
      v_cod_actividad := 701;
      RETURN v_cod_actividad;
  END;

  FUNCTION fu_obt_rub_eco_cliente(p_cod_persona IN ge_clientes.cod_persona%TYPE)
      RETURN VARCHAR2 IS
      v_cod_rub_economico ba_personas.cod_rub_primario%type;
  BEGIN
    SELECT nvl(ba.cod_rub_primario,ba.cod_rub_secundario)
      INTO v_cod_rub_economico
      FROM ba_personas ba
     WHERE ba.cod_persona = p_cod_persona;

    RETURN v_cod_rub_economico;
  EXCEPTION
    WHEN OTHERS THEN
      v_cod_rub_economico := '970108';
      RETURN v_cod_rub_economico;
  END;

begin
  v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(6);
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;
  -- se obtiene la cuenta origen con mayor saldo
  BEGIN
    SELECT MAX(t.nro_cuenta)
      INTO v_nro_cta_max
      FROM pr_cta_pre_res4_tmp t
     WHERE t.cod_persona = p_cod_persona
       AND t.mto_deu_neto = ( SELECT MAX(a.mto_deu_neto)
                                FROM pr_cta_pre_res4_tmp a
                               WHERE a.cod_persona = t.cod_persona );
  EXCEPTION
    WHEN OTHERS THEN
      v_nro_cta_max := p_nro_cta_ori;
  END;
  if  p_nro_cta_ori is null then
      raise_application_error(-20000,'Error. Nro de cuenta origen nulo');
  else
      v_nro_cta_ori:= p_nro_cta_ori;
  end if;

  v_lugar:= 'Inicio proceso principal: ' || p_cod_persona;
  v_mto_prestamo:= 0;
  v_cod_per_proc:= p_cod_persona;--fug_obt_cli_principal(v_nro_cta_ori);
  v_mto_prestamo:= nvl(p_mto_pre_nuevo,0);
  v_nro_solicitud:= null;

  for x in cur_datos loop
   begin
      v_nro_cta_proc:= x.nro_cuenta;
      v_fec_pri_vto:=null;
      v_dia_vto:=null;
      v_mes_vto:=null;
      v_ano_vto:=null;
      v_nro_cta_nueva:= null;
      v_nro_cuenta_debito:= null;
      v_nro_linea:= null;
      v_deb_automatico:= null;
      v_cod_gar_pre_ant:=null;
      v_nro_gar_pre_ant:=null;
      v_lugar:= 'Inicio Obtenemos la Fecha de Vencimiento en Junio-Persona: '||v_nro_cta_proc;
      IF p_cod_sub_mad_base = 97 THEN
        IF v_nro_cta_max = x.nro_cuenta THEN
           BEGIN
             SELECT MAX(fec_vencimiento)
               INTO v_fec_inicio
               FROM pr_cuotas
              WHERE nro_cuenta = x.nro_cuenta
                AND nro_cuota = p_nro_cuo_hasta;
           EXCEPTION 
             WHEN OTHERS THEN
               v_fec_inicio := v_fec_actual;
           END;
           IF v_fec_inicio < v_fec_actual THEN
              v_fec_inicio := v_fec_actual;
           END IF;
           v_lugar:= 'Seteamos la Fecha de Vencimiento : '||v_cod_per_proc;
           v_fec_pri_vto := add_months(v_fec_inicio, 1);
        END IF;       
        v_tip_can_rrr := 'C';--tipo RRR cancelación cuotas
      ELSE     
        IF v_nro_cta_max = x.nro_cuenta THEN
          --Obtenemos la Fecha de Vencimiento del prestamo en el mes actual, sino tiene, asumimos la fec_vto_Ult_Cuota
          v_mes_vto := to_number(to_char(add_months(v_fec_actual,1),'mm'));
          v_ano_vto := to_number(to_char(add_months(v_fec_actual,1),'yyyy'));
          if x.cod_modulo = 6 then --Es prestamos--
             begin
               select to_char(a.fec_vencimiento,'dd')
                 into v_dia_vto
                 from pr_cuotas a
                where a.nro_cuenta= x.nro_cuenta
                  and to_char(a.fec_vencimiento,'mmyyyy')= to_char(v_fec_actual,'mmyyyy')
                  and rownum=1;
             exception
               when no_data_found then
                 select to_char(max(a.fec_vencimiento),'dd')
                   into v_dia_vto
                   from pr_cuotas a
                  where a.nro_cuenta= x.nro_cuenta;
             end;
          else
             v_dia_vto := to_char(v_fec_actual,'dd');
          end if;

          v_lugar:= 'Seteamos la Fecha de Vencimiento: '||v_cod_per_proc;
          if v_mes_vto = 2 and v_dia_vto in ('29','30','31') then
             if MOD(v_ano_vto,4) = 0 then
                v_dia_vto:= '29'; --Es bisiesto--
             else
                v_dia_vto:= '28';
             end if;
          elsif v_mes_vto in (4,6,9,11) and v_dia_vto= '31' then
            v_dia_vto:= '30';
          end if;

          v_fec_pri_vto_cal:= trim(v_dia_vto || trim(to_char(add_months(v_fec_actual,1),'/mm/yyyy')));
          v_fec_pri_vto:= to_date(v_fec_pri_vto_cal ,'dd/mm/yyyy');
        END IF;  
        v_tip_can_rrr := 'T';--tipo RRR cancelación total
      END IF;  
      --v_nro_solicitud:=null;
      v_nro_cta_ori := null;

      IF v_nro_cta_max = x.nro_cuenta THEN
        if x.cod_modulo = 6 then
        --Obtenemos una de las garantias del prestamo anterior para asignar al nuevo
           begin
                   SELECT w.cod_garantia, w.nro_garantia
                   into v_cod_gar_pre_ant,v_nro_gar_pre_ant
            FROM
                 ( select z.cod_garantia,z.nro_garantia
                 from pr_cta_garantias z
                      where z.nro_cuenta = x.nro_cuenta
                          order by z.fec_insercion desc) w
                     WHERE  rownum = 1 ;
           exception
              when no_data_found then
                   v_cod_gar_pre_ant:=null;
                   v_nro_gar_pre_ant:=null;
              when others then
                     v_cod_gar_pre_ant:=null;
                     v_nro_gar_pre_ant:=null;
           end;
        else
          begin
                   SELECT w.cod_garantia, w.nro_garantia
                   into v_cod_gar_pre_ant,v_nro_gar_pre_ant
            FROM
                 ( select z.cod_garantia,z.nro_garantia
                 from ov_cta_garantias z
                      where z.nro_cuenta = x.nro_cuenta
                          order by z.fec_insercion desc) w
                     WHERE  rownum = 1 ;
           exception
              when no_data_found then
                   v_cod_gar_pre_ant:=null;
                   v_nro_gar_pre_ant:=null;
              when others then
                     v_cod_gar_pre_ant:=null;
                     v_nro_gar_pre_ant:=null;
           end;
        end if;
      END IF;  

      if x.cod_modulo = 6 then
       --Generar descuento del interes por Moratorio y Punitorio--
       v_lugar:= 'Generando descuentos para Cta: '||v_nro_cta_proc;
       if x.tip_interes = 'V' then
          v_mto_mor_interes := x.mto_mor_int;
          v_mto_mor_int_ade := 0;
       else --Es A-Adelantado--
          v_mto_mor_interes := 0;
          v_mto_mor_int_ade := x.mto_mor_int;
       end if;
       IF p_cod_sub_mad_base = 97 THEN
          v_cod_tra_padre := 360;
       ELSE
          v_cod_tra_padre := 359;
       END IF;
       prp_ins_des_prestamos(v_nro_cta_proc, 
                             v_cod_tra_padre,
                             x.mto_mora,
                             v_mto_mor_interes,
                             v_mto_mor_int_ade,
                             x.mto_punitorio,
                             0,
                             x.mto_impuesto,
                             'Reestructuracion. Resol4.');
      end if;

      IF v_nro_cta_max = x.nro_cuenta THEN
        --Validar Rub Eco + Sec Credtio para insertar--
        v_lugar := 'Validar Rub.Eco. Sec.Econ';
        v_cod_sec_credito := x.cod_sec_credito;
        v_cod_rub_economico := x.cod_rub_economico;
        if v_cod_sec_credito is null then
           v_cod_sec_credito := NVL(fu_obt_cod_actividad(v_cod_per_proc),701);
        end if;
        if v_cod_rub_economico is null then
           v_cod_rub_economico := NVL(fu_obt_rub_eco_cliente(v_cod_per_proc),'970108');
        end if;

        begin
          select 'S'
            into v_exi_rub_eco_modal
            from pr_rub_eco_modalidades x
           where x.cod_rub_economico = v_cod_rub_economico
             and x.cod_modulo = 6
             and x.cod_modalidad = p_cod_mad_base
             and x.referencia = v_cod_sec_credito;
        exception
          when too_many_rows then
               select x.cod_rub_economico
                 into v_cod_rub_economico
                 from pr_rub_eco_modalidades x
                where x.cod_rub_economico = v_cod_rub_economico
                  and x.cod_modulo = 6
                  and x.cod_modalidad = p_cod_mad_base
                  and x.referencia = v_cod_sec_credito
                  and rownum = 1;
          when no_data_found then
               select x.cod_rub_economico, x.referencia
                 into v_cod_rub_economico, v_cod_sec_credito
                 from pr_rub_eco_modalidades x
                where x.cod_modulo = 6
                  and x.cod_modalidad = p_cod_mad_base
                  and rownum = 1;
        end;

         v_lugar:= 'Procesando la Solicitud; '||v_cod_per_proc;
         PRP_GEN_SOL_ESP_RES4(v_cod_per_proc,
                                        p_cod_mad_base,
                                        p_cod_mon_base,
                                        v_mto_prestamo,--monto
                                        v_can_cuotas,--cuota
                                        'S',--grabar
                                        'N', --B-BRUTO o N-NETO
                                        v_fec_inicio,
                                        nvl(v_fec_pri_vto,null),--null,--primer vencimiento
                                        null,--tasa
                                        null,--canal
                                        null,--campaña
                                        'Sol. Reestruracion Res 04 BCP - Tasa Abierta',
                                        null,
                                        null,
                                        null,
                                        null,
                                        x.nro_cta_debito, --La misma ctade Débito del Préstamo Actual
                                        v_sub_mad_tas_abierta, --Enviamos la Nueva Sub_Modalidad (99)
                                        v_cod_rub_economico, --Rubro economico de Solicitud anterior
                                        v_cod_sec_credito, --Sector economico
                                        nvl(x.deb_automatico,'N') , --Enviamos si el anterior prestamo tenia deb_automatico o no.
                                        v_cod_gar_pre_ant, --cod garantia prest anterior
                                        v_nro_gar_pre_ant, --nro garantia prest anterior
                                        v_nro_solicitud);                               

       v_lugar:= 'Desembolsando; '||v_cod_per_proc || ' Nro.Sol: ' ||v_nro_solicitud;
       IF v_nro_solicitud is not null then
          --Ajustar el Tip_renovacion de la solicitud--
          update pr_solicitudes a
             set a.tip_renovacion = 'E' --Reestructurado--
           where a.nro_solicitud = v_nro_solicitud;

          --Insertar parametro de Seguro Anual Hipotecario--
          v_pre_nue_cal_seguros := nvl(fug_obt_pardinamico('PRE_NUE_CAL_SEGUROS',6,p_cod_mad_base),'N');
          if nvl(v_pre_nue_cal_seguros,'N') = 'S' then
             insert into Ba_Tab_dat_Adicionales
             (TAB_RELACION, REFERENCIA, PARAMETRO, VAL_PARAMETRO)
             values
             ('PR_SOLICITUDES', v_nro_solicitud, 'PRE_IND_CUO_CAL_SEGURO', 'S');
          end if;
        END IF;  
      END IF;
      IF v_nro_solicitud IS NOT NULL THEN
          --Actualizar nro de sol renovada--
          if x.cod_modulo = 6 then --Renovacion de Prestamos--
             update pr_cta_prestamos x
                set x.nro_sol_renovada = v_nro_solicitud --Reestructurado--
              where x.nro_cuenta = v_nro_cta_proc;
          else --Renovacion de Op. Vencidas--
             update ov_cta_vencidas x
                set x.nro_sol_renovada = v_nro_solicitud --Reestructurado--
              where x.nro_cuenta = v_nro_cta_proc;
          end if;

          --Insertar valores en tabla maestra espejo--
          v_tot_deuda := (nvl(x.sal_capital, p_mto_capital) +
                          nvl(x.sal_interes, p_mto_interes) +
                          nvl(x.mto_mora, p_mto_mor_capital) +
                          nvl(x.mto_mor_int, p_mto_mor_interes) +
                          nvl(x.mto_punitorio, p_mto_punitorio) +
                          nvl(x.mto_impuesto, p_mto_impuesto) +
                          nvl(x.mto_cargo, p_mto_cargo) +
                          nvl(x.mto_iva_interes, p_mto_iva_interes));

          v_tot_descuento := (nvl(x.mto_mora, p_mto_mor_capital) +
                              nvl(x.mto_mor_int, p_mto_mor_interes) +
                              nvl(x.mto_punitorio, p_mto_punitorio) +
                              nvl(x.mto_impuesto, p_mto_impuesto));

          insert into PR_CTA_PRE_REF_RES4
          (NRO_CUENTA, COD_PERSONA, COD_MONEDA, DIA_ATRASO,
           SAL_CAPITAL, SAL_INTERES, MTO_CARGO, MTO_IMPUESTO,
           MTO_MORA, MTO_MOR_INT, MTO_PUNITORIO, TOT_DEUDA,
           MTO_DEVENGADO, MTO_DEV_SUSPENSO, NRO_SOL_NUEVA,
           NRO_CTA_NUEVA, MOV_ACT, REVERSADO, FEC_SOL_REVERSA,
           FEC_REVERSION, COD_USU_REVERSION, HOR_REVERSION,
           MTO_SOL_NUEVA, MTO_TOT_DESCUENTO, MTO_IVA_INTERES,
           MTO_DEU_NETO, COT_MON_FUERTE, COD_MON_SOL_NUEVA,
           NRO_CUO_DESDE, NRO_CUO_HASTA, FEC_PROCESO, TIP_CAN_RRR)
          values
          (v_nro_cta_proc, v_cod_per_proc, x.cod_moneda, x.dia_atraso,
           nvl(x.sal_capital, p_mto_capital), nvl(x.sal_interes, p_mto_interes), nvl(x.mto_cargo, p_mto_cargo), nvl(x.mto_impuesto, p_mto_impuesto),
           nvl(x.mto_mora, p_mto_mor_capital), nvl(x.mto_mor_int, p_mto_mor_interes), nvl(x.mto_punitorio, p_mto_punitorio), v_tot_deuda,
           x.dev_no_cobrado, x.dev_suspenso, v_nro_solicitud,
           null, null, 'N', null,
           null, null, null,
           p_mto_pre_nuevo, v_tot_descuento, nvl(x.mto_iva_interes, p_mto_iva_interes),
           nvl(x.mto_deu_neto, p_mto_deu_neto), p_cot_mon_fuerte, p_cod_mon_base,
           nvl(x.nro_cuo_desde, p_nro_cuo_desde), nvl(x.nro_cuo_hasta, p_nro_cuo_hasta), v_fec_actual, v_tip_can_rrr);
       end if;

       P_RESULTADO:= V_RESULTADO;
       p_nro_sol_nueva:= v_nro_solicitud;

     exception
      when others then
        v_resultado := v_lugar||sqlerrm;
        P_RESULTADO := V_RESULTADO;
        p_nro_sol_nueva :=null;
     end;
   end loop;
   --- elimino los registros de la tabla temporal
   DELETE pr_cta_pre_res4_tmp
    WHERE cod_persona = p_cod_persona;
exception
  when others then
     raise_application_error(-20000,'ERROR: en PRP_GEN_SOL_OPE_RES4 '||sqlerrm);
end PRP_GEN_SOL_OPE_RES4;
/

