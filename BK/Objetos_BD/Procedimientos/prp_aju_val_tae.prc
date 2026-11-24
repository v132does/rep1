CREATE OR REPLACE PROCEDURE IT.PRP_AJU_VAL_TAE(
  p_nro_sol_sim       in number,
  p_tipo                in varchar2, --Tipo 'SI' -Simulacion/'SO'- Solicitud
  p_dia_plazo in number default null) --Se envia solo para simulacion
IS
--PROCEDIMIENTO PARA AJUSTAR EN FORMA AUTOMATICA EL VALOR
--DE LA COMISION POR DESEMBOLSO PARA AJUSTAR AL TAE.
--SOLO PARA HB Y ATM. PARA PRESTAMOS DE TIPO 'B' Bruto(No aplica a Neto)
--Si es mayor la comision al tae, asume monto de tae
/*Obtengo el monto máximo posible para la comision por desembo transacción 704
   1)v_auxiliar1 = 1+(porcentaje del TAE/100)
   2)v_auxiliar2 = Potencia(v_auxiliar1,(1/(365/30)))
   3)v_aux_tir   = (v_auxiliar2-1)*100
   4)v_aux_tan   = ((v_aux_tir*365)/30)
   5)se aplica el v_aux_tir a cada cuota para obtner el VNA, en el cursor
     (monto_cuota)/Potencia(1+(v_aux_tir/100),nro_cuota)
   6)El valor del VNA que es v_aux_mon_tot, se resta al monto total del prestamo
     para obtener el monto máximo de la comision
     v_mto_max_comision =(:PR_SOLICITUDES.TOT_PRESTAMO - v_aux_mon_tot)
   */
v_dif_mto_maximo      number := 0;
v_mto_car_prestamo    number(18,4):=0;
v_exi_tra_704         varchar2(1) := 'N';
v_cod_tra_comision    number:='704';
v_auxiliar1           number := 0;
v_auxiliar2           number := 0;
v_aux_tir             number := 0;
v_aux_tan             number := 0;
v_aux_mon_tot         number := 0;
v_mto_max_comision    number := 0;
v_piz_tasa_min        number(18,4):=0;
v_piz_tasa_max        number(18,4):=0;
v_piz_tasa_actual     number(18,4):=0;
v_piz_tasa_tae        number(18,4):=0;
v_mensaje             varchar2(3000);
v_redondeo            number(18,4):=0;
v_mto_max_diferencia  number(18,4):=0;
v_lugar               varchar2(3000);
v_mto_seg_prestamo    number(18,4):=0;

v_tae             number := 0;
v_tan             number := 0;
v_pro_dias        number;
v_tip_interes     varchar2(1):=null;
v_dif_tae         number;
v_mto_tot_cargo   number;
v_dif_mto_tae   number;
v_mto_max_imp   number;
v_dif_max_imp   number;


--******* Para solicitudes *****************************************
Cursor pr_solicitudes is
  select a.nro_solicitud,a.cod_modulo,a.cod_modalidad,a.cod_moneda,a.cod_oficina,
    a.cod_sub_modalidad, a.tot_prestamo,a.mto_cargo,a.iva_desglose,a.mto_interes,
    a.tip_monto, a.tot_desembolsar, a.tot_desembolso, a.monto, a.dia_plazo,
    a.fec_inicio,a.per_vto_capital,a.tip_interes
    from pr_solicitudes a
     where a.nro_solicitud= p_nro_sol_sim;

Cursor pr_sol_cuotas is
 Select (mto_capital+val_interes)/power(1+(v_aux_tir/100),nro_cuota) tot_cuota
   From pr_sol_cuotas
   where nro_solicitud = p_nro_sol_sim
     and nro_cuota > 0;

Cursor pr_sol_cargos is
 Select a.cod_transaccion,a.mto_mon_prestamo,a.val_tasa,a.cod_moneda,
   a.monto,a.mto_mon_prestamo mto_equivalente, a.cod_ent_seguro
   From pr_sol_cargos a
   where a.nro_solicitud = p_nro_sol_sim;

