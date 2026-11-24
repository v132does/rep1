create or replace function it.fug_obt_dat_cli_rat(p_cod_persona in ba_personas.cod_persona%type)
  return TYP_DATOSCLIENTESRAT is
  v_retorno              TYP_DATOSCLIENTESRAT := TYP_DATOSCLIENTESRAT;
  v_cod_oficina          ba_oficinas.cod_oficina%type;  
  v_est_civil            ba_per_fisicas.est_civil%type;  
  v_cod_actividad        ba_personas.cod_actividad%type;  
  v_sit_infocheck        ge_cli_antecedentes.sit_infocheck%type; 
  v_fec_ult_infocheck    ge_cli_antecedentes.fec_ult_infocheck%type; 
  v_can_chq_rch          ge_eqf_chk_cheques.nro_secuencia%type; 
  v_can_inhabilitaciones ge_eqf_inhabilitaciones_res.nro_solicitud%type; 
  v_faj_buro             ge_cli_antecedentes.faj_buro%type;  
  v_fec_ult_informconf   ge_cli_antecedentes.fec_ult_informconf%type; 
  v_can_demandas         ge_eqf_demandas_res.nro_solicitud%type; 
  v_can_dem_finiq        ge_eqf_demandas_res.nro_solicitud%type; 
  v_can_dem_no_finiq     ge_eqf_demandas_res.nro_solicitud%type; 
  v_can_inhibiciones     ge_eqf_inhibiciones_res.nro_solicitud%type; 
  v_can_inhi_finiq       ge_eqf_inhibiciones_res.nro_solicitud%type;
  v_can_no_inhi_finiq    ge_eqf_inhibiciones_res.nro_solicitud%type;
  v_can_pp_rrr           pr_cta_prestamos.can_cuotas%type;  
  v_sal_promedio_act     ah_sal_mensuales.sal_acu_diario%type; 
  v_sal_promedio_ant     ah_sal_mensuales.sal_acu_diario%type; 
  v_sal_promedio_ant2    ah_sal_mensuales.sal_acu_diario%type; 
  v_dia_mora_30          pr_cta_prestamos.dia_atraso%type;
  v_dia_mora_45          pr_cta_prestamos.dia_atraso%type;
  v_tip_persona          ba_personas.tipo%type;
  v_cod_usu_oficial      ge_clientes.cod_usu_oficial%type;
  v_nom_usu_oficial      ba_usuarios.nombre%type;
  v_cat_sistema          ge_clientes.cat_sistema%type;
  v_cat_riesgo           ge_clientes.cat_riesgo%type;
  v_tot_deu_sistema      ge_clientes.tot_deu_sistema%type;
  v_tot_deu_real         ge_clientes.tot_deu_real%type;
  v_hab_dat_crc          VARCHAR2(1);
  v_error                VARCHAR2(1);
  v_nombreRespuesta      VARCHAR2(15);
  v_descripcionRespuesta VARCHAR2(200);
  v_err_informcomf     varchar2(100);

