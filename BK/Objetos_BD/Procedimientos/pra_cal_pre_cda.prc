create or replace procedure it.pra_cal_pre_cda
(p_nro_cuenta in varchar2 default null,
 p_fec_inicio in date default null,
 p_fec_fin    in date default null) is
 v_nro_cuenta varchar2(20);
 v_nro_cupon number(7);
 v_dev_anterior number(18,2);
 v_fec_inicio date;
 v_fec_fin    date;
 v_fec_desde  date;
 v_fec_hasta  date;
 v_fec_actual date;
 v_VAL_TASA number;
 v_FEC_VIG_TASA date;
 v_pri_dia_mes date;
 v_TIP_VALOR varchar2(1);
 v_TIP_TASA  varchar2(1);
 v_dias       number;
 v_dias_2     number;
 v_mto_interes number(18,2);
 v_error number(1) := 0;
 v_fec_sistema date := pag_cal.FU_OBT_FEC_ACTUAL(3);
 v_can_cuentas number;
 cursor ctas is
    SELECT COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, COD_MONEDA,
           NVL(ult_vencimiento,FEC_APERTURA) FEC_ULT_CAPITALIZACION,
           FEC_APERTURA,
           CAPITAL, FEC_VENCIMIENTO, COD_TASA, TAS_PERSONALIZADA
      FROM AH_CTA_CERTIFICADOS a,
      (select nro_cuenta cuenta, max(fec_vencimiento) ult_vencimiento
         from ah_cupones
        where fec_vencimiento <= v_fec_actual
        group by nro_cuenta) b
     WHERE FEC_APERTURA between nvl(p_fec_inicio,v_fec_sistema) and nvl(p_fec_fin,v_fec_sistema)
       and b.cuenta(+) = a.nro_cuenta
       and (p_nro_cuenta is null or nro_cuenta = p_nro_cuenta)
       and fec_vencimiento >= add_months(v_fec_sistema,-1);
 cursor cups is
    SELECT nro_cupon,fec_vencimiento, mto_interes
      from ah_cupones
     where nro_cuenta = v_nro_cuenta
       and fec_vencimiento between v_fec_desde+1 and v_fec_hasta+1
      order by fec_vencimiento;
begin
-- inicio y fin del devengamiento
select min(fec_apertura), max(fec_vencimiento), nvl(count(*),0)
  into v_fec_inicio, v_fec_fin, v_can_cuentas
  from ah_cta_certificados
 where fec_vencimiento >= add_months(v_fec_sistema,-1)
   and (nro_cuenta = p_nro_cuenta or p_nro_cuenta is null)
   and fec_apertura between nvl(p_fec_inicio,v_fec_sistema) and nvl(p_fec_fin,v_fec_sistema);
