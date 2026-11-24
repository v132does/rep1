create or replace procedure it.prp_gen_pre_dif_resolucion4 (p_nro_cuenta ge_cuentas.nro_cuenta%type default null) is
-- Proposito: Generar Movimientos por diferimiento de Previsiones de Productos relacionados a RESOLUCION-4
-- Proceso diseñado para ejecutarse mensualmente - solo fin de mes

v_fec_actual           ge_calendarios.fec_actual%type;
v_fec_anterior         ge_calendarios.fec_anterior%type;  
v_ult_dia_mes_habil    ge_calendarios.ult_dia_mes_habil%type;
r_gmovi                ge_movimientos%rowtype;
v_nro_secuencia        ge_movimientos.nro_secuencia%type;
v_hora                 ge_movimientos.hora%type;
v_redondeo             number(2);
v_redondeo_ori         number(2);
v_redondeo_nva         number(2);
v_mto_pre_dif_actual   pr_re4_dif_previsiones.mto_pre_diferido%type;
v_mto_can_pre_diferido pr_re4_dif_previsiones.mto_pre_diferido%type;
v_cod_mon_local        ba_monedas.cod_moneda%type;
v_cotizacion           ge_cotizaciones.val_conversion%type;
v_cot_mon_local        ge_cotizaciones.val_conversion%type := 1;
rg_prdif               pr_re4_dif_previsiones%rowtype;
v_red_mon_local        number(2) := 0;
v_mes_a_diferir        pr_re4_dif_previsiones.can_mes_diferido%type;
v_can_mes_diferir      pr_re4_dif_previsiones.can_mes_diferido%type;
v_can_mes_diferimiento  pr_re4_dif_previsiones.can_mes_diferimiento%type;

--SDRES4COVI-171 - Cuentas Meses de Gracia: se agrega nvl para fec_ini_rrr / fec_inicio

cursor c_datos_nuevos is
select dat_cli.cod_persona            cod_cliente,
       dat_cli.cat_riesgo             cat_rie_cliente,
       dat_cli.fecha                  fec_dat_cliente,
       dat_cta.nro_cuenta              nro_cta_Nueva,
       nvl(dat_cta.fec_ini_rrr,dat_cta.fec_inicio)   fec_ini_cta_hijo,
       dat_cta.cod_moneda              cod_mon_cta_hijo,
       dat_his.tot_deu_real            tot_deu_cta_hijo,
       (dat_his.tot_deu_real - dat_his.dev_no_cobrado) sal_capital,
       dat_his.dev_no_cobrado          dev_no_cobrado,
           round(nvl(mov.monto, 0) *
                 decode(dat_cta.cod_moneda,
                        'GS',
                        1,
                        fug_obt_cotizacion(dat_cta.cod_moneda, v_fec_actual)),
                 0) mto_prevision,
       mov.monto                        mto_pre_mon_original,
       prev.porcentaje                  por_pre_cta_hijo,
       dat_cta.cat_renovaciones         cat_ren_cta_hijo                          
  from pr_cta_prestamos dat_cta,

       ge_par_dinamicos gpar,
       ge_cta_clientes  gcta,
       ge_clientes_his  dat_cli,
       ge_cla_operaciones dat_his,
       ge_movimientos   mov,
       pr_previsiones   prev
 where dat_cta.nro_cuenta = gcta.nro_cuenta
   /*and dat_cli.cat_riesgo > 1*/
   and gcta.cod_persona = dat_cli.cod_persona
   and gcta.relacion = 'P'
   and gpar.parametro = 'COD_MAD_RESOLUCION04'
   and dat_cta.cod_modulo = gpar.cod_modulo
   and dat_cta.cod_modalidad = gpar.cod_modalidad
   and dat_cta.estado not in ('N', 'I')
   and dat_cta.nro_cuenta = dat_his.nro_cuenta
   and dat_cli.fecha = pag_cal.FU_OBT_FEC_ANT_HAB (nvl(dat_cta.fec_ini_rrr,dat_cta.fec_inicio),31,1) 
   and dat_cta.nro_cuenta = mov.nro_cuenta
   and mov.cod_transaccion = 9730
   and dat_cta.nro_cuenta = prev.nro_cuenta
   and prev.fecha = mov.fecha
   and mov.fecha <= v_fec_actual
   and not exists (select 1
                     from pr_re4_dif_previsiones i
                    where i.nro_cuenta = dat_cta.nro_cuenta);                     
 

