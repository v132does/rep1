CREATE OR REPLACE PROCEDURE IT.PRP_CAR_DAT_OPE_RES4(P_NRO_CUENTA IN VARCHAR2,
                                                 P_NRO_CTA_ORI IN VARCHAR2,
                                                 P_FEC_PAGO IN DATE,
                                                 P_HOR_PAGO IN VARCHAR2,
                                                 P_USU_PAGO IN VARCHAR2,
                                                 P_TIP_CAN_RRR IN VARCHAR2 DEFAULT NULL,
                                                 P_COD_SUB_MODALIDAD IN NUMBER,
                                                 P_TIP_RENOVACION IN VARCHAR2,
                                                 P_RESULTADO OUT VARCHAR2) IS
  --Proyecto SDRES4COVI-134--
  --Procedimiento que isnerta los datos de las cuentas refinanciadas--
  --por Resolucion 4 que fueron ingresadas por Operaciones en forma separada--

  --Variables--
  v_lugar varchar2(1000);
  v_exi_inv_res4 varchar2(1);
  v_nro_sol_des pr_solicitudes.nro_solicitud%type;
  r_pcpre pr_cta_prestamos%rowtype;
  r_pcpor pr_cta_prestamos%rowtype;
  v_cod_per_proc pr_solicitudes.cod_persona%type;
  v_nro_cta_ren_ori pr_cta_prestamos.nro_cta_renovada%type;
  V_MTO_CAPITAL NUMBER(18,2);
  V_MTO_INTERES NUMBER(18,2);
  V_MTO_MORA    NUMBER(18,2);
  V_MTO_MOR_INT NUMBER(18,2);
  V_MTO_PUNITORIO NUMBER(18,2);
  V_MTO_CARGO   NUMBER(18,2);
  V_MTO_IMPUESTO NUMBER(18,2);
  V_TOT_DEUDA   NUMBER(18,2);
  V_MTO_DEV_NOC NUMBER(18,2);
  V_MTO_DEV_SUS NUMBER(18,2);
  v_cot_mon_fuerte ge_cotizaciones.val_conversion%type;
  v_dia_atraso  pr_cta_prestamos.dia_atraso%type;
  v_cod_sub_modalidad pr_cta_prestamos.cod_sub_modalidad%type;
  v_tip_renovacion pr_cta_prestamos.tip_renovacion%type;
  v_cod_mod_cta_ori ba_modulos.cod_modulo%type;
  v_cod_mon_cta_ori ba_monedas.cod_moneda%type;
  --Variables para llamada dinamica--
  v_sentencia           varchar2(1000);
  v_error               varchar2(1000):= null;
  v_nom_procedimiento   varchar2(30);
  v_pri_cuota           number(15);
  v_ult_cuota           number(15);
  v_hab_ins_dev_par varchar2(100):= nvl(fug_obt_pardinamico('HAB_INS_DEV_PAR',null,null,null, null,null),'N');
  v_hab_pro_dev_par varchar2(100):= nvl(fug_obt_pardinamico('HAB_PRO_DEV_PAR',null,null,null, null,null),'N');
  v_hab_rev_gan_re4 varchar2(100):= nvl(fug_obt_pardinamico('HAB_REV_GAN_RE4',null,null,null, null,null),'N'); 
  v_hab_pro_car_dat     ge_par_dinamicos.val_parametro%type;
