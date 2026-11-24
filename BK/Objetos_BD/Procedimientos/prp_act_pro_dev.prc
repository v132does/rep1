CREATE OR REPLACE PROCEDURE IT.PRP_ACT_PRO_DEV(
  P_NRO_CUENTA IN VARCHAR2 default null,
  P_NRO_ORDEN IN NUMBER  DEFAULT NULL,
  P_FEC_CANCELACION IN DATE  DEFAULT NULL
)
IS
--Actualizamos devengamiento de cargado por operaciones y 1-1 Parcial
v_mto_cancelacion    number(18,2);
v_fec_ven_pri_cuota date;
v_fec_ven_ult_cuota date;
v_ult_dia_mes       number;
v_fec_ult_dia_mes   date;
v_dia_fec_actual    number;
v_can_dias_dev      number;
v_can_dias_sig_cuota  number;
v_mes  varchar2(50);
v_anho  varchar2(50);
v_fec_actual         date := pag_cal.fu_obt_fec_actual(6);
v_fec_ant_cal        date := pag_cal.FU_OBT_FEC_ANTERIOR(6);
v_lugar              varchar2(3000);
v_fec_ult_devengado  date:= null;
v_fec_dev_inicio     date;
v_tip_interes        varchar2(10);
v_mto_interes        pr_cuotas.sal_interes%type;
v_mto_capital        pr_cuotas.mto_capital%type;
v_mto_cap_cuo_actual   pr_cuotas.mto_capital%type;
v_mto_int_cuo_actual   pr_cuotas.mto_interes%type;
v_nro_orden     number(10);
v_mto_int_mov_dev pr_cuotas.mto_capital%type;
v_nro_cuota_dev number(10);
v_devengar        varchar2(1):='S';
v_fec_vto_ult_cuo  date;
v_fec_vto_cuo_dev  date;
v_fec_vto_cuo_actual  date;
v_cod_modulo      number;
v_nro_cuo_dev     number;
v_nro_cuo_desde   number;
v_fec_dev_final   date;
v_fec_anterior    date;
v_cod_mon_local   varchar2(10):= pag_gen.FU_OBT_MON_LOCAL;
v_cod_moneda      varchar2(10);
v_can_dia_actual  number(3);
v_can_dia_acumulado  number(3);
v_can_dia_anterior number(3);
v_mto_dev_anterior  pr_cuotas.mto_capital%type;
v_mto_dev_acumulado pr_cuotas.mto_capital%type;
v_mto_dev_dia       number(18,4);
v_mto_dev_dia_esp   number(18,4);
v_mto_tot_esp       number(18,4);
v_tot_dias          number(3);
v_dif_dia_ant       number(3);
v_dif_dia_act       number(3);
v_pri_registro      varchar2(1);
v_mto_dev_actual    number(18,2);
v_can_dia_dev_actual    number(6);
v_dia_devengar       number(4);
v_dia_devengado       number(4);
v_ult_proceso        varchar2(1);
v_fec_utilizar       date;
v_fec_sig_cuota      date;
v_mto_dev_mes    number(18,2);
v_mto_int_sig_cuota number(18,2);
v_ult_nro_cuo   number(18);
v_pri_vez       varchar2(1);
v_dias_sig_cuota number(3);
v_mto_dev_sig_cuota number(18,2);
v_nro_cuenta  varchar2(20);
v_fec_cancelacion date;
v_nom_dia varchar2(100);
v_fec_ant_can date;
v_dif_dias number(5);
v_nro_cuo_dev_act number(5);
v_especial varchar2(1):='N';
v_tot_dias_esp number(3);
v_fec_ant_cuota date;
--Para cargar devengamiento paralelo
CURSOR c_cur_dat_dev_par IS
  select a.*
    from ge_dev_res4 a
      where a.nro_cuenta= nvl(P_NRO_CUENTA,a.nro_cuenta)
       and a.nro_orden= nvl(p_nro_orden,a.nro_orden)
       order by a.nro_cuenta,a.nro_orden;
--- Cursor de cuotas
   cursor c_cuotas is
     select a.* from pr_cuotas a
       where a.nro_cuenta= v_nro_cuenta
        and a.nro_cuota=v_nro_cuo_dev_act
        order by a.nro_cuota;

