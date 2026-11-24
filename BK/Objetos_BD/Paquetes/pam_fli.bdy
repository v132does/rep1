CREATE OR REPLACE PACKAGE BODY IT.PAM_FLI is

  --Variables Generales--
  vg_fecha            date := pag_cal.FU_OBT_FEC_ACTUAL(10);
  vg_nro_cuenta       md_cta_documentos.nro_cuenta%type;
  vg_cod_programa     ge_log_procesos.cod_programa%type := 'PAM_DEP';
  vg_des_operacion    varchar2(4000);
  vg_nro_referencia   ge_snp_mensajes.nro_referencia%type;
  vg_nro_orden        ge_pro_paralelos_det.nro_orden%type;
  vg_cod_swi_entidad  ge_snp_transferencias.cod_swi_pte_solicitante%type;
  vg_cta_ban_entidad  cc_cta_bancarias.nro_cta_bancaria%type;
  vg_fecfor           varchar2(2000) := 'DEPO '||to_char(pag_cal.FU_OBT_FEC_ACTUAL(10),'dd/mm/yyyy')||' - ';

PROCEDURE PR_CAR_VAR_PARAMETROS IS
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
BEGIN
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'PR_CAR_VAR_INICIAL';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC  := vg_nro_orden;
  V_HOR_INI_LOC  := TO_CHAR(SYSDATE,'HH24:MI:SS');
  ----PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);

  --Carga de Variables y Datos--
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 10; end;
  pre_cam_for_numerico(',.');
  pae_cnf.G_PROGRAMA := 'PAM_FLI';


  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  ----PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);
EXCEPTION
  WHEN OTHERS THEN
    ----PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END;

PROCEDURE PR_GEN_MSJ_SWI_MT549 (P_NRO_REFERENCIA OUT VARCHAR2) IS
  -- Procedimiento de generación y envio de encaje legal (MT541)
  v_cod_mensaje             sb_snp_tip_mensajes.cod_mensaje%type := 'MT549';
  v_mensaje                 varchar2(4000);
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  PRAGMA AUTONOMOUS_TRANSACTION;
begin
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'PR_GEN_MSJ_SWI_MT541';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  ----PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

  PAM_FLI.PR_CAR_VAR_PARAMETROS;

   --Variables--
   P_NRO_REFERENCIA := pas_snp.fu_obt_sig_nro_referencia;

   --CABECERA--
  /* pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje,
                                      'CAB',
                                      '{1:F01'||rpad(pam_dep.g_usu_xad_depo,12,'X')||'}'||
                                      '{2:I549'||rpad(pam_dep.g_bic_bcp_depo,12,'X')||'N}'||
                                      '{3:{113'||':'||lpad('90',4,'0')||'}}{4:');*/
   --DETALLE de Campos--
   --Bloque de Datos Generales--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'GENL');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '20C', ':SEME//'||P_NRO_REFERENCIA);  --Referencia Unica--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '23G', 'NEWM');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '13A', ':REQU//535');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '97A', ':SAFE//BBVA/DEPO/DEPO');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'GENL');
   --PIE del MT541--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, 'PIE', '-}{5:{TNG:}}');

   begin
     --Generar Archivo con Formato--
     pao_pmt.pr_pro_mt_enviado(v_cod_mensaje, v_mensaje);

     pas_snp.g_lugar := 'Insertando mensaje en GE_SNP_MENSAJES, ';
     begin
       insert into ge_snp_mensajes
       (nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor,
        msj_swift, cod_moneda, monto, situacion, error, msj_swi_original)
        values
       (P_NRO_REFERENCIA, null, 549, vg_fecha, v_mensaje, null,
        null, 'V', pas_snp.g_msj_error, v_mensaje);
     exception
       when others then
           raise_application_error(-20000,
                                  'Insertando en ge_snp_mensajes ' || sqlerrm);
     end;

    --Envia el Mensaje al Socket--
    /* pam_dep.PR_GEN_ARC_SWI_SERV(v_mensaje);*/

    commit;
   exception
      when others then
         raise;
   end;

   --Fin Registro del Log--
   V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
   ----PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC,vg_nro_referencia,NULL,NULL,NULL,vg_nro_cuenta,vg_des_operacion);
   PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);
   commit;
