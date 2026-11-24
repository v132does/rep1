CREATE OR REPLACE PACKAGE BODY IT.pap_pcs IS

 v_redondeo_ml number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, pag_gen.fu_obt_mon_local);
----------------------------------------------------------------------------------
--Paquete manejador de Calculos de Cuotas de Solicitudes de Préstamo            --
--Inicialmente se trataran los casos de Cuotas con Refuerzo de Capital          --
--Issue relacionado: ---DYDMR-9246 Incidencia SAU - ITGF - Propuesta de Crédito --
--LCabrera - Noviembre/2018                                                     --
------------------------------------------------------------------------------
procedure pr_obt_val_cuota 
          (p_nro_solicitud in pr_solicitudes.nro_solicitud%type default null,
           p_cod_modalidad in number,
           p_cod_moneda in varchar2,
           p_monto in number, 
           p_can_cuotas in number, 
           p_mto_refuerzo in number default 0, 
           p_can_cuo_refuerzo in number default 0, 
           p_val_tasa in number, 
           p_fec_inicio in date,
           p_fec_pri_vencimiento in date,
           p_dias in number default null,
           p_exo_impuesto in varchar2 default 'N') is
     
  WW_FRANCES                NUMBER;
  WW_TASADIV                NUMBER := p_val_tasa / 36500; 
  WW_VLSALAN                NUMBER(18,2) := p_monto;
  WW_TTCUOTA                NUMBER(18,2) := NULL;
  WW_DFCUOTA                NUMBER(18,2); 
  WW_TTCAPIT                NUMBER(18,2) := 0;
  WW_TTREFUE                NUMBER(18,2) := p_mto_refuerzo; --Mto. Refuerzo
  WW_CTREFUE                NUMBER(10)  := p_can_cuo_refuerzo; ---Cantidad Cuota Refuerzo
  WW_NRO                    NUMBER(10)  := 0;
  WW_VECES                  NUMBER(10)  := 0;
  ww_redondeo               number(2) := 0;   -- redondeo a cero para moneda local
  ww_limite                 number     := 10;  -- limite superior para ajustes de cuotas iguales en moneda local
  v_dias                    number := 30.416666666666666666666666666667;
  v_fec_vcto                date;
  v_fec_ven_anterior        date := p_fec_inicio;
  v_tot_interes             number := 0;
  v_mto_capital             number;
  v_val_interes             number;
  v_val_cuota               number;
  v_tot_cuota               number;
  v_dia_interes             number;
  v_sumo                    varchar(2) := null;
  v_fec_inicio              date := p_fec_inicio;
  v_ant_diferencia          number;
  v_ant_val_cuota           number;
  v_mto_refuerzo            pr_sol_cuo_ref_tmp.val_int_original%type := 0;
  v_val_cuo_refuerzo        number;
  v_val_imp_interes         number;
  v_val_tas_imp             ge_tas_fechas.val_tasa%type;
  v_fec_vigencia            date;
  v_tip_valor               ge_tasas.tip_valor%type;
  v_tipo                    ge_tasas.tipo%type;
  v_cod_tasa                ge_tasas.cod_tasa%type;
  v_sal_cap_anterior        number;
  v_nro_cuota               number;  
  
procedure lp_del_cuo_tmp is  
pragma autonomous_transaction;

begin
  delete from  pr_sol_cuotas_tmp b
  where b.nro_solicitud = p_nro_solicitud;
  commit; 
end;
  
procedure lp_ins_cuo_tmp is  
pragma autonomous_transaction;

begin
  insert into pr_sol_cuotas_tmp
    (nro_solicitud,
     cal_cuo_frances,
     val_tasa,
     sal_capital,
     cuo_sugerida,
     dif_cuota,
     tot_capital,
     tot_refuerzo,
     can_cuo_ref,
     can_cuota,
     veces,
     redondeo,
     limite,
     dias,
     fec_vcto,
     fec_ven_anterior,
     tot_interes,
     mto_capital,
     val_interes,
     val_cuota,
     tot_cuota,
     dia_interes,
     sumo,
     fec_inicio,
     ant_diferencia,
     ant_val_cuota,
     mto_refuerzo,
     val_cuo_refuerzo,
     MTO_CAP_INICIAL,
     fec_pri_vencimiento,
     nro_cuota)
  values
    (p_nro_solicitud,
     ww_frances,
     ww_tasadiv,
     ww_vlsalan,
     ww_ttcuota,
     ww_dfcuota,
     ww_ttcapit,
     ww_ttrefue,
     ww_ctrefue,
     ww_nro,
     ww_veces,
     ww_redondeo,
     ww_limite,
     v_dias,
     v_fec_vcto,
     v_fec_ven_anterior,
     v_tot_interes,
     v_mto_capital,
     v_val_interes,
     v_val_cuota,
     v_tot_cuota,
     v_dia_interes,
     v_sumo,
     v_fec_inicio,
     v_ant_diferencia,
     v_ant_val_cuota,
     v_mto_refuerzo,
     v_val_cuo_refuerzo,
     p_monto,
     p_fec_pri_vencimiento,
     v_nro_cuota);
  commit;
