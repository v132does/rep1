CREATE OR REPLACE FUNCTION IT.fug_pue_env_tra_fue_hora(p_cod_msj_swift     IN ge_snp_par_mensajes.cod_msj_swift%TYPE,
                                            p_tip_operacion     IN ge_snp_par_mensajes.cod_tip_operacion%TYPE,
                                            p_sub_tip_operacion IN ge_snp_par_mensajes.cod_sub_tip_operacion%TYPE,
                                            p_cod_tra_padre     IN ge_snp_par_mensajes.cod_tra_padre%type,
                                            p_monto             IN ge_snp_transferencias.monto%TYPE,
                                            p_cod_mon_credito   IN ge_snp_transferencias.cod_moneda%type,
                                            p_fec_pago          IN ge_snp_transferencias.fec_valor%type default null,
                                            p_nro_cta_debito    IN ge_snp_transferencias.cod_per_solicitante%type)
     return varchar2
    IS
     -- varibles
     v_fec_actual  date := pag_cal.FU_OBT_FEC_ACTUAL(9);
     v_hor_actual  varchar2(10) := to_char(sysdate,'hh24mi') ;
     v_fec_snp     ge_snp_horarios.fecha%type;
     v_hor_ini_snp ge_snp_horarios.hor_inicio%type;
     v_hor_fin_snp ge_snp_horarios.hor_fin%type;
     v_cod_periodo ge_snp_horarios.cod_periodo%type;
     v_lugar       varchar(200);
     v_tip_msj_swift sb_snp_tip_mensajes.cod_mensaje%type;
     v_cod_mon_local ba_monedas.cod_moneda%type;
     v_mto_lim_int_tarde ge_snp_transferencias.monto%type;
     v_mto_tra_env_cliente ge_snp_transferencias.monto%type;
     v_hor_ini_tarde ge_snp_horarios.hor_inicio%type;
     v_hor_fin_tarde ge_snp_horarios.hor_fin%type;
     v_dia_actual varchar2(1);
     v_es_feriado varchar2(1);
     v_cod_mensaje varchar2(100);
     v_pue_env_fue_hora varchar2(1);
     v_cod_persona ba_personas.cod_persona%type;
     v_cod_mon_debito ba_monedas.cod_moneda%type;
     begin
     --Carga de Variables--
     v_hor_ini_snp := paw_bas.fu_obt_hor_ini_snp(p_cod_msj_swift,p_tip_operacion,p_sub_tip_operacion,p_cod_tra_padre);
     v_hor_fin_snp := paw_bas.fu_obt_hor_fin_snp(p_cod_msj_swift,p_tip_operacion,p_sub_tip_operacion,p_cod_tra_padre);
     v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
     v_dia_actual := rtrim(upper(to_char(trunc(sysdate),'d')));
     v_cod_persona := fug_obt_cli_principal(p_nro_cta_debito);
     v_cod_mon_debito := fug_obt_mon_cta(p_nro_cta_debito);
     
     --Verificar si fecha sistema es feriado--
     select decode(nvl(count(*),0),0,'N','S')
       into v_es_feriado
       from ba_feriados
      where fecha = trunc(sysdate)
        and cod_oficina = fug_obt_ofi_usuario(user);

     begin
       v_lugar :='-1.Obt periodo sipap.'||p_cod_msj_swift||'-'||p_tip_operacion||'-'||p_sub_tip_operacion;
       SELECT m.cod_periodo
         INTO v_cod_periodo
         FROM ge_snp_par_mensajes m
        WHERE m.cod_msj_swift = p_cod_msj_swift
          AND m.cod_tip_operacion = p_tip_operacion
          AND nvl(m.cod_sub_tip_operacion,'x') = nvl(p_sub_tip_operacion,'x')
          AND nvl(m.cod_tra_padre, pas_snp.fu_obt_cod_tra_padre) =nvl(p_cod_tra_padre, pas_snp.fu_obt_cod_tra_padre) ;
     exception
        when others then
          v_lugar := v_lugar|| '-Err.'||sqlerrm;
           return v_lugar;
     end;
     begin
       v_lugar :='-2-Obt fecha sipap.'||p_cod_msj_swift||'-'||p_tip_operacion||'-'||p_sub_tip_operacion;
       SELECT h.fecha
         INTO v_fec_snp
         FROM ge_snp_horarios h
        WHERE h.cod_periodo = v_cod_periodo;
     exception
        when others then
          v_lugar := v_lugar|| '-Err.'||sqlerrm;
           return v_lugar;
     end;

     begin
       v_lugar :='-3-Obt hora inicio fin tarde';
       SELECT h.hor_inicio, h.hor_fin
         INTO v_hor_ini_tarde, v_hor_fin_tarde
         FROM ge_snp_horarios h
        WHERE h.cod_periodo = 3; --Periodo Tarde--
     exception
       when others then
         v_lugar := v_lugar|| 'Periodo tarde-Err.'||sqlerrm;
         return v_lugar;
     end;        

         -- si es dia habil  el horario esta dentro del horario de sipap
         -- seteamos como de Alto Valor - MT103, o si el monto supera el mto maximo para ACH
         IF v_fec_actual = v_fec_snp and  -- si son iguales ya abrio el mercado
            v_hor_actual between v_hor_ini_snp and v_hor_fin_snp
         THEN
            IF v_hor_actual between v_hor_ini_tarde and v_hor_fin_tarde
            THEN
               if (v_hor_actual < v_hor_ini_snp) then
                  return 'N';
               elsif (v_hor_actual > v_hor_fin_tarde) then
                  return 'N';
               else
                if p_cod_tra_padre not in (302) then
                  if ((p_cod_mon_credito <> v_cod_mon_local) or 
                      (v_cod_mon_debito <> v_cod_mon_local)) then
                     return 'N';
                  else
                      v_mto_lim_int_tarde := fug_obt_pardinamico('SNP_MTO_LIM_INT_TARDE',null,null,v_cod_mon_local);
                      v_mto_tra_env_cliente := fug_obt_tot_tra_snp(v_cod_persona, v_cod_mon_local,
                                                                   v_fec_actual, v_hor_ini_tarde,
                                                                   v_hor_fin_tarde, 103);

                      if ((nvl(v_mto_tra_env_cliente,0) + nvl(p_monto,0) <= nvl(v_mto_lim_int_tarde,0)) and
                          (v_hor_actual between v_hor_ini_tarde and v_hor_fin_tarde) and
                          (fug_den_per_act_snp(p_cod_msj_swift,p_tip_operacion,p_sub_tip_operacion,p_cod_tra_padre,3) = 'S'))
                       then
                         return 'S';
                      else
                        return 102;
                      end if;
                  end if;
                else
                  return 102;
                end if;
               end if;
            else
              return 'S';
            end if;
         else
            /*if ((v_dia_actual in ('1','7')) or (v_es_feriado = 'S')) then
               --Sabado, Domingo, o Feriado--
               return 'N';
            else*/
              if (v_hor_actual < v_hor_ini_snp) then
                  return 'N';
              elsif (v_hor_actual > v_hor_fin_tarde) then
                  return 'N';
              else
                if p_cod_tra_padre not in (302) then
                  if ((p_cod_mon_credito <> v_cod_mon_local)) then
                     return 'N';
                  else
                      v_mto_lim_int_tarde := fug_obt_pardinamico('SNP_MTO_LIM_INT_TARDE',null,null,v_cod_mon_local);
                      v_mto_tra_env_cliente := fug_obt_tot_tra_snp(v_cod_persona, v_cod_mon_local,
                                                                   v_fec_actual, v_hor_ini_tarde,
                                                                   v_hor_fin_tarde, 103);

                      if ((nvl(v_mto_tra_env_cliente,0) + nvl(p_monto,0) <= nvl(v_mto_lim_int_tarde,0)) and
                          (v_hor_actual between v_hor_ini_tarde and v_hor_fin_tarde) and
                          (fug_den_per_act_snp(p_cod_msj_swift,p_tip_operacion,p_sub_tip_operacion,p_cod_tra_padre,3) = 'S'))
                       then
                         return 'S';
                      else
                        return 'N';
                      end if;
                  end if;
                else
                  return 'N';
                end if;
              end if;
            --end if;
         END IF;
end;
/