BEGIN

  BEGIN
    select a.est_civil, b.cod_actividad
      into v_est_civil, v_cod_actividad	
      from ba_per_fisicas a, ba_personas b
     where a.cod_persona = b.cod_persona
       and b.cod_persona = p_cod_persona;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      Begin
        select b.cod_actividad
          into v_cod_actividad
          from ba_personas b
         where b.cod_persona = p_cod_persona;
       exception
         when NO_DATA_FOUND then  
           v_cod_actividad := nulL;
        end;
      v_est_civil := null;
    WHEN OTHERS THEN  
       paw_uti.pr_mensajeusuario('XX',
                            v_retorno.nombreRespuesta,
                            v_retorno.descripcionrespuesta,
                            v_retorno.error);
        RETURN v_retorno;
  END;
 

  BEGIN
     select nvl(a.cod_oficina, 0), a.cod_usu_oficial, a.tot_deu_real, a.tot_deu_sistema, a.cat_riesgo, a.cat_sistema
       into v_cod_oficina, v_cod_usu_oficial, v_tot_deu_real, v_tot_deu_sistema, v_cat_riesgo, v_cat_sistema
       from ge_clientes a
      where a.cod_persona = p_cod_persona;
  EXCEPTION
     WHEN NO_DATA_FOUND THEN
       v_cod_oficina := null;
       v_cod_usu_oficial := null;
     WHEN OTHERS THEN  
        paw_uti.pr_mensajeusuario('XX',
                             v_retorno.nombreRespuesta,
                             v_retorno.descripcionrespuesta,
                             v_retorno.error);
         RETURN v_retorno;      
  END;
  
  if v_cod_usu_oficial is not null then
       BEGIN
         select a.nombre
           into v_nom_usu_oficial
           from ba_usuarios a
          where a.cod_usuario = v_cod_usu_oficial;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
           v_nom_usu_oficial := null;
         WHEN OTHERS THEN  
            paw_uti.pr_mensajeusuario('XX',
                                 v_retorno.nombreRespuesta,
                                 v_retorno.descripcionrespuesta,
                                 v_retorno.error);
             RETURN v_retorno;      
      END;
  END if;

  BEGIN
    select count(a.tip_renovacion) as CAN_RRR
      into v_can_pp_rrr
      from pr_cta_prestamos a, ge_cta_clientes b 
     where a.nro_cuenta = b.nro_cuenta 
       and b.relacion = 'P'
       and a.estado <> 'N'
       and a.tip_renovacion in ('R','E')
       and a.tip_renovacion is not null
       and b.cod_persona = p_cod_persona;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_can_pp_rrr := 0;
     WHEN OTHERS THEN  
        paw_uti.pr_mensajeusuario('XX',
                             v_retorno.nombreRespuesta,
                             v_retorno.descripcionrespuesta,
                             v_retorno.error);
         RETURN v_retorno;     
   END;
 ----SALDO MEDIO ACTUAL
  BEGIN
    select sum(nvl(x.sal_promedio,0)) as sal_promedio 
      into v_sal_promedio_act
      from (select nvl(b.sal_acu_diario/b.can_dia_acumulado,0) as sal_promedio 
              from ge_cta_clientes a, cc_sal_mensuales b, ge_cuentas c
             where b.nro_cuenta = a.nro_cuenta
               and a.nro_cuenta = c.nro_cuenta
               and c.cod_moneda = 'GS'
               and a.relacion in ('P','Y')
               and lpad(b.mes,2,0)||'/'||b.ano = to_char(pag_cal.FU_OBT_FEC_ACTUAL(1),'mm/yyyy')
               and a.cod_persona = p_cod_persona
         union all 
            select nvl(round(b.sal_acu_diario/b.can_dia_acumulado*fug_obt_cotizacion(c.cod_moneda),2),0) as sal_promedio
              from ge_cta_clientes a, cc_sal_mensuales b, ge_cuentas c
             where b.nro_cuenta = a.nro_cuenta
               and a.nro_cuenta = c.nro_cuenta
               and c.cod_moneda = 'USD'
               and a.relacion in ('P','Y')
               and lpad(b.mes,2,0)||'/'||b.ano = to_char(pag_cal.FU_OBT_FEC_ACTUAL(1),'mm/yyyy')
               and a.cod_persona = p_cod_persona
         union all
            select nvl(b.sal_acu_diario/b.can_dia_acumulado,0) as sal_promedio
              from ge_cta_clientes a, ah_sal_mensuales b, ge_cuentas c
             where b.nro_cuenta = a.nro_cuenta
               and a.nro_cuenta = c.nro_cuenta
               and c.cod_moneda = 'GS'
               and a.relacion in ('P','Y')
               and lpad(b.mes,2,0)||'/'||b.ano = to_char(pag_cal.FU_OBT_FEC_ACTUAL(1),'mm/yyyy')
               and a.cod_persona = p_cod_persona
         union all 
            select nvl(round(b.sal_acu_diario/b.can_dia_acumulado*fug_obt_cotizacion(c.cod_moneda),2),0) as sal_promedio
              from ge_cta_clientes a, ah_sal_mensuales b, ge_cuentas c
             where b.nro_cuenta = a.nro_cuenta
               and a.nro_cuenta = c.nro_cuenta
               and c.cod_moneda = 'USD'
               and a.relacion in ('P','Y')
               and lpad(b.mes,2,0)||'/'||b.ano = to_char(pag_cal.FU_OBT_FEC_ACTUAL(1),'mm/yyyy')
               and a.cod_persona = p_cod_persona) x;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_sal_promedio_act := 0;
     WHEN OTHERS THEN  
        paw_uti.pr_mensajeusuario('XX',
                             v_retorno.nombreRespuesta,
                             v_retorno.descripcionrespuesta,
                             v_retorno.error);
         RETURN v_retorno;     
   END;
 ----SALDO MEDIO -6 MESES   
  BEGIN
    select sum(nvl(x.sal_promedio,0)) as sal_promedio 
      into v_sal_promedio_ant
      from (select nvl(b.sal_acu_diario/b.can_dia_acumulado,0) as sal_promedio 
              from ge_cta_clientes a, cc_sal_mensuales b, ge_cuentas c
             where b.nro_cuenta = a.nro_cuenta
               and a.nro_cuenta = c.nro_cuenta
               and c.cod_moneda = 'GS'
               and a.relacion in ('P','Y')
               and lpad(b.mes,2,0)||'/'||b.ano = to_char(add_months(pag_cal.FU_OBT_FEC_ACTUAL(1),-6), 'mm/yyyy')
               and a.cod_persona = p_cod_persona
         union all 
            select nvl(round(b.sal_acu_diario/b.can_dia_acumulado*fug_obt_cotizacion(c.cod_moneda),2),0) as sal_promedio
              from ge_cta_clientes a, cc_sal_mensuales b, ge_cuentas c
             where b.nro_cuenta = a.nro_cuenta
               and a.nro_cuenta = c.nro_cuenta
               and c.cod_moneda = 'USD'
               and a.relacion in ('P','Y')
               and lpad(b.mes,2,0)||'/'||b.ano = to_char(add_months(pag_cal.FU_OBT_FEC_ACTUAL(1),-6), 'mm/yyyy')
               and a.cod_persona = p_cod_persona
         union all
            select nvl(b.sal_acu_diario/b.can_dia_acumulado,0) as sal_promedio
              from ge_cta_clientes a, ah_sal_mensuales b, ge_cuentas c
             where b.nro_cuenta = a.nro_cuenta
               and a.nro_cuenta = c.nro_cuenta
               and c.cod_moneda = 'GS'
               and a.relacion in ('P','Y')
               and lpad(b.mes,2,0)||'/'||b.ano = to_char(add_months(pag_cal.FU_OBT_FEC_ACTUAL(1),-6), 'mm/yyyy')
               and a.cod_persona = p_cod_persona
         union all 
            select nvl(round(b.sal_acu_diario/b.can_dia_acumulado*fug_obt_cotizacion(c.cod_moneda),2),0) as sal_promedio
              from ge_cta_clientes a, ah_sal_mensuales b, ge_cuentas c
             where b.nro_cuenta = a.nro_cuenta
               and a.nro_cuenta = c.nro_cuenta
               and c.cod_moneda = 'USD'
               and a.relacion in ('P','Y')
               and lpad(b.mes,2,0)||'/'||b.ano = to_char(add_months(pag_cal.FU_OBT_FEC_ACTUAL(1),-6), 'mm/yyyy')
               and a.cod_persona = p_cod_persona) x;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_sal_promedio_ant := 0;
     WHEN OTHERS THEN  
        paw_uti.pr_mensajeusuario('XX',
                             v_retorno.nombreRespuesta,
                             v_retorno.descripcionrespuesta,
                             v_retorno.error);
         RETURN v_retorno;     
   END;
 ----SALDO MEDIO -12 MESES   
  BEGIN
    select sum(nvl(x.sal_promedio,0)) as sal_promedio 
      into v_sal_promedio_ant2
      from (select nvl(b.sal_acu_diario/b.can_dia_acumulado,0) as sal_promedio 
              from ge_cta_clientes a, cc_sal_mensuales b, ge_cuentas c
             where b.nro_cuenta = a.nro_cuenta
               and a.nro_cuenta = c.nro_cuenta
               and c.cod_moneda = 'GS'
               and a.relacion in ('P','Y')
               and lpad(b.mes,2,0)||'/'||b.ano = to_char(add_months(pag_cal.FU_OBT_FEC_ACTUAL(1),-12), 'mm/yyyy')
               and a.cod_persona = p_cod_persona
         union all 
            select nvl(round(b.sal_acu_diario/b.can_dia_acumulado*fug_obt_cotizacion(c.cod_moneda),2),0) as sal_promedio
              from ge_cta_clientes a, cc_sal_mensuales b, ge_cuentas c
             where b.nro_cuenta = a.nro_cuenta
               and a.nro_cuenta = c.nro_cuenta
               and c.cod_moneda = 'USD'
               and a.relacion in ('P','Y')
               and lpad(b.mes,2,0)||'/'||b.ano = to_char(add_months(pag_cal.FU_OBT_FEC_ACTUAL(1),-12), 'mm/yyyy')
               and a.cod_persona = p_cod_persona
         union all
            select nvl(b.sal_acu_diario/b.can_dia_acumulado,0) as sal_promedio
              from ge_cta_clientes a, ah_sal_mensuales b, ge_cuentas c
             where b.nro_cuenta = a.nro_cuenta
               and a.nro_cuenta = c.nro_cuenta
               and c.cod_moneda = 'GS'
               and a.relacion in ('P','Y')
               and lpad(b.mes,2,0)||'/'||b.ano = to_char(add_months(pag_cal.FU_OBT_FEC_ACTUAL(1),-12), 'mm/yyyy')
               and a.cod_persona = p_cod_persona
         union all 
            select nvl(round(b.sal_acu_diario/b.can_dia_acumulado*fug_obt_cotizacion(c.cod_moneda),2),0) as sal_promedio
              from ge_cta_clientes a, ah_sal_mensuales b, ge_cuentas c
             where b.nro_cuenta = a.nro_cuenta
               and a.nro_cuenta = c.nro_cuenta
               and c.cod_moneda = 'USD'
               and a.relacion in ('P','Y')
               and lpad(b.mes,2,0)||'/'||b.ano = to_char(add_months(pag_cal.FU_OBT_FEC_ACTUAL(1),-12), 'mm/yyyy')
               and a.cod_persona = p_cod_persona) x;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_sal_promedio_ant2 := 0;
     WHEN OTHERS THEN  
        paw_uti.pr_mensajeusuario('XX',
                             v_retorno.nombreRespuesta,
                             v_retorno.descripcionrespuesta,
                             v_retorno.error);
         RETURN v_retorno;     
   END;
   