end;

begin

if p_can_cuotas > 1 then
   v_dias := (ADD_MONTHS(p_fec_pri_vencimiento, (p_can_cuotas ) -1) - p_fec_inicio) / (p_can_cuotas)  ;
else
   v_dias := p_fec_pri_vencimiento - p_fec_inicio;
end if;      

-- DYDMR-4098 Jun/2016
if p_dias is not null then
  v_dias := p_dias;
end if;

ww_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, p_cod_modalidad, p_cod_moneda);
If ww_redondeo != 0 then
   ww_limite   := 0.05; 
end if;

/*if abs(30 - (p_fec_pri_vencimiento - p_fec_inicio)) > 2 then
   v_fec_inicio := add_months(p_fec_pri_vencimiento,-1);
end if;*/

---limpia los valores calculados anteriormente si existe
lp_del_cuo_tmp;

LOOP
  -- inicializacion de variables
  v_fec_ven_anterior := v_fec_inicio;
  ww_ttcuota := null;
  ww_vlsalan  := p_monto;
  v_tot_interes := 0;
  ww_ttcapit  := 0;
  ww_nro      := 0;  /* acumulador de cuotas calculadas automaticamente, sin refuerzo */
  --
  ww_veces := NVL(ww_veces,0)  + 1;
  --- calculo del valor del metodo frances -----------------------------
  IF ( power( ( 1 + ( ww_tasadiv * v_dias ) ), ( p_can_cuotas ) + nvl(ww_ctrefue ,0) ) - 1 ) > 0 THEN
    ww_frances := ( ( NVL( p_monto, 0 ) - NVL(WW_TTREFUE,0) ) * ww_tasadiv * v_dias ) /
                  ( power( ( 1 + ( ww_tasadiv * v_dias ) ),( p_can_cuotas  ) ) - 1 );
  END IF;
  
     
  v_val_cuota := ROUND((ww_frances * power((1 + (ww_tasadiv * v_dias)), (0))),ww_redondeo) +         
                 ROUND((ww_vlsalan * ww_tasadiv * (v_dias)),ww_redondeo);   
                 
   ----------------------------------------------------------------------
  
  FOR CUOTA IN 1..p_can_cuotas LOOP
        v_sal_cap_anterior := ww_vlsalan;
        v_fec_vcto := ADD_MONTHS(p_fec_pri_vencimiento, (cuota -1));
        --
        v_dia_interes := v_fec_vcto - v_fec_ven_anterior;
        
        v_val_interes := ROUND((ww_vlsalan * ww_tasadiv * v_dia_interes),ww_redondeo); ---***


        ww_nro := ww_nro + 1;
        v_nro_cuota := ww_nro;
        pap_pcs.pr_obt_val_refuerzo (p_nro_solicitud, ww_nro, v_mto_refuerzo);
        if v_mto_refuerzo <> 0 then
           v_mto_capital := v_val_cuota + v_mto_refuerzo - v_val_interes;
           v_val_cuo_refuerzo := v_val_cuota + v_mto_refuerzo;
        else
          IF CUOTA = 1 AND ABS(30 - (p_fec_pri_vencimiento - p_fec_inicio)) > 2 THEN 
            v_mto_capital := ROUND((ww_frances * power((1 + (ww_tasadiv * v_dias)), (ww_nro - 1))),ww_redondeo);
          ELSE	
            v_mto_capital := v_val_cuota - v_val_interes;
          END IF; 
        end if;
        
        if nvl(p_exo_impuesto,'N') = 'S' then
          pag_gen.pr_obt_val_tasa(6, p_cod_modalidad, null,
                                  null, p_cod_moneda, null, 'N',
                                  v_cod_tasa, 709,
                                  p_fec_inicio, v_val_tas_imp, v_fec_vigencia, v_tip_valor, v_tipo);
          if v_dia_interes <= 31 then
            v_val_imp_interes := round( (nvl(v_val_interes,0) * v_val_tas_imp/100),ww_redondeo);
            v_mto_capital := v_mto_capital - v_val_imp_interes;
          else
            v_val_imp_interes := 0;
          end if;
        else
          v_val_imp_interes := 0;
        end if;
        
        v_tot_cuota := NVL(v_mto_capital,0) + NVL(v_val_interes,0) + nvl(v_val_imp_interes,0);
        ww_dfcuota :=  NVL(ww_ttcuota,v_tot_cuota) - NVL(v_tot_cuota,0);
        -- ajuste de cuotas para que sean iguales solo se hace si esta dentro del limite
        IF (ABS(ww_dfcuota) BETWEEN 0.001 AND ww_limite)  THEN 
           v_val_interes := v_val_interes + ww_dfcuota;
           v_tot_cuota := v_tot_cuota + ww_dfcuota;           
        END IF;
        ww_ttcuota := v_tot_cuota;
        
        ww_vlsalan := (NVL(ww_vlsalan,0) + nvl(WW_CTREFUE,0) - v_mto_capital) + v_val_imp_interes;
        
        ww_ttcapit := NVL(ww_ttcapit,0) + NVL(v_mto_capital,0);
        v_tot_interes := v_tot_interes + NVL(v_val_interes,0);
        v_fec_ven_anterior := v_fec_vcto;
       
  END LOOP; 
  --- veo si se necesita ajustar la ultima cuota de capital ------
  ww_dfcuota := p_monto - ww_ttcapit;

  if abs(ww_dfcuota) / p_can_cuotas >= 5 then
     if ww_dfcuota > 0 then
        if v_sumo = 'N' then
           exit;  -- significa que ya se paso
        end if;   
        v_dias := v_dias + .01;
        v_sumo := 'S';
     else
        if v_sumo = 'S' then
           exit;  --ya se paso, se suspende
        end if;   
        v_dias := v_dias - .01;
        v_sumo := 'N';
     end if;      
  else
     exit; -- ya sale     
  end if; 
  IF ww_veces > 1000 THEN
     EXIT;
  END IF;
  v_ant_diferencia := ww_dfcuota;
  v_ant_val_cuota  := v_val_cuota;

