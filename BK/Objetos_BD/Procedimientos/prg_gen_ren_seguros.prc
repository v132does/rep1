CREATE OR REPLACE PROCEDURE IT.PRG_GEN_REN_SEGUROS is
  v_cod_renovacion NUMBER(18);
  v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_fec_ult_mes_habil  ge_calendarios.ult_dia_mes_habil%type;
  v_fec_seguro ge_ren_pol_seguros.fecha%type;
  v_fec_ini_ven_seg ge_pol_seguros.fec_inicial%type := TRUNC(add_months(v_fec_actual, 2), 'MM');
  v_fec_fin_ven_seg ge_pol_seguros.fec_final%type := TRUNC(LAST_DAY(add_months(v_fec_actual, 2)));  
  v_fec_pri_notificacion ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_HABIL(to_date(lpad(fug_obt_pardinamico('SEG_NOT_1RA_NOTIFICACION'), 2,'0')||'/'||to_char(sysdate, 'MM/YYYY'), 'dd/mm/yyyy'  ),1, 7);
  v_fec_seg_notificacion ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_HABIL(to_date(lpad(fug_obt_pardinamico('SEG_NOT_2DA_NOTIFICACION'), 2,'0')||'/'||to_char(sysdate, 'MM/YYYY'), 'dd/mm/yyyy'  ),1, 7);
  v_fec_int_comercial ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_HABIL(to_date(lpad(fug_obt_pardinamico('SEG_NOT_INT_COMERCIAL'), 2,'0')||'/'||to_char(sysdate, 'MM/YYYY'), 'dd/mm/yyyy'  ),1, 7);
  v_fec_anterior ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ANTERIOR(1);
CURSOR c_seguros IS
  SELECT s.cod_persona, s.nro_poliza, decode(s.seccion, 'V', decode(s.cod_sub_seccion, '0401', 'V', s.seccion), s.seccion) seccion, s.cod_ente, s.fec_final, s.mto_capital,
         s.mto_cuota, s.cod_moneda, s.codigo
    FROM ge_pol_seguros s, ba_cod_referencias c, ba_personas p
   WHERE c.dominio = 'SEC_SEGURO' 
     AND c.val_minimo = s.seccion
     AND s.cod_persona = p.cod_persona
     AND s.estado in(2, 3) 
     AND s.situacion in(1, 2, 3) 
     AND s.FEC_FINAL BETWEEN v_fec_ini_ven_seg AND v_fec_fin_ven_seg
     AND not exists (SELECT nro_poliza FROM ge_ren_pol_seguros where nro_seg_ant = s.codigo)
     AND not exists (select w.referencia
                                from Ge_Pol_Seguros w
                               where w.referencia = s.nro_poliza
                                 and w.codigo > s.codigo)
     AND exists (select 1 from ba_cod_referencias where dominio = 'SEC_NOT_SEGURO' and val_maximo = 'S' and val_minimo = s.seccion)
     AND s.sub_seccion NOT LIKE '%CAUCION%' AND s.sub_seccion NOT LIKE '%R.C. INTERNACIONAL%'
     AND not exists (select 1 from ba_cod_referencias where dominio = 'EXC_ENT_REN_SEG' 
                        and val_minimo = decode(s.seccion, 'V', decode(s.cod_sub_seccion, '0401', 'V', s.seccion), s.seccion)||s.cod_ente
                        and val_maximo = 'S') ;
                        
CURSOR c_ren_seguros is
  select r.nro_renovacion
    from ge_ren_pol_seguros r
   where exists (select w.referencia
                   from Ge_Pol_Seguros w
                  where w.referencia = r.nro_poliza
                    and w.codigo > r.nro_seg_ant)
     and estado = 'I';

CURSOR c_can_seguros is
  select r.nro_renovacion
    from ge_ren_pol_seguros r
   where r.fecha < v_fec_actual
     and r.fec_ven_pol_ant >= v_fec_actual
     and r.estado = 'I';     
BEGIN
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; pae_cnf.G_PROGRAMA := 'GPPROFIN'; end;
  v_fec_seguro := TRUNC(add_months(v_fec_actual,1), 'MM');
  PAG_CAL.PR_OBT_DAT_CALENDAR(1);
  v_fec_ult_mes_habil := pag_cal.G_ULT_DIA_MES_HABIL;
  if v_fec_actual = v_fec_ult_mes_habil then
    -- Cancelación de los seguros de vida, hogar y accidentes personales que ya fueron cancelado
    for w in c_can_seguros loop
      begin
        update ge_ren_pol_seguros
           set estado = 'C'
         where nro_renovacion = w.nro_renovacion
           and fecha < v_fec_actual
           and fec_ven_pol_ant >= v_fec_actual
           and estado = 'I';
      exception
         when others then
          raise_application_error(-20000, 'Error al cancelar la Ren. Seguro '||w.nro_renovacion||' - '||sqlerrm);
      end;
    end loop;

    FOR c in c_seguros LOOP
      BEGIN
        SELECT s_nro_renovacion.nextval
          INTO v_cod_renovacion
          FROM dual;
          
        INSERT INTO GE_REN_POL_SEGUROS(FECHA, NRO_RENOVACION, COD_PERSONA, COD_TIP_SEGURO, COD_ENTE, NRO_POLIZA, NRO_CTA_DEBITO,
                FEC_DESDE, FEC_HASTA, MTO_CAPITAL, MTO_CUOTA, IND_IMP_SEBAOT, IND_INT_COMERCIAL, IND_AUTOGESTION, COD_CANAL, ESTADO, OBSERVACION,
                MOTIVO, FEC_CONFIRMACION, FEC_CANCELACION, COD_MONEDA, FEC_VEN_POL_ANT, NRO_SEG_ANT)
                VALUES(v_fec_seguro, v_cod_renovacion, c.cod_persona, c.seccion, c.cod_ente, c.nro_poliza, null,
                NULL, NULL, c.mto_capital, c.mto_cuota, 'N', 'N', 'N', null, 'I', NULL, NULL, NULL, NULL, c.cod_moneda, c.fec_final, c.codigo);
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000, 'No se ha podido insertar la renovacion de la poliza '||c.nro_poliza||'. '||sqlerrm);
      END;
    END LOOP;
  end if; 
  
  -- Se marcan como renovados los seguros renovados por Sebaot
  FOR c in c_ren_seguros LOOP
    begin
      update ge_ren_pol_seguros
         set estado = 'P'
       where nro_renovacion = c.nro_renovacion;
    exception
      when others then
          raise_application_error(-20000, 'No se puede marcar como renovado el registro '||c.nro_renovacion||'. '||sqlerrm);        
    end;
  END LOOP;
  
  if v_fec_pri_notificacion = v_fec_actual then
     prg_not_ven_ren_seguros;
  end if;
  
  if v_fec_seg_notificacion = v_fec_actual then
     prg_not_ven_ren_seguros;
  end if;
  
  if v_fec_int_comercial = v_fec_actual then
     PRG_GEN_ARC_REN_SEG_COM;
  end if;
  
  prg_gen_arc_ren_seguros(v_fec_anterior);

END;
/