EXCEPTION
  WHEN OTHERS THEN
    if sqlcode <= -20000 then
      null;
      ----PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
      raise;
    else
      ----PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
      RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
    end if;
END;

PROCEDURE PR_GEN_MSJ_SWI_MT524 (P_IDE_INSTRUMENTO IN VARCHAR2,
                                P_TIP_ACCION IN VARCHAR2,
                                P_CANTIDAD IN NUMBER,
                                P_NRO_REFERENCIA OUT VARCHAR2) IS
  -- Procedimiento de generación y envio de encaje legal (MT541)
  v_cod_mensaje     sb_snp_tip_mensajes.cod_mensaje%type := 'MT524';
  v_cod_msj_num     ge_snp_mensajes.cod_msj_swift%type;
  v_mensaje                 varchar2(4000);
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  v_fec_hor_prep            varchar2(14);
  v_can_instrumento        ge_snp_transferencias.monto%type;
  v_can_par_entera          varchar2(16);
  v_can_par_decimal         varchar2(2);
  v_salto varchar2(100) := CHR(10)||CHR(13);
  v_ins_debito     varchar2(4);
  v_ins_credito    varchar2(4);
  PRAGMA AUTONOMOUS_TRANSACTION;
begin
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'PR_GEN_MSJ_SWI_MT524';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  ----PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

   v_cod_msj_num  := to_number(substr(v_cod_mensaje,3,3));
   v_can_instrumento   := P_CANTIDAD;  --cantidad de instrumentos--
   --v_mto_operacion   := 999999999999;
   v_can_par_entera  := to_char(trunc(v_can_instrumento));
   v_can_par_decimal := replace(to_char((nvl(v_can_instrumento,0) - nvl(v_can_par_entera,0))*100),'0',null);
   PAM_FLI.PR_CAR_VAR_PARAMETROS;

   IF P_TIP_ACCION NOT IN ('R','D') THEN --R-Pasar a Restringir / D-Pasar a Disponible
      --PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
      RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
   ELSE
      if P_TIP_ACCION = 'R' then
         v_ins_debito := 'AVAI';
         v_ins_credito := 'RSTR';
      else
         v_ins_debito := 'RSTR';
         v_ins_credito := 'AVAI';
      end if;
   END IF;

   --Variables--
   v_fec_hor_prep    := to_char(sysdate,'yyyymmddhh24miss');
   P_NRO_REFERENCIA := pas_snp.fu_obt_sig_nro_referencia;

   --CABECERA--
  /* pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje,
                                      'CAB',
                                      '{1:F01'||rpad(pam_dep.g_usu_xad_depo,12,'X')||'}'||
                                      '{2:I'||to_char(v_cod_msj_num)||rpad(pam_dep.g_bic_bcp_depo,12,'X')||'N}'||
                                      '{3:{113'||':'||lpad('90',4,'0')||'}}{4:');*/
   --DETALLE de Campos--
   --Bloque de Datos Generales--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'GENL');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '20C', ':SEME//'||P_NRO_REFERENCIA);  --Referencia Unica--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '23G', 'NEWM');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '98C', ':PREP//'||v_fec_hor_prep); --Fecha y Hora del mensaje--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'GENL');
   --Bloque de DatOS del Instrumento--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'INPOSDET');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '97A', ':SAFE//BBVA/DEPO/DEPO'); --Cuenta Ref de BBVA--
   --====Inicio de Campos Variables===--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '36B', ':SETT//UNIT/'||v_can_par_entera||','||v_can_par_decimal);  --Cantidad de Instrumentos--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '35B', '/XX/'||P_IDE_INSTRUMENTO); --PK Identificador de Instrumento--
   --====Fin de Campos Variables===--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '98A', ':SETT//'||to_char(vg_fecha,'yyyymmdd'));  --Fecha de Inicio--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '93A', ':FROM//'||v_ins_debito||v_salto||':93A::TOBA//'||v_ins_credito); --Saldo Origen--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'INPOSDET');
   --PIE del MT541--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, 'PIE', '}');

   begin
     --Generar Archivo con Formato--
     pao_pmt.pr_pro_mt_enviado(v_cod_mensaje, v_mensaje);

     pas_snp.g_lugar := 'Insertando mensaje en GE_SNP_MENSAJES, ';
     begin
       insert into ge_snp_mensajes
       (nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor,
        msj_swift, cod_moneda, monto, situacion, error, msj_swi_original)
        values
       (P_NRO_REFERENCIA, null, v_cod_msj_num, vg_fecha, v_mensaje, null,
        null, 'V', pas_snp.g_msj_error, v_mensaje);
     exception
       when others then
           raise_application_error(-20000,
                                  'Insertando en ge_snp_mensajes ' || sqlerrm);
     end;

    --Envia el Mensaje al Socket--
    /* pam_dep.PR_GEN_ARC_SWI_SERV(v_mensaje);*/

    commit;
   exception
      when others then
         raise;
   end;

   --Fin Registro del Log--
   V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
   --PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC,vg_nro_referencia,NULL,NULL,NULL,vg_nro_cuenta,vg_des_operacion);
   PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);
   commit;