END LOOP;
--inserta los resultados de calculos
lp_ins_cuo_tmp; 
pap_pcs.pr_gen_cal_cuo_refuerzo(p_nro_solicitud,p_cod_modalidad,p_cod_moneda,p_fec_inicio, p_exo_impuesto);
---return v_val_cuota;
END;

procedure pr_obt_val_refuerzo 
          (p_nro_solicitud  in pr_sol_cuo_ref_tmp.nro_solicitud%type,
           p_nro_cuota      in pr_sol_cuo_ref_tmp.nro_cuota%type,
           p_mto_refuerzo   in out pr_sol_cuo_ref_tmp.val_int_original%type) is 
       
begin

  select t.val_int_original
    into p_mto_refuerzo
    from pr_sol_cuo_ref_tmp t
   where t.nro_solicitud = p_nro_solicitud
     and t.nro_cuota = p_nro_cuota;
exception
  when no_data_found then
    p_mto_refuerzo := 0;
  when others then
    p_mto_refuerzo := 0;
end;


procedure pr_gen_cal_cuo_refuerzo
          (p_nro_solicitud in pr_solicitudes.nro_solicitud%type,
           p_cod_modalidad in number,
           p_cod_moneda in varchar2,
           p_fec_inicio in date,
           p_exo_impuesto in varchar2 default 'N') is
           
  v_nro_cuota                pr_sol_cuotas_tmp.can_cuota%type := 1;
  v_mto_cuo_refuerzo         pr_sol_cuotas_tmp.val_cuo_refuerzo%type;   
  rg_cuotmp                  pr_sol_cuotas_tmp%rowtype;
  -----
  WW_FRANCES                NUMBER;
  WW_TTCUOTA                NUMBER(18,2) := NULL;
  WW_DFCUOTA                NUMBER(18,2); 
  WW_TTCAPIT                NUMBER(18,2) := 0;
  WW_NRO                    NUMBER(10)  := 0;
  ww_redondeo               number(2) := 0;   -- redondeo a cero para moneda local
  ww_limite                 number     := 10;  -- limite superior para ajustes de cuotas iguales en moneda local
  v_fec_vcto                date;
  v_fec_vto_exacto          date;
  v_tot_interes             number := 0;
  v_mto_capital             number;
  v_val_interes             number;
  v_tot_cuota               number;
  v_dia_interes             number;
  v_mto_refuerzo            pr_sol_cuo_ref_tmp.val_int_original%type := 0;
  v_val_cuo_refuerzo        number;
  v_fec_ven_anterior        date;
  ww_vlsalan                number;
  ww_tasadiv                NUMBER;
  v_sal_cap_anterior        number;
  rg_ccalt                  pr_sol_cal_cuo_tmp%rowtype;
  v_val_imp_interes         number;
  v_val_tas_imp             ge_tas_fechas.val_tasa%type;
  v_fec_vigencia            date;
  v_tip_valor               ge_tasas.tip_valor%type;
  v_tipo                    ge_tasas.tipo%type;
  v_cod_tasa                ge_tasas.cod_tasa%type;
  v_dias                    number := 30.416666666666666666666666666667;