--******* Para simulaciones *****************************************

Cursor pr_simulaciones is
  select a.nro_simulacion nro_solicitud,a.cod_modulo,a.cod_modalidad,a.cod_moneda,
    a.cod_sub_modalidad, a.tot_prestamo,a.tot_cargos mto_cargo,a.iva_desglose,
    a.tip_monto,a.tot_prestamo - a.tot_cargos tot_desembolsar, a.monto, p_dia_plazo dia_plazo,
    a.fec_inicio,a.per_vto_capital,a.tip_interes
    from pr_simulaciones a
     where a.nro_simulacion= p_nro_sol_sim;

Cursor pr_sim_cuotas is
 Select (mto_capital+mto_interes)/power(1+(v_aux_tir/100),nro_cuota) tot_cuota
   From pr_sim_cuotas
   where nro_simulacion = p_nro_sol_sim
     and nro_cuota > 0;

Cursor pr_sim_cargos is
 Select a.cod_transaccion,a.mto_equivalente mto_mon_prestamo,a.val_tasa,a.cod_moneda,
 a.monto,a.mto_equivalente mto_equivalente, a.cod_ent_seguro
   From pr_sim_cargos a
   where a.nro_simulacion = p_nro_sol_sim;

PROCEDURE pr_obtener_tasas_de_pizarra(p_cod_modulo in number,
                                   p_cod_modalidad in number,
                                   p_cod_moneda in varchar2,
                                   p_monto   in number,
                                   p_dia_plaz in number,
                                   p_cod_sub_modalidad in number) IS
BEGIN
   v_piz_tasa_actual := null;
   v_piz_tasa_min    := null;
   v_piz_tasa_max    := null;
   v_piz_tasa_tae    := null;
   --:variables.lugar := 'obtener_tasas de pizarras';
   pap_pre.pr_obt_tas_pizarra(p_cod_modulo, p_cod_modalidad, p_cod_moneda,
                              p_dia_plaz, p_monto, null,
                              v_piz_tasa_min,
                              v_piz_tasa_max,
                              v_piz_tasa_actual,
                              v_piz_tasa_tae,
                              p_cod_sub_modalidad);
                              
    If nvl(v_piz_tasa_min,0) = 0 and nvl(v_piz_tasa_max,0) = 0 and nvl(v_piz_tasa_actual,0) = 0
        and nvl(fug_obt_pardinamico('MAD_TAS_CERO', p_cod_modulo,p_cod_modalidad, p_cod_moneda, null, p_cod_sub_modalidad),'N') = 'N' then
       v_mensaje:=('Debe definir la Pizarra para el Tipo de Préstamo.');
    End if;
END;
-- INICIO DEL PROCEDIMIENTO PRINCIPAL----------------------------------------
BEGIN
 BEGIN PRE_INI_APLICACION;PAE_CNF.G_COD_MODULO:=1; END;

 if p_tipo is null then
   RAISE_APPLICATION_ERROR(-20000,'Debe enviar tipo SO-SI');
 end if;