EXCEPTION
  WHEN OTHERS THEN
    if sqlcode <= -20000 then
      --PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
      raise;
    else
      --PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
      RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
    end if;
END;

PROCEDURE PR_GEN_MSJ_SWI_MT986 (P_COD_MONEDA IN VARCHAR2, P_MTO_OPERACION IN NUMBER, P_NRO_REFERENCIA OUT VARCHAR2) IS
  -- Procedimiento de generación y envio de encaje legal (MT541)
  v_cod_mensaje     sb_snp_tip_mensajes.cod_mensaje%type := 'MT986';
  v_cod_msj_num     ge_snp_mensajes.cod_msj_swift%type;
  v_mensaje                 varchar2(4000);
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  v_fec_hor_prep            varchar2(14);
  v_mto_solicitado        ge_snp_transferencias.monto%type;
  v_mto_par_entera          varchar2(16);
  v_mto_par_decimal         varchar2(2);
  v_salto varchar2(100) := CHR(10)||CHR(13);
  vg_cod_mon_iso      ba_monedas.cod_moneda%type;
  vg_cod_mon_local    ba_monedas.cod_moneda%type;
  PRAGMA AUTONOMOUS_TRANSACTION;
begin
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'PR_GEN_MSJ_SWI_MT986';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  --PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

   v_cod_msj_num  := to_number(substr(v_cod_mensaje,3,3));
   v_mto_solicitado   := P_MTO_OPERACION;  --Monto Solicitado--
   v_mto_par_entera  := to_char(trunc(v_mto_solicitado));
   v_mto_par_decimal := replace(to_char((nvl(v_mto_solicitado,0) - nvl(v_mto_par_entera,0))*100),'0',null);
   PAM_FLI.PR_CAR_VAR_PARAMETROS;

   --Variables--
   v_fec_hor_prep    := to_char(sysdate,'yyyymmddhh24mi');
   P_NRO_REFERENCIA := pas_snp.fu_obt_sig_nro_referencia;
   vg_cod_swi_entidad := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
   vg_cta_ban_entidad := pas_snp.fu_obt_cta_ban_participante(vg_cod_swi_entidad,'GS');
   vg_cod_mon_local   := pag_gen.FU_OBT_MON_LOCAL;

   --Verificar la moneda ISO--
   if P_COD_MONEDA = vg_cod_mon_local then
      vg_cod_mon_iso := pas_snp.g_cod_mon_iso_local;
   else
      vg_cod_mon_iso := P_COD_MONEDA;
   end if;

   --CABECERA--
  /* pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje,
                                      'CAB',
                                      '{1:F01'||rpad(pam_dep.g_usu_xad_depo,12,'X')||'}'||
                                      '{2:I'||to_char(v_cod_msj_num)||rpad(pam_dep.g_bic_bcp_depo,12,'X')||'N}'||
                                      '{3:{113'||':'||lpad('90',4,'0')||'}}{4:');*/
   --DETALLE de Campos--
   --Bloque de Datos Generales--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '20', P_NRO_REFERENCIA);  --Referencia Unica--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '21', 'NONREF');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '59', '/'||vg_cta_ban_entidad||v_salto||vg_cod_swi_entidad);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79', 'ILFR/'||v_fec_hor_prep||v_salto||
                                 'RA'||vg_cod_mon_iso||'0,'||v_salto||'SD'||vg_cod_mon_iso||'0,'||v_salto||'SC'||vg_cod_mon_iso||'0,'||v_salto||
                                 'ED'||vg_cod_mon_iso||v_mto_par_entera||','||v_mto_par_decimal||v_salto||
                                 'EC'||vg_cod_mon_iso||'0,'||v_salto||'LD'||vg_cod_mon_iso||'0,'||v_salto||'LC'||vg_cod_mon_iso||'0,'||v_salto||
                                 'CC'||vg_cod_mon_iso||'0,'||v_salto||'AC'||vg_cod_mon_iso||'0,'); --Fecha y Hora del mensaje--
   --PIE del MT541--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, 'PIE', '}');

   begin
     --Generar Archivo con Formato--
     pao_pmt.pr_pro_mt_enviado(v_cod_mensaje, v_mensaje);

     pas_snp.g_lugar := 'Insertando mensaje en GE_SNP_MENSAJES, ';
     begin
       insert into ge_snp_mensajes
       (nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor,
        msj_swift, cod_moneda, monto, situacion, error, msj_swi_original)
        values
       (P_NRO_REFERENCIA, null, v_cod_msj_num, vg_fecha, v_mensaje, null,
        null, 'V', pas_snp.g_msj_error, v_mensaje);
     exception
       when others then
           raise_application_error(-20000,
                                  'Insertando en ge_snp_mensajes ' || sqlerrm);
     end;

    --Envia el Mensaje al Socket--
    /* pam_dep.PR_GEN_ARC_SWI_SERV(v_mensaje);*/

    commit;
   exception
      when others then
         raise;
   end;

   --Fin Registro del Log--
   V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
   --PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC,vg_nro_referencia,NULL,NULL,NULL,vg_nro_cuenta,vg_des_operacion);
   PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);
   commit;