cursor c_actualizacion is 
select resol4.cod_persona,
       resol4.nro_cuenta nro_cta_original,
       resol4.nro_cta_nueva nro_cta_nueva,
       resol4.fec_ini_cta_nueva,
       i.cod_mon_cta_hijo, 
       i.cod_mon_cta_madre
 from pr_cta_pre_can_res4  resol4, pr_re4_dif_previsiones i
where nvl(resol4.reversado,'N') = 'N'
  and nvl(resol4.nro_cta_nueva,'X') = i.nro_cuenta
  and i.por_cta_hij_fec_ini is null 
union all
select resol4.cod_persona,
       resol4.nro_cuenta nro_cta_original,
       resol4.nro_cta_nueva nro_cta_nueva,
       resol4.fec_ini_cta_nueva,
       i.cod_mon_cta_hijo, 
       i.cod_mon_cta_madre
 from pr_cta_pre_ref_res4  resol4, pr_re4_dif_previsiones i
where nvl(resol4.reversado,'N') = 'N'
  and nvl(resol4.nro_cta_nueva,'X') = i.nro_cuenta
  and i.por_cta_hij_fec_ini is null 
union all
select i.cod_persona,
       null nro_cta_original,
       i.nro_cuenta nro_cta_nueva,
       i.fec_ini_cta_nueva fec_ini_cta_nueva,
       i.cod_mon_cta_hijo, 
       i.cod_mon_cta_madre
 from pr_re4_dif_previsiones i
 where i.por_cta_hij_fec_ini is null 
   and not exists (select 1 
                     from pr_cta_pre_can_res4 c  
                    where c.nro_cta_nueva = i.nro_cuenta
               and rownum < 2
                    union
                    select 1 
                     from pr_cta_pre_ref_res4 c  
             where c.nro_cta_nueva = i.nro_cuenta
               and rownum < 2);


----CURSOR PARA DIFERIMIENTO MENSUAL
Cursor c_dif_previsiones is
       select r.cod_persona,
              r.nro_cuenta,
              r.fec_actualizacion,
              r.mto_prevision,
              (r.mto_prevision / r.can_mes_diferimiento) mto_pre_diferido,
              r.mto_pre_dif_acumulado,
              r.can_mes_diferimiento, 
              r.can_mes_diferido,
              p.cod_modulo, 
              p.cod_modalidad,
              p.cod_oficina,
              p.cod_moneda,
              p.estado,
              nvl(p.fec_ini_rrr, p.fec_inicio) fec_inicio
         from pr_re4_dif_previsiones r, pr_cta_prestamos p
        where r.nro_cuenta = p.nro_cuenta
          and p.estado not in ('I', 'N')
          and r.can_mes_diferimiento > nvl(r.can_mes_diferido,0)
          and nvl(r.mto_pre_mon_original,0) > 0;


----CURSOR CUENTAS CANCELADAS - SE DEBE CANCELAR DIFERIMENTO POR EL SALDO NO PREVISIONADO
Cursor c_can_dif_previsiones is
       select r.cod_persona,
              r.nro_cuenta,
              r.fec_actualizacion,
              r.mto_prevision,
              r.mto_pre_diferido,
              r.mto_pre_dif_acumulado,
              r.can_mes_diferimiento, 
              r.can_mes_diferido,
              p.cod_modulo, 
              p.cod_modalidad,
              p.cod_oficina,
              p.cod_moneda,
              p.estado
         from pr_re4_dif_previsiones r, pr_cta_prestamos p
        where r.nro_cuenta = p.nro_cuenta
          and r.can_mes_diferimiento > r.can_mes_diferido
          and p.estado = 'N';