if upper(p_tipo)='SO' then
 --LOGICA PARA SOLICITUDES
 FOR sol in pr_solicitudes loop
   --- Veo el tipo de redondeo de los calculos ------------------------------------------
   v_lugar:='Verificamos redondeo';
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', sol.cod_modulo, sol.cod_modalidad, sol.cod_moneda,
   sol.cod_oficina, sol.cod_sub_modalidad);
   -- Obtengo el monto máximo de diferencia posible
   v_mto_max_diferencia := fug_obt_pardinamico('MTO_MAX_DIF_COM_TAE', null, null, sol.cod_moneda, null, null);
   v_lugar:='Obtenemos tasa de Pizzarra';
   pr_obtener_tasas_de_pizarra(sol.cod_modulo,sol.cod_modalidad,sol.cod_moneda,sol.monto,
                                   sol.dia_plazo,sol.cod_sub_modalidad);


   --Ajuste WA:para optimizacion del tae 26/08
    PRP_OBT_TAS_PRE_TAE(p_nro_sol_sim, v_tae,v_tan);
    --Obtenemos promedio de dia para verificar de vuelta el tae
    v_pro_dias:=0;
    BEGIN
     select AVG(dia_interes) -- BSEVOCORE-367 sin redondeo 
       into v_pro_dias
     from pr_sol_cuotas
     where nro_solicitud = p_nro_sol_sim
     and nro_cuota > 0;
   EXCEPTION
     WHEN OTHERS THEN
       v_pro_dias:=30;
   END;
   --Obtenemos el tipo de interes de dia para verificar de vuelta el tae
    BEGIN
     select tip_interes
       into v_tip_interes
     from pr_solicitudes
     where nro_solicitud = p_nro_sol_sim;
   EXCEPTION
     WHEN OTHERS THEN
        v_tip_interes:='V';
   END;
   --llamamos al proceso que se llama en el Desembolso
  v_tae := fus_obt_tae_tasa(v_tan,round(v_pro_dias,0),v_tip_interes);
                           
   if v_tae > v_piz_tasa_tae then
       v_lugar:='Cargamos auxiliar 1';
       v_auxiliar1 := 1+(v_piz_tasa_tae/100);
       Begin
           Select power(v_auxiliar1,(1/(365/v_pro_dias))) -- BSEVOCORE-367 utiliza v_pro_dias en lugar de 30 fijo
           Into v_auxiliar2
           from dual;
       Exception
          When others then
           v_auxiliar2 := null;
       End;
       v_lugar:='Cargamos auxiliar tir';
       v_aux_tir := (v_auxiliar2-1)*100;
       v_lugar:='Cargamos auxiliar tan';
       v_aux_tan := ((v_aux_tir*365)/v_pro_dias); -- BSEVOCORE-367 utiliza v_pro_dias en lugar de 30 fijo

       v_lugar:='Recorremos pr_sol_cuotas';
       Begin

        FOR cuo in pr_sol_cuotas loop
             v_aux_mon_tot := round((v_aux_mon_tot + cuo.tot_cuota),v_redondeo);
         End Loop;
       End ;
       -- Obtengo el monto máximo de comisión.
       v_mto_max_comision := round((sol.tot_prestamo - v_aux_mon_tot),v_redondeo);
       --Controla contra el parametro dinámico que la diferencia entre el monto por la comision de desembolso no supere el monto máximo.
       v_lugar:='Valido y Controlo contra el parametro dinámico que la diferencia entre el monto por la comision de desembolso no supere el monto máximo';
       v_exi_tra_704 := 'N';
       v_lugar:='Recorremos pr_sol_cargos';
       v_mto_car_prestamo:=0;
       v_mto_seg_prestamo:=0;
       FOR car in pr_sol_cargos loop
           If car.COD_TRANSACCION = 704 then
              v_dif_mto_maximo:= car.mto_mon_prestamo - nvl(v_mto_max_comision,0);
              v_mto_car_prestamo:= v_mto_car_prestamo + car.mto_mon_prestamo;
              v_exi_tra_704 := 'S';
          End If;

          if car.cod_ent_seguro is not null then
            v_mto_seg_prestamo:= nvl(v_mto_seg_prestamo,0) + nvl(car.monto,0);
          end if;

       end loop;
       --Solo si lo que se cobra es mayor al maximo posible se ajusta
       ---if nvl(v_mto_car_prestamo,0) > nvl(v_mto_max_comision,0) then
             --Controla que exista comisión por desembolso 704
             v_lugar:='Control que exista 704';
             If v_exi_tra_704 = 'N' then
                  RAISE_APPLICATION_ERROR(-20000,'No existe el cargo por comisión de desembolso. No se puede ajustar la comisión en forma automática.!');
             end IF;

             --v_lugar:='Control Mto Max Comision';

             v_lugar:='Control Mto Max Comision';
             if v_dif_mto_maximo > v_mto_max_diferencia then
                 RAISE_APPLICATION_ERROR(-20000,'El monto calculado para la comisión por desembolso es: '||v_mto_max_comision|| '.-'||
                         'La diferencia entre el monto calculado y el original es: '||v_dif_mto_maximo||'.-'||
                         'La diferencia supera el Mto. máximo definido: '||v_mto_max_diferencia||'-.'||
                         'No se puede ajustar la comisión en forma automática.!');
             Else
                if v_dif_mto_maximo <= 0 then
                   --Entra por negativo;
                   -- Obtenemos El total de los cargos de la solicitud
                   v_dif_tae:= v_tae - v_piz_tasa_tae;
                   v_mto_tot_cargo:=sol.mto_cargo;
                   v_dif_mto_tae:= round(((v_mto_tot_cargo*v_dif_tae)/100),0);
                   v_mto_max_comision:= v_dif_mto_tae;
                   v_dif_mto_maximo:= v_mto_car_prestamo - v_dif_mto_tae;
                elsif v_mto_max_comision < 0 then
                    if abs(v_mto_max_comision) < v_mto_car_prestamo then
                      v_mto_max_imp:=0;
                      v_dif_max_imp:=0;
                      v_mto_max_imp:= ((v_mto_car_prestamo / 2)/1.1);
                      if abs(v_mto_max_comision) > v_mto_max_imp then
                          v_mto_max_comision:= abs(v_mto_max_imp);
                          v_dif_mto_maximo:= v_mto_car_prestamo - v_mto_max_comision;
                      else
                          v_mto_max_comision:= abs(v_mto_max_comision);
                          v_dif_mto_maximo:= v_mto_car_prestamo - v_mto_max_comision;
                      end if;
                    else
                     if v_mto_max_comision < 0 then
                         RAISE_APPLICATION_ERROR(-20000,'El monto calculado para la comisión por desembolso no es valido '||v_mto_max_comision||'.-'||
                          'No se puede ajustar la comisión en forma automática.!');
                      end if;

                    end if;
                end if;
               IF v_mto_max_comision > 0 then
                --Si se debe ajustar el TAE
                v_lugar:='Actualiza el cargo';
                    update pr_sol_cargos w
                       set w.monto= v_mto_max_comision,
                           w.mto_mon_prestamo = v_mto_max_comision
                         where w.nro_solicitud= sol.nro_solicitud
                           and w.cod_transaccion= v_cod_tra_comision;

                v_lugar:='Actualiza pr_solicitudes II';

                --Actualiza importe a desembolsar
                 update pr_solicitudes x
                  set x.tot_desembolsar= (x.tot_desembolsar + v_dif_mto_maximo), --- v_mto_seg_prestamo,
                      x.mto_cargo= (x.mto_cargo- v_dif_mto_maximo)
                  where x.nro_solicitud=sol.nro_solicitud;
               else
                   RAISE_APPLICATION_ERROR(-20000,'El monto calculado para la comisión por desembolso no es valido '||v_mto_max_comision||'.-'||
                          'No se puede ajustar la comisión en forma automática.!');
               end if;
             End if;
       ---end if;
   end if;
 end loop;

