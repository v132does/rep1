CREATE OR REPLACE PROCEDURE IT.PRL_CIE_CAMBIOS
  is
 v_lugar varchar2(200);
 v_fec_actual    DATE;
 
 FUNCTION fu_ver_logs(p_sub_programa IN VARCHAR2) RETURN BOOLEAN IS
        v_existe NUMBER := 0;
    BEGIN
        SELECT COUNT(1)
          INTO v_existe
          FROM ge_pro_programas_log
         WHERE cod_proceso = 11
           AND cod_programa = 'PRL_CIE_CAMBIOS'
           AND nivel = 'TRACE'
           AND fecha = v_fec_actual
           AND mensaje = p_sub_programa; 
           
        RETURN (v_existe > 0);
    END;

begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 7;
    v_fec_actual         := pag_cal.fu_obt_fec_actual(pae_cnf.g_cod_modulo);	

    v_lugar := 'PAL_CIE.PR_PRO_DEV_AHORROS';
    IF NOT fu_ver_logs(v_lugar) THEN
      --generacion de movimientos de cambios automaticos
      pal_cie.PR_PRO_DEV_AHORROS;
      pag_cie.PR_INS_LOG(v_lugar, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      commit;
    END IF;

    v_lugar := 'PAL_CIE.PR_PRO_DEV_PRESTAMOS';
    IF NOT fu_ver_logs(v_lugar) THEN
      pal_cie.PR_PRO_DEV_PRESTAMOS;
      pag_cie.PR_INS_LOG(v_lugar, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      commit;
    END IF;
    v_lugar := 'PAL_CIE.PR_PRO_VENTAS';
    IF NOT fu_ver_logs(v_lugar) THEN
      pal_cie.PR_PRO_VENTAS;
      pag_cie.PR_INS_LOG(v_lugar, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      commit;
    END IF;

    v_lugar := 'PAL_CIE.PR_PRO_COMPRAS';
    IF NOT fu_ver_logs(v_lugar) THEN
      pal_cie.PR_PRO_COMPRAS;
      pag_cie.PR_INS_LOG(v_lugar, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      commit;
    END IF;

    v_lugar := 'PAL_CIE.PR_PRO_DEV_MESA';
    IF NOT fu_ver_logs(v_lugar) THEN
      pal_cie.PR_PRO_DEV_MESA;
      pag_cie.PR_INS_LOG(v_lugar, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      commit;
    END IF;

   -- CNFLPCAM-1 -- CN: 11/2015 --
   -- Verificacion de Límite de Posicion de Cambios.
    v_lugar := 'PAL_CIE.PR_VER_LIM_POS_CAMBIOS';
    IF NOT fu_ver_logs(v_lugar) THEN
      PAL_CIE.PR_VER_LIM_POS_CAMBIOS;
      pag_cie.PR_INS_LOG(v_lugar, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      commit;
    END IF;

   -- Ajuste de la tabla de posiciones si es necesario
    v_lugar := 'PRL_AJU_DIF_MOV_POSICION';
    IF NOT fu_ver_logs(v_lugar) THEN
      PRL_AJU_DIF_MOV_POSICION;
      pag_cie.PR_INS_LOG(v_lugar, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      commit;
    END IF;
   
   v_lugar := 'DELETE/UPDATE';
   IF NOT fu_ver_logs(v_lugar) THEN
     -- borrar las operaciones pendientes q no se liquidaron
     delete from lc_ope_pendientes where liquidado ='N' and ope_homebanking <> 'S' ;
     --Proyecto DDARBDIG-1-Arbitraje Digital----
     delete from lc_ope_pen_cambios where liquidado ='N' and ope_homebanking <> 'S' ;
     -- OMM 06/06/2011 Se agrego condicion para actualizar las operaciones HomeBanking
     Update lc_ope_pendientes set liquidado ='C'
     where liquidado ='N' and ope_homebanking = 'S' ;
     --Proyecto DDARBDIG-1-Arbitraje Digital--
     Update lc_ope_pen_cambios set liquidado ='C'
     where liquidado ='N' and ope_homebanking = 'S' ;
     pag_cie.PR_INS_LOG(v_lugar, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
     commit;
    END IF;
   
   --inicializar lc_sal_diarios x si se crean nuevas oficinas de cambios o es la 1ra vez
    v_lugar := 'PRL_INI_SAL_DIARIOS';
    IF NOT fu_ver_logs(v_lugar) THEN    
      prl_ini_sal_diarios;
      pag_cie.PR_INS_LOG(v_lugar, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      commit;
    END IF;

    v_lugar := 'PRL_GEN_SAL_POSICIONES';
    IF NOT fu_ver_logs(v_lugar) THEN
      PRL_GEN_SAL_POSICIONES; --commit implícito
      pag_cie.PR_INS_LOG(v_lugar, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      commit;
    END IF;

    v_lugar := 'PRL_GEN_RES_OPERACIONES';
    IF NOT fu_ver_logs(v_lugar) THEN
      PRL_GEN_RES_OPERACIONES;--commit implícito
      pag_cie.PR_INS_LOG(v_lugar, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      commit;
    END IF;

    v_lugar := 'PRL_ACT_POS_UTI_DIARIO';
    IF NOT fu_ver_logs(v_lugar) THEN
      PRL_ACT_POS_UTI_DIARIO;  
      pag_cie.PR_INS_LOG(v_lugar, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      commit;
    END IF;

   --PRL_GEN_ASI_UTILIDAD;  -- UTILIDAD RESUMIDA POR MONEDA
    v_lugar := 'PRL_GEN_ASI_UTI_OPE';
    IF NOT fu_ver_logs(v_lugar) THEN
      prl_gen_asi_uti_ope; -- UTILIDAD POR OPERACIONES.
      pag_cie.PR_INS_LOG(v_lugar, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      commit;
    END IF;

    v_lugar := 'PRL_ACT_SALDOS_RES';
    IF NOT fu_ver_logs(v_lugar) THEN
       -- proceso de actualizacion de resumen de operaciones de compra- ventas
        prl_act_saldos_res;
        pag_cie.PR_INS_LOG(v_lugar, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
        commit;
    END IF;

    v_lugar := 'PRL_GEN_MOV_POSICION';
    IF NOT fu_ver_logs(v_lugar) THEN
     -- generacion de movimientos por la posicion
      prl_gen_mov_posicion;
      pag_cie.PR_INS_LOG(v_lugar, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      commit;
    END IF;


exception
when others then
    raise_application_error(-20005, 'lugar '||v_lugar ||'-'||sqlerrm);
end prl_cie_cambios;
/