---------
procedure lp_del_cuo_cal_tmp is  
pragma autonomous_transaction;

begin
  delete from  pr_sol_cal_cuo_tmp b
  where b.nro_solicitud = p_nro_solicitud;
  commit; 
end;
---------
procedure lp_ins_cuo_cal_tmp (rg_cuocal pr_sol_cal_cuo_tmp%rowtype) is  
pragma autonomous_transaction;

begin
  insert into pr_sol_cal_cuo_tmp (nro_solicitud, 
                                  nro_cuota, 
                                  mto_capital, 
                                  fec_vto_habil, 
                                  fec_vto_exacto, 
                                  val_interes, 
                                  sal_capital, 
                                  sal_cap_anterior, 
                                  dia_periodo, 
                                  dia_transcurridos, 
                                  dia_interes, 
                                  tip_calculo, 
                                  val_int_original, 
                                  val_int_adelantado,
                                  val_cuo_calculado
                                  )
                          values( rg_cuocal.nro_solicitud, 
                                  rg_cuocal.nro_cuota, 
                                  NVL(rg_cuocal.mto_capital,0), 
                                  rg_cuocal.fec_vto_habil, 
                                  rg_cuocal.fec_vto_exacto, 
                                  rg_cuocal.val_interes, 
                                  rg_cuocal.sal_capital, 
                                  rg_cuocal.sal_cap_anterior, 
                                  rg_cuocal.dia_periodo, 
                                  rg_cuocal.dia_transcurridos, 
                                  rg_cuocal.dia_interes, 
                                  rg_cuocal.tip_calculo, 
                                  rg_cuocal.val_int_original, 
                                  rg_cuocal.val_int_adelantado,
                                  rg_cuocal.val_cuo_calculado);
  commit; 