elsif upper(p_tipo)='SI' then
 --LOGICA PARA SIMULACIONES
 FOR sol in pr_simulaciones loop
   --- Veo el tipo de redondeo de los calculos ------------------------------------------
   v_lugar:='Verificamos redondeo';
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', sol.cod_modulo, sol.cod_modalidad, sol.cod_moneda,
   null, sol.cod_sub_modalidad);
   -- Obtengo el monto máximo de diferencia posible
   v_mto_max_diferencia := fug_obt_pardinamico('MTO_MAX_DIF_COM_TAE', null, null, sol.cod_moneda, null, null);
   v_lugar:='Obtenemos tasa de Pizzarra';
   pr_obtener_tasas_de_pizarra(sol.cod_modulo,sol.cod_modalidad,sol.cod_moneda,sol.monto,
                                   sol.dia_plazo,sol.cod_sub_modalidad);
  --Ajuste WA:para optimizacion del tae 26/08
   PRP_OBT_TAS_PRE_TAE(p_nro_sol_sim, v_tae,v_tan);
     --Obtenemos promedio de dia para verificar de vuelta el tae
    v_pro_dias:=0;
    BEGIN
     select AVG(PER_DIAS) -- BSEVOCORE-367 sin redondeo
       into v_pro_dias
     from pr_sim_cuotas
     where nro_simulacion = p_nro_sol_sim
     and nro_cuota > 0;
   EXCEPTION
     WHEN OTHERS THEN
       v_pro_dias:=30;
   END;
   --Obtenemos el tipo de interes de dia para verificar de vuelta el tae
    BEGIN
     select tip_interes
       into v_tip_interes
     from pr_simulaciones
     where nro_simulacion= p_nro_sol_sim;
   EXCEPTION
     WHEN OTHERS THEN
        v_tip_interes:='V';
   END;

   if v_tip_interes is null then
     v_tip_interes:='V';
   end if;
   --llamamos al proceso que se llama en el Desembolso
   v_tae := fus_obt_tae_tasa(v_tan,round(v_pro_dias,0),v_tip_interes);

   if v_tae > v_piz_tasa_tae then
         v_lugar:='Cargamos auxiliar 1';
         v_auxiliar1 := 1+(v_piz_tasa_tae/100);
         Begin
             Select power(v_auxiliar1,(1/(365/v_pro_dias))) -- BSEVOCORE-367 utiliza v_pro_dias en lugar de 30 fijo
             Into v_auxiliar2
             from dual;
         Exception
            When others then
             v_auxiliar2 := null;
         End;
         v_lugar:='Cargamos auxiliar tir';
         v_aux_tir := (v_auxiliar2-1)*100;
         v_lugar:='Cargamos auxiliar tan';
         v_aux_tan := ((v_aux_tir*365)/v_pro_dias); -- BSEVOCORE-367 utiliza v_pro_dias en lugar de 30 fijo

         v_lugar:='Recorremos pr_sim_cuotas';
         Begin

          FOR cuo in pr_sim_cuotas loop
               v_aux_mon_tot := round((v_aux_mon_tot + cuo.tot_cuota),v_redondeo);
           End Loop;
         End ;
         -- Obtengo el monto máximo de comisión.
         v_mto_max_comision := round((sol.tot_prestamo - v_aux_mon_tot),v_redondeo);
         --Controla contra el parametro dinámico que la diferencia entre el monto por la comision de desembolso no supere el monto máximo.
         v_lugar:='Valido y Controlo contra el parametro dinámico que la diferencia entre el monto por la comision de desembolso no supere el monto máximo';
         v_exi_tra_704 := 'N';
         v_lugar:='Recorremos pr_sol_cargos';
         v_mto_car_prestamo:=0;
         v_mto_seg_prestamo:=0;
         FOR car in pr_sim_cargos loop
             If car.COD_TRANSACCION = 704 then
                v_dif_mto_maximo:= car.mto_mon_prestamo - nvl(v_mto_max_comision,0);
                v_mto_car_prestamo:= v_mto_car_prestamo + car.mto_mon_prestamo;
                v_exi_tra_704 := 'S';
            End If;

            if car.cod_ent_seguro is not null then
              v_mto_seg_prestamo:= nvl(v_mto_seg_prestamo,0) + nvl(car.monto,0);
            end if;

         end loop;
         --Solo si lo que se cobra es mayor al maximo posible se ajusta
         --if nvl(v_mto_car_prestamo,0) > v_mto_max_comision then
               --Controla que exista comisión por desembolso 704
               v_lugar:='Control que exista 704';
               If v_exi_tra_704 = 'N' then
                    RAISE_APPLICATION_ERROR(-20000,'No existe el cargo por comisión de desembolso. No se puede ajustar la comisión en forma automática.!');
               end IF;
               /*
               v_lugar:='Control Mto Max Comision';
               if v_mto_max_comision < 0 then
                    RAISE_APPLICATION_ERROR(-20000,'El monto calculado para la comisión por desembolso no es valido '||v_mto_max_comision||'.-'||
                            'No se puede ajustar la comisión en forma automática.!');
               end if;*/
               v_lugar:='Control Mto Max Comision';
               if v_dif_mto_maximo > v_mto_max_diferencia then
                   RAISE_APPLICATION_ERROR(-20000,'El monto calculado para la comisión por desembolso es: '||v_mto_max_comision|| '.-'||
                           'La diferencia entre el monto calculado y el original es: '||v_dif_mto_maximo||'.-'||
                           'La diferencia supera el Mto. máximo definido: '||v_mto_max_diferencia||'-.'||
                           'No se puede ajustar la comisión en forma automática.!');
               Else
                 if v_dif_mto_maximo < 0 then
                   --Entra por negativo;
                   --Obtenemos diferencia de Tae
                   v_dif_tae:= v_tae - v_piz_tasa_tae;
                   -- Obtenemos El total de los cargos de la solicitud
                   v_mto_tot_cargo:=sol.mto_cargo;
                   v_dif_mto_tae:= round(((v_mto_tot_cargo*v_dif_tae)/100),0);
                   v_mto_max_comision:= v_dif_mto_tae;
                   v_dif_mto_maximo:= v_mto_car_prestamo - v_dif_mto_tae;
                  elsif v_mto_max_comision < 0 then
                    if abs(v_mto_max_comision) < v_mto_car_prestamo then
                      v_mto_max_imp:=0;
                      v_dif_max_imp:=0;
                      v_mto_max_imp:= ((v_mto_car_prestamo / 2)/1.1);
                      if abs(v_mto_max_comision) > v_mto_max_imp then
                          v_mto_max_comision:= abs(v_mto_max_imp);
                          v_dif_mto_maximo:= v_mto_car_prestamo - v_mto_max_comision;
                      else
                          v_mto_max_comision:= abs(v_mto_max_comision);
                          v_dif_mto_maximo:= v_mto_car_prestamo - v_mto_max_comision;
                      end if;
                    else
                     if v_mto_max_comision < 0 then
                         RAISE_APPLICATION_ERROR(-20000,'El monto calculado para la comisión por desembolso no es valido '||v_mto_max_comision||'.-'||
                          'No se puede ajustar la comisión en forma automática.!');
                      end if;

                    end if;
               end if;
                  --Si se debe ajustar el TAE
                  v_lugar:='Actualiza el cargo';
                      update pr_sim_cargos w
                         set w.monto= v_mto_max_comision,
                             w.mto_equivalente = v_mto_max_comision
                           where w.nro_simulacion= sol.nro_solicitud
                             and w.cod_transaccion= v_cod_tra_comision;

                  v_lugar:='Actualiza pr_simulaciones II';
                  --Actualiza importe a desembolsar
                    update pr_simulaciones x
                    set x.tot_prestamo= x.tot_prestamo + v_dif_mto_maximo ,
                        x.tot_cargos= x.tot_cargos- v_dif_mto_maximo
                    where x.nro_simulacion=sol.nro_solicitud;

               End if;
         --end if;
   end if;
 end loop;

end if;


EXCEPTION
     WHEN OTHERS THEN
            raise_application_error(-20000,'Error AjuValTae,Lugar:'||v_lugar||' - '||sqlerrm);
END;
/

