create or replace function it.fug_den_per_act_snp(p_cod_msj_swift IN ge_snp_par_mensajes.cod_msj_swift%TYPE,
                                                  p_tip_operacion     IN ge_snp_par_mensajes.cod_tip_operacion%TYPE,
                                                  p_sub_tip_operacion IN ge_snp_par_mensajes.cod_sub_tip_operacion%TYPE,
                                                  p_cod_tra_padre     IN ge_snp_par_mensajes.cod_tra_padre%type,
                                                  p_cod_periodo       IN number)
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
     v_hor_ini_tarde ge_snp_horarios.hor_inicio%type;
     v_hor_fin_tarde ge_snp_horarios.hor_fin%type;
     v_es_feriado varchar2(1);
begin
     --Carga de Variables--
     v_hor_ini_snp := paw_bas.fu_obt_hor_ini_snp(p_cod_msj_swift,p_tip_operacion,p_sub_tip_operacion,p_cod_tra_padre);
     v_hor_fin_snp := paw_bas.fu_obt_hor_fin_snp(p_cod_msj_swift,p_tip_operacion,p_sub_tip_operacion,p_cod_tra_padre);
     --v_cod_mon_debito  := FUG_OBT_MON_CTA(v_nro_cta_debito);
     --v_nro_cta_debito  := v_nro_cta_debito;
     
     --Verificacion de Sabado o Domingo--
     if fug_ver_fec_sabdom(trunc(sysdate)) = 'S' then
        return 'N';
     end if;
     
     --Verificar si fecha sistema es feriado--
     select decode(nvl(count(*),0),0,'N','S')
       into v_es_feriado
       from ba_feriados
      where fecha = trunc(sysdate)
        and nvl(cod_oficina,fug_obt_ofi_usuario(user)) = fug_obt_ofi_usuario(user);

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
        ((p_cod_periodo = 1 and v_hor_actual between v_hor_ini_snp and v_hor_fin_snp) or
         (p_cod_periodo = 3 and v_hor_actual between v_hor_ini_tarde and v_hor_fin_tarde))
     THEN
        return 'S';            
     else
        return 'N';
     END IF;
exception
  when others then
    raise_application_error(-20000,'Error en fug_pue_tra_fue_hora - '||sqlerrm);
end;
/