EXCEPTION
  WHEN OTHERS THEN
    if sqlcode <= -20000 then
      --PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
      raise;
    else
      --PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
      RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
    end if;
END;

PROCEDURE PR_GEN_MSJ_SWI_MT595 (P_IDE_INSTRUMENTO IN VARCHAR2, P_NRO_REFERENCIA OUT VARCHAR2) IS
  -- Procedimiento de generación y envio de encaje legal (MT541)
  v_cod_mensaje     sb_snp_tip_mensajes.cod_mensaje%type := 'MT595';
  v_cod_msj_num     ge_snp_mensajes.cod_msj_swift%type;
  v_mensaje                 varchar2(4000);
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  v_fec_hor_prep            varchar2(14);
  v_salto varchar2(100) := CHR(10)||CHR(13);
  PRAGMA AUTONOMOUS_TRANSACTION;
begin
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'PR_GEN_MSJ_SWI_MT986';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  --PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

   v_cod_msj_num  := to_number(substr(v_cod_mensaje,3,3));
   PAM_FLI.PR_CAR_VAR_PARAMETROS;

   --Variables--
   v_fec_hor_prep     := to_char(sysdate,'yymmdd');
   P_NRO_REFERENCIA   := pas_snp.fu_obt_sig_nro_referencia;
   vg_cod_swi_entidad := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
   vg_cta_ban_entidad := pas_snp.fu_obt_cta_ban_participante(vg_cod_swi_entidad,'GS');

   --CABECERA--
  /* pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje,
                                      'CAB',
                                      '{1:F01'||rpad(pam_dep.g_usu_xad_depo,12,'X')||'}'||
                                      '{2:I'||to_char(v_cod_msj_num)||rpad(pam_dep.g_bic_bcp_depo,12,'X')||'N}'||
                                      '{3:{113'||':'||lpad('90',4,'0')||'}}{4:');*/
   --DETALLE de Campos--
   --Bloque de Datos Generales--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '20', P_NRO_REFERENCIA);  --Referencia Unica--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '21', P_IDE_INSTRUMENTO);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '75', 'BBRQ');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '11S', '543'||v_salto||v_fec_hor_prep);

   --PIE del MT541--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, 'PIE', '}');

   begin
     --Generar Archivo con Formato--
     pao_pmt.pr_pro_mt_enviado(v_cod_mensaje, v_mensaje);

     pas_snp.g_lugar := 'Insertando mensaje en GE_SNP_MENSAJES, ';
     begin
       insert into ge_snp_mensajes
       (nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor,
        msj_swift, cod_moneda, monto, situacion, error, msj_swi_original)
        values
       (P_NRO_REFERENCIA, null, v_cod_msj_num, vg_fecha, v_mensaje, null,
        null, 'V', pas_snp.g_msj_error, v_mensaje);
     exception
       when others then
           raise_application_error(-20000,
                                  'Insertando en ge_snp_mensajes ' || sqlerrm);
     end;

    --Envia el Mensaje al Socket--
    /* pam_dep.PR_GEN_ARC_SWI_SERV(v_mensaje);*/

    commit;
   exception
      when others then
         raise;
   end;

   --Fin Registro del Log--
   V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
   --PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC,vg_nro_referencia,NULL,NULL,NULL,vg_nro_cuenta,vg_des_operacion);
   PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);
   commit;