-- solo se ejecuta si hay datos a procesar en el periodo
if v_fec_inicio is not null and v_fec_fin is not null and  nvl(v_can_cuentas,0) > 0 then
   v_fec_actual := add_months(v_fec_inicio,-1);
   -- borro los datos anteriores
   delete from ah_pre_dev_cda a
     where exists (select 0
                     from ah_cta_certificados b
                    where FEC_APERTURA between nvl(p_fec_inicio,v_fec_sistema) and nvl(p_fec_fin,v_fec_sistema)
                      and (p_nro_cuenta is null or nro_cuenta = p_nro_cuenta)
                      and fec_vencimiento >= add_months(v_fec_sistema,-1)
                      and a.nro_cuenta = b.nro_cuenta);
   -- ciclo mensual
   loop
      v_fec_actual := last_day(add_months(v_fec_actual,1));
      v_pri_dia_mes := to_date('01'||to_char(v_fec_actual,'mmyyyy'),'ddmmyyyy');
      --
      for ct in ctas loop
          v_error := 0;
          v_nro_cuenta := ct.nro_cuenta;
          -- borro los registros anteriores de la cuenta
          if ct.fec_apertura > v_pri_dia_mes then
             v_fec_desde := ct.fec_apertura;
          else
             v_fec_desde := v_pri_dia_mes;
          end if;
          if ct.fec_vencimiento > v_fec_actual then
             v_fec_hasta := v_fec_actual;
          else
             v_fec_hasta := ct.fec_vencimiento;
          end if;
          -- obtengo la tasa
          PAG_GEN.PR_OBT_VAL_TASA(ct.COD_MODULO,
                              ct.COD_MODALIDAD, ct.COD_OFICINA,
                              ct.NRO_CUENTA, ct.COD_MONEDA, ct.CAPITAL,
                              ct.TAS_PERSONALIZADA, ct.COD_TASA, 609, v_fec_desde,
                              v_VAL_TASA, v_FEC_VIG_TASA, v_TIP_VALOR,
                              v_TIP_TASA);
          if v_tip_valor <> 'P' then
             raise_application_error(-20000,'Tasa no es porcentual. Verificar la cuenta '||v_nro_cuenta);
          end if;
          if v_tip_tasa <> 'F' then
             raise_application_error(-20000,'Tasa debe ser Fija. Verificar la cuenta '||v_nro_cuenta);
          end if;
          if v_val_tasa > 100 then
             raise_application_error(-20000,'Tasa por encima del 100%. Verificar la cuenta '||v_nro_cuenta);
          end if;
          -- recorro si hay cortes de cupones intermedios en el periodo
          for cp in cups loop
              v_fec_hasta := cp.fec_vencimiento -1;
              v_dias := v_fec_hasta - v_fec_desde + 1;
              v_mto_interes := FLOOR(PAG_GEN.FU_CAL_INT_SIMPLE(CT.CAPITAL, V_DIAS, V_VAL_TASA));
              select nvl(sum(mto_interes),0)
                into v_dev_anterior
                from ah_pre_dev_cda
               where nro_cuenta = v_nro_cuenta
                 and nro_cupon = cp.nro_cupon;
              if nvl(v_mto_interes,0) + nvl(v_dev_anterior,0) <> cp.mto_interes then
                 v_mto_interes := cp.mto_interes  - nvl(v_dev_anterior,0);
              end if;
              insert into ah_pre_dev_cda
                   (nro_cuenta, nro_cupon, ano, mes, mto_interes, cod_modulo, cod_modalidad, cod_oficina,
                    fec_inicio, fec_final, dias)
              values
                   (v_nro_cuenta, cp.nro_cupon,to_char(v_fec_hasta,'yyyy'), to_char(v_fec_hasta,'mm'),
                    v_mto_interes,
                    ct.cod_modulo, ct.cod_modalidad, ct.cod_oficina, v_fec_desde, v_fec_hasta, v_dias);
              -- sigte fec _inicio
              v_fec_desde := cp.fec_vencimiento;
          end loop;
          -- vuelvo a poner la fecha hasta final
          if ct.fec_vencimiento > v_fec_actual then
             v_fec_hasta := v_fec_actual;
          else
             v_fec_hasta := ct.fec_vencimiento - 1;
          end if;

          if v_fec_hasta >= v_fec_desde then
            -- busco el nro de cupon que corresponde al periodo
            v_error := 0;
            begin
              select nro_cupon
                into v_nro_cupon
                from ah_cupones x
               where nro_cuenta = v_nro_cuenta
                 and fec_vencimiento = (select min(fec_vencimiento)
                                          from ah_cupones
                                         where nro_cuenta = v_nro_cuenta
                                           and fec_vencimiento > v_fec_desde);
              select nvl(sum(mto_interes),0)
                into v_dev_anterior
                from ah_pre_dev_cda
               where nro_cuenta = v_nro_cuenta
                 and nro_cupon = v_nro_cupon;
            exception
                when others then
                    raise_application_error(-20000,'No existe cupon posterior al '||to_char(v_fec_desde,'dd/mm/yyyy')||' para la Cta. '||v_nro_cuenta);
                    --insert into xx_errores
                    -- values ('No existe cupon posterior al '||to_char(v_fec_desde,'dd/mm/yyyy')||' para la Cta. '||v_nro_cuenta);
                    v_error := 1;
            end;
            if v_error = 0 then
               v_dias := v_fec_hasta - v_fec_desde + 1;
               v_dias_2 := v_fec_hasta - ct.fec_ult_capitalizacion + 1; -- desde el ultimo vencimiento
               -- calculo del interes desde el ultimo vencimiento
               v_mto_interes := FLOOR(PAG_GEN.FU_CAL_INT_SIMPLE(CT.CAPITAL, V_DIAS_2, V_VAL_TASA));
               -- resto al total de interes - devengado anterior
               v_mto_interes := nvl(v_mto_interes,0) - nvl(v_dev_anterior,0);
               insert into ah_pre_dev_cda
                     (nro_cuenta, nro_cupon, ano, mes, mto_interes, cod_modulo, cod_modalidad, cod_oficina,
                      fec_inicio, fec_final, dias)
                values
                     (v_nro_cuenta, v_nro_cupon,to_char(v_fec_hasta,'yyyy'), to_char(v_fec_hasta,'mm'),
                      v_mto_interes,
                      ct.cod_modulo, ct.cod_modalidad, ct.cod_oficina, v_fec_desde, v_fec_hasta, v_dias);
            end if;
          end if;
      end loop;
      exit when v_fec_actual > v_fec_fin;
   end loop;
   /* SE ANULA PORQUE NO TENEMOS TABLA DE INTERFAZ
   -- inserto en la tabla de interface
   insert into in_oso_aahdeven
      (COD_OFICINA,SUB_APLIC,NRO_CUENTA,MES,ANO,DIAS,MTO_INTERES)
   select b.cod_oficina, decode(b.cod_moneda,pag_gen.fu_obt_mon_local,'04',pag_gen.fu_obt_mon_fuerte,'06'),
          b.nro_cuenta, a.mes, a.ano, sum(a.dias), sum(a.mto_interes)
     from ah_cta_certificados b, ah_pre_dev_cda a
    where FEC_APERTURA between nvl(p_fec_inicio,v_fec_sistema) and nvl(p_fec_fin,v_fec_sistema)
      and (p_nro_cuenta is null or b.nro_cuenta = p_nro_cuenta)
      and fec_vencimiento >= add_months(v_fec_sistema,-1)
      and a.nro_cuenta = b.nro_cuenta
    group by b.cod_oficina, decode(b.cod_moneda,pag_gen.fu_obt_mon_local,'04',pag_gen.fu_obt_mon_fuerte,'06'),
          b.nro_cuenta, a.mes, a.ano;
   */       
   -- commit
   commit;
end if;
end;
/