/*   Begin 
      v_err_informcomf := pag_eqf.fu_pro_dat_informconf(p_cod_persona, 'N', 99);  
      fug_obt_cli_informconf
  EXCEPTION
      WHEN others THEN
        null;
      end;*/
   
     
    BEGIN
      select a.sit_infocheck,  a.fec_ult_infocheck, a.faj_buro, a.fec_ult_informconf
        into v_sit_infocheck, v_fec_ult_infocheck, v_faj_buro, v_fec_ult_informconf
        from ge_cli_antecedentes a
       where a.cod_persona = p_cod_persona;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_sit_infocheck := null;
        v_fec_ult_infocheck := null;
        v_faj_buro := null;
        v_fec_ult_informconf := null;
     WHEN OTHERS THEN  
        paw_uti.pr_mensajeusuario('XX',
                             v_retorno.nombreRespuesta,
                             v_retorno.descripcionrespuesta,
                             v_retorno.error);
         RETURN v_retorno;     
   END;
    
   BEGIN
      select nvl(count(1), 0)
        into v_can_chq_rch
        from ge_eqf_chk_cheques a
       where a.cod_mot_rechazo in (101, 201, 502, 501, 902)
         and a.fec_rechazo between add_months(trunc(sysdate), -12) and trunc(sysdate)
         and a.cod_persona = p_cod_persona;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_can_chq_rch := 0;
   END;
   
   BEGIN
     select nvl(count(1), 0)
       into v_can_inhabilitaciones
       from ge_eqf_chk_inhabilitaciones a
      where a.fec_inhabilitacion between add_months(trunc(sysdate), -12) and trunc(sysdate)
        and a.cod_persona  = p_cod_persona;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_can_inhabilitaciones := 0;
     WHEN OTHERS THEN  
        paw_uti.pr_mensajeusuario('XX',
                             v_retorno.nombreRespuesta,
                             v_retorno.descripcionrespuesta,
                             v_retorno.error);
         RETURN v_retorno;     
   END;
   
      
   BEGIN
     select a.can_total, a.can_finiquitadas, a.can_no_finiquitadas
       into v_can_demandas, v_can_dem_finiq, v_can_dem_no_finiq
       from ge_eqf_demandas_res a
      where a.may_fec_dem_no_finiquitadas between add_months(trunc(sysdate), -12) and trunc(sysdate)
        and a.can_total is not null
        and a.cod_persona  = p_cod_persona;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_can_demandas := 0;
        v_can_dem_finiq := 0;
        v_can_dem_no_finiq := 0;
     WHEN OTHERS THEN  
        paw_uti.pr_mensajeusuario('XX',
                             v_retorno.nombreRespuesta,
                             v_retorno.descripcionrespuesta,
                             v_retorno.error);
         RETURN v_retorno;     
   END;
   
   
   BEGIN
       select a.can_total, a.can_finiquitadas, a.can_no_finiquitadas
       into v_can_inhibiciones, v_can_inhi_finiq, v_can_no_inhi_finiq 
       from ge_eqf_inhibiciones_res a
      where a.may_fec_inh_no_finiquitadas between add_months(trunc(sysdate), -12) and trunc(sysdate)
        and a.can_total is not null
        and a.cod_persona  = p_cod_persona;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_can_inhibiciones := 0;
        v_can_inhi_finiq := 0;
        v_can_no_inhi_finiq := 0;
     WHEN OTHERS THEN  
        paw_uti.pr_mensajeusuario('XX',
                             v_retorno.nombreRespuesta,
                             v_retorno.descripcionrespuesta,
                             v_retorno.error);
         RETURN v_retorno;     
   END;
  
  BEGIN
     select max(a.dia_atraso)
      into v_dia_mora_30
      from ge_cla_operaciones_his a
     where a.fecha between add_months(trunc(sysdate), -12) and trunc(sysdate)
       and a.dia_atraso >= 30
       and a.cod_persona = p_cod_persona;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_dia_mora_30 := 0; 
     WHEN OTHERS THEN  
        paw_uti.pr_mensajeusuario('XX',
                             v_retorno.nombreRespuesta,
                             v_retorno.descripcionrespuesta,
                             v_retorno.error);
         RETURN v_retorno;     
   END;
   
  
  BEGIN
   select max(a.dia_atraso)
     into v_dia_mora_45
     from ge_cla_operaciones_his a
     where a.fecha between add_months(trunc(sysdate), -12) and trunc(sysdate)
      and a.dia_atraso >= 45
      and a.cod_persona = p_cod_persona;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_dia_mora_45 := 0; 
     WHEN OTHERS THEN  
        paw_uti.pr_mensajeusuario('XX',
                             v_retorno.nombreRespuesta,
                             v_retorno.descripcionrespuesta,
                             v_retorno.error);
         RETURN v_retorno;     
   END;
   
   
  BEGIN
   select max(a.tipo)
     into v_tip_persona
     from ba_personas a
     where a.cod_persona = p_cod_persona;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_tip_persona := 0; 
     WHEN OTHERS THEN  
        paw_uti.pr_mensajeusuario('XX',
                             v_retorno.nombreRespuesta,
                             v_retorno.descripcionrespuesta,
                             v_retorno.error);
         RETURN v_retorno;     
   END;
   
   BEGIN
     v_hab_dat_crc := fup_hab_dat_crc(p_cod_persona);
   EXCEPTION
      WHEN OTHERS THEN  
        paw_uti.pr_mensajeusuario('XX',
                             v_retorno.nombreRespuesta,
                             v_retorno.descripcionrespuesta,
                             v_retorno.error);
         RETURN v_retorno;     
   END;
      
  v_retorno.cod_oficina          := v_cod_oficina; 
  v_retorno.est_civil            := v_est_civil;   
  v_retorno.cod_actividad        := v_cod_actividad; 
  v_retorno.sit_infocheck        := v_sit_infocheck; 
  v_retorno.fec_ult_infocheck    := v_fec_ult_infocheck;
  v_retorno.can_chq_rch          := v_can_chq_rch;
  v_retorno.can_inhabilitaciones := v_can_inhabilitaciones;
  v_retorno.faj_buro             := v_faj_buro;
  v_retorno.fec_ult_informconf   := v_fec_ult_informconf;
  v_retorno.can_demandas         := v_can_demandas;
  v_retorno.can_dem_finiq        := v_can_dem_finiq;
  v_retorno.can_dem_no_finiq     := v_can_dem_no_finiq;
  v_retorno.can_inhibiciones     := v_can_inhibiciones;
  v_retorno.can_inhi_finiq       := v_can_inhi_finiq;
  v_retorno.can_no_inhi_finiq    := v_can_no_inhi_finiq;
  v_retorno.can_pp_rrr           := v_can_pp_rrr;
  v_retorno.sal_promedio_act     := v_sal_promedio_act;
  v_retorno.sal_promedio_ant     := v_sal_promedio_ant;
  v_retorno.sal_promedio_ant2    := v_sal_promedio_ant2;
  v_retorno.dia_mora_30          := v_dia_mora_30;
  v_retorno.dia_mora_45          := v_dia_mora_45;
  v_retorno.tip_persona          := v_tip_persona;
  v_retorno.cod_usu_oficial      := v_cod_usu_oficial;
  v_retorno.nom_usu_oficial      := v_nom_usu_oficial;
  v_retorno.cat_sistema          := v_cat_sistema;
  v_retorno.cat_riesgo           := v_cat_riesgo;
  v_retorno.tot_deu_sistema      := v_tot_deu_sistema;
  v_retorno.tot_deu_real         := v_tot_deu_real;      
  v_retorno.hab_dat_crc          := v_hab_dat_crc;
  paw_uti.pr_mensajeusuario('OP_APROBADA',
                            v_retorno.nombreRespuesta,
                            v_retorno.descripcionrespuesta,
                            v_retorno.error);
  return(v_retorno);
  
end fug_obt_dat_cli_rat;
/