begin

   pag_cal.pr_obt_dat_calendar(6);
   v_fec_actual        := pag_cal.G_FEC_ACTUAL;
   v_fec_anterior      := pag_cal.FU_OBT_FEC_ANTERIOR(6);    
   v_ult_dia_mes_habil := pag_cal.G_ULT_DIA_MES_HABIL;
   v_hora              := to_char(sysdate,'HH24:MI:SS');
   v_hora              := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
   v_nro_secuencia     := 0;
   v_cod_mon_local     := pag_gen.fu_obt_mon_local;
   v_redondeo          := 0;
 
 --INSERCION DE PRODUCTOS COVID 
 for c_ins in c_datos_nuevos loop
   if c_ins.cod_mon_cta_hijo = v_cod_mon_local then
      v_cotizacion := v_cot_mon_local;
   else
      v_cotizacion := pag_gen.fu_obt_cotizacion(c_ins.cod_mon_cta_hijo, c_ins.fec_ini_cta_hijo);
   end if;
 
   
   begin
    select g.val_parametro                            
      into v_can_mes_diferimiento
      from pr_cta_prestamos  cta_nueva, ge_par_dinamicos g
     where cta_nueva.nro_cuenta = c_ins.nro_cta_nueva
       and g.parametro = 'CAN_MES_DIF_PRE_RESOLUCION04'
       and cta_nueva.cod_modulo = g.cod_modulo
       and cta_nueva.cod_modalidad = g.cod_modalidad;
    exception
      when no_data_found then
        null;
     end;   
 
 

   begin        
  
      insert into pr_re4_dif_previsiones r 
              (cod_persona, nro_cuenta, fec_ini_cta_nueva, 
               mto_prevision, mto_pre_mon_original, can_mes_diferimiento,
               mto_deu_real, mto_capital, mto_dev_no_cobrado,
               cotizacion,  cat_rie_cliente, fec_dat_rie_cliente,
               COD_MON_CTA_HIJO, POR_PRE_CTA_HIJO, cat_ren_cta_hijo)
        values(c_ins.cod_cliente, c_ins.nro_cta_nueva, c_ins.fec_ini_cta_hijo, 
               c_ins.mto_prevision, c_ins.mto_pre_mon_original, v_can_mes_diferimiento,
               c_ins.tot_deu_cta_hijo, c_ins.sal_capital, c_ins.dev_no_cobrado,
               v_cotizacion, c_ins.cat_rie_cliente, c_ins.fec_dat_cliente,
               c_ins.cod_mon_cta_hijo, c_ins.por_pre_cta_hijo, c_ins.cat_ren_cta_hijo);
    exception
      when others then
        raise_application_error(-20005, 'Error al insertar Previsiones Diferidas-'||sqlerrm);
     end; 
 
 end loop;