BEGIN
  --Obtener datos--
  v_lugar := 'Traer datos de cta origen';
  P_RESULTADO := 'OK';

  --Traer datos de la cuenta origen por modulo--
  v_cod_mod_cta_ori := null;
  v_cod_mon_cta_ori := null;
  v_nro_cta_ren_ori := null;

  --Traer modulo y moneda cta origen--
  begin
    select k.cod_modulo, k.cod_moneda
      into v_cod_mod_cta_ori, v_cod_mon_cta_ori
      from ge_cuentas k
     where k.nro_cuenta = p_nro_cta_ori;
  exception
    when no_data_found then
      raise_application_error(-20000,'ERROR. Cuenta origen '||P_NRO_CTA_ORI||' no existe. Verifique.');
    when others then
      raise_application_error(-20000,'ERROR. Al traer datos de la cuenta origen '||P_NRO_CTA_ORI||'-'||sqlerrm);
  end;

  if v_cod_mod_cta_ori = 6 then --Prestamos--
     pap_pre.pr_obt_dat_prestamo(P_NRO_CTA_ORI, r_pcpor);
     v_nro_cta_ren_ori := r_pcpor.nro_cta_renovada;
  elsif v_cod_mod_cta_ori = 4 then --CtasCtes--
     --No tien campo de Cuenta Origen--
     null;
  elsif v_cod_mod_cta_ori = 15 then --Ope. Vencidas--
     begin
       select x.nro_cta_renovada
         into v_nro_cta_ren_ori
         from ov_cta_vencidas x
        where x.nro_cuenta = P_NRO_CTA_ORI;
     exception
       when no_data_found then
         raise_application_error(-20000,'ERROR. Cuenta origen '||P_NRO_CTA_ORI||' no existe. Verifique.');
       when others then
         raise_application_error(-20000,'ERROR. Al traer datos de la cuenta origen '||P_NRO_CTA_ORI||'-'||sqlerrm);
     end;
  elsif v_cod_mod_cta_ori = 5 then --Tarjetas--
     --No tien campo de Cuenta Origen--
     null;
  else
     raise_application_error(-20000,'ERROR: Modulo '||v_cod_mod_cta_ori||' de Cta Origen no tratado. Verifique.');
  end if;


  v_lugar := 'Traer datos de cta nueva';
  pap_pre.pr_obt_dat_prestamo(p_nro_cuenta, r_pcpre);
  v_nro_sol_des := r_pcpre.nro_solicitud;
  v_cod_per_proc := fug_obt_cli_principal(P_NRO_CTA_ORI);
  v_cod_sub_modalidad := r_pcpre.cod_sub_modalidad;
  v_tip_renovacion := r_pcpre.tip_renovacion;

  --Inicializar variables--
  V_MTO_CAPITAL := 0;
  V_MTO_INTERES := 0;
  V_MTO_MORA    := 0;
  V_MTO_MOR_INT := 0;
  V_MTO_PUNITORIO := 0;
  V_MTO_CARGO   := 0;
  V_MTO_IMPUESTO := 0;
  V_TOT_DEUDA   := 0;
  V_MTO_DEV_NOC := 0;
  V_MTO_DEV_SUS := 0;
  v_cot_mon_fuerte := null;
  v_dia_atraso := null;

  v_lugar := 'Busca si existe cta en inventario Resol4';
  select decode(nvl(count(*),0),0,'N','S')
    into v_exi_inv_res4
    from pr_cta_pre_ref_res4 x
   where x.nro_cuenta = P_NRO_CTA_ORI
     and x.nro_sol_nueva = v_nro_sol_des;

  v_lugar := 'Valida si existe cta en inventario Resol4';
  if v_exi_inv_res4 = 'S' then
     raise_application_error(-20000,'ERROR: Ya existe en Res4. '||P_NRO_CTA_ORI||
                     '- Cta.Nueva '||P_NRO_CUENTA||' en Inventario.');
  end if;

  v_lugar := 'Verifica y Actualiza enlace de cta renovada';
  if v_nro_cta_ren_ori is not null then
     if nvl(v_nro_cta_ren_ori,'XX') <> P_NRO_CUENTA then
        if v_cod_mod_cta_ori = 6 then
          UPDATE pr_cta_prestamos x
             SET x.nro_cta_renovada = P_NRO_CUENTA
           WHERE x.nro_cuenta = P_NRO_CTA_ORI;
        elsif v_cod_mod_cta_ori = 15 then
          UPDATE ov_cta_vencidas x
             SET x.nro_cta_renovada = P_NRO_CUENTA
           WHERE x.nro_cuenta = P_NRO_CTA_ORI;
        end if;
     end if;
  else
     if v_cod_mod_cta_ori = 6 then
       UPDATE pr_cta_prestamos x
          SET x.nro_cta_renovada = P_NRO_CUENTA
        WHERE x.nro_cuenta = P_NRO_CTA_ORI;
     elsif v_cod_mod_cta_ori = 15 then
       UPDATE ov_cta_vencidas x
          SET x.nro_cta_renovada = P_NRO_CUENTA
        WHERE x.nro_cuenta = P_NRO_CTA_ORI;
     end if;
  end if;

  v_lugar := 'Verifica y actualiza sub modalidad';
  if nvl(p_cod_sub_modalidad,-9) <> nvl(v_cod_sub_modalidad,-9) then
     UPDATE pr_cta_prestamos x
        SET x.cod_sub_modalidad = p_cod_sub_modalidad
      WHERE x.nro_cuenta = P_NRO_CUENTA;
  end if;

  v_lugar := 'Verifica y actualiza tip renovacion';
  if nvl(p_tip_renovacion,'X') <> nvl(v_tip_renovacion,'X') then
     UPDATE pr_cta_prestamos x
        SET x.tip_renovacion = p_tip_renovacion
      WHERE x.nro_cuenta = P_NRO_CUENTA;
  end if;

  if ((P_FEC_PAGO is not null) and
      (P_HOR_PAGO is not null) and
      (P_USU_PAGO is not null)) THEN
      --Obtener los datos de la cancelacion--
    if v_cod_mod_cta_ori = 6 then --Prestamos--
      select sum(nvl(a.mto_capital,0)),
             sum(nvl(a.mto_interes,0) + nvl(a.mto_int_documentado,0)),
             sum(nvl(a.mto_int_moratorio,0)),
             sum(nvl(a.mto_int_mor_interes,0) + nvl(a.mto_int_mor_adelantado,0)),
             sum(nvl(a.mto_int_punitorio,0)),
             sum(nvl(a.mto_cargo,0)),
             sum(nvl(a.mto_impuesto,0)),
             sum(nvl(a.dev_no_cobrado,0)),
             sum(nvl(a.dev_suspenso,0)),
             max(a.dia_mora)
        into V_MTO_CAPITAL, V_MTO_INTERES,
             V_MTO_MORA, V_MTO_MOR_INT,
             V_MTO_PUNITORIO,
             V_MTO_CARGO, V_MTO_IMPUESTO,
             V_MTO_DEV_NOC, V_MTO_DEV_SUS,
             v_dia_atraso
        from pr_cobros a
       where a.nro_cuenta = P_NRO_CTA_ORI  --'0766283798'--'0766275230'
         and a.fecha = P_FEC_PAGO
         and a.hora = P_HOR_PAGO
         and a.usu_insercion = P_USU_PAGO;

         v_cot_mon_fuerte := fug_obt_cotizacion(pag_gen.FU_OBT_MON_FUERTE,
                             P_FEC_PAGO);
         v_tot_deuda := nvl(V_MTO_CAPITAL,0) + nvl(V_MTO_INTERES,0) +
                        nvl(V_MTO_MORA,0) + nvl(V_MTO_MOR_INT,0) +
                        nvl(V_MTO_PUNITORIO,0) +
                        nvl(V_MTO_CARGO,0)+ nvl(V_MTO_IMPUESTO,0);
    END IF;
  END IF;
  --insertar fec_proceso = fecha de la cancelacion--
  insert into PR_CTA_PRE_REF_RES4
  (NRO_CUENTA, COD_PERSONA, COD_MONEDA, DIA_ATRASO,
   SAL_CAPITAL, SAL_INTERES, MTO_CARGO, MTO_IMPUESTO,
   MTO_MORA, MTO_MOR_INT, MTO_PUNITORIO, TOT_DEUDA,
   MTO_DEVENGADO, MTO_DEV_SUSPENSO,
   NRO_SOL_NUEVA, NRO_CTA_NUEVA, REVERSADO,
   MTO_SOL_NUEVA, MTO_TOT_DESCUENTO, MTO_DEU_NETO,
   MTO_IVA_INTERES, COT_MON_FUERTE,
   COD_MON_SOL_NUEVA, TIP_CAN_RRR, TIP_CARGA,
   FEC_MOV_CAN, HOR_MOV_CAN, USU_MOV_CAN, fec_proceso)
   values
  (P_NRO_CTA_ORI, v_cod_per_proc, v_cod_mon_cta_ori, v_dia_atraso,
   v_mto_capital, v_mto_interes, v_mto_cargo, v_mto_impuesto,
   v_mto_mora, v_mto_mor_int, v_mto_punitorio, v_tot_deuda,
   v_mto_dev_noc, v_mto_dev_sus,
   v_nro_sol_des, P_NRO_CUENTA, 'N',
   v_tot_deuda, 0, v_tot_deuda,
   0, v_cot_mon_fuerte,
   r_pcpre.cod_moneda,P_TIP_CAN_RRR,'O',
   P_FEC_PAGO, P_HOR_PAGO, P_USU_PAGO, p_fec_pago);

   v_lugar := 'Cargar Mov./Inv.';
   if P_FEC_PAGO is not null and P_HOR_PAGO is not null and P_USU_PAGO is not null and P_NRO_CTA_ORI is not null then
      --Sentencia para llamada dinamica--
      /*v_sentencia := 'BEGIN '||'PRP_RE4'||'('||
      'to_date('||chr(39)||to_char(P_FEC_PAGO,'dd/mm/yyyy')||chr(39)||','||
      chr(39)||'dd/mm/yyyy'||chr(39)||'),'|| --fecha--
      chr(39)||P_HOR_PAGO||chr(39)||','||    --hora--
      chr(39)||P_USU_PAGO||chr(39)||','||    --cod_usuario--
      chr(39)||P_NRO_CTA_ORI||chr(39)||','|| --nro_cuenta--
      'null'||','||                          --nro_sol_nueva--
      chr(39)||'S'||chr(39)                  --act_inventario--
                ||'); END;';
      sql_util.ejecute_dml(v_sentencia, v_error);
      If v_error is not null then
         v_error := substr(v_error,instr(v_error,':')+1);
         raise_application_error(-20000, v_error);
      End if;*/
      if upper(v_hab_rev_gan_re4) = 'S' then  
        PRP_REV_GAN_RES4(P_FEC_PAGO,P_HOR_PAGO ,P_USU_PAGO,P_NRO_CTA_ORI, null,'S');
      end if;
      --OJO -Para carga de devengado paralelo
      --Verificamos si es cancelación parcial (Total no se devenga), y si es Cta de Prestamos
      if nvl(P_TIP_CAN_RRR,'W') = 'C' and v_cod_mod_cta_ori = 6 then
         --Buscamos la primera y ultima cuota cancelada
         v_pri_cuota:=null;
         v_ult_cuota:=null;
         --Buscamos primera cuota
         begin
           select min(nvl(f.nro_documento3,9999999))
             into v_pri_cuota
            from pr_movimientos_his f
              where trunc(f.fecha)= trunc(P_FEC_PAGO)
               and f.hora= P_HOR_PAGO
               and f.cod_usuario= P_USU_PAGO
               and f.nro_cuenta= P_NRO_CTA_ORI;
         exception
           when no_data_found then
               begin
                 
                 --Buscamos en los del dia
                  select min(nvl(f.nro_documento3,9999999))
                     into v_pri_cuota
                    from ge_movimientos f
                      where trunc(f.fecha)= trunc(P_FEC_PAGO)
                       and f.hora= P_HOR_PAGO
                       and f.cod_usuario= P_USU_PAGO
                       and f.nro_cuenta= P_NRO_CTA_ORI;
               exception 
                 when no_data_found then
                     v_pri_cuota:=null; 
                  when others then
                     v_pri_cuota:=null; 
                  end;
           when others then
               v_pri_cuota:=null;
         end;
         
          --Buscamos ultima cuota
         begin
           select max(nvl(f.nro_documento3,0))
             into v_ult_cuota
            from pr_movimientos_his f
              where trunc(f.fecha)= trunc(P_FEC_PAGO)
                and f.hora= P_HOR_PAGO
                and f.cod_usuario= P_USU_PAGO
                and f.nro_cuenta= P_NRO_CTA_ORI;
         exception
           when no_data_found then
               begin
                 --Buscamos en los del dia
                  select max(nvl(f.nro_documento3,0))
                     into v_ult_cuota
                    from ge_movimientos f
                      where trunc(f.fecha)= trunc(P_FEC_PAGO)
                        and f.hora= P_HOR_PAGO
                        and f.cod_usuario= P_USU_PAGO
                        and f.nro_cuenta= P_NRO_CTA_ORI;
                exception
                  when no_data_found then
                     v_ult_cuota:=null; 
                  when others then
                     v_ult_cuota:=null; 
                  end;
           when others then
               v_ult_cuota:=null;
         end;
         
         if nvl(v_pri_cuota,0)>0 and nvl(v_ult_cuota,0)> 0 then
             --Cargamos devengamiento paralelo
			 if upper(v_hab_ins_dev_par) = 'S' then
			    PRP_INS_DEV_RES4(P_NRO_CTA_ORI,v_pri_cuota,v_ult_cuota,trunc(P_FEC_PAGO) );
			 end if;
			 --Cargamos projeccion para cuentas operativas
			 if upper(v_hab_pro_dev_par) = 'S' then
			    PRP_ACT_PRO_DEV(P_NRO_CTA_ORI,null,trunc(P_FEC_PAGO));
			 end if;
         end if;
      end if;
       
   end if;

exception
  when others then
     P_RESULTADO := 'ERROR: en PRP_CAR_DAT_OPE_RES4: '||v_lugar||'-'||sqlerrm;
     --raise_application_error(-20000,'ERROR: en PRP_CAR_DAT_OPE_RES4: '||sqlerrm);
END;
/