--- Cursor de cuotas
   cursor c_cuotas_sig is
     select a.nro_cuota,a.mto_interes, b.mes, b.anho, b.mto_dev_dia, b.mto_sig_cuo,
     a.fec_vencimiento, b.nro_cuo_final
       from pr_cuotas a, GE_PRO_DEV_RES4 b
       where a.nro_cuenta= v_nro_cuenta
        and a.nro_cuenta= b.nro_cuenta
        and a.nro_cuota > b.nro_cuo_inicial and a.nro_cuota <= b.nro_cuo_final
        and a.nro_cuota> b.nro_cuo_dev
        order by a.nro_cuota;

BEGIN
   Begin PRE_INI_APLICACION;PAE_CNF.G_COD_MODULO:= 1; pae_cnf.G_PROGRAMA := 'GPPROFIN';  End;
   --Para devengado paralelo
    FOR x IN c_cur_dat_dev_par LOOP
       --Para la cuota Inicial
       v_nro_cuenta:= x.nro_cuenta;

       v_fec_cancelacion:= nvl(P_FEC_CANCELACION, x.fec_cancelacion);
        v_especial:='N';
       --Buscamos el maximo Nro de CUOTA PARA ESE MES DE CANCELACION
       v_nro_cuo_dev:=null;
       BEGIN
        select max(a.nro_cuota)
          into v_nro_cuo_dev_act
           from pr_cuotas a
          where a.nro_cuenta= v_nro_cuenta
             and to_char(a.fec_vencimiento,'yyyymm') =  to_char(v_fec_cancelacion,'yyyymm');
       EXCEPTION
         WHEN OTHERS THEN
          v_nro_cuo_dev_act:= null;
       END;
       for cuo in c_cuotas loop
          v_mes:=null;
          v_anho:= null;
          v_mto_tot_esp:= null;
          --Obtenemos mes
          if to_char(v_fec_cancelacion, 'mmyyyy')= to_char(cuo.fec_vencimiento, 'mmyyyy') then
             v_mes:=  to_number(to_char(cuo.fec_vencimiento, 'mm'));
             v_anho:= to_number(to_char(cuo.fec_vencimiento, 'yyyy'));

             v_fec_ult_dia_mes:=  LAST_DAY(cuo.fec_vencimiento);
             v_ult_dia_mes:= to_number(to_char(v_fec_ult_dia_mes,'dd'));
             --Verificamos si es lunes (comportamiento especial)
             v_fec_ant_can:=null;
             v_dif_dias:=null;
             --Buscamos la fecha habil anterior
             v_fec_ant_can:= pag_cal.fu_obt_fec_ant_hab(v_fec_cancelacion,
                                        null,
                                        1);
             -- Hacemos la diferencia
             select v_fec_cancelacion - v_fec_ant_can
             into v_dif_dias
             from dual;

             if v_dif_dias = 1 then
                 if v_fec_ant_can <  cuo.fec_vencimiento
                   and cuo.fec_vencimiento > (v_fec_cancelacion+1)/*v_fec_cancelacion*/ then
                   v_dif_dias:=0;
                   v_dif_dias:= cuo.fec_vencimiento - v_fec_cancelacion;
                   --9 Dias por ejemplo
                   v_dia_fec_actual:=to_number(to_char(cuo.fec_vencimiento,'dd'));
                    v_especial:='S';
                    --Excepcion
                    if v_nro_cuenta = '0766140075' then
                       v_especial:='N';
                    end if;
                 else
                   --Excepcion
                   if v_nro_cuenta='0766243303' then
                     v_dia_fec_actual:= to_number(to_char(v_fec_cancelacion,'dd')-1);
                   else
                     v_dia_fec_actual:= to_number(to_char(v_fec_cancelacion,'dd'));
                   end if;
                 end if;
             else
               --fue fin de semana o hubo feriados por medio
                --Si justo era el dia de vencimiento, se toma desde ese día
                if v_fec_ant_can <  cuo.fec_vencimiento
                   and cuo.fec_vencimiento < v_fec_cancelacion    then
                   v_dia_fec_actual:=to_number(to_char(cuo.fec_vencimiento,'dd'));
                elsif v_fec_ant_can <  cuo.fec_vencimiento
                   and cuo.fec_vencimiento > (v_fec_cancelacion+1) then
                   v_dif_dias:=0;
                   v_dif_dias:= cuo.fec_vencimiento - v_fec_ant_can/*v_fec_cancelacion*/;
                   --9 Dias por ejemplo
                  -- v_dia_fec_actual:=(to_number(to_char(cuo.fec_vencimiento,'dd'))) - v_dif_dias;
                   v_dia_fec_actual:=(to_number(to_char(cuo.fec_vencimiento,'dd'))) ;
                    v_especial:='S';

                else
                    v_dia_fec_actual:=to_number(to_char(v_fec_ant_can,'dd'))+1;
                 end if;

             end if;
             --v_dia_fec_actual:= to_number(to_char(v_fec_cancelacion,'dd'));
             v_can_dias_dev:= v_ult_dia_mes - v_dia_fec_actual;
             --Obtenemos la cantidad de Dias de las cuotas
             begin
              select b.fec_vencimiento, b.mto_interes
                into v_fec_sig_cuota,v_mto_int_sig_cuota
                  from pr_cuotas b
                    where b.nro_cuenta= v_nro_cuenta
                    and b.nro_cuota= cuo.nro_cuota+1;
             exception
               when others then
                 v_fec_sig_cuota:= null;

             end;
                --Obtenemos la ultima cuota
              begin
              select x.nro_cuota
                into v_ult_nro_cuo
                  from pr_cuotas x
                    where x.nro_cuenta= v_nro_cuenta
                    and x.fec_vencimiento= x.fec_dev_fin;

             exception
               when others then
                 v_ult_nro_cuo:= null;

             end;
             v_tot_dias:= v_fec_sig_cuota - cuo.fec_vencimiento;
             --v_can_dias_sig_cuota:= v_fec_sig_cuota -

             v_mto_int_cuo_actual:= v_mto_int_sig_cuota;
             v_mto_dev_dia:= round(v_mto_int_cuo_actual/v_tot_dias,2);
             v_mto_dev_mes := round(v_mto_dev_dia * v_can_dias_dev,0);

             if  v_especial='S' THEN
                  --Obtenemos la cantidad de Dias de las cuotas
                   begin
                    select b.fec_vencimiento
                      into v_fec_ant_cuota
                        from pr_cuotas b
                          where b.nro_cuenta= v_nro_cuenta
                          and b.nro_cuota= cuo.nro_cuota-1;
                   exception
                     when others then
                       v_fec_ant_cuota:= null;
                    end;

                    v_tot_dias_esp:= cuo.fec_vencimiento- v_fec_ant_cuota;
                    v_mto_dev_dia_esp:= round(cuo.mto_interes/v_tot_dias_esp,2);
                    --Excepcion
                    if v_nro_cuenta='0366111930' then
                      v_dif_dias:= v_dif_dias-1;
                    end if;
                    v_mto_tot_esp:= v_mto_dev_dia_esp * (v_dif_dias);
                    v_mto_dev_mes:= v_mto_dev_mes + v_mto_tot_esp;

             END IF;


             --Dias que devenga siguiente cuota
             v_dias_sig_cuota:=0;
             v_mto_dev_sig_cuota:=0;
             v_dias_sig_cuota:= v_fec_sig_cuota- v_fec_ult_dia_mes;
             v_dias_sig_cuota:= v_dias_sig_cuota ; --Porque no se devenga el ultimo dia
             v_mto_dev_sig_cuota:=round(v_dias_sig_cuota * v_mto_dev_dia,0);


             insert into GE_PRO_DEV_RES4(nro_cuenta, nro_orden, mes,anho,mto_dev_dia, Can_Dias_Dev, Mto_Devengado,
             nro_cuo_inicial, nro_cuo_final,DIAS_SIG_CUO, MTO_SIG_CUO,NRO_CUO_DEV,
             cod_moneda, fec_cancelacion )
             values(x.nro_cuenta, x.nro_orden,to_number(v_mes),to_number(v_anho),v_mto_dev_dia,v_can_dias_dev, v_mto_dev_mes,
             cuo.nro_cuota,v_ult_nro_cuo,v_dias_sig_cuota,v_mto_dev_sig_cuota,cuo.nro_cuota,
             x.cod_moneda,x.fec_cancelacion );
             commit;
          end if;
    end loop;

   --Para las giguientes Cuotas
    v_pri_vez:='S';
    FOR w IN c_cuotas_sig LOOP
           v_mes:=null;
           v_anho:= null;
           if w.nro_cuota <> w.nro_cuo_final  then
             v_mes:=  to_char(w.fec_vencimiento, 'mm');
             v_anho:= to_char(w.fec_vencimiento, 'yyyy');
             v_fec_ult_dia_mes:=  LAST_DAY(w.fec_vencimiento);
             v_ult_dia_mes:= to_number(to_char(v_fec_ult_dia_mes,'dd'));
             v_dia_fec_actual:= to_number(to_char(w.fec_vencimiento,'dd'));
             v_can_dias_dev:= v_ult_dia_mes - v_dia_fec_actual;
             v_can_dias_dev:= v_can_dias_dev;
             --Obtenemos la cantidad de Dias de las cuotas
             begin
              select b.fec_vencimiento, b.mto_interes
                into v_fec_sig_cuota,v_mto_int_sig_cuota
                  from pr_cuotas b
                    where b.nro_cuenta= x.nro_cuenta
                    and b.nro_cuota= w.nro_cuota+1;
             exception
               when others then
                 v_fec_sig_cuota:= null;

             end;

             v_tot_dias:= v_fec_sig_cuota - w.fec_vencimiento;
             --v_can_dias_sig_cuota:= v_fec_sig_cuota -

             v_mto_int_cuo_actual:= v_mto_int_sig_cuota;
             v_mto_dev_dia:= round(v_mto_int_cuo_actual/v_tot_dias,2);
             v_mto_dev_mes := round(v_mto_dev_dia * v_can_dias_dev,0);
             --Se le suman el monto del anterior
             IF v_pri_vez='S' THEN
                v_mto_dev_mes:= v_mto_dev_mes + w.mto_sig_cuo;
             ELSE
                v_mto_dev_mes:= v_mto_dev_mes + v_mto_dev_sig_cuota;
             END IF;

             --Dias que devenga siguiente cuota
             v_dias_sig_cuota:=0;
             v_mto_dev_sig_cuota:=0;
             v_dias_sig_cuota:= v_tot_dias - v_can_dias_dev;
             v_dias_sig_cuota:= v_dias_sig_cuota ;-- No se devenga el ultimo dia
             v_mto_dev_sig_cuota:=round(v_dias_sig_cuota * v_mto_dev_dia,0);

             insert into GE_PRO_DEV_RES4(nro_cuenta, nro_orden, mes,anho,mto_dev_dia, Can_Dias_Dev, Mto_Devengado,
             nro_cuo_inicial, nro_cuo_final,DIAS_SIG_CUO, MTO_SIG_CUO,nro_cuo_dev,
             cod_moneda, fec_cancelacion)
             values(x.nro_cuenta, x.nro_orden,to_number(v_mes),to_number(v_anho),v_mto_dev_dia,v_can_dias_dev, v_mto_dev_mes,
             w.nro_cuota,v_ult_nro_cuo,v_dias_sig_cuota,v_mto_dev_sig_cuota ,w.nro_cuota,
             x.cod_moneda, x.fec_cancelacion);
             commit;
             v_pri_vez:='N';
          else
            --Es para la última Cuota
             v_mes:=  to_char(w.fec_vencimiento, 'mm');
             v_anho:= to_char(w.fec_vencimiento, 'yyyy');
             v_fec_ult_dia_mes:=  LAST_DAY(w.fec_vencimiento);
             v_ult_dia_mes:= to_number(to_char(v_fec_ult_dia_mes,'dd'));
             v_dia_fec_actual:= to_number(to_char(w.fec_vencimiento,'dd'));
             --Calculado anteriormente
             v_can_dias_dev:= v_dias_sig_cuota;
             v_mto_dev_mes:=v_mto_dev_sig_cuota;
              --Dias que devenga siguiente cuota
             v_dias_sig_cuota:=0;
             v_mto_dev_sig_cuota:=0;
             v_dias_sig_cuota:= 0;
             v_dias_sig_cuota:= 0 ;-- No se devenga el ultimo dia
             v_mto_dev_sig_cuota:=0;

             insert into GE_PRO_DEV_RES4(nro_cuenta, nro_orden, mes,anho,mto_dev_dia, Can_Dias_Dev, Mto_Devengado,
             nro_cuo_inicial, nro_cuo_final,DIAS_SIG_CUO, MTO_SIG_CUO,nro_cuo_dev,
             cod_moneda, fec_cancelacion)
             values(x.nro_cuenta, x.nro_orden,to_number(v_mes),to_number(v_anho),v_mto_dev_dia,v_can_dias_dev, v_mto_dev_mes,
             w.nro_cuota,v_ult_nro_cuo,v_dias_sig_cuota,v_mto_dev_sig_cuota ,w.nro_cuota,
             x.cod_moneda, x.fec_cancelacion);
             commit;
             v_pri_vez:='N';

          end if;

    end loop;
end loop;
EXCEPTION
 WHEN OTHERS THEN
    raise_application_error(-20000, 'ERROR. Act.Proy Devengado: '||v_lugar||'-'||SQLERRM);
END PRP_ACT_PRO_DEV;
/