end; 
------INICIO PROCESAMIENTO -------
BEGIN
  ---
  lp_del_cuo_cal_tmp;
  ---
  
  begin
    select *
      into rg_cuotmp
      from pr_sol_cuotas_tmp c
     where c.nro_solicitud = p_nro_solicitud;
  exception
    when others then
      null;
  end;
  --
  v_fec_ven_anterior := rg_cuotmp.fec_inicio;
  ww_vlsalan         := rg_cuotmp.mto_cap_inicial;
  ww_tasadiv         := rg_cuotmp.val_tasa;
  ---
  rg_ccalt.nro_cuota     := 0;
  rg_ccalt.nro_solicitud :=rg_cuotmp.nro_solicitud;
  rg_ccalt.fec_vto_habil := rg_cuotmp.fec_inicio;
  rg_ccalt.fec_vto_exacto:= rg_cuotmp.fec_inicio;
  rg_ccalt.val_interes   := 0;
  rg_ccalt.mto_capital   := v_mto_capital;
  rg_ccalt.sal_capital := ww_vlsalan;
  rg_ccalt.sal_cap_anterior:= v_sal_cap_anterior;
  rg_ccalt.val_int_original      := 0;
  rg_ccalt.val_int_adelantado    := 0;    
  
  lp_ins_cuo_cal_tmp (rg_ccalt);
  -----------------
  v_nro_cuota := 1;
  IF ( power( ( 1 + ( ww_tasadiv * v_dias ) ), ( rg_cuotmp.can_cuota ) + nvl(rg_cuotmp.can_cuo_ref ,0) ) - 1 ) > 0 THEN
    ww_frances := ( ( NVL( rg_cuotmp.mto_cap_inicial, 0 ) - NVL(rg_cuotmp.can_cuo_ref,0) ) * ww_tasadiv * v_dias ) /
                  ( power( ( 1 + ( ww_tasadiv * v_dias ) ),( rg_cuotmp.can_cuota  ) ) - 1 );
    
  END IF;
   
  FOR CUO IN 1..rg_cuotmp.can_cuota LOOP  
        v_sal_cap_anterior := ww_vlsalan;
        v_fec_vcto := ADD_MONTHS(rg_cuotmp.fec_pri_vencimiento, (v_nro_cuota -1));
        
        --
        v_dia_interes := v_fec_vcto - v_fec_ven_anterior;
        
        v_val_interes := ROUND((ww_vlsalan * rg_cuotmp.val_Tasa * v_dia_interes),ww_redondeo); ---***

        if ww_nro = 1 then
           v_fec_vto_exacto := rg_cuotmp.fec_pri_vencimiento;
        else
           v_fec_vto_exacto := rg_cuotmp.fec_pri_vencimiento + (((v_nro_cuota-1) * v_dia_interes));
        end if;

        ww_nro := ww_nro + 1;
        --Se verifica si existe refuerzo 
        pap_pcs.pr_obt_val_refuerzo (p_nro_solicitud, ww_nro, v_mto_refuerzo);
        if v_mto_refuerzo <> 0 then
           v_mto_capital := rg_cuotmp.val_cuota + v_mto_refuerzo - v_val_interes;
           v_val_cuo_refuerzo := rg_cuotmp.val_cuota + v_mto_refuerzo;
        else
          IF CUO = 1 AND ABS(30 - (rg_cuotmp.fec_pri_vencimiento - rg_cuotmp.fec_inicio)) > 2 THEN 
            v_mto_capital := ROUND((ww_frances * power((1 + (ww_tasadiv * v_dias)), (ww_nro - 1))),ww_redondeo);
          ELSE	
            v_mto_capital := rg_cuotmp.val_cuota - v_val_interes;
          END IF; 
        end if;
        
        if nvl(p_exo_impuesto,'N') = 'S' then
          pag_gen.pr_obt_val_tasa(6, p_cod_modalidad, null,
                                  null, p_cod_moneda, null, 'N',
                                  v_cod_tasa, 709,
                                  p_fec_inicio, v_val_tas_imp, v_fec_vigencia, v_tip_valor, v_tipo);

            v_val_imp_interes := round( (nvl(v_val_interes,0) * v_val_tas_imp/100),ww_redondeo);
            v_mto_capital := v_mto_capital - v_val_imp_interes;
        else
          v_val_imp_interes := 0;
        end if;
        
        ---Se aplica la diferencia directo a la última cuota
        if ww_nro = rg_cuotmp.can_cuota then
          if v_mto_capital <> ww_vlsalan then
             v_mto_capital := rg_cuotmp.mto_cap_inicial - ww_ttcapit;
             --ww_vlsalan := 0;
             v_sal_cap_anterior := v_mto_capital;
          
           end if;
        end if;
        
        v_tot_cuota := NVL(v_mto_capital,0) + NVL(v_val_interes,0) + nvl(v_val_imp_interes,0);
        ww_dfcuota :=  NVL(ww_ttcuota,v_tot_cuota) - NVL(v_tot_cuota,0);
        -- ajuste de cuotas para que sean iguales solo se hace si esta dentro del limite
        IF (ABS(ww_dfcuota) BETWEEN 0.001 AND ww_limite)  THEN 
           v_val_interes := v_val_interes + ww_dfcuota;
           v_tot_cuota := v_tot_cuota + ww_dfcuota;           
        END IF;
        ww_ttcuota := v_tot_cuota;

        --Ajuste en última cuota 
        if ww_nro = rg_cuotmp.can_cuota then
           ww_vlsalan := 0;
        else
           ww_vlsalan := (NVL(ww_vlsalan,0) - v_mto_capital) + v_val_imp_interes;
        end if;
        
        ww_ttcapit := NVL(ww_ttcapit,0) + NVL(v_mto_capital,0);
        v_tot_interes := v_tot_interes + NVL(v_val_interes,0);
        ----
    
        rg_ccalt.nro_solicitud         :=rg_cuotmp.nro_solicitud;
        rg_ccalt.nro_cuota             := v_nro_cuota;
        
        if v_mto_cuo_refuerzo = 0 then
           rg_ccalt.val_cuo_calculado     := rg_cuotmp.val_cuota;
        else
           rg_ccalt.val_cuo_calculado     := rg_cuotmp.val_cuo_refuerzo;          
        end if;
        
        rg_ccalt.mto_capital           := v_mto_capital;
        rg_ccalt.fec_vto_habil         := v_fec_vcto;
        rg_ccalt.fec_vto_exacto        := v_fec_vto_exacto;
        rg_ccalt.val_interes           := v_val_interes;
        --rg_ccalt.sal_capital           := ww_vlsalan;
        rg_ccalt.sal_cap_anterior      := v_sal_cap_anterior;
        rg_ccalt.dia_periodo           :=v_dia_interes;
        ---rg_ccalt.dia_transcurridos     :=v_dia_interes;
        rg_ccalt.dia_interes           :=v_dia_interes;
        rg_ccalt.tip_calculo           := null;
        rg_ccalt.val_int_original      := v_mto_refuerzo;
        rg_ccalt.val_int_adelantado    := 0;
    ---
     lp_ins_cuo_cal_tmp (rg_ccalt);
     --- 
   v_nro_cuota := v_nro_cuota + 1;
   v_mto_refuerzo := 0;
   v_fec_ven_anterior := v_fec_vcto;
  END LOOP;
  --  
