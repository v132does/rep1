create or replace function it.fup_obt_val_cuota
    (p_cod_modalidad in number,
     p_cod_moneda in varchar2,
     p_monto in number, 
     p_can_cuotas in number, 
     p_val_tasa in number, 
     p_fec_inicio in date,
     p_fec_pri_vencimiento in date,
     p_dias number default null) 
  return number  is
     
  --WW_DIAVENC VARCHAR2(02) := TO_CHAR(p_fec_pri_vencimiento,'DD');
  WW_FRANCES NUMBER;
  WW_TASADIV NUMBER := p_val_tasa / 36500; -- * 30.416666666666666666666666666667;
  WW_VLSALAN NUMBER(18,2) := p_monto;
  WW_TTCUOTA NUMBER(18,2) := NULL;
  WW_DFCUOTA NUMBER(18,2); 
  WW_TTCAPIT NUMBER(18,2) := 0;
  WW_TTREFUE NUMBER(18,2) := 0;
  --WW_REFREAL NUMBER(18,2) := 0;
  WW_CTREFUE NUMBER(6)  := 0;
  WW_NRO     NUMBER(6)  := 0;
  WW_VECES   NUMBER(3)  := 0;
  ww_redondeo number(2) := 0;   -- redondeo a cero para moneda local
  ww_limite  number     := 10;  -- limite superior para ajustes de cuotas iguales en moneda local
  v_dias     number := 30.416666666666666666666666666667;
  v_fec_vcto date;
  v_fec_ven_anterior date := p_fec_inicio;
  v_tot_interes number := 0;
  v_mto_capital number;
  v_val_interes number;
  v_val_cuota   number;
  v_tot_cuota   number;
  v_dia_interes number;
  v_sumo        varchar(2) := null;
  v_fec_inicio  date := p_fec_inicio;
  v_ant_diferencia number;
  v_ant_val_cuota number;
  
begin
--if p_can_cuotas > 60 then -- se inicia en dias mas alto
--   v_dias := v_dias + (p_can_cuotas / 30); 
--end if;
if p_can_cuotas > 1 then
   v_dias := (ADD_MONTHS(p_fec_pri_vencimiento, (p_can_cuotas -1)) - p_fec_inicio) / (p_can_cuotas);
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

if abs(30 - (p_fec_pri_vencimiento - p_fec_inicio)) > 2 then
   v_fec_inicio := add_months(p_fec_pri_vencimiento,-1);
end if;

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
  IF ( power( ( 1 + ( ww_tasadiv * v_dias ) ), ( p_can_cuotas - ww_ctrefue ) ) - 1 ) > 0 THEN
    ww_frances := ( ( NVL( p_monto, 0 ) - NVL( ww_ttrefue, 0 ) ) * ww_tasadiv * v_dias ) /
                  ( power( ( 1 + ( ww_tasadiv * v_dias ) ),( p_can_cuotas - ww_ctrefue ) ) - 1 );
  END IF;
    
  v_val_cuota := ROUND((ww_frances * power((1 + (ww_tasadiv * v_dias)), (0))),ww_redondeo) +         
                 ROUND((ww_vlsalan * ww_tasadiv * (v_dias)),ww_redondeo);     
  ----------------------------------------------------------------------
  FOR CUOTA IN 1..p_can_cuotas LOOP
        v_fec_vcto := ADD_MONTHS(p_fec_pri_vencimiento, (cuota -1));
        --
        v_dia_interes := v_fec_vcto - v_fec_ven_anterior;
        v_val_interes := ROUND((ww_vlsalan * ww_tasadiv * v_dia_interes),ww_redondeo);
        ww_nro := ww_nro + 1;
        v_mto_capital := v_val_cuota - v_val_interes;
        v_tot_cuota := NVL(v_mto_capital,0) + NVL(v_val_interes,0);
        ww_dfcuota :=  NVL(ww_ttcuota,v_tot_cuota) - NVL(v_tot_cuota,0);
        -- ajuste de cuotas para que sean iguales solo se hace si esta dentro del limite
        IF (ABS(ww_dfcuota) BETWEEN 0.001 AND ww_limite)  THEN 
           v_val_interes := v_val_interes + ww_dfcuota;
           v_tot_cuota := v_tot_cuota + ww_dfcuota;           
        END IF;
        ww_ttcuota := v_tot_cuota;
        ww_vlsalan := NVL(ww_vlsalan,0) - v_mto_capital;
        ww_ttcapit := NVL(ww_ttcapit,0) + NVL(v_mto_capital,0);
        v_tot_interes := v_tot_interes + NVL(v_val_interes,0);
        v_fec_ven_anterior := v_fec_vcto;
  END LOOP; 
  --- veo si se necesita ajustar la ultima cuota de capital ------
  ww_dfcuota := p_monto - ww_ttcapit;
  if abs(ww_dfcuota) > abs(v_ant_diferencia) then
     -- el anterior ciclo tenia menos diferencia, se toma este
     v_val_cuota := v_ant_val_cuota;
     exit;
  end if;
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
  IF ww_veces > 50 THEN
     EXIT;
  END IF;
  v_ant_diferencia := ww_dfcuota;
  v_ant_val_cuota  := v_val_cuota;

END LOOP;
return v_val_cuota;
END;
/