for c_act in c_actualizacion loop
   
   rg_prdif := null;
   rg_prdif.cod_mon_cta_hijo := c_act.cod_mon_cta_hijo;
   rg_prdif.cod_mon_cta_madre := c_act.cod_mon_cta_madre;
 
     begin  
      select cta_nva.tot_deu_real
        into rg_prdif.mto_capital
        from ge_cla_operaciones_his cta_nva
       where cta_nva.nro_cuenta = c_act.nro_cta_nueva
         and cta_nva.fecha = c_act.fec_ini_cta_nueva;
      exception
        when no_data_found then
              begin
                select cta_nva.tot_deu_real
                  into rg_prdif.mto_capital
                  from ge_cla_operaciones cta_nva
                 where cta_nva.nro_cuenta = c_act.nro_cta_nueva;
              exception
                when no_data_found then
                  null;
              end;
       end;   
       

      begin  
      select cta_ori.dia_atraso,
             cta_ori.cat_automatica,
             cta_ori.cat_renovaciones,
             cta_ori.cod_moneda,
             cta_ori.tot_deu_real
        into rg_prdif.dia_atraso,
             rg_prdif.cat_aut_cta_madre,
             rg_prdif.cat_ren_cta_madre,
             rg_prdif.cod_mon_cta_madre,
             rg_prdif.mto_tot_deu_cta_madre
        from ge_cla_operaciones_his cta_ori
       where cta_ori.nro_cuenta = c_act.nro_cta_original
         and cta_ori.fecha = pag_cal.FU_OBT_FEC_ANT_HAB (c_act.fec_ini_cta_nueva,31,1);
      exception
        when no_data_found then
              begin
                select cta_nva.tot_deu_real
                  into rg_prdif.mto_capital
                  from ge_cla_operaciones cta_nva
                 where cta_nva.nro_cuenta = c_act.nro_cta_nueva;
              exception
                when no_data_found then
                  null;
              end;
       end;         
       
       
       
  begin 
    select prv_cta_ori.porcentaje,
           prv_cta_ori.monto,
           prv_cta_ori.fecha ,
           prv_cta_ori.porcentaje  
      into rg_prdif.por_pre_cta_madre, 
           rg_prdif.Mto_Prev_Cta_Madre,
           rg_prdif.Fec_Pre_Cta_Madre,
           rg_prdif.por_pre_cta_hijo
      from pr_previsiones prv_cta_ori
     where prv_cta_ori.nro_cuenta = c_act.nro_cta_original
       and prv_cta_ori.fecha in (select max(x.fecha) 
                                   from pr_previsiones x
                                  where x.nro_cuenta = prv_cta_ori.nro_cuenta 
                                    and x.fecha < c_act.fec_ini_cta_nueva);
    exception
      when no_data_found then
        begin 
          select prv_cta_ori.porcentaje,
                 prv_cta_ori.monto,
                 prv_cta_ori.fecha   
            into rg_prdif.por_pre_cta_madre, 
                 rg_prdif.Mto_Prev_Cta_Madre,
                 rg_prdif.Fec_Pre_Cta_Madre
            from ov_previsiones prv_cta_ori
           where prv_cta_ori.nro_cuenta = c_act.nro_cta_original
             and prv_cta_ori.fecha in (select max(x.fecha) 
                                         from ov_previsiones x
                                        where x.nro_cuenta = prv_cta_ori.nro_cuenta 
                                          and x.fecha < c_act.fec_ini_cta_nueva);
          exception
            when no_data_found then
              null;
           end;   
     end;   
    
    begin
      select prv_cta_ori_ini.monto ,
             prv_cta_ori_ini.fecha
        into rg_prdif.Mto_Pre_Cta_Mad_Fec_Ini,
             rg_prdif.Fec_Pre_Ini_Cta_Ori
        from pr_previsiones  prv_cta_ori_ini
       where prv_cta_ori_ini.nro_cuenta = c_act.nro_cta_original
         and prv_cta_ori_ini.fecha = c_act.fec_ini_cta_nueva;
    exception
      when no_data_found then
        begin
          select prv_cta_ori_ini.monto ,
                 prv_cta_ori_ini.fecha
            into rg_prdif.Mto_Pre_Cta_Mad_Fec_Ini,
                 rg_prdif.Fec_Pre_Ini_Cta_Ori
            from ov_previsiones  prv_cta_ori_ini
           where prv_cta_ori_ini.nro_cuenta = c_act.nro_cta_original
             and prv_cta_ori_ini.fecha = c_act.fec_ini_cta_nueva;
        exception
          when no_data_found then
            null;
         end;  
     end;     
     
     begin
       select prv_cta_nva.porcentaje,               
              prv_cta_nva.monto,                     
              prv_cta_nva.fecha                     
         into rg_prdif.por_cta_hij_fec_ini,
              rg_prdif.mto_pre_cta_hij_fec_ini,
              rg_prdif.fec_pre_cta_hijo 
         from pr_previsiones prv_cta_nva
        where prv_cta_nva.nro_cuenta =  c_act.nro_cta_nueva
          and prv_cta_nva.fecha = c_act.fec_ini_cta_nueva;
      exception
       when no_data_found then
         null;
      end;         
   
   v_redondeo_ori := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6, null, rg_prdif.cod_mon_cta_madre );
   v_redondeo_nva := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6, null, rg_prdif.cod_mon_cta_hijo);
      
      update pr_re4_dif_previsiones p
         set p.por_pre_cta_madre        = nvl(rg_prdif.por_pre_cta_madre,p.por_pre_cta_madre), 
             p.fec_pre_ini_cta_ori      = nvl(rg_prdif.fec_pre_ini_cta_ori, p.fec_pre_ini_cta_ori),
             p.fec_pre_cta_madre        = nvl(rg_prdif.fec_pre_cta_madre, p.fec_pre_cta_madre),
             p.fec_pre_cta_hijo         = nvl(rg_prdif.fec_pre_cta_hijo, p.fec_pre_cta_hijo),
             p.mto_prev_cta_madre       = nvl(round(rg_prdif.mto_prev_cta_madre/
                                          decode(rg_prdif.cod_mon_cta_madre,'GS', v_cot_mon_local, 
                                          fug_obt_cotizacion(rg_prdif.cod_mon_cta_madre,c_act.fec_ini_cta_nueva))
                                          ,v_redondeo_ori), p.mto_prev_cta_madre),
             p.por_cta_mad_fec_ini      = nvl(rg_prdif.por_cta_mad_fec_ini,p.por_cta_mad_fec_ini), 
             p.mto_pre_cta_mad_fec_ini  = nvl(round(rg_prdif.mto_pre_cta_mad_fec_ini/
                                          decode(rg_prdif.cod_mon_cta_madre,'GS', v_cot_mon_local, 
                                          fug_obt_cotizacion(rg_prdif.cod_mon_cta_madre,c_act.fec_ini_cta_nueva))
                                          ,v_redondeo_ori),p.mto_pre_cta_mad_fec_ini), 
             p.por_cta_hij_fec_ini      = nvl(rg_prdif.por_cta_hij_fec_ini, p.por_cta_hij_fec_ini),
             p.mto_pre_cta_hij_fec_ini  = nvl(round(rg_prdif.mto_pre_cta_hij_fec_ini/
                                          decode(rg_prdif.cod_mon_cta_hijo,'GS', v_cot_mon_local, 
                                          fug_obt_cotizacion(rg_prdif.cod_mon_cta_hijo,c_act.fec_ini_cta_nueva))
                                          ,v_redondeo_nva),p.mto_pre_cta_hij_fec_ini),
             p.dia_atraso               = rg_prdif.dia_atraso,
             p.cat_aut_cta_madre        = rg_prdif.cat_aut_cta_madre,
             p.cat_ren_cta_madre        = rg_prdif.cat_ren_cta_madre,
             p.cod_mon_cta_madre        = rg_prdif.cod_mon_cta_madre,
             p.mto_tot_deu_cta_madre    = rg_prdif.mto_tot_deu_cta_madre                                          
       where p.cod_persona = c_act.cod_persona
         and p.nro_cuenta = c_act.Nro_Cta_Nueva;
         
 
 end loop;     
   
   --Procesar solo fin de mes: DIFERIMIENTO DE PREVISIONES - PRODUCTOS COVID-19
   if v_fec_actual = v_ult_dia_mes_habil then

     for diprev in c_dif_previsiones loop
          
          if diprev.can_mes_diferimiento = (diprev.can_mes_diferido + 1 ) then
             v_mto_pre_dif_actual := round(diprev.mto_prevision - diprev.mto_pre_dif_acumulado,v_red_mon_local);
          else
             v_mes_a_diferir := round((v_fec_actual-diprev.fec_inicio)/30);
             if v_mes_a_diferir > (diprev.can_mes_diferimiento +1) then
                v_mto_pre_dif_actual := round(diprev.mto_pre_diferido,v_red_mon_local) * v_mes_a_diferir;
             else
                v_mto_pre_dif_actual := round(diprev.mto_pre_diferido,v_red_mon_local);
                v_mes_a_diferir := 1;                
             end if;
          end if;
     
       if v_mto_pre_dif_actual > 0 then
          
          --insertar movimiento:
          r_gmovi.cod_usuario    := user;
          r_gmovi.hora           := v_hora;
          r_gmovi.fecha          := v_fec_actual;
          r_gmovi.fec_valor      := v_fec_actual;
          r_gmovi.cod_mod_padre  := diprev.cod_modulo;
          r_gmovi.cod_mad_padre  := diprev.cod_modalidad;
          r_gmovi.cod_modulo     := diprev.cod_modulo;
          r_gmovi.cod_modalidad  := diprev.cod_modalidad;
          r_gmovi.cod_oficina    := diprev.cod_oficina;
          r_gmovi.cod_ofi_origen := diprev.cod_oficina;
          --r_gmovi.cod_moneda     := diprev.cod_moneda;
          r_gmovi.cod_moneda     := v_cod_mon_local;
          r_gmovi.estado         := 'N';
          r_gmovi.reversado      := 'N';
          r_gmovi.emi_aviso      := 'N';
          r_gmovi.protegido      := 'N';
          --r_gmovi.nro_cuenta     := diprev.nro_cuenta;
          r_gmovi.referencia     := diprev.nro_cuenta;
          r_gmovi.est_cuenta     := diprev.estado;
          if v_nro_secuencia + 2 > 999 then
             v_nro_secuencia := 0;
             v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
             r_gmovi.hora           := v_hora;
          end if;  
            --- Constituir previsiones
           v_nro_secuencia         := v_nro_secuencia + 1;
           r_gmovi.nro_secuencia   := v_nro_secuencia;
           r_gmovi.cod_tra_padre   := 9124;
           r_gmovi.cod_transaccion := 9124;
           r_gmovi.monto           := v_mto_pre_dif_actual;         
           r_gmovi.concepto        :=  diprev.nro_cuenta||' '||'DIFERIMIENTO PREVISION - RESOL.04';
           pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
       
         update pr_re4_dif_previsiones x
            set x.can_mes_diferido = nvl(x.can_mes_diferido,0) + v_mes_a_diferir,
                x.mto_pre_diferido = v_mto_pre_dif_actual,
                x.mto_pre_dif_acumulado = nvl(x.mto_pre_dif_acumulado,0) + v_mto_pre_dif_actual,
                x.fec_actualizacion = v_fec_actual
          where x.nro_cuenta = diprev.nro_cuenta;
        end if;
      end loop;   
    
   end if;   
 
   --CUENTAS CANCELADAS - SE DEBE CANCELAR DIFERIMIENTO POR EL SALDO PREVISIONADO NO DIFERIDO
   for candif in c_can_dif_previsiones loop
       
        v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,candif.cod_moneda,null);
        v_mto_can_pre_diferido := round(candif.mto_prevision - candif.mto_pre_dif_acumulado, v_redondeo);
        v_can_mes_diferir := candif.can_mes_diferimiento - candif.can_mes_diferido;
       
     if candif.mto_pre_diferido > 0 then
          
        --insertar movimiento:
        r_gmovi.cod_usuario    := user;
        r_gmovi.hora           := v_hora;
        r_gmovi.fecha          := v_fec_actual;
        r_gmovi.fec_valor      := v_fec_actual;
        r_gmovi.cod_mod_padre  := candif.cod_modulo;
        r_gmovi.cod_mad_padre  := candif.cod_modalidad;
        r_gmovi.cod_modulo     := candif.cod_modulo;
        r_gmovi.cod_modalidad  := candif.cod_modalidad;
        r_gmovi.cod_oficina    := candif.cod_oficina;
        r_gmovi.cod_ofi_origen := candif.cod_oficina;
         --r_gmovi.cod_moneda     := candif.cod_moneda;
        r_gmovi.cod_moneda     := v_cod_mon_local;
        r_gmovi.estado         := 'N';
        r_gmovi.reversado      := 'N';
        r_gmovi.emi_aviso      := 'N';
        r_gmovi.protegido      := 'N';
        --r_gmovi.nro_cuenta     := candif.nro_cuenta;
        r_gmovi.referencia     := candif.nro_cuenta;
        r_gmovi.est_cuenta     := candif.estado;
        if v_nro_secuencia + 2 > 999 then
           v_nro_secuencia := 0;
           v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
           r_gmovi.hora           := v_hora;
        end if;  
          --- Constituir previsiones
         v_nro_secuencia         := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         r_gmovi.cod_tra_padre   := 9124;
         r_gmovi.cod_transaccion := 9124;
         r_gmovi.monto           := v_mto_can_pre_diferido;         
         r_gmovi.concepto        := 'CANCELACION DIF. PREVISION - RESOL.04';
         pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
       
       update pr_re4_dif_previsiones x
          set x.can_mes_diferido = nvl(x.can_mes_diferido,0) + v_can_mes_diferir,
              x.mto_pre_diferido = v_mto_can_pre_diferido,
              x.mto_pre_dif_acumulado = nvl(x.mto_pre_dif_acumulado,0) + v_mto_can_pre_diferido,
              x.fec_actualizacion = v_fec_actual
        where x.nro_cuenta = candif.nro_cuenta;
          
     End if;
    End loop;  
 
end;
/