exception
  when others then
       raise_application_error(-20000,'Error al insertar cuotas calculadas. '||sqlerrm);     
end;

function fu_obt_cal_cuo_ref_tmp 
          (p_nro_solicitud  in pr_solicitudes.nro_solicitud%type,
           p_nro_cuota  in pr_sol_cal_cuo_tmp.nro_cuota%type) return pr_sol_cal_cuo_tmp%rowtype is 

rg_prcasol   pr_sol_cal_cuo_tmp%rowtype;  

begin

  select *
    into rg_prcasol
    from pr_sol_cal_cuo_tmp t
   where t.nro_solicitud = p_nro_solicitud
     and t.nro_cuota = p_nro_cuota;
     
   return rg_prcasol;
 
  
exception
  when no_data_found then
   null;
end;

procedure pr_ins_val_refuerzo 
          (rg_cuoref pr_sol_cuo_ref_tmp%rowtype) is 

pragma autonomous_transaction;

  begin
    insert into pr_sol_cuo_ref_tmp
      (nro_solicitud,
       nro_cuota,
       fec_vto_habil,
       fec_vto_exacto,
       val_int_original)
    values
      (rg_cuoref.nro_solicitud,
       rg_cuoref.nro_cuota,
       rg_cuoref.fec_vto_habil,
       rg_cuoref.fec_vto_exacto,
       rg_cuoref.val_int_original);
    commit;
  end;
procedure pr_act_val_refuerzo (p_nro_solicitud number)is  
pragma autonomous_transaction;

begin
  delete from  pr_sol_cuo_ref_tmp b
  where b.nro_solicitud = p_nro_solicitud;
  commit; 
end;

procedure pr_eli_calculos_tmp is  

Begin
 
 delete from pr_sol_cuo_ref_tmp b
   where (trunc(sysdate) - trunc(b.fec_insercion)) > 15;

  delete from pr_sol_cuotas_tmp b
   where  (trunc(sysdate) - trunc(b.fec_insercion)) > 15;

 
  delete from pr_sol_cuo_ref_tmp b
   where (trunc(sysdate) - trunc(b.fec_insercion)) > 15
     and exists (select 1
            from pr_solicitudes p
           where p.nro_solicitud = b.nro_solicitud
             and p.estado in ('A', 'R'));
exception
  when others then
       raise_application_error(-20001,'Error al Borrar Datos Temporales. '||sqlerrm);     
end;

END pap_pcs;
/