EXCEPTION
  WHEN OTHERS THEN
    if sqlcode <= -20000 then
      --PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
      raise;
    else
      --PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
      RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
    end if;
END;

PROCEDURE PR_GEN_MSJ_SWI_MT542 (P_IDE_INSTRUMENTO IN VARCHAR2,
                                P_COD_MONEDA IN VARCHAR2,
                                P_MTO_OPERACION IN NUMBER, P_NRO_REFERENCIA OUT VARCHAR2) IS
  -- Procedimiento de generación y envio de encaje legal (MT541)
  v_cod_mensaje     sb_snp_tip_mensajes.cod_mensaje%type := 'MT542';
  v_cod_msj_num     ge_snp_mensajes.cod_msj_swift%type;
  v_mensaje                 varchar2(4000);
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  v_fec_hor_prep            varchar2(14);
  v_mto_solicitado        ge_snp_transferencias.monto%type;
  v_mto_par_entera          varchar2(16);
  v_mto_par_decimal         varchar2(2);
  v_salto varchar2(100) := CHR(10)||CHR(13);
  vg_cod_mon_iso      ba_monedas.cod_moneda%type;
  vg_cod_mon_local    ba_monedas.cod_moneda%type;
  vg_fecha            date := pag_cal.FU_OBT_FEC_ACTUAL(10);
  vg_fec_vencim       date;
  vg_cod_swi_otr_bco  ge_snp_transferencias.cod_swi_pte_solicitante%type;
  vg_cod_per_ope      ba_personas.cod_persona%type;
  vg_cod_mad_ope      ge_modalidades.cod_modalidad%type;
  vg_cod_modulo       ba_modulos.cod_modulo%type;

  PRAGMA AUTONOMOUS_TRANSACTION;
