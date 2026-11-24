create or replace procedure it.prp_act_fec_solicitudes is
  v_fec_actual      date := pag_cal.fu_obt_fec_actual(6);
  v_dia_diferencia  number;
  v_tip_implementacion ge_par_generales.tip_implementacion%type := fug_obt_tip_implementacion;
  v_hor_inicio      varchar2(8);
  v_hor_fin         varchar2(8); 
  cursor c_sol is
  select *
    from pr_solicitudes a
   where a.estado = 'L'
     and a.est_verificacion in ('S','V')
     and a.cod_modalidad not in (660,608,62,602,663)
     and a.fec_inicio < v_fec_actual
     and (nvl(fug_obt_pardinamico('SIB_MAD_COM_CARTERA', a.cod_modulo, a.cod_modalidad), 'N') = 'N' -- Excluir compra de cartera //1266
         OR nvl(fug_obt_pardinamico('COD_MAD_ACT_FEC_INICIO', a.cod_modulo, a.cod_modalidad), 'N') = 'S') --se incluyen otras modalidades especificas
     and not exists (select 1 from pr_cta_prestamos b where b.nro_solicitud = a.nro_solicitud);

PROCEDURE lp_ins_log(p_cod_proceso varchar2, p_hor_ini varchar2, p_hor_fin varchar2)
  is pragma autonomous_transaction;
  begin   
    insert into ge_log_procesos(fecha,cod_programa,cod_proceso,hor_inicio,hor_fin)
    values(v_fec_actual,'PRP_ACT_FEC_SOLICITUDES',p_cod_proceso, p_hor_ini, p_hor_fin);
    commit;
  exception
    when others then null;
  end; 
        
begin
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  v_hor_inicio:= to_char(sysdate,'hh24:mi:ss');
  if nvl(fug_obt_pardinamico('PRE_ACT_FEC_SOLICITUD'),'N') = 'S' then
    for k in c_sol loop
      IF v_tip_implementacion <> 3  THEN
        v_dia_diferencia := v_fec_actual - k.fec_inicio;
        IF v_dia_diferencia <> 0 THEN
          UPDATE pr_sol_tasas
             SET fec_vigencia = fec_vigencia + v_dia_diferencia
           WHERE nro_solicitud = k.nro_solicitud;
          UPDATE pr_solicitudes
             SET fec_inicio          = fec_inicio + v_dia_diferencia,
                 fec_pri_vencimiento = fec_pri_vencimiento + v_dia_diferencia,
                 fec_vencimiento     = fec_vencimiento + v_dia_diferencia
           WHERE nro_solicitud = k.nro_solicitud;
          UPDATE pr_sol_cuotas
             SET fec_vto_habil  = fec_vto_habil + v_dia_diferencia,
                 fec_vto_exacto = fec_vto_exacto + v_dia_diferencia
           WHERE nro_solicitud = k.nro_solicitud;
        END IF;
      END IF;
       commit;
    end loop;   
  end if;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss'); 
  lp_ins_log('PRP_ACT_FEC_SOLICITUDES',v_hor_inicio,v_hor_fin);
end;
