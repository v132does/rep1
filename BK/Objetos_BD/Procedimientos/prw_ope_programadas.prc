create or replace procedure it.prw_ope_programadas is
  -- --------------
  -- envio de mail 
  -- --------------
  PROCEDURE lp_env_notificacion(p_asunto IN LONG, p_mensaje IN VARCHAR2) IS
  BEGIN
     it_mail.mail(fug_obt_dir_correo, fug_obt_pardinamico('CAM_MAR_DIR_MON_CAN')/*'monitoreocanales.py.group@bbva.com'*/, 
                  '[OPERACION PROGRAMADA] '||p_asunto,
                  'Se registro el siguiente error en fecha ' || to_char(sysdate, 'dd/mm/yyyy') || chr(10) || chr(13) || p_mensaje);
  EXCEPTION
    WHEN OTHERS THEN
      null;
  END;
  -- ---------------------
  -- registro de bitacora
  -- ---------------------
  PROCEDURE lp_reg_operacion(p_mensaje IN LONG, p_respuesta IN VARCHAR2, p_notificar varchar2 default 'S') is
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_respuesta ba_log_mensajeria.respuesta%type;
  BEGIN
    v_respuesta := substr(p_respuesta, 1, 4000);    
    -- notificamos
    if nvl(p_notificar, 'S') = 'S' then
       lp_env_notificacion(p_mensaje, v_respuesta);
    end if;
    -- registramos
    insert into ba_log_mensajeria
      (mensaje, respuesta)
    values
      (p_mensaje, v_respuesta);
    commit;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END lp_reg_operacion;
  -- ------------------------------------
  -- generacion de pendientes programados
  -- ------------------------------------
  procedure lp_pro_generar is
     PRAGMA AUTONOMOUS_TRANSACTION;
  begin
     paw_pro.pr_gen_programadas;
     commit;
  exception
     when others then
        lp_reg_operacion('paw_pro.pr_gen_programadas', sqlerrm);
        rollback;
  end lp_pro_generar;
  -- ---------------------------------
  -- generacion de debitos programados
  -- ---------------------------------
  procedure lp_pro_debitar is
     PRAGMA AUTONOMOUS_TRANSACTION;
  begin
     paw_pro.pr_pro_debitos;
     commit;
  exception
     when others then
        lp_reg_operacion('paw_pro.pr_pro_debitos', sqlerrm);
        rollback;
  end lp_pro_debitar;
  -- -------------------------------------
  -- finalizacion de programados cumplidos
  -- -------------------------------------
  procedure lp_pro_cancelar is
     PRAGMA AUTONOMOUS_TRANSACTION;
  begin
     paw_pro.pr_can_ope_programadas;
     commit;
  exception
     when others then
        lp_reg_operacion('paw_pro.pr_can_ope_programadas', sqlerrm);
        rollback;
  end lp_pro_cancelar;
  -- -----------------
  -- PROCESO PRINCIPAL
  -- -----------------
begin
  if trunc(sysdate) <> trunc(pag_cal.fu_obt_fec_actual(1)) then
     lp_reg_operacion('PRW_OPE_PROGRAMADAS', 'Omitiendo generacion por dia no habil', 'N');
     return;
  end if;  
  -- utils
  pre_cam_for_numerico('.,');
  pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; 
  -- generar operaciones programadas del dia
  lp_pro_generar;
    -- debitar las operaciones pendientes al dia
  lp_pro_debitar;
    -- cancelar las operaciones vencidas
  lp_pro_cancelar;
  -- notificar los debitos realizados
  paw_pro.pr_not_operaciones;
  -- notificar los debitos a procesar mañana
  paw_pro.pr_not_ope_siguiente;
  -- generar comprobantes web
  paw_pro.pr_gen_web_comprobante;
end prw_ope_programadas;
/