begin
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'PR_GEN_MSJ_SWI_MT986';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  --PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

   v_cod_msj_num  := to_number(substr(v_cod_mensaje,3,3));
   v_mto_solicitado   := P_MTO_OPERACION;  --Monto Solicitado--
   v_mto_par_entera  := to_char(trunc(v_mto_solicitado));
   v_mto_par_decimal := replace(to_char((nvl(v_mto_solicitado,0) - nvl(v_mto_par_entera,0))*100),'0',null);
   PAM_FLI.PR_CAR_VAR_PARAMETROS;

   --Variables--
   v_fec_hor_prep    := to_char(sysdate,'yyyymmddhh24miss');
   P_NRO_REFERENCIA := pas_snp.fu_obt_sig_nro_referencia;
   vg_cod_swi_entidad := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
   vg_cta_ban_entidad := pas_snp.fu_obt_cta_ban_participante(vg_cod_swi_entidad,'GS');
   vg_cod_mon_local   := pag_gen.FU_OBT_MON_LOCAL;
   vg_fec_vencim := pag_cal.fu_obt_fec_habil(vg_fecha+1,1,1);

   --Verificar la moneda ISO--
   if P_COD_MONEDA = vg_cod_mon_local then
      vg_cod_mon_iso := pas_snp.g_cod_mon_iso_local;
   else
      vg_cod_mon_iso := P_COD_MONEDA;
   end if;

   --Obtener la persona de bcp--
   vg_cod_mad_ope   := fue_obt_val_max_refcodes('DEP_AUT_TIP_OPE','FLI');
   --Traer el dato de cod_modulo-
   select x.cod_modulo
     into vg_cod_modulo
     from ge_modalidades x
    where x.cod_modalidad = vg_cod_mad_ope;

   vg_cod_per_ope := fug_obt_pardinamico('DEP_FLI_COD_PER_OPE',vg_cod_modulo, vg_cod_mad_ope,P_COD_MONEDA,null,null);
   vg_cod_swi_otr_bco := pas_snp.fu_obt_cod_swi_participante(vg_cod_per_ope);

   --CABECERA--
  /* pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje,
                                      'CAB',
                                      '{1:F01'||rpad(pam_dep.g_usu_xad_depo,12,'X')||'}'||
                                      '{2:I'||to_char(v_cod_msj_num)||rpad(pam_dep.g_bic_bcp_depo,12,'X')||'N}'||
                                      '{3:{113'||':'||lpad('90',4,'0')||'}}{4:');*/
   --DETALLE de Campos--
   --Bloque de Datos Generales--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'GENL');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '20C', ':SEME//'||P_NRO_REFERENCIA);  --Referencia Unica--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '23G', 'NEWM');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '98C', ':PREP//'||v_fec_hor_prep); --Fecha y Hora del mensaje--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'LINK');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '13A', ':LINK//543');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '20C', ':PREV//'||P_IDE_INSTRUMENTO);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'LINK');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'LINK');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '20C', ':COMM//'||P_NRO_REFERENCIA);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'LINK'||v_salto||':16S:GENL');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'TRADDET');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '94B', ':TRAD//OTCO');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '98A', ':SETT//'||to_char(vg_fecha,'yyyymmdd')); --Fecha de Inicio--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '35B', '/XX/ILF');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'FIA');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '12A', ':CLAS//ILF'); --
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'FIA'||v_salto||':16S:TRADDET');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'FIAC');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '36B', ':SETT//UNIT/'||v_mto_par_entera||','||v_mto_par_decimal);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '97A', ':SAFE//BCPA/ILF');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'FIAC');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'REPO');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '98A', ':TERM//'||to_char(vg_fec_vencim,'yyyymmdd'));
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'REPO');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'SETDET');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '22F', ':SETR//REPU'||v_salto||
                                                       ':22F::STCO//DLWM'||v_salto||
                                                       ':22F::CCPT//YCCP'||v_salto||
                                                       ':22F::COLA//LIQU'||v_salto||
                                                       ':22F::REPT//ROLP');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '95Q', ':DEAG//'||vg_cod_swi_entidad);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '95Q', ':DECU//'||vg_cod_swi_entidad);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '97A', ':SAFE//BBVA/DEPO');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '95Q', ':SELL//'||vg_cod_swi_entidad);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '97A', ':SAFE//RSTR/BBVA/DEPO/DEPO');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '95Q', ':REAG//'||vg_cod_swi_otr_bco);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '95Q', ':RECU//'||vg_cod_swi_otr_bco);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '97A', ':SAFE//BCPA/ILF');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '95Q', ':BUYR//'||vg_cod_swi_otr_bco);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '97A', ':SAFE//BORR/BCPA/ILF/ILF');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'AMT');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '19A', ':DEAL//'||vg_cod_mon_iso||v_mto_par_entera||','||v_mto_par_decimal);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'AMT'||v_salto||':16S:SETDET');

   --PIE del MT541--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, 'PIE', '}');

   begin
     --Generar Archivo con Formato--
     pao_pmt.pr_pro_mt_enviado(v_cod_mensaje, v_mensaje);

     pas_snp.g_lugar := 'Insertando mensaje en GE_SNP_MENSAJES, ';
     begin
       insert into ge_snp_mensajes
       (nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor,
        msj_swift, cod_moneda, monto, situacion, error, msj_swi_original)
        values
       (P_NRO_REFERENCIA, null, v_cod_msj_num, vg_fecha, v_mensaje, null,
        null, 'V', pas_snp.g_msj_error, v_mensaje);
     exception
       when others then
           raise_application_error(-20000,
                                  'Insertando en ge_snp_mensajes ' || sqlerrm);
     end;

    --Envia el Mensaje al Socket--
     /*pam_dep.PR_GEN_ARC_SWI_SERV(v_mensaje);*/

    commit;
   exception
      when others then
         raise;
   end;

   --Fin Registro del Log--
   V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
   --PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC,vg_nro_referencia,NULL,NULL,NULL,vg_nro_cuenta,vg_des_operacion);
   PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);
   commit;
EXCEPTION
  WHEN OTHERS THEN
    if sqlcode <= -20000 then
      --PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
      raise;
    else
      --PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
      RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
    end if;
END;

END PAM_FLI;
/

