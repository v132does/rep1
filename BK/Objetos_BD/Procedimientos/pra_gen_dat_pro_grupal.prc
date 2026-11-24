CREATE OR REPLACE PROCEDURE IT.PRA_GEN_DAT_PRO_GRUPAL(P_TIPO IN VARCHAR2,
                                                   P_COD_PERSONA IN VARCHAR2 DEFAULT NULL,
                                                   P_COD_GRUPO IN VARCHAR2 DEFAULT NULL,
                                                   P_DIR_CORREO IN VARCHAR2 DEFAULT NULL,
                                                   P_DET_CALCULO OUT VARCHAR2) IS
  pragma autonomous_transaction;
  --Variables Generales--
  v_fec_actual date;
  v_nro_cuenta ah_cta_vistas.nro_cuenta%type;
  v_cod_moneda ba_monedas.cod_moneda%type;
  v_sal_promedio ah_sal_mensuales.sal_acu_diario%type;
  v_ref_cuentas varchar2(4000);
  v_for_dis_interes ah_dev_gru_cuentas.for_dis_interes%type;
  v_cod_mon_local ba_monedas.cod_moneda%type;
  v_redondeo number(1);
  v_for_monto varchar2(50);
  v_lon_datos number(6);
  v_hora varchar2(8);
  v_fec_proxima date;
  v_ult_dia_mes_habil ge_calendarios.ult_dia_mes_habil%type;
  v_cod_persona ah_dev_gru_cuentas.cod_persona%type;
  v_nom_completo ba_personas.nom_completo%type;
  v_cod_grupo   ah_dev_gru_cuentas.cod_grupo%type;
  v_dir_correo  ge_par_dinamicos.val_parametro%type;
  v_ind_envio   varchar2(1);
  v_hab_env_precalculo  varchar2(1);
  v_dir_ema_adicionales ge_par_dinamicos.val_parametro%type;
  v_env_ema_oficial varchar2(1);
  v_dir_ema_oficial ba_usuarios.dir_correo%type;
  v_cod_usu_oficial ba_usuarios.cod_usuario%type;

  --Variables del Interes--
  v_sal_acumulado ah_devengados.sal_acumulado%type;
  v_fec_inicio ah_devengados.fec_inicio%type;
  v_val_tasa   ah_devengados.val_tasa%type;
  v_fec_tasa   ah_devengados.fec_tasa%type;
  v_cod_tasa ah_cta_vistas.cod_tasa%type;
  v_can_dia_interes ah_devengados.can_dia_interes%type;
  v_mto_interes ah_devengados.mto_interes%type;
  v_des_diaint varchar2(50);
  v_exi_dat_generados varchar2(1);
  v_tex_mto_dis_cuenta varchar2(8000);
  v_can_lin_dis number(4);

  --Cursor de Grupos--
  cursor c_det_grupos is
  select distinct m.cod_persona, m.cod_grupo, m.nro_cuenta, x.cod_moneda, x.SAL_ACUMULADO,
                  x.FEC_INICIO, x.VAL_TASA, x.FEC_TASA, x.CAN_DIA_INTERES,
                  x.MTO_INTERES, z.cod_usu_oficial
            from ah_dev_gru_cuentas m, ah_devengados x, ge_clientes z
           where m.nro_cuenta = x.nro_cuenta
             and m.tipo = 'P' --Principal--
             and x.fecha = v_fec_actual
             and z.cod_persona = m.cod_persona;

  --Cursor de Cuentas--
  cursor c_det_gru_cuentas is
   select x.nro_cuenta, x.tipo, y.cod_moneda, y.cod_tasa, x.for_dis_interes
     from AH_DEV_GRU_CUENTAS x, ah_cta_vistas y, ge_clientes z
    where x.cod_persona = v_cod_persona
      and x.cod_grupo = v_cod_grupo
      and y.nro_cuenta = x.nro_cuenta
      and z.cod_persona = x.cod_persona;

  cursor c_dis_interes(p_nro_cuenta in varchar2, p_tot_interes in number) is
    select nro_cuenta, cod_oficina, cod_moneda, tot_saldo, sal_cuenta, can_dias,
       round((sal_cuenta / tot_saldo),2) * 100 porcen,
       -----------------------------------------------
       p_tot_interes tot_interes,
       round((sal_cuenta / tot_saldo) * p_tot_interes,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',NULL,NULL,cod_moneda)) mto_interes
        from
        (SELECT b.nro_cuenta, d.cod_oficina, d.cod_moneda, nn.tot_saldo,
               sum(Nvl(fub_con_mon_a_moneda(d.cod_moneda,pp.cod_moneda,nvl(x.sal_acu_diario,0),NULL,v_fec_actual),0)) sal_cuenta,
               max(nvl(x.can_dia_acumulado,0)) can_dias
           FROM AH_SAL_MENSUALES x, AH_DEV_GRU_CUENTAS b, ah_cta_vistas d,
           (SELECT sum(Nvl(fub_con_mon_a_moneda(d.cod_moneda,pp.cod_moneda,nvl(x.sal_acu_diario,0),NULL,v_fec_actual),0)) tot_saldo,
               max(nvl(x.can_dia_acumulado,0)) can_dias
           FROM AH_SAL_MENSUALES x, AH_DEV_GRU_CUENTAS b, ah_cta_vistas d,
           (select distinct m.cod_persona, m.cod_grupo, l.cod_moneda
                    from ah_dev_gru_cuentas m, ah_cta_vistas l
                   where m.nro_cuenta = p_nro_cuenta
                     and m.tipo = 'P' --Principal--
                     and l.nro_cuenta = m.nro_cuenta) pp
           WHERE ANO = to_number(to_char(v_fec_actual,'yyyy'))
           AND MES = to_number(to_char(v_fec_actual,'mm'))
           --Proyecto Dev. Grupal Cta Tran. Bancard - CORECTRB-19--
           and b.cod_persona = pp.cod_persona
           and b.cod_grupo = pp.cod_grupo
           and b.nro_cuenta = x.nro_cuenta
           and d.nro_cuenta = b.nro_cuenta) nn,
           (select distinct m.cod_persona, m.cod_grupo, l.cod_moneda
                    from ah_dev_gru_cuentas m, ah_cta_vistas l
                   where m.nro_cuenta = p_nro_cuenta
                     and m.tipo = 'P' --Principal--
                     and l.nro_cuenta = m.nro_cuenta) pp
           WHERE x.ANO(+) = to_number(to_char(v_fec_actual,'yyyy'))
           AND x.MES(+) = to_number(to_char(v_fec_actual,'mm'))
           --Proyecto Dev. Grupal Cta Tran. Bancard - CORECTRB-19--
           and b.cod_persona = pp.cod_persona
           and b.cod_grupo = pp.cod_grupo
           and b.nro_cuenta = x.nro_cuenta(+)
           and d.nro_cuenta = b.nro_cuenta
        group by b.nro_cuenta, d.cod_oficina, d.cod_moneda, nn.tot_saldo)
     order by round((sal_cuenta / tot_saldo) * p_tot_interes,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',NULL,NULL,cod_moneda));

procedure lp_gen_dat_env_mail is
begin
  --Inicializar Variables--
      v_nro_cuenta  := null;
      v_cod_moneda  := null;
      v_cod_tasa    := null;
      v_ref_cuentas := null;
      v_for_monto   := null;
      v_redondeo    := null;

      for det in c_det_gru_cuentas loop
          if det.tipo = 'P' then
             v_nro_cuenta := det.nro_cuenta;
             v_cod_moneda := det.cod_moneda;
             v_cod_tasa   := det.cod_tasa;
             v_ref_cuentas := v_ref_cuentas||det.nro_cuenta||'(P)'||';';
             v_for_dis_interes := det.for_dis_interes;
          else
             v_ref_cuentas := v_ref_cuentas||det.nro_cuenta||';';
          end if;
      end loop;
      
      if v_ref_cuentas is null then
         p_det_calculo := 'Atencion: Cliente no tiene grupo de Devengado';
      else
         --Validar Formatos--
          v_for_monto := '999,999,999,999,990';
          v_redondeo := 0;
          if v_cod_moneda <> v_cod_mon_local then
              v_redondeo := 2;
              v_for_monto := v_for_monto||'.00';
          end if;

          if p_tipo = 'P' then
             --Generacion de datos a pedido--
             pra_dev_vis_pedido(v_nro_cuenta);

             --Obtener Datos Calculados--
             begin
               select SAL_ACUMULADO, FEC_INICIO, VAL_TASA,
                      FEC_TASA, CAN_DIA_INTERES, MTO_INTERES
                 into v_sal_acumulado, v_fec_inicio, v_val_tasa,
                      v_fec_tasa, v_can_dia_interes, v_mto_interes
                 from AH_DEV_GRU_PEDIDOS_TMP t
                where t.nro_cuenta = v_nro_cuenta
                  and t.referencia = 'AH_DEV_PEDIDOS'
                  and t.fec_inicio = (select max(x.fec_inicio)
                                        from AH_DEV_GRU_PEDIDOS_TMP x
                                       where x.nro_cuenta = t.nro_cuenta
                                         and x.referencia = t.referencia);
               v_exi_dat_generados := 'S';
             EXCEPTION
                when no_data_found then
                     v_exi_dat_generados := 'N';
                when too_many_rows then
                     v_exi_dat_generados := 'N';
                WHEN OTHERS THEN
                  RAISE_APPLICATION_ERROR(-20001,'Error PRA_GEN_DAT_PRO_GRUPAL. '||sqlerrm);
             end;
          elsif p_tipo = 'M' then --Mensual--
                if v_env_ema_oficial = 'S' then
                   v_dir_ema_oficial := fug_obt_dir_mail_usu(v_cod_usu_oficial);
                   if v_dir_ema_oficial is not null then
                      v_dir_correo := v_dir_ema_oficial||';';
                   end if;
                end if;
                if v_dir_ema_adicionales is not null then
                   v_dir_correo := v_dir_correo||v_dir_ema_adicionales;
                end if;
          end if;          
          ---Traer la distribucion--
          v_tex_mto_dis_cuenta := null;
          v_can_lin_dis := 0;
          if v_for_dis_interes = 'D' then
             for dis in c_dis_interes(v_nro_cuenta, v_mto_interes) loop 
                 v_can_lin_dis := nvl(v_can_lin_dis,0) + 1;
                 if v_can_lin_dis = 1 then
                    v_tex_mto_dis_cuenta := 'Cta:'||dis.nro_cuenta||'='||trim(to_char(round(dis.mto_interes,v_redondeo),v_for_monto))||';';
                 else
                   v_tex_mto_dis_cuenta := v_tex_mto_dis_cuenta||chr(10)||'Cta:'||dis.nro_cuenta||'='||trim(to_char(round(dis.mto_interes,v_redondeo),v_for_monto))||';';
                 end if;
             end loop;
          else
             v_tex_mto_dis_cuenta := 'Cta:'||v_nro_cuenta||'='||trim(to_char(round(v_mto_interes,v_redondeo),v_for_monto))||';';
          end if;
          if (nvl(v_can_dia_interes,0) > 0 and v_exi_dat_generados = 'S') then
             v_sal_promedio := round(nvl(v_SAL_ACUMULADO,0) / nvl(v_can_dia_interes,0),v_redondeo);
             --Respuesta y Datos--
             v_lon_datos := length(
                            --1---
                            'Cliente: '||v_COD_PERSONA||'-'||v_nom_completo||' '||
                            'Grupo: '||v_COD_GRUPO||' '||
                            'Cta.Principal: '||v_nro_cuenta||' '||
                            'Oficial: '||v_cod_usu_oficial||chr(10)||
                            --2--
                            --'Detalle.Ctas: '||v_ref_cuentas||chr(10)||
                            --3--
                            'Fec.Inicio: '||to_char(v_fec_inicio,'dd/mm/yyyy')||' '||
                            'Fec.Fin: '||to_char(v_fec_actual,'dd/mm/yyyy')||' '||
                            --4--
                            'Cod.Tasa: '||to_char(v_cod_tasa)||' '||
                            'Fec.Tasa: '||to_char(v_fec_tasa,'dd/mm/yyyy')||' '||
                            'Tasa: '||trim(to_char(v_val_tasa,'999,999,990.0000'))||' % '||chr(10)||
                            --5--
                            'Sal.Acumulado: '||trim(to_char(round(v_sal_acumulado,v_redondeo),v_for_monto))||' '||
                            'Cant.Dias: '||trim(to_char(v_can_dia_interes,'999,999,999,999,990'))||' '||
                            'Sal.Promedio: '||trim(to_char(round(v_sal_promedio,v_redondeo),v_for_monto))||chr(10)||
                            'Distribucion Interes: '||v_for_dis_interes||'-'||fue_obt_des_refcodes('FOR_CAP_DEV_GRUPAL',v_for_dis_interes)||chr(10)||
                            '('||v_tex_mto_dis_cuenta||')'||chr(10)||
                            --6--
                            '** '||v_des_diaint||' al '||to_char(v_fec_actual,'dd/mm/yyyy')||': '||v_cod_moneda||' '||trim(to_char(round(v_mto_interes,v_redondeo),v_for_monto))||' **'
                            );
             if v_lon_datos <= 4000 then
                p_det_calculo := --1---
                                 'Cliente: '||v_COD_PERSONA||'-'||v_nom_completo||' '||
                                 'Grupo: '||v_COD_GRUPO||' '||
                                 'Cta.Principal: '||v_nro_cuenta||' '||
                                 'Oficial: '||v_cod_usu_oficial||chr(10)||
                                 --2--
                                 --'Detalle.Ctas: '||v_ref_cuentas||chr(10)||
                                 --3--
                                 'Fec.Inicio: '||to_char(v_fec_inicio,'dd/mm/yyyy')||' '||
                                 'Fec.Fin: '||to_char(v_fec_actual,'dd/mm/yyyy')||' '||
                                 --4--
                                 'Cod.Tasa: '||to_char(v_cod_tasa)||' '||
                                 'Fec.Tasa: '||to_char(v_fec_tasa,'dd/mm/yyyy')||' '||
                                 'Tasa: '||trim(to_char(v_val_tasa,'999,999,990.0000'))||' % '||chr(10)||
                                 --5--
                                 'Sal.Acumulado: '||trim(to_char(round(v_sal_acumulado,v_redondeo),v_for_monto))||' '||
                                 'Cant.Dias: '||trim(to_char(v_can_dia_interes,'999,999,999,999,990'))||' '||
                                 'Sal.Promedio: '||trim(to_char(round(v_sal_promedio,v_redondeo),v_for_monto))||chr(10)||
                                 'Distribucion Interes: '||v_for_dis_interes||'-'||fue_obt_des_refcodes('FOR_CAP_DEV_GRUPAL',v_for_dis_interes)||chr(10)||
                                  '('||v_tex_mto_dis_cuenta||')'||chr(10)||
                                 --6--
                                 '** '||v_des_diaint||' al '||to_char(v_fec_actual,'dd/mm/yyyy')||': '||v_cod_moneda||' '||trim(to_char(round(v_mto_interes,v_redondeo),v_for_monto))||' **';
               else
                 p_det_calculo := substr(
                                  --1---
                                  'Cliente: '||v_COD_PERSONA||'-'||v_nom_completo||' '||
                                  'Grupo: '||v_COD_GRUPO||' '||
                                  'Cta.Principal: '||v_nro_cuenta||' '||
                                  'Oficial: '||v_cod_usu_oficial||chr(10)||
                                  --2--
                                  --'Detalle.Ctas: '||v_ref_cuentas||chr(10)||
                                  --3--
                                  'Fec.Inicio: '||to_char(v_fec_inicio,'dd/mm/yyyy')||' '||
                                  'Fec.Fin: '||to_char(v_fec_actual,'dd/mm/yyyy')||' '||
                                  --4--
                                  'Cod.Tasa: '||to_char(v_cod_tasa)||' '||
                                  'Fec.Tasa: '||to_char(v_fec_tasa,'dd/mm/yyyy')||' '||
                                  'Tasa: '||trim(to_char(v_val_tasa,'999,999,990.0000'))||' % '||chr(10)||
                                  --5--
                                  'Sal.Acumulado: '||trim(to_char(round(v_sal_acumulado,v_redondeo),v_for_monto))||' '||
                                  'Cant.Dias: '||trim(to_char(v_can_dia_interes,'999,999,999,999,990'))||' '||
                                  'Sal.Promedio: '||trim(to_char(round(v_sal_promedio,v_redondeo),v_for_monto))||chr(10)||
                                  'Distribucion Interes: '||v_for_dis_interes||'-'||fue_obt_des_refcodes('FOR_CAP_DEV_GRUPAL',v_for_dis_interes)||chr(10)||
                                  '('||v_tex_mto_dis_cuenta||')'||chr(10)||
                                  --6--
                                  '** '||v_des_diaint||' al '||to_char(v_fec_actual,'dd/mm/yyyy')||': '||v_cod_moneda||' '||trim(to_char(round(v_mto_interes,v_redondeo),v_for_monto))||' **'
                                  ,1,4000);
               end if;
          else
             p_det_calculo := 'Atencion: Sin datos acumulados';
          end if;
       end if;
       IF v_DIR_CORREO IS NOT NULL THEN
          pag_dom.pr_tra_env_email(v_dir_correo,
                                   'DEV.GRUPAL '||to_char(v_fec_actual,'dd/mm/yyyy')||' Grupo '||v_COD_GRUPO||' '||v_des_diaint||' Ctas. Transacc. Hora:'||v_hora,
                                   p_det_calculo);
       END IF;
end;


BEGIN
  --Variables--
  pag_cal.pr_obt_dat_calendar(3);
  v_fec_actual        := pag_cal.G_FEC_ACTUAL;
  v_fec_proxima       := pag_cal.G_FEC_PROXIMA;
  v_ult_dia_mes_habil := pag_cal.G_ULT_DIA_MES_HABIL;
  v_cod_mon_local     := pag_gen.fu_obt_mon_local;
  v_hora              := to_char(sysdate,'hh24:mi:ss');
  pae_cnf.G_PROGRAMA  := 'PRA_DES_DAT_PRO_GRUPAL';
  v_exi_dat_generados := 'N';
  v_des_diaint        := 'Interes Pre-Calculado';

  IF P_TIPO = 'P' then --Es a pedido (Requerimiento)--
     --Cargar Variables Recibidas--
     v_cod_persona := p_cod_persona;
     v_nom_completo := fue_obt_nom_persona(v_cod_persona);
     v_cod_grupo   := p_cod_grupo;
     v_dir_correo  := p_dir_correo;
     lp_gen_dat_env_mail;
  elsif P_TIPO = 'M' then --Mensual - desde los procesos de Cierre--
     v_hab_env_precalculo := nvl(fug_obt_pardinamico('DEV_GRU_HAB_ENV_PRECAL'),'N');
     if v_hab_env_precalculo = 'S' then
        if (v_fec_proxima = v_ult_dia_mes_habil) then
            v_ind_envio := 'S';
        elsif (v_fec_actual = v_ult_dia_mes_habil) then
           v_ind_envio := 'S';
           v_des_diaint := 'Interes Calculado';
        else
           v_ind_envio := 'N';
           v_des_diaint := null;
        end if;
        if v_ind_envio = 'S' then
            v_env_ema_oficial     := nvl(fug_obt_pardinamico('DEV_GRU_ENV_EMA_OFICIAL'),'N');
            v_dir_ema_adicionales := fug_obt_pardinamico('DEV_GRU_DIR_EMA_ADICIONALES');
            for gru in c_det_grupos loop
                v_exi_dat_generados := 'S';
                v_cod_persona := gru.cod_persona;
                v_nom_completo := fue_obt_nom_persona(v_cod_persona);
                v_cod_grupo   := gru.cod_grupo;
                v_sal_acumulado := gru.sal_acumulado;
                v_fec_inicio := gru.fec_inicio;
                v_val_tasa := gru.val_tasa;
                v_fec_tasa := gru.fec_tasa;
                v_can_dia_interes := gru.can_dia_interes;
                v_mto_interes := gru.mto_interes;
                v_cod_usu_oficial := gru.cod_usu_oficial;
                v_dir_correo  := null;
                lp_gen_dat_env_mail; --
            end loop;
        end if;
      end if;
  end if;
  commit;

EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20001,'Error PRA_GEN_DAT_PRO_GRUPAL. '||sqlerrm);
END;
/

