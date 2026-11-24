CREATE OR REPLACE FUNCTION IT.FUB_OBT_SAL_PRO_CUENTA
(P_FECHA IN DATE,
 P_COD_RUBRO IN CB_RUBROS.COD_RUBRO%TYPE,
 P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE,
 P_MONEDA IN VARCHAR2 DEFAULT 'ML'
 )
 RETURN NUMBER
  IS
v_promedio NUMBER;
  
v_ult_fecha number;
v_dia_falt number:=0;
v_promedio_ml number;
v_promedio_me number;
v_promedio_ml_tot number;
v_promedio_me_tot number;

cursor c_sal_dia is
----trae todos los saldos del mes solicitado
    select a.cod_oficina,a.cod_rubro,
           sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))mon_loc,
           sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))mon_ext
            from cb_sal_oficinas_dia a  
            where a.cod_rubro =P_COD_RUBRO
            and a.fecha=P_FECHA
            and a.cod_oficina=P_COD_OFICINA
           group by a.cod_oficina,a.cod_rubro;      
         
   cursor c_sal_pro is
     select d.cod_rubro,
     d.cod_oficina,
     (sum(nvl(d.tot_acu_mon_local,0)/*/d.can_dia_acumulado*/))prom_loc,
     (sum(nvl(d.tot_acumulado,0)/*/d.can_dia_acumulado*/))prom_ext
        from cb_sal_promedios d
         where d.mes=to_char(p_fecha, 'mm') and d.ano = to_char(p_fecha, 'yyyy')
         and d.cod_oficina=P_COD_OFICINA
         and d.cod_rubro=P_COD_RUBRO
         group by d.cod_rubro,d.cod_oficina;
   
   
BEGIN
  
 
 --recupera la ultima fecha del mes
 select to_char(trunc(last_day(P_FECHA)),'dd') into v_ult_fecha from dual;
 --calcula cuantos dias faltan antes del ultimo día
 select (v_ult_fecha - to_char(P_FECHA,'dd')+1) into v_dia_falt from dual;
  begin
      
      for i in c_sal_dia loop
          v_promedio_ml := nvl(i.mon_loc,0) * nvl(v_dia_falt,0);
          v_promedio_me:=nvl(i.mon_ext,0) * nvl(v_dia_falt,0);
        
      end loop;
      for reg in c_sal_pro loop
          v_promedio_ml_tot := nvl(reg.prom_loc,0) + v_promedio_ml;
          v_promedio_me_tot:= nvl(reg.prom_ext,0) + v_promedio_me;
        
      end loop;
      
   --verifica si se envia el promedio en monto local o extranjero
    if P_MONEDA = 'ML' then
       v_promedio:=nvl(v_promedio_ml_tot,0);
    else
       v_promedio:=nvl(v_promedio_me_tot,0);
    end if;
    
    EXCEPTION 
       when others then
        v_promedio  :=0;
    end;
    
      return v_promedio/v_ult_fecha;
      
      
END;
/

