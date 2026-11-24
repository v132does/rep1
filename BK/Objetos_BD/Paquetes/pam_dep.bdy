CREATE OR REPLACE PACKAGE BODY IT.PAM_DEP is

  --Variables Generales--
  vg_fecha            date;
  vg_fecfor           varchar2(2000);
  vg_fec_sistema      date := trunc(sysdate);
  vg_redondeo         number(1);
  vg_cod_modulo       ba_modulos.cod_modulo%type;
  vg_mto_interes      md_cta_documentos.mto_interes%type;
  vg_val_tas_actual   md_cta_documentos.val_tasa%type;
  vg_val_tas_min      md_cta_documentos.val_tasa%type;
  vg_val_tas_max      md_cta_documentos.val_tasa%type;
  vg_val_tas_tae      md_cta_documentos.val_tasa%type;
  vg_tasadiv          number;
  vg_cod_moneda       ba_monedas.cod_moneda%type;
  vg_fec_vencim       date;
  vg_nro_cuenta       md_cta_documentos.nro_cuenta%type;
  vg_nom_cliente      ba_personas.nom_completo%type;
  vg_mto_operacion    md_cta_documentos.monto%type;
  vg_dia_plazo        md_cta_documentos.dia_devengado%type;
  vg_mto_lim_diario   md_cta_documentos.monto%type;
  vg_mto_man_diario   md_cta_documentos.monto%type;
  vg_sal_cta_sipap    md_cta_documentos.monto%type;
  vg_mto_enc_normal   md_cta_documentos.monto%type;
  vg_mto_enc_especial md_cta_documentos.monto%type;
  vg_mto_ope_bruto    md_cta_documentos.monto%type;
  vg_nom_entidad      ge_par_generales.nom_entidad%type;
  vg_cod_per_entidad  ge_par_generales.cod_persona%type;
  vg_cod_swi_entidad  ge_snp_transferencias.cod_swi_pte_solicitante%type;
  vg_cod_swi_beneficiario ge_snp_transferencias.cod_swi_pte_solicitante%type;
  vg_cta_ban_entidad  cc_cta_bancarias.nro_cta_bancaria%type := null;
  vg_cta_ban_beneficiario cc_cta_bancarias.nro_cta_bancaria%type;
  vg_hor_saldo        ge_snp_transferencias.hora%type;
  --vg_hor_actual       ge_snp_transferencias.hora%type;
  vg_msj_swift        ge_snp_mensajes.msj_swift%type;
  vg_cod_mon_iso      ba_monedas.cod_moneda%type;
  vg_cod_mon_local    ba_monedas.cod_moneda%type;
  vg_cod_programa     ge_log_procesos.cod_programa%type := 'PAM_DEP';
  vg_des_operacion    varchar2(4000);
  vg_nro_referencia   ge_snp_mensajes.nro_referencia%type;
  --vg_nro_ref_mt999    ge_snp_mensajes.nro_referencia%type;
  vg_cod_msj_swift    ge_snp_mensajes.cod_msj_swift%type := '541';
  vg_bic_entidad      ge_snp_transferencias.cod_swi_pte_solicitante%type;
  vg_tie_espera       constant number(4)   := fug_obt_pardinamico( 'DEPO_SCK_TIE_ESPERA' ); --DYDMR-12398

  --Variables de Par Dinamicos--
  vg_cod_mad_ope      ge_modalidades.cod_modalidad%type;
  vg_mon_hab_ope      varchar2(1);
  vg_cod_per_ope      ba_personas.cod_persona%type;
  vg_dia_plz_ope      md_cta_documentos.dia_devengado%type;
  vg_cod_ofi_ope      ba_oficinas.cod_oficina%type;
  vg_tip_cal_ope      md_cta_documentos.tip_calculo%type;
  vg_for_pag_ope      md_cta_documentos.for_pago%type;
  vg_ref_cre_ope      md_cta_documentos.nro_ref_credito%type;
  vg_dia_ano_ope      md_cta_documentos.dia_ano%type;
  vg_mer_sec_ope      md_cta_documentos.mer_secundario%type;
  vg_rub_eco_ope      md_cta_documentos.cod_rub_economico%type;
  vg_seg_csa_ope      number(6);

  --Variables para Desembolso--
  vg_mto_desembolsar  ge_movimientos.monto%type;
  vg_hora             ge_movimientos.hora%type;
  vg_mto_garantia     md_garantias.monto%type;
  vg_nro_secuencia    ge_movimientos.nro_secuencia%type;
  vg_cotizacion       ge_movimientos.cotizacion%type;
  r_gmovi             ge_movimientos%rowtype;
  r_gmovc             ge_movimientos%rowtype;
  vg_cod_rubro        ge_movimientos.cod_rubro%type;

  --Variables control Ejecucion--
  vg_nro_orden        ge_pro_paralelos_det.nro_orden%type;
  vg_bic_beneficiario ge_snp_transferencias.cod_swi_pte_solicitante%type;
  vg_cod_ejecucion    MD_DEP_MSJ_AUTOMATICOS.COD_EJECUCION%type;
  vg_asunto           varchar2(2000);
  vg_mensaje          varchar2(2000);
  vg_des_ope_enviada  md_dep_cta_documentos.des_operacion%type;
  ---
  vg_es_nocturno varchar2(1) := 'N';
  
  --SPI
  vg_cta_origen       varchar2(5) := null;
  vg_ref_cre_spi      md_cta_documentos.nro_ref_credito%type := fug_obt_pardinamico('SPI_COD_RUB_MX');
/* Obtener Valor de Parametros Especiales de DEPO */
FUNCTION FU_OBT_PARAMETRO(P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE,
                          P_PARAMETRO IN VARCHAR2,
                          P_FECHA IN DATE default pag_cal.FU_OBT_FEC_ACTUAL(10))
                          RETURN NUMBER IS
  /*Obtiene el valor de Parametros Especiales de DEPO  */
  /*Requerimiento CNFNORMA-338 - DEPO/X  */

  V_MONTO MD_DEP_PAR_ESPECIALES.MONTO%TYPE;
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
BEGIN
  --Inicio Registro del Log--
  V_LUG_PRO_LOC := 'FU_OBT_PARAMETRO';
  vg_nro_orden  := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);

  --Obtencion de Datos--
  IF P_PARAMETRO = 'MTO_MAN_DIA_FPD' THEN
     SELECT monto
       INTO v_monto
       FROM md_dep_par_especiales a
      WHERE a.cod_moneda = p_cod_moneda
        and a.parametro = p_parametro
        and a.fecha  = vg_fecha;
  ELSE
     SELECT monto
       INTO v_monto
       FROM md_dep_par_especiales a
      WHERE a.cod_moneda = p_cod_moneda
        and a.parametro = p_parametro
        and a.fecha  = (SELECT max(b.fecha)
                          FROM md_dep_par_especiales b
                         WHERE b.cod_moneda = p_cod_moneda
                           and b.parametro = p_parametro
                           AND b.fecha <= P_FECHA);
  END IF;
  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

  --Retorna el Valor--
  Return v_monto;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      v_monto := 0;
      Return v_monto;
   WHEN OTHERS THEN
      PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC);
      RAISE_APPLICATION_ERROR(-20000,SQLERRM||'ERROR en pam_dep.fu_obt_parametro - '||sqlerrm);
END;

/* Calcula el Valor de monto recibido dentro de su unidad */
FUNCTION FU_CAL_VAL_MTO_PISO(P_VALOR IN NUMBER) RETURN NUMBER IS
  /*Calcula el Valor del piso del Monto recibida dentro de la unidad recibida*/
  /*Requerimiento CNFNORMA-338 */
  v_numero  varchar2(15);
  v_numchar varchar2(3);
  v_inicio  number(2);
  v_numdes  number;
  v_val_calculado number;
  v_fac_calculado number;
  v_fin_calculado varchar2(1);
  V_HOR_INI_LOC   VARCHAR2(8);
  V_HOR_FIN_LOC   VARCHAR2(8);
  V_LUG_PRO_LOC   VARCHAR2(250);
  V_MONTO         NUMBER;--PARA VALORES MENORES A fug_obt_pardinamico('DEPO_MONTO') 
  V_MONTO_SUP     NUMBER;--PARA VALORES SUPERIORES O IGUALES fug_obt_pardinamico('DEPO_MONTO') 
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
begin
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'FU_CAL_VAL_MTO_PISO';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);

  --Inicio del Calculo--
  v_inicio := 1;
  v_numdes := 5;
  v_numero := lpad(to_char(floor(p_valor)),15,'0');
  v_fin_calculado := 'N';
  V_MONTO_SUP := null;
  --VAE 2021/02/03 VALIDAR SI ES MAYOR A UN BILLON QUE CORTE SOLAMENTE HASTA EL MILLAR DE MILLON, 
  --CASO CONTRARIO CONTINUA EL CONTROL DE SIEMPRE
  IF p_valor >= fug_obt_pardinamico('DEPO_MONTO') 
    and fug_obt_pardinamico('DEPO_CANT_DIG_MONTO') is not null 
    then
    Select trunc(p_valor,-1* fug_obt_pardinamico('DEPO_CANT_DIG_MONTO'))
    Into   V_MONTO_SUP
    From   dual;
    v_fin_calculado := 'S';
  END IF;
  --
  WHILE (v_fin_calculado <> 'S') loop
    v_numchar := substr(v_numero,v_inicio,3);
    IF v_numchar <> '000' THEN
       v_val_calculado := to_number(v_numchar);
       v_fac_calculado := power(1000,v_numdes-1);
       v_fin_calculado := 'S';
    else
       v_inicio:= v_inicio + 3;
       v_numdes := v_numdes - 1;
    END IF;
  end loop;
  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

  V_MONTO:=v_val_calculado * v_fac_calculado;
  --Retorno del Valor--
  return NVL(V_MONTO_SUP,V_MONTO);
exception
  WHEN OTHERS THEN
       PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC);
       RAISE_APPLICATION_ERROR(-20000,SQLERRM||'ERROR en pam_dep.fu_cal_val_piso - '||sqlerrm);
end;

FUNCTION FU_OBT_HOR_SEGUNDO
 (P_HORA IN GE_MOVIMIENTOS.HORA%TYPE,
  P_CAN_SEGUNDOS IN NUMBER)
 RETURN VARCHAR2
 IS

  v_hora number;
  V_MINUTO number;
  V_SEGUNDO number;
  v_total number;
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
BEGIN
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'FU_OBT_HOR_SEGUNDO';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);

  --Calculo de Hora segundo--
  v_total := ((to_number(SUBSTR(P_HORA,1,2)) * 3600) +
              (to_number(SUBSTR(P_HORA,4,2)) * 60) +
              (to_number(SUBSTR(P_HORA,7,2)))) + P_CAN_SEGUNDOS;
  v_hora    := trunc(v_total / 3600);
  V_MINUTO  := trunc((v_total - (v_hora * 3600)) / 60);
  V_SEGUNDO := v_total - ((v_hora * 3600) + (V_MINUTO * 60));

  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

  --Retorna el siguiente segundo a la hora dada--
  RETURN  LPAD(v_hora,2,'0')||':'||LPAD(V_MINUTO,2,'0')||':'||LPAD(V_SEGUNDO,2,'0');
END;

FUNCTION FU_OBT_VAL_CAM_ESP(P_MEN_PROCESAR IN CLOB,
                            P_CAMPO IN SB_SNP_CAMPOS.CAMPO%TYPE) RETURN VARCHAR2 is
  v_cadena varchar2(4000);
  v_texto  varchar2(4000);
  v_buscar varchar2(4000);
BEGIN
   --Obtiene el valor del TAG, en caso de no existir solo retorna NULL
   v_buscar := p_campo||'(.*)';
   v_cadena := regexp_substr(p_men_procesar, v_buscar);
   v_texto  := SUBSTR(v_cadena,LENGTH(p_campo)+1);
   v_texto  := REPLACE(REPLACE(v_texto, chr(10),''),chr(13),'');
   return v_texto;
END;

FUNCTION FU_OBT_EST_MOD_DEPO(P_COD_PERIODO IN NUMBER) RETURN VARCHAR2 is
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  v_estado md_dep_horarios.estado%type;
BEGIN
   V_LUG_PRO_LOC := 'FU_OBT_EST_MOD_DEPO';
   vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
   V_NRO_ORD_LOC := vg_nro_orden;
   V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
   PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
   --Obtiene el valor del TAG, en caso de no existir solo retorna NULL
   SELECT x.estado
     INTO v_estado
     from md_dep_horarios x
    where x.cod_periodo = p_cod_periodo;
   return v_estado;
   --Fin Registro del Log--
   V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
   PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC, vg_nro_referencia,NULL,NULL,NULL,vg_nro_cuenta,vg_des_operacion);
   PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);
EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END;

FUNCTION FU_OBT_DAT_MONITOREO RETURN VARCHAR2 IS
  CURSOR C_DAT_MONITOREO IS
         SELECT '==========INICIO MONITOREO=========='||chr(10)||CHR(13)||
        'Fecha: '||TO_CHAR(fecha,'DD/MM/YYYY')||' Cod.Ejecucion: '||to_char(cod_ejecucion) cabecera,
        'Orden: '||to_char(nro_orden)||' - Env: '||cod_msj_enviado||' - Ref.: '||nro_ref_enviado||' - Hora: '||hor_enviado||
        ' // Res: '||cod_msj_respuesta||' - Ref.: '||rpad(nro_ref_respuesta,20,' ')||' - Hora: '||hor_respuesta||' - Est: '||estado linea
        from MD_DEP_MSJ_AUTOMATICOS t
        where fecha = vg_fecha
          and to_number(t.cod_ejecucion) = (select max(to_number(cod_ejecucion))
                                              from MD_DEP_MSJ_AUTOMATICOS x
                                             where x.fecha = vg_fecha)
        order by fecha, cod_ejecucion, nro_orden;
  v_can_lineas number(6);
  v_tex_monitoreo varchar2(4000);
  v_pie varchar2(4000) := '========== FIN  MONITOREO ==========';
  v_salto varchar2(100) := CHR(10)||CHR(13);
BEGIN
  v_tex_monitoreo := null;
  for det in C_DAT_MONITOREO loop
      v_can_lineas := nvl(v_can_lineas,0) + 1;
      if v_can_lineas = 1 then
         v_tex_monitoreo := det.cabecera||v_salto;
         v_tex_monitoreo := v_tex_monitoreo||det.linea||v_salto;
      else
         v_tex_monitoreo := v_tex_monitoreo||det.linea||v_salto;
      end if;
  end loop;
  if v_tex_monitoreo is null then
     v_tex_monitoreo := 'Sin Envios FPD de fecha '||to_char(vg_fecha,'dd/mm/yyyy');
  else
     v_tex_monitoreo := v_tex_monitoreo||v_pie;
  end if;
  return v_tex_monitoreo;
END;

FUNCTION FU_OBT_VAL_SAL_SIPAP(P_COD_EJECUCION IN VARCHAR2) RETURN NUMBER is
  --Para marcar el envio--
  v_cod_ejecucion md_dep_msj_automaticos.cod_ejecucion%type;
  v_nro_orden     md_dep_msj_automaticos.nro_orden%type;
  v_exi_msj_enviado varchar2(1);
  v_tex_cam_especial varchar2(4000);
  v_tex_sal_cta_sipap varchar2(4000);
  v_cod_msj_env_bcp sb_snp_tip_mensajes.cod_mensaje%type;
BEGIN
  pam_dep.PR_CAR_VAR_PARAMETROS;
  pam_dep.PR_OBT_DAT_MSJ_ACTUAL('MT920','S',P_COD_EJECUCION,v_exi_msj_enviado,v_cod_ejecucion,v_nro_orden, v_cod_msj_env_bcp);
  if v_exi_msj_enviado = 'S' then
      select y.val_campo1
        into vg_msj_swift
        from MD_DEP_MSJ_AUTOMATICOS y
       where y.fecha = vg_fecha
         and y.cod_tip_ope = 'DEP_AUT_MSJ_FPD'
         and y.cod_ejecucion = P_COD_EJECUCION
         and y.nro_orden = v_nro_orden
         and y.cod_msj_enviado = 'MT920'
         --AND y.nro_ref_enviado = :new.nro_ref_externa
         and y.estado = 'R'
         and y.ref_campo1 = '64'
         and y.val_campo1 is not null;
       -----
       v_tex_cam_especial := 'C'||to_char(vg_fecha,'yymmdd')||vg_cod_mon_iso;
       v_tex_sal_cta_sipap := REPLACE(PAM_DEP.FU_OBT_VAL_CAM_ESP(vg_msj_swift, v_tex_cam_especial),'.',',');
       vg_sal_cta_sipap := to_number(v_tex_sal_cta_sipap);
  else
    if P_COD_EJECUCION = 'X' then --Saldo a Requerimiento, viene cargado vg_msj_swift--
       v_tex_cam_especial := 'C'||to_char(vg_fecha,'yymmdd')||vg_cod_mon_iso;
       v_tex_sal_cta_sipap := REPLACE(PAM_DEP.FU_OBT_VAL_CAM_ESP(vg_msj_swift, v_tex_cam_especial),'.',',');
       vg_sal_cta_sipap := to_number(v_tex_sal_cta_sipap);
    end if;
  end if;
  return vg_sal_cta_sipap;
END FU_OBT_VAL_SAL_SIPAP;

FUNCTION FU_PRO_MSJ_RECIBIDOS ( P_MENSAJE IN LONG )  RETURN VARCHAR2
IS
   /*
   || Carga la mensajer¿a recibida desde el Socket. ramonpavon
   */

   v_respuesta varchar2(4000);

BEGIN
   -- Inicializaci¿n del sistema.
   pre_ini_aplicacion;
   pae_cnf.g_cod_modulo := 1;
   PAM_DEP.PR_CAR_VAR_PARAMETROS;

   pas_snp.g_lugar := 'Iniciando verificacion del mensaje recibido a traves del PAO_PMT, ';

   --Nueva l¿gica esquematizada
   v_respuesta := pam_dep.fu_pro_mt_recibido( replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ) );
   if substr( v_respuesta, 1, 2 ) not in ( '00', '99' ) then
      -- Si tiene ERRORES se guarda el mensaje.
      pas_snp.pr_reg_operacion( replace( dbms_lob.substr(p_mensaje,4000,1), pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), '99|' || pas_snp.g_lugar || v_respuesta );
   elsif upper(v_respuesta) like '%TIP%MEN%NO%ENC%' then
       v_respuesta := pam_dep.fu_reg_msj_generico(p_mensaje);
   end if;

   pas_snp.g_lugar := 'Registrando datos en el LOG, ';

   pas_snp.pr_reg_operacion( replace( dbms_lob.substr(p_mensaje,4000,1), pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), v_respuesta );

   return v_respuesta;

EXCEPTION
   when others then
      -- Si tiene ERRORES se guarda el mensaje.
      pas_snp.pr_reg_operacion( replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), '99|' || pas_snp.g_lugar || sqlerrm );

      return '-1|Error durante el proceso del Mensaje ';

END FU_PRO_MSJ_RECIBIDOS;

/*Procesa el MT de Recepción*/
FUNCTION FU_PRO_MT_RECIBIDO( P_TEXTO IN CLOB )
  return varchar2 is

   r_sb_snp_tmp_mensajes sb_snp_mensajes_tmp%rowtype := null;
   v_cod_mensaje         sb_snp_tip_mensajes.cod_mensaje%type;
   v_can_lineas          number;
   v_det_campo sb_snp_campos.campo%type;
   v_cod_msj_sin_formato ge_par_dinamicos.val_parametro%type;

begin
   begin
     --obtengo el mensaje, si no encuentra esquematizado igual se debe registrar en GE_SNP_MENSAJES
     v_cod_mensaje := pao_pmt.fu_obt_cod_mensaje(p_texto);
   exception
     when others then
       if sqlcode <= -20000 and
           upper( sqlerrm ) like '%MEN%NO%ENCONT%'
       then
          return '00|'||v_cod_mensaje||'|Error en la obtención del código de mensaje: '||sqlerrm;
       else
          raise;
       end if;
   end;
   --Obtengo el campo PK del Detalle
   select max(d.campo)
     into v_det_campo
     from sb_snp_campos d
    where d.cod_mensaje = v_cod_mensaje
      and d.orden = (select min(orden)
                       from sb_snp_campos
                      where cod_mensaje = d.cod_mensaje
                        and ind_detalle = d.ind_detalle)
      and d.ind_detalle = 'S';
   --Se cuentan la cantidad de líneas para el recorrido
   select count(*)
     into v_can_lineas
     from table(fug_obt_tab_registro(replace(p_texto, chr(13)), chr(10)));
   --Se elimina los datos de la tabla temporal para el tipo de mensaje
   delete sb_snp_mensajes_tmp where cod_mensaje = v_cod_mensaje;
   --Grabo línea por línea
   for i in 1..v_can_lineas loop
      r_sb_snp_tmp_mensajes.cod_mensaje := v_cod_mensaje;
      r_sb_snp_tmp_mensajes.orden := i;
      r_sb_snp_tmp_mensajes.valor := trim(pao_pmt.fu_obt_linea(p_texto, r_sb_snp_tmp_mensajes.orden));
      r_sb_snp_tmp_mensajes.campo := nvl(pao_pmt.fu_obt_campo(r_sb_snp_tmp_mensajes.valor), r_sb_snp_tmp_mensajes.campo);
      if r_sb_snp_tmp_mensajes.campo = pao_pmt.fu_obt_campo(r_sb_snp_tmp_mensajes.valor) then
         r_sb_snp_tmp_mensajes.nro_linea := 1;
         if nvl(v_det_campo, '*') = r_sb_snp_tmp_mensajes.campo then
            r_sb_snp_tmp_mensajes.nro_detalle := nvl(r_sb_snp_tmp_mensajes.nro_detalle, 0) + 1;
         end if;
      else
         r_sb_snp_tmp_mensajes.nro_linea := r_sb_snp_tmp_mensajes.nro_linea + 1;
      end if;
      r_sb_snp_tmp_mensajes.valor := trim(replace(r_sb_snp_tmp_mensajes.valor, ':'||r_sb_snp_tmp_mensajes.campo||':'));
      insert into sb_snp_mensajes_tmp values r_sb_snp_tmp_mensajes;
   end loop;

   --Se verifica el esquema
   v_cod_msj_sin_formato := fug_obt_pardinamico('DEP_AUT_MSJ_SFO_OPE');
   if instr(v_cod_msj_sin_formato,v_cod_mensaje) = 0 then
   --if v_cod_mensaje NOT IN ('MT545','MT543','MT547') then
     r_sb_snp_tmp_mensajes.err_formato := pao_pmt.fu_ver_esquema(v_cod_mensaje, 'N');
     if trim(r_sb_snp_tmp_mensajes.err_formato) is not null then
        --Si hubieron errores retorna
        return '00|'||v_cod_mensaje||'|Error en el formato: '||r_sb_snp_tmp_mensajes.err_formato;
     end if;
   end if;
   --Procesa la Ejecución dinámica con la función parametrizada
   declare
      v_obj_proceso   sb_snp_tip_mensajes.obj_proceso%type;
      v_ret_funcion   varchar2(1000);
      v_sql           varchar2(32767);
    begin
       --Obtengo la función
       select b.obj_proceso
         into v_obj_proceso
         from md_dep_tip_mensajes b
        where b.cod_mensaje = r_sb_snp_tmp_mensajes.cod_mensaje;
       if v_obj_proceso is null then
          return '00|'||v_cod_mensaje||'|Error al buscar el objeto a procesar: No hay Función de proceso definida para '||r_sb_snp_tmp_mensajes.cod_mensaje;
       else
          v_sql := 'BEGIN :b := '||v_obj_proceso||'('||chr(39)||replace(replace(p_texto, chr(39), chr(39)||chr(39)),chr(13)||chr(10),'*')||chr(39)||'); END;';
          EXECUTE IMMEDIATE v_sql USING OUT v_ret_funcion;
       end if;
       --Retorno el mensaje de la lógica de negocios
       return v_ret_funcion;
    exception
       when no_data_found then
          return '00|'||v_cod_mensaje||'|Error al buscar el objeto a procesar(2): No hay Función de proceso definida para '||r_sb_snp_tmp_mensajes.cod_mensaje;
       when others then
          return '00|'||v_cod_mensaje||'|Error al ejecutar el objeto '||v_obj_proceso||': '||sqlerrm;
    end;

exception
   when others then
      return '00|'||v_cod_mensaje||'Error al procesar el MT recibido: '||sqlerrm;

END FU_PRO_MT_RECIBIDO;

FUNCTION FU_REG_MSJ_GENERICO  ( P_MENSAJE          IN CLOB,
                                P_IND_MSJ_RECIBIDO IN VARCHAR2 DEFAULT 'S',
                                P_ENV_MAIL         IN VARCHAR2 DEFAULT 'S'
                               ) RETURN VARCHAR2
is

   v_cod_mensaje      sb_snp_mensajes_tmp.cod_mensaje%type;
   v_nro_referencia   ge_snp_mensajes.nro_referencia%type;
   v_nro_ref_externa  ge_snp_mensajes.nro_referencia%type;
   v_dir_correo      ge_par_dinamicos.val_parametro%type := nvl( pam_dep.g_gru_dir_correo, pam_dep.g_err_dir_correo );
   v_txt_mail        varchar2(4000);
   v_asunto          varchar2(4000);
   v_msj_swift       varchar2(4000);
   v_msj_swi_original  clob := null;
   v_contador      number:=0;
   cursor c_msj_temporal is
   select a.cod_mensaje,
     a.campo,
     a.valor,
     a.descripcion,
     a.err_formato,
     a.orden
   from sb_snp_mensajes_tmp a
   where a.campo not in ('CAB', 'PIE')
     and a.descripcion is not null
   order by orden;

begin

   select count(*)
   into v_contador
   from sb_snp_mensajes_tmp;

   if v_contador=0 then
      -- Se recuperar valores para la insercion en GE_SNP_MENSAJES cuando no est¿ esquematizado.
      v_cod_mensaje := pao_pmt.fu_obt_cod_msj_swift( pao_pmt.fu_obt_linea(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), 1) );
    v_msj_swift := dbms_lob.substr(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ),200,1)||
                 pas_snp.fu_obt_salto||
                 '. . . .'||
                 pas_snp.fu_obt_salto||
                 '. . . .'||
                 pas_snp.fu_obt_salto||
                 '. . . .';
    v_msj_swi_original := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
      v_nro_referencia  := pao_pmt.fu_obt_val_campo( replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), '20' );
      v_nro_ref_externa := pao_pmt.fu_obt_val_campo( replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), '21' );
      v_asunto := vg_fecfor||'Se recibio un Mensaje sin formato';
      v_txt_mail := 'Se recibio un MT con el siguiente detalle:' || chr(10) || chr(10) ||
               'Nro. Referencia     : ' || v_nro_referencia || chr(10) ||
               'Nro. Ref. Original  : ' || v_nro_ref_externa || chr(10) ||
               'Detalle del mensaje : ' || replace( dbms_lob.substr(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ),3000,1)
                          ||pas_snp.fu_obt_salto
                          ||'. . . .'
                          ||pas_snp.fu_obt_salto
                          ||'. . . .'
                          ||pas_snp.fu_obt_salto
                          ||'. . . .',
                          pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ) || chr(10) || chr(10) || chr(10) ||
               'Atentamente.';

   else
    for msj in c_msj_temporal loop
        --Creo la cabecera del mail
         v_asunto := vg_fecfor||'Mensajeria '|| msj.cod_mensaje || ' Recibida' ||chr(10);
         v_cod_mensaje := msj.cod_mensaje;
         --Se concatena los datos disponibles para el env¿o del Mail.
         v_txt_mail := v_txt_mail || chr(10) ||
                    msj.descripcion || ': '||
                    msj.valor;
         --Se concatenan los errores de formato que pudieron ocurrir
         if msj.err_formato is not null then
            pas_snp.pr_set_texto( pas_snp.g_det_msj_error, msj.err_formato, pas_snp.fu_obt_salto );
         end if;
         --Se obtiene el campo 20 (nro_referencia)
         if msj.campo = '20' then
            v_nro_referencia := substr(msj.valor, 1, 20);
         end if;
         --Se obtiene el campo 21 (nro_ref_externa)
         if msj.campo = '21' then
           v_nro_ref_externa := msj.valor;
         end if;
      end loop;
    v_cod_mensaje := pao_pmt.fu_obt_cod_msj_swift( pao_pmt.fu_obt_linea(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), 1) );
    v_msj_swift := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
    v_msj_swi_original := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
    v_txt_mail := v_txt_mail || chr(10) || chr(10) || 'MT Recibido: ' || chr(10) || v_msj_swift || chr(10) || chr(10) || 'Atentamente.';
   end if;

   begin
      insert into ge_snp_mensajes
          ( cod_msj_swift,
            nro_referencia,
            nro_ref_externa,
            fec_valor,
            msj_swift,
            msj_swi_original,
            error,
            fec_recepcion,
            situacion
          )
     values
          ( v_cod_mensaje,
            v_nro_referencia,
            v_nro_ref_externa,
            pas_snp.g_fec_actual,
            v_msj_swift,
            v_msj_swi_original,
            pas_snp.g_det_msj_error,
            case when p_ind_msj_recibido='S' then sysdate else NULL end,
            case when p_ind_msj_recibido='S' then 'R' else 'P' end
          );
   exception
      when dup_val_on_index then
         pas_snp.g_cod_error := 55;
         pas_snp.g_msj_error := 'Ya existen registros en GE_SNP_MENSAJES para el numero de Ref.Externa '|| v_nro_ref_externa ||'!';
         raise pas_snp.ex_salir;
      when others then
         pas_snp.g_cod_error := 55;
         pas_snp.g_msj_error := SQLERRM;
         raise pas_snp.ex_salir;
   end;

   /*
   || Env¿a Correo con los detalles de la mensajer¿a recibida
   */
   BEGIN
      if p_env_mail = 'S' and v_dir_correo is not null then
         if v_asunto is null then
            v_asunto := vg_fecfor||'Detalle de MT'||v_cod_mensaje||' recibido';
         end if;
         it_mail.mail( fug_obt_dir_correo,
                       v_dir_correo,
                       v_asunto,
                       v_txt_mail
                     );
      end if;
   EXCEPTION
     when others then
        NULL;
   END;

   if pas_snp.g_det_msj_error is NULL then
      return '00' || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Procesado OK';
   else
      return '00' || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Error ' || pas_snp.g_det_msj_error;
   end if;

EXCEPTION
   when pas_snp.ex_salir then
      return '99' || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Error ' || pas_snp.fu_obt_msj_error;
   when others then
      return '99' || '|' || v_cod_mensaje || '|' || SQLERRM;

END  FU_REG_MSJ_GENERICO;

FUNCTION FU_OBT_CTA_BANCARIA (P_NRO_REFERENCIA IN VARCHAR2, P_COD_MSJ IN VARCHAR2) RETURN VARCHAR2 is
  v_cta_bancaria cc_cta_bancarias.nro_cta_bancaria%type;
  v_msj_swift    ge_snp_mensajes.msj_swift%type;
  v_hor_ini_loc  varchar2(8);
  v_hor_fin_loc  varchar2(8);
  v_lug_pro_loc  varchar2(250);
  v_nro_ord_loc  ge_pro_paralelos_det.nro_orden%type;
BEGIN
  v_lug_pro_loc  := 'FU_OBT_CTA_BANCARIA';
  vg_nro_orden   := nvl(vg_nro_orden,0) + 1;
  v_nro_ord_loc := vg_nro_orden;
  v_hor_ini_loc := to_char(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
  
  IF P_COD_MSJ = '920' THEN 
    select d.msj_swift 
      into v_msj_swift
      from ge_snp_men_enviados d
     where d.cod_msj_swift = P_COD_MSJ
       and d.fec_valor = vg_fecha
       and d.nro_referencia = P_NRO_REFERENCIA;
    
    v_cta_bancaria := pas_snp.fu_pro_val_tag(v_msj_swift,'25');
  ELSIF P_COD_MSJ = '541' THEN
    select p.nro_cta_pte_solicitante
      into v_cta_bancaria
      from ge_snp_transferencias p
     where p.cod_msj_swift = p_cod_msj
       and p.fec_valor = vg_fecha
       and p.nro_referencia =  P_NRO_REFERENCIA;
  END IF;
  
  return v_cta_bancaria;
  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

EXCEPTION
  when others then
     PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC);
     RAISE_APPLICATION_ERROR(-20050,SQLERRM||'ERROR en pam_dep.fu_obt_cta_bancaria - '||sqlerrm);
END FU_OBT_CTA_BANCARIA;

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
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);

  --Carga de Variables y Datos--
  pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 10; end;
  pae_cnf.G_PROGRAMA := 'PAM_DEP';
  vg_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
  vg_cod_moneda    := vg_cod_mon_local; --FPD es siempre en GS--
  vg_redondeo      := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', null, null, vg_cod_moneda, null, null);
  vg_cod_mad_ope   := fue_obt_val_max_refcodes('DEP_AUT_TIP_OPE','FPD');

  --Verificar la moneda ISO--
   if vg_cod_moneda = vg_cod_mon_local then
      vg_cod_mon_iso := pas_snp.g_cod_mon_iso_local;
   else
      vg_cod_mon_iso := vg_cod_moneda;
   end if;

  --Traer el dato de cod_modulo-
  select x.cod_modulo
    into vg_cod_modulo
    from ge_modalidades x
   where x.cod_modalidad = vg_cod_mad_ope;


  --Obtencion de Parametros Dinamicos--
  vg_cod_per_ope := fug_obt_pardinamico('DEP_AUT_COD_PER_OPE',vg_cod_modulo, vg_cod_mad_ope,vg_cod_moneda,null,null);
  vg_mon_hab_ope := fug_obt_pardinamico('DEP_AUT_MON_HAB_OPE',vg_cod_modulo, vg_cod_mad_ope,vg_cod_moneda,null,null);
  vg_dia_plz_ope := fug_obt_pardinamico('DEP_AUT_DIA_PLZ_OPE',vg_cod_modulo, vg_cod_mad_ope,vg_cod_moneda,null,null);
  vg_cod_ofi_ope := fug_obt_pardinamico('DEP_AUT_COD_OFI_OPE',vg_cod_modulo, vg_cod_mad_ope,vg_cod_moneda,null,null);
  vg_tip_cal_ope := fug_obt_pardinamico('DEP_AUT_TIP_CAL_OPE',vg_cod_modulo, vg_cod_mad_ope,vg_cod_moneda,null,null);
  vg_for_pag_ope := fug_obt_pardinamico('DEP_AUT_FOR_PAG_OPE',vg_cod_modulo, vg_cod_mad_ope,vg_cod_moneda,null,null);
  vg_ref_cre_ope := fug_obt_pardinamico('DEP_AUT_REF_CRE_OPE',vg_cod_modulo, vg_cod_mad_ope,vg_cod_moneda,null,null);
  vg_dia_ano_ope := fug_obt_pardinamico('DEP_AUT_DIA_ANO_OPE',vg_cod_modulo, vg_cod_mad_ope,vg_cod_moneda,null,null);
  vg_mer_sec_ope := fug_obt_pardinamico('DEP_AUT_MER_SEC_OPE',vg_cod_modulo, vg_cod_mad_ope,vg_cod_moneda,null,null);
  vg_rub_eco_ope := fug_obt_pardinamico('DEP_AUT_RUB_ECO_OPE',vg_cod_modulo, vg_cod_mad_ope,vg_cod_moneda,null,null);
  vg_seg_csa_ope := fug_obt_pardinamico('DEP_AUT_SEG_CSA_OPE',vg_cod_modulo, vg_cod_mad_ope,vg_cod_moneda,null,null);

  --Obtener Monto Limite para Operacion FPD--
  vg_mto_lim_diario   := pam_dep.fu_obt_parametro(vg_cod_moneda, 'MTO_LIM_DIA_FPD', vg_fecha);
  vg_mto_enc_normal   := pam_dep.fu_obt_parametro(vg_cod_moneda, 'MTO_ENC_NOR_FPD', vg_fecha);
  vg_mto_enc_especial := pam_dep.fu_obt_parametro(vg_cod_moneda, 'MTO_ENC_ESP_FPD', vg_fecha);
  vg_mto_man_diario   := pam_dep.fu_obt_parametro(vg_cod_moneda, 'MTO_MAN_DIA_FPD', vg_fecha);

  --Validar Moneda--
  if nvl(vg_mon_hab_ope,'N') = 'N' then
     PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, 'Error. Moneda '||vg_cod_moneda||' no habilitada para FPD. Verifique.'||'-'||V_LUG_PRO_LOC);
     RAISE_application_error(-20002, 'Error. Moneda '||vg_cod_moneda||' no habilitada para FPD. Verifique.');
  end if;

  --Parametos de Cliente y Beneficiario--
  vg_nom_cliente    := fue_obt_nom_persona(vg_cod_per_ope);
  vg_nom_entidad    := FUG_OBT_NOM_ENTIDAD;
  vg_nro_referencia := pas_snp.fu_obt_sig_nro_referencia;
  vg_cod_per_entidad := fug_obt_per_entidad;
  vg_cod_swi_entidad := pas_snp.fu_obt_cod_swi_participante(vg_cod_per_entidad);
  vg_cod_swi_beneficiario := pas_snp.fu_obt_cod_swi_participante(vg_cod_per_ope);
  /*if nvl(vg_cta_origen,'x') = 'SPI' then
    vg_cta_ban_entidad := g_cta_ban_spi;
    vg_ref_cre_ope     := vg_ref_cre_spi;
  else
    vg_cta_ban_entidad := pas_snp.fu_obt_cta_ban_participante(vg_cod_swi_entidad,vg_cod_moneda);
    vg_ref_cre_ope     := fug_obt_pardinamico('DEP_AUT_REF_CRE_OPE',vg_cod_modulo, vg_cod_mad_ope,vg_cod_moneda,null,null);
  end if;
  vg_cta_ban_beneficiario := pas_snp.fu_obt_cta_ban_participante(vg_cod_swi_beneficiario,vg_cod_moneda);
*/
  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END;

PROCEDURE PR_PRO_CAM_MOD_FPD(P_COD_PERIODO IN NUMBER, P_ESTADO IN VARCHAR2) IS
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
BEGIN
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'PR_PRO_CAM_MOD_FPD';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC  := vg_nro_orden;
  V_HOR_INI_LOC  := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
  --Modificacion de Modulo--
  update md_dep_horarios a
     set a.estado = p_estado,
         a.fecha = vg_fecha
   where a.cod_periodo = P_COD_PERIODO;
  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END;

PROCEDURE PR_VAL_RES_REC_BCP(P_MENSAJE IN VARCHAR2, P_TIPO IN VARCHAR2) IS
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  V_DES_RESPUESTA VARCHAR2(4000);
BEGIN
  --Inicio Registro del Log--
  V_LUG_PRO_LOC := 'PR_GEN_OPE_FPD_AUT';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
  -----
  IF P_TIPO = 'PER' THEN --Validar Perioo Activo--
     select pam_dep.FU_OBT_VAL_CAM_ESP(P_MENSAJE,'/BUSINESSDAY/')
       into V_DES_RESPUESTA
       FROM DUAL;
     if V_DES_RESPUESTA <> to_char(vg_fecha,'yymmdd') then --Periodo de Intercambio distinto--
        pag_dom.pr_tra_env_email(pam_dep.g_gru_dir_correo, 'DEPO '||to_char(vg_fecha,'dd/mm/yyyy')||' - Error en Validacion de Periodo', P_MENSAJE);
        PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, 'Error. Periodo de Intercambio de BCP '||V_DES_RESPUESTA||' <> '||'Fecha de ITGF '||to_char(vg_fecha,'yymmdd'));
        raise_application_error(-20002, 'Error-2. Periodo de Intercambio BCP <> ITGF y/o Contiene Errores. ITGF='||to_char(vg_fecha,'yymmdd')||'-BCP='||V_DES_RESPUESTA);
     end if;
  ELSIF P_TIPO = 'TEX' THEN --Validar Mesaje de Texto--
     select decode(INSTR(P_MENSAJE,'OK'),0,'N','S')
       into V_DES_RESPUESTA
       FROM DUAL;
     if V_DES_RESPUESTA <> 'S' then --No ee establecio intercambio de mensajes--
        pag_dom.pr_tra_env_email(pam_dep.g_gru_dir_correo, 'DEPO '||to_char(vg_fecha,'dd/mm/yyyy')||' - Error en Intercambio Mens.de Texto', P_MENSAJE);
        PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, 'Error. No se establecio Intercambio de mensajes ITGF a BCP');
        raise_application_error(-20002, 'Error. No se establecio Intercambio de mensajes ITGF a BCP');
     end if;
  ELSIF P_TIPO = 'EPE' THEN
     pag_dom.pr_tra_env_email(pam_dep.g_gru_dir_correo, vg_fecfor||'Recibido de BCP Error en Validacion de Periodo', P_MENSAJE);
  ELSIF P_TIPO = 'ETE' THEN
     pag_dom.pr_tra_env_email(pam_dep.g_gru_dir_correo, vg_fecfor||'Recibido de BCP Error en Validacion de Intercambio Mens.de Texto', P_MENSAJE);
  ELSIF P_TIPO = 'EDE' THEN
     pag_dom.pr_tra_env_email(pam_dep.g_gru_dir_correo, vg_fecfor||'Recibido de BCP Error en Deposito FPD del dia', P_MENSAJE);
  ELSIF P_TIPO = 'CDE' THEN
     pag_dom.pr_tra_env_email(pam_dep.g_gru_dir_correo, vg_fecfor||'Recibido de BCP Confirmacion de Deposito FPD OK.', P_MENSAJE);
  END IF;
  -----
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC, vg_nro_referencia,NULL,NULL,NULL,vg_nro_cuenta,vg_des_operacion);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);
EXCEPTION
  WHEN OTHERS THEN
      PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC);
      RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END;

PROCEDURE PR_GEN_OPE_BCP_COL(P_NRO_REFERENCIA IN VARCHAR2) IS
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  rg_snp_tra        pas_snp.rg_msj;
  v_exi_cta_temporal varchar2(1);
BEGIN
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'PR_GEN_OPE_BCP_COL';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC  := vg_nro_orden;
  V_HOR_INI_LOC  := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);

  --Actualiza a Liquidado la Transferencia--
  rg_snp_tra := null;
  rg_snp_tra.nro_referencia := P_NRO_REFERENCIA;
  rg_snp_tra.estado := 'A'; --Aprobado--
  rg_snp_tra.situacion := 'L'; --Liquidado--
  pas_snp.pr_set_transferencias(rg_snp_tra);
  if pas_snp.fu_obt_cod_error <> 0 then
     --Si Tiene Error--
     raise pas_snp.ex_salir;
  end if;

  select decode(nvl(count(*),0),'N','S')
    into v_exi_cta_temporal
   from md_dep_cta_documentos x
   where x.nro_referencia = P_NRO_REFERENCIA
     and x.estado = 'S'; --Solicitado--
  if v_exi_cta_temporal = 'N' then
     PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, 'Error. No existe Cta temporal creada para envio'||'-'||V_LUG_PRO_LOC);
     raise_application_error(-20002, 'Error. Error. No existe Cta temporal creada para envio');
  end if;

  vg_nro_cuenta     := fug_obt_sig_nro_cuenta(vg_cod_modulo, vg_cod_mad_ope, vg_cod_ofi_ope, vg_cod_moneda, vg_cod_per_ope);
  insert into md_cta_documentos
  (COD_MODULO, NRO_CUENTA, COD_MODALIDAD, COD_OFICINA, COD_MONEDA,
   COD_PERSONA, NRO_DOCUMENTO, DENOMINACION, FEC_INICIO, FEC_VENCIMIENTO,
   MONTO, VAL_TASA, CANTIDAD, ESTADO, FEC_CAM_ESTADO, MTO_INTERES,
   VAL_PRESENTE, SAL_INTERES, SAL_VAL_PRE_BATCH, SAL_INT_BATCH, BENEFICIARIO,
   TIP_CALCULO, COM_DOC_RELACIONADOS, SAL_VAL_PRESENTE, OBSERVACION,
   FOR_PAGO, NRO_REF_CREDITO, DIA_ANO, COMISION, MTO_IMPUESTO, MER_SECUNDARIO,
   COD_RUB_ECONOMICO, SAL_DISPONIBLE)

  select X.COD_MODULO, vg_nro_cuenta, X.COD_MODALIDAD, X.COD_OFICINA, X.COD_MONEDA,
   X.COD_PERSONA, X.NRO_DOCUMENTO, X.DENOMINACION, X.FEC_INICIO, X.FEC_VENCIMIENTO,
   X.MONTO, X.VAL_TASA, X.CANTIDAD, X.ESTADO, X.FEC_CAM_ESTADO, X.MTO_INTERES,
   X.VAL_PRESENTE, X.SAL_INTERES, X.SAL_VAL_PRE_BATCH, X.SAL_INT_BATCH, X.BENEFICIARIO,
   X.TIP_CALCULO, X.COM_DOC_RELACIONADOS, X.SAL_VAL_PRESENTE, X.OBSERVACION,
   X.FOR_PAGO, X.NRO_REF_CREDITO, X.DIA_ANO, X.COMISION, X.MTO_IMPUESTO, X.MER_SECUNDARIO,
   X.COD_RUB_ECONOMICO, X.SAL_DISPONIBLE
  from md_dep_cta_documentos x
  where x.nro_referencia = P_NRO_REFERENCIA
    and x.estado = 'S'; --Solicitado--

  update md_dep_cta_documentos y
     set y.nro_cuenta = vg_nro_cuenta,
         y.estado = 'L' --Liquidado en BCP--
   where y.nro_referencia = P_NRO_REFERENCIA;

  --Cargar demas variables--
  select x.monto, mto_interes, x.des_operacion
    into vg_mto_operacion, vg_mto_interes, vg_des_ope_enviada
    from md_dep_cta_documentos x
   where x.nro_referencia = P_NRO_REFERENCIA;

  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END PR_GEN_OPE_BCP_COL;

PROCEDURE PR_CON_SOL_PER_ACTIVO(P_COD_EJECUCION IN VARCHAR2 DEFAULT NULL) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  V_NRO_REF_SOLICITUD GE_SNP_MENSAJES.NRO_REFERENCIA%TYPE;
  --Para marcar el envio--
  v_hor_envio VARCHAR2(8);
  v_cod_ejecucion md_dep_msj_automaticos.cod_ejecucion%type;
  v_nro_orden     md_dep_msj_automaticos.nro_orden%type;
  v_cod_msj_swift sb_snp_mensajes.cod_mensaje%type;
  v_exi_msj_enviado varchar2(1);
  v_cod_msj_env_bcp sb_snp_tip_mensajes.cod_mensaje%type;
BEGIN
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'PR_CON_SOL_PER_ACTIVO';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
  ----------------------------

  PAM_DEP.PR_CAR_VAR_PARAMETROS;
  --Genera Archivo MT999 y envia--
  vg_hor_saldo := to_char(sysdate, 'hh24:mi:ss');
  PAM_DEP.PR_GEN_MSJ_SWI_MT999(V_NRO_REF_SOLICITUD);
  --Actualiza archivo enviado--
  v_cod_msj_swift := 'MT999';
  v_hor_envio := to_char(sysdate, 'hh24:mi:ss');
  v_cod_ejecucion := P_COD_EJECUCION;
  PAM_DEP.PR_OBT_DAT_MSJ_ACTUAL(v_cod_msj_swift, 'I', V_NRO_REF_SOLICITUD, v_exi_msj_enviado, v_cod_ejecucion, v_nro_orden, v_cod_msj_env_bcp);
  if v_exi_msj_enviado = 'S' then
     PR_CON_ENV_AUTOMATICO('E', V_NRO_REF_SOLICITUD, v_hor_envio, v_cod_ejecucion, v_nro_orden);
  end if;

  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);
  ------------------------
  commit;
EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END PR_CON_SOL_PER_ACTIVO;

PROCEDURE PR_CON_INT_MSJ_TEXTO IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  V_NRO_REF_SOLICITUD GE_SNP_MENSAJES.NRO_REFERENCIA%TYPE;
  --Para marcar el envio--
  v_hor_envio VARCHAR2(8);
  v_cod_ejecucion md_dep_msj_automaticos.cod_ejecucion%type;
  v_nro_orden     md_dep_msj_automaticos.nro_orden%type;
  v_cod_msj_swift sb_snp_mensajes.cod_mensaje%type;
  v_exi_msj_enviado varchar2(1);
  v_cod_msj_env_bcp sb_snp_tip_mensajes.cod_mensaje%type;
BEGIN
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'PR_OBT_PER_ACT_BCP';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);

  PAM_DEP.PR_CAR_VAR_PARAMETROS;
  --Genera Archivo MT599 y envia--
  vg_hor_saldo := to_char(sysdate, 'hh24:mi:ss');
  PAM_DEP.PR_GEN_MSJ_SWI_MT599(vg_cod_per_ope,'mensaje de prueba', V_NRO_REF_SOLICITUD);
  --Actualiza archivo enviado--
  v_cod_msj_swift := 'MT599';
  v_hor_envio := to_char(sysdate, 'hh24:mi:ss');
  PAM_DEP.PR_OBT_DAT_MSJ_ACTUAL(v_cod_msj_swift, 'I', V_NRO_REF_SOLICITUD, v_exi_msj_enviado, v_cod_ejecucion, v_nro_orden, v_cod_msj_env_bcp);
  if v_exi_msj_enviado = 'S' then
     PR_CON_ENV_AUTOMATICO('E', V_NRO_REF_SOLICITUD, v_hor_envio, v_cod_ejecucion, v_nro_orden);
  end if;
  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

  commit;
EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END PR_CON_INT_MSJ_TEXTO;

PROCEDURE PR_OBT_SAL_CTA_SIPAP(P_COD_EJECUCION IN VARCHAR2 DEFAULT NULL) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  V_NRO_REF_SOLICITUD GE_SNP_MENSAJES.NRO_REFERENCIA%TYPE;
  --Para marcar el envio--
  v_hor_envio VARCHAR2(8);
  v_cod_ejecucion md_dep_msj_automaticos.cod_ejecucion%type;
  v_nro_orden     md_dep_msj_automaticos.nro_orden%type;
  v_cod_msj_swift sb_snp_mensajes.cod_mensaje%type;
  v_exi_msj_enviado varchar2(1);
  v_cod_msj_env_bcp sb_snp_tip_mensajes.cod_mensaje%type;
BEGIN
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'PR_OBT_SAL_CTA_SIPAP';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);

  PAM_DEP.PR_CAR_VAR_PARAMETROS;
  vg_hor_saldo := to_char(sysdate, 'hh24:mi:ss');
  if vg_cta_origen = 'SPI' then
    PAM_DEP.PR_GEN_MSJ_SWI_MT920_SPI(V_NRO_REF_SOLICITUD);
  ELSE
    PAM_DEP.PR_GEN_MSJ_SWI_MT920(V_NRO_REF_SOLICITUD);
  END IF;
  
  --Actualiza archivo enviado--
  v_cod_msj_swift := 'MT920';
  v_hor_envio := to_char(sysdate, 'hh24:mi:ss');
  v_cod_ejecucion := P_COD_EJECUCION;
  PAM_DEP.PR_OBT_DAT_MSJ_ACTUAL(v_cod_msj_swift, 'I', V_NRO_REF_SOLICITUD, v_exi_msj_enviado, v_cod_ejecucion, v_nro_orden, v_cod_msj_env_bcp);
  if v_exi_msj_enviado = 'S' then
     PR_CON_ENV_AUTOMATICO('E', V_NRO_REF_SOLICITUD, v_hor_envio, v_cod_ejecucion, v_nro_orden);
  end if;

  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

  commit;
EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END;

PROCEDURE PR_OBT_DAT_MSJ_ACTUAL(P_COD_MSJ_SWIFT IN VARCHAR2,
                                P_ESTADO IN VARCHAR2,
                                P_NRO_REF_CONTROL IN VARCHAR2,
                                P_EXI_MSJ_ENVIADO OUT VARCHAR2,
                                P_COD_EJECUCION IN OUT VARCHAR2,
                                P_NRO_ORDEN OUT NUMBER,
                                P_COD_MSJ_ENVIADO OUT VARCHAR2)

 IS
  v_fecha date := pag_cal.FU_OBT_FEC_ACTUAL(10);
BEGIN
  P_EXI_MSJ_ENVIADO := 'N';
  IF P_ESTADO = 'I' then
     select t.cod_ejecucion, t.nro_orden
        into p_cod_ejecucion, p_nro_orden
        from MD_DEP_MSJ_AUTOMATICOS t
       where t.fecha = v_fecha
         and t.cod_tip_ope = 'DEP_AUT_MSJ_FPD'
         and t.cod_msj_enviado = P_COD_MSJ_SWIFT
         and t.cod_ejecucion = P_COD_EJECUCION
         and ((P_ESTADO = 'I') and (t.estado = P_ESTADO) and (t.hor_enviado is null) and (t.hor_respuesta is null))
         and t.fec_insercion = (select max(x.fec_insercion)
                                  from MD_DEP_MSJ_AUTOMATICOS x
                                 where x.fecha = v_fecha
                                   and x.cod_tip_ope = 'DEP_AUT_MSJ_FPD'
                                   and x.cod_msj_enviado = P_COD_MSJ_SWIFT
                                   and x.cod_ejecucion = P_COD_EJECUCION
                                   and ((P_ESTADO = 'I') and (x.estado = P_ESTADO) and (x.hor_enviado is null) and (x.hor_respuesta is null)));

        P_EXI_MSJ_ENVIADO := 'S';
  ELSIF P_ESTADO IN ('E','R') then
      select t.cod_ejecucion, t.nro_orden, t.cod_msj_enviado
        into P_cod_ejecucion, P_nro_orden, p_cod_msj_enviado
        from MD_DEP_MSJ_AUTOMATICOS t
       where t.fecha = v_fecha
         and t.cod_tip_ope = 'DEP_AUT_MSJ_FPD'
         --and t.cod_msj_enviado = P_COD_MSJ_SWIFT
         and t.nro_ref_enviado = P_NRO_REF_CONTROL
         and (((P_ESTADO = 'E') and (t.estado = P_ESTADO) and (t.hor_enviado is not null) and (t.hor_respuesta is null)) or
              ((P_ESTADO = 'R') and (t.estado = P_ESTADO) and (t.hor_enviado is not null) and (t.hor_respuesta is not null)))
         and t.fec_insercion = (select max(x.fec_insercion)
                                  from MD_DEP_MSJ_AUTOMATICOS x
                                 where x.fecha = v_fecha
                                   and x.cod_tip_ope = 'DEP_AUT_MSJ_FPD'
                                   --and x.cod_msj_enviado = P_COD_MSJ_SWIFT
                                   and x.nro_ref_enviado = P_NRO_REF_CONTROL
                                   and (((P_ESTADO = 'E') and (x.estado = P_ESTADO) and (x.hor_enviado is not null) and (x.hor_respuesta is null)) or
                                        ((P_ESTADO = 'R') and (x.estado = P_ESTADO) and (x.hor_enviado is not null) and (x.hor_respuesta is not null))));
        P_EXI_MSJ_ENVIADO := 'S';
    elsif P_ESTADO = 'S' then
        select t.cod_ejecucion, t.nro_orden
        into p_cod_ejecucion, p_nro_orden
        from MD_DEP_MSJ_AUTOMATICOS t
       where t.fecha = v_fecha
         and t.cod_tip_ope = 'DEP_AUT_MSJ_FPD'
         and t.cod_msj_enviado = P_COD_MSJ_SWIFT
         and t.cod_ejecucion = P_NRO_REF_CONTROL
         and ((t.estado = 'R') and (t.hor_enviado is not null) and (t.hor_respuesta is not null))
         and t.fec_insercion = (select max(x.fec_insercion)
                                  from MD_DEP_MSJ_AUTOMATICOS x
                                 where x.fecha = v_fecha
                                   and x.cod_tip_ope = 'DEP_AUT_MSJ_FPD'
                                   and x.cod_msj_enviado = P_COD_MSJ_SWIFT
                                   and x.cod_ejecucion = P_NRO_REF_CONTROL
                                   and ((x.estado = 'R') and (x.hor_enviado is not null) and (x.hor_respuesta is not null)));
        P_EXI_MSJ_ENVIADO := 'S';
    end if;
exception
    when no_data_found then
         P_EXI_MSJ_ENVIADO := 'N';
    when others then
         PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  null, /*V_LUG_PRO_LOC*/ null, /*V_NRO_ORD_LOC*/ vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM/*||'-'||V_LUG_PRO_LOC*/);
         RAISE_APPLICATION_ERROR(-20000,SQLERRM||'ERROR en pam_dep.fu_obt_parametro - '||sqlerrm);
END;

PROCEDURE PR_CAL_BCP_DEPOSITO(P_COD_EJECUCION IN VARCHAR2) IS
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
BEGIN
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'PR_CAL_BCP_DEPOSITO';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
  --Obteniendo campo desde el mensaje--
  vg_sal_cta_sipap := PAM_DEP.FU_OBT_VAL_SAL_SIPAP(P_COD_EJECUCION);
  vg_mto_ope_bruto := nvl(vg_sal_cta_sipap,0);

  if nvl(vg_mto_ope_bruto,0) <= 0 then
     PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, 'Error. Monto de Operacion <= 0'||'-'||V_LUG_PRO_LOC);
     raise_application_error(-20002, 'Error. Monto de Deposito '||to_char(nvl(vg_mto_ope_bruto,0))||' <= 0');
  --end if;                                                                                                                              
  else -- solo si tiene saldo que continue  

    if nvl(vg_mto_man_diario,0) > 0 then
       vg_mto_operacion := pam_dep.fu_cal_val_mto_piso(nvl(vg_mto_man_diario,0));
    else
       vg_mto_operacion := pam_dep.fu_cal_val_mto_piso(vg_mto_ope_bruto);
    end if;

    if vg_mto_operacion > nvl(vg_sal_cta_sipap,0) then
       --Comparar con el Saldo SIPAP--
       vg_mto_operacion := pam_dep.fu_cal_val_mto_piso(vg_sal_cta_sipap);
    end if;

    if vg_mto_operacion > vg_mto_lim_diario then
       vg_mto_operacion := pam_dep.fu_cal_val_mto_piso(vg_mto_lim_diario);
    end if;
  end if; 

  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END;

PROCEDURE PR_CAL_BCP_INTERES IS
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
BEGIN
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'PR_CAL_BCP_INTERES';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
  --Traer Tasa de Interes--
  vg_val_tas_actual := null;
  vg_val_tas_min    := null;
  vg_val_tas_max    := null;
  vg_val_tas_tae    := null;

  --Calcula Dias y Fecha de Vencimiento--
  vg_fec_vencim := pag_cal.fu_obt_fec_habil(vg_fecha+vg_dia_plz_ope,1,1);
  vg_dia_plazo  := vg_fec_vencim - vg_fecha;

  --Obtener la Tasa de la Pizarra--
  pap_pre.pr_obt_tas_pizarra(vg_cod_modulo, vg_cod_mad_ope, vg_cod_moneda,
                             vg_dia_plazo, vg_mto_operacion, null, vg_val_tas_min,
                             vg_val_tas_max, vg_val_tas_actual, vg_val_tas_tae);
  If nvl(vg_val_tas_min,0) = 0 and nvl(vg_val_tas_max,0) = 0 and nvl(vg_val_tas_actual,0) = 0 then
     PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC);
     raise_application_error(-20002, 'Error. Debe definir la pizarra para el Tipo de Operación');
  End if;

  --Calculo del Interes--
  vg_mto_interes := 0;
  vg_tasadiv     := vg_val_tas_actual / (365 * 100);
  vg_mto_interes := round((vg_mto_operacion * vg_tasadiv * vg_dia_plazo ),vg_redondeo);

  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END;

PROCEDURE PR_INS_OPE_BCP_TMP IS
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
BEGIN
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'PR_GEN_OPE_BCP_COL';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);

  --Insertar la Operacion de Mesa de Dinero--
  insert into md_dep_cta_documentos
  (COD_MODULO, NRO_CUENTA, COD_MODALIDAD, COD_OFICINA, COD_MONEDA,
   COD_PERSONA, NRO_DOCUMENTO, DENOMINACION, FEC_INICIO, FEC_VENCIMIENTO,
   MONTO, VAL_TASA, CANTIDAD, ESTADO, FEC_CAM_ESTADO, MTO_INTERES,
   VAL_PRESENTE, SAL_INTERES, SAL_VAL_PRE_BATCH, SAL_INT_BATCH, BENEFICIARIO,
   TIP_CALCULO, COM_DOC_RELACIONADOS, SAL_VAL_PRESENTE, OBSERVACION,
   FOR_PAGO, NRO_REF_CREDITO, DIA_ANO, COMISION, MTO_IMPUESTO, MER_SECUNDARIO,
   COD_RUB_ECONOMICO, SAL_DISPONIBLE, NRO_REFERENCIA)
  values
  (vg_cod_modulo, vg_nro_cuenta, vg_cod_mad_ope, vg_cod_ofi_ope, vg_cod_moneda,
   vg_cod_per_ope, 0, vg_nom_cliente, vg_fecha, vg_fec_vencim,
   vg_mto_operacion, vg_val_tas_actual, 0, 'S', vg_fecha, vg_mto_interes,
   vg_mto_operacion, vg_mto_interes, 0, 0, vg_nom_entidad,
   vg_tip_cal_ope, 'N', vg_mto_operacion, 'Operacion DEPO FPD Aut. Ref. '||vg_nro_referencia,
   vg_for_pag_ope, vg_ref_cre_ope, vg_dia_ano_ope, 0, 0, vg_mer_sec_ope,
   vg_rub_eco_ope, vg_mto_operacion, vg_nro_referencia);

  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC,vg_nro_referencia,NULL,NULL,NULL,vg_nro_cuenta,vg_des_operacion);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END PR_INS_OPE_BCP_TMP;

PROCEDURE PR_GEN_DAT_PEDIDO(P_TIPO IN VARCHAR2) IS
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  V_NRO_REF_SOLICITUD GE_SNP_MENSAJES.NRO_REFERENCIA%TYPE;
  V_MSJ_PRUEBA varchar2(100);

  --Inserta Datos de Mensaje a Pedido--
  procedure lp_ins_msj_pedido(p_fecha in date,
                              p_nro_referencia in varchar2,
                              p_cod_mensaje in varchar2) is
   PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    insert into MD_DEP_MSJ_PEDIDOS
      (fecha, nro_ref_pedido, cod_msj_pedido)
    values
      (p_fecha, p_nro_referencia, p_cod_mensaje);
    commit;
  end;

BEGIN
    --Inicio Registro del Log--
    V_LUG_PRO_LOC  := 'PAM_DEP.PR_GEN_DAT_PEDIDO';
    vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
    V_NRO_ORD_LOC := vg_nro_orden;
    V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
    ----------------------------
    PAM_DEP.PR_CAR_VAR_PARAMETROS;
    V_MSJ_PRUEBA := 'Mensaje de Prueba';
    IF P_TIPO = 'RSA' THEN --Solicitud de Saldo y Pre-Calculo FPD--
       PAM_DEP.PR_GEN_MSJ_SWI_MT920(V_NRO_REF_SOLICITUD);
       lp_ins_msj_pedido(vg_fecha, V_NRO_REF_SOLICITUD, 'MT920');
    ELSIF P_TIPO = 'SPI' THEN -- Solicitud de saldo y pre calculo FPD - SPI
       PAM_DEP.PR_GEN_MSJ_SWI_MT920_SPI(V_NRO_REF_SOLICITUD);
       lp_ins_msj_pedido(vg_fecha, V_NRO_REF_SOLICITUD, 'MT920');
       vg_cta_origen := null;
    ELSIF P_TIPO = 'RPE' THEN --Solicitud de Periodo--
       PAM_DEP.PR_GEN_MSJ_SWI_MT999(V_NRO_REF_SOLICITUD);
       lp_ins_msj_pedido(vg_fecha, V_NRO_REF_SOLICITUD, 'MT999');
    ELSIF P_TIPO = 'RTE' THEN --Solicitud de Mensaje de Texto--
       PAM_DEP.PR_GEN_MSJ_SWI_MT599(vg_cod_per_ope,V_MSJ_PRUEBA, V_NRO_REF_SOLICITUD);
       lp_ins_msj_pedido(vg_fecha, V_NRO_REF_SOLICITUD, 'MT599');
    ELSIF P_TIPO = 'RPD' THEN --Solicitud de Prueba de Puerto Depo--
       PAM_DEP.PR_GEN_ARC_SWI_SERV (V_MSJ_PRUEBA);
   -- ELSIF P_TIPO = 'RPS' THEN --Solicitud de Prueba de Puerto Sipap--
       --PAS_SNP.PR_GEN_ARC_SWI_LOTE(V_MSJ_PRUEBA);
       --PAS_SNP.PR_GEN_ARC_SWI_LOTE(V_MSJ_PRUEBA,vg_nro_orden,PAG_CAL.FU_OBT_FEC_ACTUAL(1),999);
    END IF;
    ----------------------------
    --Fin Registro del Log--
    V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC, vg_nro_referencia, NULL, NULL, null, vg_nro_cuenta,vg_des_operacion);
    PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);
EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END;

PROCEDURE PR_GEN_PRE_DEPOSITO(P_VALOR IN VARCHAR2, P_NRO_REFERENCIA IN VARCHAR2) IS
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  v_det_pre_calculo varchar2(4000);
  v_car_enter varchar2(100) := CHR(13);
  v_cta_inicial ge_snp_transferencias.nro_cta_pte_solicitante%type;
BEGIN
    --Inicio Registro del Log--
    V_LUG_PRO_LOC := 'PAM_DEP.PR_GEN_PRE_DEPOSITO';
    vg_nro_orden  := NVL(vg_nro_orden,0) + 1;
    V_NRO_ORD_LOC := vg_nro_orden;
    V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
    ----------------------------
    PR_CAR_VAR_PARAMETROS;
    vg_msj_swift := P_VALOR;
    vg_sal_cta_sipap := PAM_DEP.FU_OBT_VAL_SAL_SIPAP('X');
    vg_mto_ope_bruto := nvl(vg_sal_cta_sipap,0);

    /*if nvl(vg_mto_ope_bruto,0) <= 0 then
       PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, 'Error. Monto de Operacion <= 0'||'-'||V_LUG_PRO_LOC);
       raise_application_error(-20002, 'Error. Monto de Deposito '||to_char(nvl(vg_mto_ope_bruto,0))||' <= 0');
    end if;*/

    if nvl(vg_mto_man_diario,0) > 0 then
       vg_mto_operacion := pam_dep.fu_cal_val_mto_piso(nvl(vg_mto_man_diario,0));
    else
       vg_mto_operacion := pam_dep.fu_cal_val_mto_piso(vg_mto_ope_bruto);
    end if;

    if vg_mto_operacion > nvl(vg_sal_cta_sipap,0) then
       --Comparar con el Saldo SIPAP--
       vg_mto_operacion := pam_dep.fu_cal_val_mto_piso(vg_sal_cta_sipap);
    end if;

    if vg_mto_operacion > vg_mto_lim_diario then
       vg_mto_operacion := pam_dep.fu_cal_val_mto_piso(vg_mto_lim_diario);
    end if;
    
    --SPI
    v_cta_inicial := fu_obt_cta_bancaria(p_nro_referencia, '920');
    --------
    PAM_DEP.PR_CAL_BCP_INTERES;
    --Se construye el Texto de Detalle que muestra el Calculo--
    v_det_pre_calculo := vg_fecfor||'Pre-Calculo de FPD. Cta: '||v_cta_inicial||'- Hora:'||V_HOR_INI_LOC||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'-----------------------------------------------------------------------------'||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'Saldo en BCP de Cta '||v_cta_inicial||': '||TRIM(TO_CHAR(vg_mto_ope_bruto,'999,999,999,999,990.00'))||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'Monto Manual cargado: '||TRIM(TO_CHAR(vg_mto_man_diario,'999,999,999,999,990.00'))||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'Limite Vigente: '||TRIM(TO_CHAR(vg_mto_lim_diario,'999,999,999,999,990.00'))||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'DEPOSITO calculado: '||TRIM(TO_CHAR(vg_mto_operacion,'999,999,999,999,990.00'))||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'Tasa Vigente cargada: '||TRIM(TO_CHAR(vg_val_tas_actual))||' %'||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'Dias de Plazo: '||TRIM(TO_CHAR(vg_dia_plazo,'999,999,999,999,990'))||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'Fecha de Vencimiento: '||to_char(vg_fec_vencim,'dd/mm/yyyy')||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'Interes calculado: '||TRIM(TO_CHAR(vg_mto_interes,'999,999,999,999,990.00'))||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'-----------------------------------------------------------------------------';
    pag_dom.pr_tra_env_email(pam_dep.g_gru_dir_correo, vg_fecfor||'Pre-Calculo de Deposito FPD en BCP. Hora:'||V_HOR_INI_LOC, v_det_pre_calculo);
    ----------------------------
    --Fin Registro del Log--
    V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC, P_NRO_REFERENCIA, NULL, NULL, null, vg_nro_cuenta,vg_des_operacion);
    PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);
EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), P_NRO_REFERENCIA, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END;

PROCEDURE PR_GEN_ENV_DEPOSITO(P_NRO_REFERENCIA IN VARCHAR2) IS
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  v_det_pre_calculo varchar2(4000);
  v_car_enter varchar2(100) := CHR(13);
  v_asunto varchar2(4000);

BEGIN
    --Inicio Registro del Log--
    V_LUG_PRO_LOC := 'PAM_DEP.PR_GEN_ENV_DEPOSITO';
    vg_nro_orden  := NVL(vg_nro_orden,0) + 1;
    V_NRO_ORD_LOC := vg_nro_orden;
    V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
    ----------------------------
    --Se construye el Texto de Detalle que muestra el Deposito--
    v_det_pre_calculo := vg_fecfor||'Deposito FPD enviado a BCP. Hora:'||V_HOR_INI_LOC||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'-----------------------------------------------------------------------------'||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'Saldo en BCP de Cta '||vg_cta_ban_entidad||': '||TRIM(TO_CHAR(vg_mto_ope_bruto,'999,999,999,999,990.00'))||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'Monto Manual cargado: '||TRIM(TO_CHAR(vg_mto_man_diario,'999,999,999,999,990.00'))||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'Limite Vigente: '||TRIM(TO_CHAR(vg_mto_lim_diario,'999,999,999,999,990.00'))||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'DEPOSITO calculado: '||TRIM(TO_CHAR(vg_mto_operacion,'999,999,999,999,990.00'))||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'Tasa Vigente cargada: '||TRIM(TO_CHAR(vg_val_tas_actual))||' %'||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'Dias de Plazo: '||TRIM(TO_CHAR(vg_dia_plazo,'999,999,999,999,990'))||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'Fecha de Vencimiento: '||to_char(vg_fec_vencim,'dd/mm/yyyy')||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'Interes calculado: '||TRIM(TO_CHAR(vg_mto_interes,'999,999,999,999,990.00'))||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'-----------------------------------------------------------------------------';
    v_asunto := vg_fecfor||'Deposito FPD enviado a BCP. '||'MT541 Ref.'||P_NRO_REFERENCIA||' Hora:'||V_HOR_INI_LOC;
    pag_dom.pr_tra_env_email(pam_dep.g_gru_dir_correo, v_asunto, v_det_pre_calculo);
    ---Grarda Descricion enviada--
    UPDATE MD_DEP_CTA_DOCUMENTOS X
       SET X.DES_OPERACION = v_asunto||v_car_enter||v_det_pre_calculo
     WHERE X.NRO_REFERENCIA = P_NRO_REFERENCIA;
    --Fin Registro del Log--
    V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC, vg_nro_referencia, NULL, NULL, null, vg_nro_cuenta,vg_des_operacion);
    PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);
EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END;

PROCEDURE PR_GEN_CON_DEPOSITO(P_NRO_REFERENCIA IN VARCHAR2) IS
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  v_det_pre_calculo varchar2(4000);
  v_car_enter varchar2(100) := CHR(13);
  v_mov_fec_dis number(4);
BEGIN
    --Inicio Registro del Log--
    V_LUG_PRO_LOC := 'PAM_DEP.PR_GEN_ENV_DEPOSITO';
    vg_nro_orden  := NVL(vg_nro_orden,0) + 1;
    V_NRO_ORD_LOC := vg_nro_orden;
    V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);

    --Verificar y ajustar si existe mov depo fecha distinta--
    --Esto se produces de la vigencia de horario entendido--
    select nvl(count(*),0)
      into v_mov_fec_dis
      from ge_movimientos a
     where a.fecha <> a.fec_valor
       and a.fec_valor = vg_fecha
       and exists (select 1
                     from ge_snp_transferencias x
                    where x.nro_referencia = a.nro_documento
                      and x.cod_msj_swift = 202 --Confiormacion Deposito--
                      and x.fec_valor = a.fec_valor
                      and x.estado = 'A'
                      and x.situacion = 'L'
                      and x.monto = a.monto
                      and x.fecha = a.fec_valor
                      and x.hora = a.hora
                      and x.cod_usuario = a.cod_usuario
                      and exists (select 1
                                    from ge_snp_transferencias y
                                   where instr(x.msj_swift,y.nro_referencia) > 0
                                     and y.cod_msj_swift = 541 --Pedido Msj 541 enviado--
                                     and y.fec_valor = a.fec_valor
                                     and y.estado = 'A'
                                     and y.situacion = 'L'
                                     and y.monto = x.monto
                                     and exists (select 1
                                                   from ge_snp_mensajes z
                                                  where z.nro_ref_externa = P_NRO_REFERENCIA
                                                    and z.nro_ref_externa = y.nro_referencia
                                                    and z.cod_msj_swift = 545 --Respuesta recibido--
                                                    and z.fec_valor = a.fec_valor)));
    if nvl(v_mov_fec_dis,0) > 0 then
       --Mofificar fecha de movimiento--
       update ge_movimientos a
          set a.fecha = vg_fecha
        where a.fecha <> a.fec_valor
          and a.fec_valor = vg_fecha
          and exists (select 1
                        from ge_snp_transferencias x
                       where x.nro_referencia = a.nro_documento
                         and x.cod_msj_swift = 202 --Confiormacion Deposito--
                         and x.fec_valor = a.fec_valor
                         and x.estado = 'A'
                         and x.situacion = 'L'
                         and x.monto = a.monto
                         and x.fecha = a.fec_valor
                         and x.hora = a.hora
                         and x.cod_usuario = a.cod_usuario
                         and exists (select 1
                                       from ge_snp_transferencias y
                                      where instr(x.msj_swift,y.nro_referencia) > 0
                                        and y.cod_msj_swift = 541 --Pedido Msj 541 enviado--
                                        and y.fec_valor = a.fec_valor
                                        and y.estado = 'A'
                                        and y.situacion = 'L'
                                        and y.monto = x.monto
                                        and exists (select 1
                                                      from ge_snp_mensajes z
                                                     where z.nro_ref_externa = P_NRO_REFERENCIA
                                                       and z.nro_ref_externa = y.nro_referencia
                                                       and z.cod_msj_swift = 545 --Respuesta recibido--
                                                       and z.fec_valor = a.fec_valor)));
    end if;

    --Se construye el Texto de Detalle que muestra el Deposito--
    v_det_pre_calculo := vg_fecfor||'Deposito FPD Confirmado por a BCP. Hora:'||V_HOR_INI_LOC||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||'Nro. de Cuenta en ITGF: '||vg_nro_cuenta||v_car_enter;
    v_det_pre_calculo := v_det_pre_calculo||v_car_enter||vg_des_ope_enviada;
    pag_dom.pr_tra_env_email(pam_dep.g_gru_con_cierre, vg_fecfor||'Deposito FPD Confirmado por BCP. '||'MT541 Ref.'||P_NRO_REFERENCIA||' Hora:'||V_HOR_INI_LOC, v_det_pre_calculo);
    --Fin Registro del Log--
    V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC, vg_nro_referencia, NULL, NULL, null, vg_nro_cuenta,vg_des_operacion);
    PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);
EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END;

PROCEDURE PR_GEN_MOV_APE_COL IS
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
BEGIN
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'PR_GEN_MOV_APE_COL';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);

  --Genera Movimiento de Cambio de Estado--
  If vg_mto_operacion > 0 then
     vg_hora := to_char(sysdate, 'hh24:mi:ss');
     vg_hora := fug_obt_hor_disponible(vg_fecha,vg_hora,user,vg_es_nocturno);
     vg_nro_secuencia := 0;
     vg_nro_secuencia := nvl(vg_nro_secuencia,0) + 1;
     r_gmovc.nro_secuencia      := vg_nro_secuencia;
     r_gmovc.cod_usuario        := user;
     r_gmovc.hora               := vg_hora;
     r_gmovc.fecha              := vg_fecha;
     r_gmovc.cod_modulo         := vg_cod_modulo;
     r_gmovc.cod_modalidad      := vg_cod_mad_ope;
     r_gmovc.cod_oficina        := vg_cod_ofi_ope;
     r_gmovc.nro_cuenta         := vg_nro_cuenta;
     r_gmovc.cod_moneda         := vg_cod_moneda;
     r_gmovc.est_cuenta         := 'S';
     r_gmovc.cod_tra_padre      := 401;
     r_gmovc.cod_transaccion    := 401;
     r_gmovc.fec_valor          := vg_fecha;
     r_gmovc.emi_aviso          := 'N';
     r_gmovc.reversado          := 'N';
     r_gmovc.protegido          := 'N';
     r_gmovc.estado             := 'N';
     r_gmovc.concepto           := 'Cambio de Estado';
     r_gmovc.cod_ofi_origen     := vg_cod_ofi_ope;
     r_gmovc.cod_mod_padre      := vg_cod_modulo;
     r_gmovc.cod_mad_padre      := vg_cod_mad_ope;
     r_gmovc.nro_documento      := vg_nro_cuenta;
     pag_gen.pr_ins_ge_movimiento(r_gmovc,vg_es_nocturno);

     --Insertar relacion de Cliente Principal--
     insert into ge_cta_clientes
     (cod_persona, nro_cuenta, dig_verificador, cod_oficina,
      cod_modulo, cod_modalidad, relacion)
     values
     (vg_cod_per_ope, vg_nro_cuenta, 0, vg_cod_ofi_ope,
     vg_cod_modulo, vg_cod_mad_ope, 'P');
  end if;

  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC, vg_nro_referencia, NULL, NULL, null, vg_nro_cuenta,vg_des_operacion);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END;

PROCEDURE PR_GEN_MSJ_SWI_MT541 (P_NRO_REFERENCIA OUT VARCHAR2) IS
  -- Procedimiento de generación y envio de encaje legal (MT541)
  v_cod_mensaje             sb_snp_tip_mensajes.cod_mensaje%type := 'MT'||vg_cod_msj_swift;
  r_ge_snp_par_mensajes     ge_snp_par_mensajes%rowtype;
  v_mensaje                 varchar2(4000);
  --v_bic_bcp_depo            varchar2(12);
  v_fec_hor_prep            varchar2(14);
  v_mto_operacion           ge_snp_transferencias.monto%type;
  v_mto_par_entera          varchar2(16);
  v_mto_par_decimal         varchar2(2);
  v_val_tasa                md_cta_documentos.val_tasa%type;
  v_val_par_entera          varchar2(16);
  v_val_par_decimal         varchar2(5);
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  v_es_spi varchar2(1) := 'N';
  PRAGMA AUTONOMOUS_TRANSACTION;
begin
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'PR_GEN_MSJ_SWI_MT541';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

   pre_cam_for_numerico(',.');

   --Se hallan los parámetros del MT--
   begin
      select *
        into r_ge_snp_par_mensajes
        from ge_snp_par_mensajes
       where cod_msj_swift = vg_cod_msj_swift;
   exception
      when others then
        PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC);
        raise_application_error(-20001, 'Error al obtener los Parámetros del '||v_cod_mensaje||': '||sqlerrm);
   end;

   -- Se valida el Horario de BCP. --Aqui se debe validar el estado del modulo de Depositos--
   /*if pas_snp.fu_obt_est_horario( r_ge_snp_par_mensajes.cod_msj_swift,
                                  r_ge_snp_par_mensajes.cod_tip_operacion,
                                  r_ge_snp_par_mensajes.cod_sub_tip_operacion ) <> 'A' then
      PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC);
      raise_application_error(-20003, pas_snp.fu_obt_msj_error);
   end if;*/

   --Variables Principales--
   v_mto_operacion   := vg_mto_operacion;
   --v_mto_operacion   := 999999999999;
   v_mto_par_entera  := to_char(trunc(v_mto_operacion));
   v_mto_par_decimal := replace(to_char((nvl(v_mto_operacion,0) - nvl(v_mto_par_entera,0))*100),'0',null);
   v_val_tasa        := vg_val_tas_actual;
   v_val_par_entera  := trim(to_char(trunc(v_val_tasa)));
   v_val_par_decimal := trim(substr(to_char((v_val_tasa-trunc(v_val_tasa))),2));
   vg_bic_entidad    := pas_snp.fu_obt_cod_swi_participante(vg_cod_per_entidad);
   vg_bic_beneficiario := pas_snp.fu_obt_cod_swi_participante(vg_cod_per_ope);
   v_fec_hor_prep    := to_char(sysdate,'yyyymmddhh24miss');

   P_NRO_REFERENCIA := vg_nro_referencia;
   
   --SPI
   if vg_cta_origen = 'SPI' then
     v_es_spi := 'S';
   end if;
   --CABECERA--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje,
                                      'CAB',
                                      '{1:F01'||rpad(pam_dep.g_usu_xad_depo,12,'X')||'}'||
                                      '{2:I'||TO_CHAR(vg_cod_msj_swift)||rpad(pam_dep.g_bic_bcp_depo,12,'X')||'N}'||
                                      '{3:{113'||':'||lpad('90',4,'0')||'}}{4:');
   --DETALLE de Campos--
   --Bloque de Datos Generales--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'GENL');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '20C', ':SEME//'||vg_nro_referencia);  --Referencia Unica--
   --pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '20C', ':SEME-xxx//'/*||vg_nro_referencia*/);  --Referencia Unica--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '23G', 'NEWM');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '98C', ':PREP//'||v_fec_hor_prep); --Fecha y Hora del mensaje--
   --pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '98C', ':PREP//'||'xxx'||v_fec_hor_prep); --Fecha y Hora del mensaje--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'LINK');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '20C', ':COMM//'||vg_nro_referencia);  --Referencia Unica--
   --pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '20C', ':COMM//'/*||vg_nro_referencia*/);  --Referencia Unica--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'LINK');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', ':16S:GENL');

   --Bloque de Detalles de la Operacion--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'TRADDET');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '94B', ':TRAD//OTCO');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '98A', ':SETT//'||to_char(vg_fec_sistema,'yyyymmdd'));  --Fecha de Inicio--
   --pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '98A', ':SETT//'||to_char(to_date('01/06/2018','dd/mm/yyyy'),'yyyymmdd'));  --Fecha de Inicio--
   if v_es_spi = 'S' then
     pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '35B', '/XX/DEPOSITOIPSPYG');
   else
     pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '35B', '/XX/DEPOSITOPYG');
   end if;
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'FIA');
   if v_es_spi = 'S' then
     pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '12A', ':CLAS//DEPO-IPS');
   else
     pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '12A', ':CLAS//DEPO-BCP');
   end if;
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'FIA');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '22F', ':BORR//YBOR');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'TRADDET');

   --Bloque de Instrumento Financiero - Cuenta--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'FIAC');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '36B', ':SETT//UNIT/'||v_mto_par_entera||','||v_mto_par_decimal);  --Monto de la Operacion--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '97A', ':SAFE//BBVA/DEPO');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'FIAC');

   --Bloque de Detalles de la Transaccion--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'REPO');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '98A', ':TERM//'||to_char(vg_fec_vencim,'yyyymmdd')); --Fech de Vencimiento--
   --pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '98A', ':TERM//'||to_char(to_date('07/06/2018','dd/mm/yyyy'),'yyyymmdd')); --Fech de Vencimiento--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '92A', ':REPO//'||v_val_par_entera||','||v_val_par_decimal);  --Tasa de Interes--
   --pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '92A', ':REPO//'||to_char(20)||','||v_val_par_decimal);  --Tasa de Interes--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '70C', ':SECO//TERM');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'REPO');

   --Bloque de Detalles de Liquidación--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'SETDET');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '22F', ':STCO//DLWM'||pas_snp.fu_obt_salto||
                                      ':22F::SETR//RVPO'||pas_snp.fu_obt_salto||
                                      ':22F::CCPT//YCCP'||pas_snp.fu_obt_salto||
                                      ':22F::COLA//CRSP');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '95Q', ':DEAG//'||vg_bic_beneficiario);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '95Q', ':DECU//'||vg_bic_beneficiario);
   ----
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '97A', ':SAFE//BCPA/DEPO');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '95Q', ':SELL//'||vg_bic_beneficiario);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '97A', ':SAFE//AVAI/BCPA/DEPO/DEPO');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '95Q', ':REAG//'||vg_bic_entidad);  --CONCATENAR VALOR--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'SETPRTY');
   ----
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '95Q', ':RECU//'||vg_bic_entidad); --CONCATENAR VALOR--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '97A', ':SAFE//BBVA/DEPO');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '95Q', ':BUYR//'||vg_bic_entidad); --CONCATENAR VALOR--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '97A', ':SAFE//AVAI/BBVA/DEPO/DEPO');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'SETPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'CSHPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '95Q', ':PAYE//'||vg_bic_entidad); --CONCATENAR VALOR--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '97A', ':CASH//'||vg_cta_ban_entidad); --CONCATENAR VALOR--
   --pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '97A', ':CASH//9xx'||vg_cta_ban_entidad); --CONCATENAR VALOR--
   ----
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'CSHPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'CSHPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '95Q', ':BENM//'||vg_bic_beneficiario);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '97A', ':CASH//'||vg_cta_ban_beneficiario);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'CSHPRTY');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16R', 'AMT');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '19A', ':DEAL//'||vg_cod_mon_iso||v_mto_par_entera||','||v_mto_par_decimal);  --CONCATENAR VALOR--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '16S', 'AMT');

   --PIE del MT541--
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, 'PIE', ':16S:SETDET}');

   --Generar Archivo con Formato--
   pao_pmt.pr_pro_mt_enviado(v_cod_mensaje, v_mensaje);

   --Inserta en GE_SNP_TRANSFERENCIAS--
   PR_GEN_SNP_MENSAJES(v_mensaje);

    --Envia el Mensaje al Socket--
  PR_GEN_ARC_SWI_SERV(v_mensaje);

  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC,vg_nro_referencia,NULL,NULL,NULL,vg_nro_cuenta,vg_des_operacion);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

  commit;
EXCEPTION
  WHEN OTHERS THEN
    if sqlcode <= -20000 then
      PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
      raise;
    else
      PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
      RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
    end if;
END;

PROCEDURE PR_GEN_MSJ_SWI_MT599(P_COD_PER_PARTICIPANTE IN VARCHAR2, P_MENSAJE IN VARCHAR2, P_NRO_REFERENCIA OUT VARCHAR2) IS
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  v_cod_msj_envio sb_snp_tip_mensajes.cod_mensaje%type := 'MTn99/TEXTMESSAGE';
  v_mensaje       ge_snp_mensajes.msj_swift%type;
  v_bic_participante varchar2(1000);
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  vg_nro_orden    := 0;

  --Inicio Registro del Log--
  V_LUG_PRO_LOC := 'PAM_DEP.PR_GEN_MSJ_SWI_MT599';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);

  -- Cabecera y Nro. Referencia
  IF LENGTH(P_MENSAJE) > 50 THEN
     PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, 'Error. Monto de Operacion <= 0'||'-'||V_LUG_PRO_LOC);
     raise_application_error(-20002, 'Error. Mensaje de Texto para MT999 solo permitido hasta caracteres');
  END IF;
  v_bic_participante := pas_snp.fu_obt_cod_swi_participante(p_cod_per_participante);
  P_NRO_REFERENCIA := pas_snp.fu_obt_sig_nro_referencia;
  pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio,
                                     'CAB',
                                     '{1:F01'||rpad(pam_dep.g_usu_xad_depo,12,'X')||'}'||
                                     '{2:I599'||rpad(pam_dep.g_bic_bcp_depo,12,'X')||'N}'||
                                     '{3:{113'||':'||lpad('30',4,'0')||'}}{4:');
  pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '20', P_NRO_REFERENCIA);
  pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '79', '/TEXTMESSAGE/'||v_bic_participante);
  --pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '79', '/USER/'||v_bic_participante||'1988');
  pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '79', '/TEXT/'||P_MENSAJE);   --Para Envio OK--
  --pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '79', '/TEXT-11/'||P_MENSAJE);  --Para probar error--
  pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, 'PIE', '}');
  begin
    pas_snp.g_lugar := 'Creando la mensajería, ';
    pao_pmt.pr_pro_mt_enviado(v_cod_msj_envio, v_mensaje);

    --Envia el Mensaje al Socket--
    PR_GEN_ARC_SWI_SERV(v_mensaje);

    pas_snp.g_lugar := 'Insertando mensaje en GE_SNP_MENSAJES, ';
    begin
      insert into ge_snp_mensajes
      (nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor,
       msj_swift, cod_moneda, monto, situacion, error, msj_swi_original)
       values
      (P_NRO_REFERENCIA, null, 599, vg_fecha, v_mensaje, null,
       null, 'V', pas_snp.g_msj_error, v_mensaje);
    exception
      when others then
          raise_application_error(-20000,
                                  'Insertando en ge_snp_mensajes ' || sqlerrm);
    end;
    commit;

  exception
      when others then
         raise;
  end;
  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC, vg_nro_referencia,NULL,NULL,NULL,vg_nro_cuenta,vg_des_operacion);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END PR_GEN_MSJ_SWI_MT599;

PROCEDURE PR_GEN_MSJ_SWI_MT920_SPI(P_NRO_REFERENCIA OUT VARCHAR2) IS

   v_mensaje       ge_snp_mensajes.msj_swift%type;
   v_cod_msj_envio sb_snp_tip_mensajes.cod_mensaje%type := '920';
   PRAGMA AUTONOMOUS_TRANSACTION;
begin
   pas_snp.pr_ini_registros;
   vg_cta_origen   	  := 'SPI';

   --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
   pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
   --
   pas_snp.g_lugar := 'Insertando en la tabla temporal SB_SNP_MENSAJES_TMP, ';
   P_NRO_REFERENCIA := pas_snp.fu_obt_sig_nro_referencia;
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(920,
                                      'CAB',
                                      '{1:F01'||rpad(pam_dep.g_usu_xad_sipap,12,'X')||'}'||
                                      '{2:I920'||rpad(pam_dep.g_bic_bcp_sipap,12,'X')||'N}'||
                                      '{3:{113'||':'||lpad('30',4,'0')||'}}{4:');

   -- Detalle
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '20', P_NRO_REFERENCIA);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '12', '941');
   ---pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '25', g_cta_ban_spi);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, 'PIE', '-}');

   begin
      pas_snp.g_lugar := 'Creando la mensajeria, ';
      pao_pmt.pr_pro_mt_enviado(v_cod_msj_envio, v_mensaje);

      pas_snp.g_lugar := 'Insertando mensaje en GE_SNP_MENSAJES, ';
      begin
         insert into ge_snp_mensajes
            ( nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor,
              msj_swift, cod_moneda, monto, situacion, error, msj_swi_original
            )
         values
            ( P_NRO_REFERENCIA, null, 920, vg_fecha, v_mensaje, null,
              null, 'V', pas_snp.g_msj_error, v_mensaje
            );
      exception
         when others then
            raise_application_error(-20000,'Insertando en ge_snp_mensajes ' || sqlerrm);
      end;

      pas_snp.g_lugar := 'Enviando mensaje swift al socket, ';
      --pas_snp.pr_gen_arc_swi_lote(v_mensaje);
      --pas_snp.pr_gen_arc_swi_lote(v_mensaje,P_NRO_REFERENCIA,vg_fecha,920);

      commit;
   exception
      when others then
         raise;
   end;
exception
   when others then
      pas_snp.g_cod_error := 90;
      pas_snp.g_msj_error := 'Error al Generar MT: '|| pas_snp.g_lugar ||' '|| sqlerrm;
END PR_GEN_MSJ_SWI_MT920_SPI;

PROCEDURE PR_GEN_MSJ_SWI_MT999(P_NRO_REFERENCIA OUT VARCHAR2) IS
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  v_cod_msj_envio sb_snp_tip_mensajes.cod_mensaje%type := 'MTn99/GETBUSINESSDAYPERIOD';
  v_mensaje       ge_snp_mensajes.msj_swift%type;

  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  --Inicio Registro del Log--
  V_LUG_PRO_LOC := 'PR_GEN_MSJ_SWI_MT999';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);

  -- Cabecera y Nro. Referencia
  pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio,
                                     'CAB',
                                     '{1:F01'||rpad(pam_dep.g_usu_xad_depo,12,'X')||'}'||
                                     '{2:I999'||rpad(pam_dep.g_bic_bcp_depo,12,'X')||'N}'||
                                     '{3:{113'||':'||lpad('30',4,'0')||'}}{4:');
  P_NRO_REFERENCIA := pas_snp.fu_obt_sig_nro_referencia;
  pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '20', P_NRO_REFERENCIA);
  pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '79', '/GETBUSINESSDAYPERIOD/');      --Para Envio OK--
  --pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '79', '/xx-GETBUSINESSDAYPERIOD/'); ----Para probar error--
  pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, 'PIE', '}');
  begin
    pas_snp.g_lugar := 'Creando la mensajería, ';
    pao_pmt.pr_pro_mt_enviado(v_cod_msj_envio, v_mensaje);

    pas_snp.g_lugar := 'Insertando mensaje en GE_SNP_MENSAJES, ';
    begin
      insert into ge_snp_mensajes
      (nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor,
       msj_swift, cod_moneda, monto, situacion, error, msj_swi_original)
       values
      (P_NRO_REFERENCIA, null, 999, vg_fecha, v_mensaje, null,
       null, 'V', pas_snp.g_msj_error, v_mensaje);
    exception
      when others then
          raise_application_error(-20000,
                                  'Insertando en ge_snp_mensajes ' || sqlerrm);
    end;

    --Envia el Mensaje al Socket--
    pam_dep.PR_GEN_ARC_SWI_SERV(v_mensaje);

    commit;
  exception
      when others then
         raise;
  end;
  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC, vg_nro_referencia,NULL,NULL,NULL,vg_nro_cuenta,vg_des_operacion);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END PR_GEN_MSJ_SWI_MT999;

PROCEDURE PR_GEN_MSJ_SWI_MT920(P_NRO_REFERENCIA OUT VARCHAR2) IS

   v_mensaje       ge_snp_mensajes.msj_swift%type;
   v_cod_msj_envio sb_snp_tip_mensajes.cod_mensaje%type := '920';
   PRAGMA AUTONOMOUS_TRANSACTION;
begin
   pas_snp.pr_ini_registros;

   --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
   pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
   --
   pas_snp.g_lugar := 'Insertando en la tabla temporal SB_SNP_MENSAJES_TMP, ';
   P_NRO_REFERENCIA := pas_snp.fu_obt_sig_nro_referencia;
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(920,
                                      'CAB',
                                      '{1:F01'||rpad(pam_dep.g_usu_xad_sipap,12,'X')||'}'||
                                      '{2:I920'||rpad(pam_dep.g_bic_bcp_sipap,12,'X')||'N}'||
                                      '{3:{113'||':'||lpad('30',4,'0')||'}}{4:');

   -- Detalle
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '20', P_NRO_REFERENCIA);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '12', '941');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '25', vg_cta_ban_entidad);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, 'PIE', '-}');

   begin
      pas_snp.g_lugar := 'Creando la mensajeria, ';
      pao_pmt.pr_pro_mt_enviado(v_cod_msj_envio, v_mensaje);

      pas_snp.g_lugar := 'Insertando mensaje en GE_SNP_MENSAJES, ';
      begin
         insert into ge_snp_mensajes
            ( nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor,
              msj_swift, cod_moneda, monto, situacion, error, msj_swi_original
            )
         values
            ( P_NRO_REFERENCIA, null, 920, vg_fecha, v_mensaje, null,
              null, 'V', pas_snp.g_msj_error, v_mensaje
            );
      exception
         when others then
            raise_application_error(-20000,'Insertando en ge_snp_mensajes ' || sqlerrm);
      end;

      pas_snp.g_lugar := 'Enviando mensaje swift al socket, ';
      --pas_snp.pr_gen_arc_swi_lote(v_mensaje);
      --pas_snp.pr_gen_arc_swi_lote(v_mensaje,P_NRO_REFERENCIA,vg_fecha,920);

      commit;
   exception
      when others then
         raise;
   end;
exception
   when others then
      pas_snp.g_cod_error := 90;
      pas_snp.g_msj_error := 'Error al Generar MT: '|| pas_snp.g_lugar ||' '|| sqlerrm;
END PR_GEN_MSJ_SWI_MT920;

PROCEDURE PR_CON_ENV_AUTOMATICO(P_TIPO IN VARCHAR2,
                                P_NRO_REFERENCIA IN VARCHAR2 DEFAULT NULL,
                                P_HORA IN VARCHAR2 DEFAULT NULL,
                                P_COD_EJECUCION IN VARCHAR2 DEFAULT NULL,
                                P_NRO_ORDEN IN NUMBER DEFAULT NULL,
                                P_COD_MSJ_SWIFT IN VARCHAR2 DEFAULT NULL,
                                P_NRO_REF_RECIBIDO IN VARCHAR2 DEFAULT NULL,
                                P_REF_CAMPO1 IN VARCHAR2 DEFAULT NULL,
                                P_VAL_CAMPO1 IN VARCHAR2 DEFAULT NULL,
                                P_REF_CAMPO2 IN VARCHAR2 DEFAULT NULL,
                                P_VAL_CAMPO2 IN VARCHAR2 DEFAULT NULL,
                                P_REF_CAMPO3 IN VARCHAR2 DEFAULT NULL,
                                P_VAL_CAMPO3 IN VARCHAR2 DEFAULT NULL,
                                P_REF_CAMPO4 IN VARCHAR2 DEFAULT NULL,
                                P_VAL_CAMPO4 IN VARCHAR2 DEFAULT NULL) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  V_CAN_ENV_PER_FPD NUMBER(4);
  V_CAN_ENV_REA_FPD NUMBER(4);
  V_COD_PER_INI_FPD md_dep_horarios.cod_periodo%type;
  v_con_est_periodo varchar2(1);
BEGIN
  V_LUG_PRO_LOC := 'PR_CON_ENV_AUTOMATICO';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);

  IF P_TIPO = 'I' then --Inserta Registros para Control de Envio Automatico--
     --Valida si Modulo de FPD se encuentra A-Abierto--
     V_COD_PER_INI_FPD := to_number(fug_obt_pardinamico('DEP_AUT_INI_FPD_OPE'));
     select decode(nvl(count(*),0),0,'N','S')
       into v_con_est_periodo
       from md_dep_horarios x
      where x.cod_periodo = V_COD_PER_INI_FPD
        and x.estado = 'A'
        and x.fecha = vg_fecha; --Abierto--;
     --if v_con_est_periodo <> 'S' then
     --   PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, 'Error. Periodo Depo de Modulo '||V_COD_PER_INI_FPD||' FPD de la fecha '||to_char(vg_fecha,'dd/mm/yyyy')||' no Abierto en BBVA. Verifique.'||'-'||V_LUG_PRO_LOC);
     --   raise_application_error(-20002, 'Error. Periodo Depo de Modulo '||V_COD_PER_INI_FPD||' FPD de la fecha '||to_char(vg_fecha,'dd/mm/yyyy')||' no Abierto en BBVA. Verifique.');
     --end if;

     --Valida si FPD ya fue enviado en forma efectiva--
     V_CAN_ENV_PER_FPD := fug_obt_pardinamico('DEP_AUT_CAN_PER_OPE');
     SELECT nvl(COUNT(distinct(a.cod_ejecucion)),0)
       into V_CAN_ENV_REA_FPD
       FROM MD_DEP_MSJ_AUTOMATICOS a
      where a.fecha = vg_fecha
        and a.cod_tip_ope = 'DEP_AUT_MSJ_FPD'
        and a.cod_ejecucion is not null
        and a.nro_orden is not null; --Controla envios brutos--

     if V_CAN_ENV_REA_FPD >= V_CAN_ENV_PER_FPD then
        vg_asunto := vg_fecfor||'Error. Envios FPD supera limite diario permitido por BCP: ('||V_CAN_ENV_PER_FPD||')';
        vg_mensaje := vg_fecfor||'Error. Envios Automaticos de FPD no puede superar limite permitido : ('||V_CAN_ENV_PER_FPD||'). Verifique y/o cambie parametro relacionado.'||'-'||'DEP_AUT_CAN_PER_OPE';
        pag_dom.pr_tra_env_email(pam_dep.g_gru_dir_correo, vg_asunto, vg_mensaje);
        PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, vg_mensaje);
        raise_application_error(-20002, vg_mensaje);
     end if;

    --Inserta los mensajes a Enviar para FPD--
    vg_cod_ejecucion := S_COD_EJE_DEP_AUTOMATICOS.NEXTVAL;
    INSERT INTO  MD_DEP_MSJ_AUTOMATICOS
    (fecha, cod_tip_ope, cod_ejecucion, nro_orden, COD_MSJ_ENVIADO, estado)
      select vg_fecha, A.DOMINIO, vg_cod_ejecucion,
      A.VAL_MINIMO, A.VAL_MAXIMO, 'I'
     from ba_cod_referencias a
     where a.dominio = 'DEP_AUT_MSJ_FPD'
     order by to_number(a.val_minimo);
  ELSIF P_TIPO = 'E' then --Actualizar Enviados cuando se envian--
     update MD_DEP_MSJ_AUTOMATICOS x
        set X.NRO_REF_ENVIADO = P_NRO_REFERENCIA,
            X.HOR_ENVIADO = P_HORA,
            x.estado = 'E' --ENVIADO--
      where x.fecha = vg_fecha
        and x.cod_tip_ope = 'DEP_AUT_MSJ_FPD'
        and x.cod_ejecucion = P_COD_EJECUCION
        and x.nro_orden = P_NRO_ORDEN
        and x.estado = 'I';
  ELSIF P_TIPO = 'R' then --Actualizar Recibidos cuando se reciben--
     update MD_DEP_MSJ_AUTOMATICOS x
        set X.COD_MSJ_RESPUESTA = P_COD_MSJ_SWIFT,
            X.NRO_REF_RESPUESTA = P_NRO_REF_RECIBIDO,
            X.HOR_RESPUESTA = P_HORA,
            x.estado = 'R', --RECIBIDO RESPUESTA--
            x.ref_campo1 = P_REF_CAMPO1,
            x.val_campo1 = P_VAL_CAMPO1,
            ---
            x.ref_campo2 = P_REF_CAMPO2,
            x.val_campo2 = P_VAL_CAMPO2,
            ---
            x.ref_campo3 = P_REF_CAMPO3,
            x.val_campo3 = P_VAL_CAMPO3,
            ---
            x.ref_campo4 = P_REF_CAMPO4,
            x.val_campo4 = P_VAL_CAMPO4
      where x.fecha = vg_fecha
        and x.cod_tip_ope = 'DEP_AUT_MSJ_FPD'
        and x.cod_ejecucion = P_COD_EJECUCION
        and x.nro_orden = P_NRO_ORDEN
        and x.estado = 'E'
        and x.nro_ref_enviado = P_NRO_REFERENCIA;
  end if;
  -------------------------
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC, vg_nro_referencia,NULL,NULL,NULL,vg_nro_cuenta,vg_des_operacion);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);
  commit;
EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END;

FUNCTION FU_PRO_MSJ_MTN99( P_MENSAJE IN LONG ) RETURN VARCHAR2
IS
   v_campo_20         ge_snp_mensajes.nro_ref_externa%type;       -- Nro. Referencia Externa
   v_campo_21         ge_snp_mensajes.nro_ref_externa%type;       -- Nro. Referencia del MT Original
   v_campo_79         ge_snp_mensajes.msj_swift%type;             -- Mensaje Swift
   v_fecha            md_dep_horarios.fecha%type;                 -- Fecha de apertura para operaciones con BCP
   v_periodo          md_dep_horarios.descripcion%type := null;   -- Descripcion del Periodo
   v_per_anterior     md_dep_horarios.descripcion%type := null;   -- Descripci¿n del Periodo a cerrar
   v_nvo_cod_periodo  md_dep_horarios.cod_periodo%type;           -- Si se ingres¿ un nuevo periodo
   v_mai_titulo       varchar2(200) := null;
   v_pos_ini          number        := 0;
   v_pos_fin          number        := 0;
   v_cod_periodo      md_dep_horarios.cod_periodo%type;
   v_val_cam_auxiliar varchar2(2000);
   v_lon_cam_auxiliar number(10);
   v_for_cam_auxiliar varchar2(2000);
   v_tex_men_auxiliar varchar2(8000);
   --Para actualizar envio--
   v_hor_recepcion VARCHAR2(8);
   v_cod_ejecucion md_dep_msj_automaticos.cod_ejecucion%type;
   v_nro_orden     md_dep_msj_automaticos.nro_orden%type;
   v_cod_msj_swift sb_snp_mensajes.cod_mensaje%type;
   v_exi_msj_enviado varchar2(1);
   v_msj_swift ge_snp_mensajes.msj_swift%type;
   v_cod_msj_env_bcp sb_snp_tip_mensajes.cod_mensaje%type;
   --Para validar Ejecucion Automatica FPD--
   V_COD_PER_INI_FPD md_dep_horarios.cod_periodo%type;
   V_IND_ENV_AUT_FPD ge_par_dinamicos.val_parametro%type;
   v_cod_per_actualizado md_dep_horarios.cod_periodo%type;

   PROCEDURE lp_act_horario (p_des_periodo in md_dep_horarios.descripcion%type,
                             p_tip_accion  in varchar2,
                             p_cod_per_actualizado out md_dep_horarios.cod_periodo%type)
   IS
     v_cod_periodo md_dep_horarios.cod_periodo%type;
     v_plsql       md_dep_horarios.det_sql%type;
     v_msj_error   varchar2(1000);
     PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
     select cod_periodo, det_sql
       into v_cod_periodo, v_plsql
       from md_dep_horarios
      where pas_snp.fu_val_cadena(replace(upper(p_des_periodo), ' ', '')) =
            pas_snp.fu_val_cadena(replace(upper(descripcion), ' ', ''))
        and tip_horario != 'A';

     -- Si no existen errores se actualiza la apertura y cierre de operaciones con BCP
     pas_snp.g_lugar := 'Actualizando datos de apertura y cierre de operaciones con BCP, ';
     p_cod_per_actualizado := 0;
     if p_tip_accion = 'A' then
        p_cod_per_actualizado := v_cod_periodo;
        update md_dep_horarios
           set fecha      = v_fecha,
               estado     = p_tip_accion
         where cod_periodo = v_cod_periodo;

       if sql%notfound then -- Si no encuentra el periodo, lo registra
            BEGIN
               Select nvl(max(cod_periodo),0)+1
                 into v_cod_periodo
                 from md_dep_horarios ;

               pas_snp.g_lugar := 'Registrando datos de apertura de operaciones con BCP, ';
               insert into md_dep_horarios
                   ( cod_periodo, descripcion, estado,
                     fecha, hor_inicio, hor_fin
                   )
               values
                   ( v_cod_periodo, trim(upper(v_periodo)), 'A',
                     v_fecha, to_char(sysdate,'hh24mi'), to_char(sysdate,'hh24mi')
                   );

            EXCEPTION
               when others then
                  -- Si tiene errores a nivel de BD, guarda el error para luego enviar por correo.
                  pas_snp.pr_set_texto ( pas_snp.g_det_msj_error, pas_snp.g_lugar || SQLERRM , pas_snp.fu_obt_salto );
            END ;
        end if ;
     else
       update md_dep_horarios
          set estado     = p_tip_accion
        where cod_periodo = v_cod_periodo
          and tip_horario != 'T'
          and fecha = v_fecha;
     end if;

     -- hay algo para ejecutar
     if v_plsql is not null then
        pas_snp.g_lugar := 'Ejecutando Script Configurado, ';
        v_plsql := replace(v_plsql,'&'||'TIP_ACCION',chr(39)||p_tip_accion||chr(39));
        sql_util.ejecute_dml(v_plsql,v_msj_error);
        if v_msj_error is not null then
           pas_snp.pr_set_texto ( pas_snp.g_det_msj_error, pas_snp.g_lugar || v_msj_error , pas_snp.fu_obt_salto );
        end if;
     end if;
     commit;
   EXCEPTION
     when no_data_found then
       Select nvl(max(cod_periodo),0)+1
         into v_nvo_cod_periodo
         from md_dep_horarios ;
       pas_snp.g_lugar := 'Registrando datos de apertura de operaciones con BCP, ';
       insert into md_dep_horarios (cod_periodo, descripcion, estado, fecha, hor_inicio, hor_fin, tip_horario)
            values (v_nvo_cod_periodo, trim(upper(p_des_periodo)), p_tip_accion, v_fecha,
                    to_char(sysdate,'hh24mi'), to_char(sysdate,'hh24mi'), 'O');
       commit;
     when others then
       -- Si tiene errores a nivel de BD, guarda el error para luego enviar por correo.
       pas_snp.pr_set_texto ( pas_snp.g_det_msj_error, pas_snp.g_lugar || SQLERRM , pas_snp.fu_obt_salto );
   END lp_act_horario;

BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   /*
   || En esta variable se almacenar¿ todos los errores encontrados y
   || se depositar¿ en el campo error de GE_SNP_TRANSFERENCIAS.
   */
   pas_snp.g_det_msj_error := null;
   v_tex_men_auxiliar := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );

   if p_mensaje is null then
      pas_snp.g_cod_error := 52;
      pas_snp.g_msj_error := 'Error en PAS_SNP.FU_PRO_MSJ_MTn99. Valor para P_MENSAJE debe contener algun valor.!';
      pas_snp.pr_set_texto ( pas_snp.g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
   end if;

   --Campos Mandatorios para el MTn99
   /**/-- Campo :20:
   pas_snp.g_lugar :=  'Obteniendo campo :20:, ';
   v_campo_20 := replace( pas_snp.fu_pro_val_tag( p_mensaje, '20', 'N' ), pas_snp.fu_obt_sal_socket );
   if v_campo_20 is null then
      pas_snp.pr_set_texto ( pas_snp.g_det_msj_error, pas_snp.g_lugar || 'Nro. Ref. Externa no puede ser nulo.! ' , pas_snp.fu_obt_salto );
   end if;

   /**/-- Campo :21: No es obligatorio, por eso no se valida
   pas_snp.g_lugar :=  'Obteniendo campo :21:, ';
   v_campo_21 := replace( pas_snp.fu_pro_val_tag( p_mensaje, '21', 'N' ), pas_snp.fu_obt_sal_socket );

   /**/-- Campo :79:
   pas_snp.g_lugar :=  'Obteniendo campo :79:, ';
   v_campo_79 := pas_snp.fu_pro_val_tag( p_mensaje, '79', 'N' );
   if v_campo_79 is null then
      pas_snp.pr_set_texto ( pas_snp.g_det_msj_error, pas_snp.g_lugar || 'Accion a realizar (QUERY) no puede ser nulo.! ' , pas_snp.fu_obt_salto );
   elsif instr ( v_campo_79, 'BUSINESSDAYPERIOD/' ) > 0 then -- Apertura de Periodos
      pas_snp.g_lugar := 'Obteniendo datos de apertura de operaciones con BCP - /BUSINESSDAY/YYMMDD, ';
      if instr ( v_campo_79, '/BUSINESSDAY/' ) > 0 then
         v_pos_ini := instr(v_campo_79,'/BUSINESSDAY/') + 13;
         -----
         v_val_cam_auxiliar := pam_dep.FU_OBT_VAL_CAM_ESP(v_tex_men_auxiliar,'/BUSINESSDAY/');
         --v_val_cam_auxiliar := pam_dep.FU_OBT_VAL_CAM_ESP(v_campo_79,'/BUSINESSDAY/');
         v_lon_cam_auxiliar := length(v_val_cam_auxiliar);
         v_for_cam_auxiliar := lpad('RRMMDD',v_lon_cam_auxiliar,'R');
         -----
         v_pos_fin := v_pos_ini + v_lon_cam_auxiliar;
         v_fecha   := to_date( substr ( v_campo_79, v_pos_ini, v_pos_fin - v_pos_ini ), v_for_cam_auxiliar );
         -----
      end if;
      if instr ( v_campo_79, '/PERIOD/' ) > 0 then
         v_pos_ini := instr(v_campo_79,'/PERIOD/') + 8;
         v_pos_fin := instr(v_campo_79,pas_snp.fu_obt_sal_socket,v_pos_ini,1);
         v_periodo := ( substr ( v_campo_79, v_pos_ini, v_pos_fin - v_pos_ini ) ) ;
      end if;
      if instr ( v_campo_79, '/PREVIOUSPERIOD/' ) > 0 then
         v_pos_ini := instr(v_campo_79,'/PREVIOUSPERIOD/') + 16;
         v_pos_fin := instr(v_campo_79,pas_snp.fu_obt_sal_socket,v_pos_ini,1);
         v_per_anterior := ( substr ( v_campo_79, v_pos_ini, v_pos_fin - v_pos_ini ) ) ;
      end if;
      if v_fecha is null then
         pas_snp.pr_set_texto ( pas_snp.g_det_msj_error, pas_snp.g_lugar || 'No se ha recuperado la fecha de la palabra reservada /BUSINESSDAY/.! ' , pas_snp.fu_obt_salto );
      end if;
      --Validacion de Fecha Actual--
      if V_FECHA <> VG_FECHA then
         pas_snp.g_cod_error := 52;
         pas_snp.g_msj_error := 'Error en PAM_DEP.FU_PRO_MSJ_MTn99. Fecha del MT999 '||to_char(v_fecha,'dd/mm/yyyy')||' <> Fecha de ITGF '||to_char(vg_fecha,'dd/mm/yyyy') ;
         pas_snp.pr_set_texto ( pas_snp.g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
      end if;
      ------------------------------
      if v_periodo is null and v_per_anterior is null then
         pas_snp.pr_set_texto ( pas_snp.g_det_msj_error, pas_snp.g_lugar || 'No se ha recuperado el concepto del periodo actual mediante la palabra reservada /PERIOD/.! ' , pas_snp.fu_obt_salto );
      else -- Se recuper¿ la descripci¿n del periodo
         -- Si no existen errores se actualiza la apertura de operaciones con BCP
         if v_periodo is not null then
            lp_act_horario(v_periodo, 'A', v_cod_per_actualizado);
         end if;
      end if;
   end if;

   --Se inserta en GE_SNP_MENSAJES el swift.
   BEGIN
      BEGIN
         INSERT INTO ge_snp_mensajes ( nro_referencia,
                                       nro_ref_externa,
                                       cod_msj_swift,
                                       fec_valor,
                                       msj_swift,
                                       error,
                                       fec_recepcion,
                                       msj_swi_original
                                     )
                              VALUES ( v_campo_20,
                                       v_campo_21,
                                       substr( p_mensaje, instr( p_mensaje, '{2:' ) + 4, 3 ),
                                       pas_snp.g_fec_actual,
                                       replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ),
                                       pas_snp.g_det_msj_error,
                                       sysdate,
                                       replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto )
                                     );

         if v_periodo is not null then
            --Llamado a Inicio Automatico FPD--(1) Si parametgro es Envio Autmatico--
            V_COD_PER_INI_FPD := to_number(fug_obt_pardinamico('DEP_AUT_INI_FPD_OPE'));
            if v_cod_per_actualizado = V_COD_PER_INI_FPD then
               V_IND_ENV_AUT_FPD := fug_obt_pardinamico('DEP_AUT_ENV_AUT_OPE');
               if nvl(V_IND_ENV_AUT_FPD,'N') = 'S' then
                  PAM_DEP.PR_VAL_APE_MOD_DEPO(v_periodo, v_cod_per_actualizado);
               end if;
            end if;
         end if;

         --Actualiza Archivo Recibido--
         v_msj_swift := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
         pas_snp.g_lugar :=  'Insertando en GE_SNP_MENSAJES, ';
         v_cod_msj_swift := 'MT'||substr( p_mensaje, instr( p_mensaje, '{2:' ) + 4, 3 );
         PAM_DEP.PR_OBT_DAT_MSJ_ACTUAL(v_cod_msj_swift, 'E', v_campo_21, v_exi_msj_enviado, v_cod_ejecucion, v_nro_orden, v_cod_msj_env_bcp);
         if v_exi_msj_enviado = 'S' then
            v_hor_recepcion := TO_CHAR(SYSDATE,'HH24:MI:SS');
            PR_CON_ENV_AUTOMATICO('R', v_campo_21, v_hor_recepcion, v_cod_ejecucion, v_nro_orden, v_cod_msj_swift, v_campo_20);
         end IF;
      ---------------------------------
      EXCEPTION
        when others then
          -- Si tiene errores a nivel de BD, guarda el error para luego enviar por correo.
          pas_snp.pr_set_texto ( pas_snp.g_det_msj_error, pas_snp.g_lugar || SQLERRM , pas_snp.fu_obt_salto );
      END;
      if pas_snp.g_det_msj_error is null then
         if pam_dep.g_gru_dir_correo is not null then
            if instr ( v_campo_79, 'TEXTMESSAGE/' ) > 0 then -- Mensajer¿a de formato libre
               v_mai_titulo := vg_fecfor||'MTn99 - Se recibio un Mensaje DEPO con formato libre';
            elsif instr ( v_campo_79, 'BUSINESSDAYPERIOD/' ) > 0 then -- MTn99: Solicitud de Propiedad (Proprietary requests)
               v_mai_titulo := vg_fecfor||'MTn99 - Se recibio una nueva solicitud de activacion de periodo DEPO con BCP';
            else
               v_mai_titulo := vg_fecfor||'MTn99 - Se recibio un Mensaje DEPO propio de BCP';
            end if;
            DECLARE
               v_mensaje varchar2(1000) := 'Se recibio un MTn99 con el siguiente detalle:' || chr(10) || chr(10) ||
                                           'Nro. Referencia     : ' || v_campo_20                                       || chr(10) ||
                                           'Nro. Ref. Original  : ' || v_campo_21                                       || chr(10) ||
                                           'Detalle del mensaje : ' || replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ) || chr(10) ||
                                           chr(10) || chr(10) ||
                                           'Atentamente.';
               -- Envia mail al grupo de notificaci¿n si se recibe un MT de Informaci¿n.
            BEGIN
               --Si se grab¿ un nuevo periodo cambia el texto a enviar.
               if nvl(v_nvo_cod_periodo, 0) != 0 then
                  v_mensaje := 'Se recibio un MTn99 con el siguiente detalle:' || chr(10) || chr(10) ||
                                           'Nro. Referencia     : ' || v_campo_20                                       || chr(10) ||
                                           'Nro. Ref. Original  : ' || v_campo_21                                       || chr(10) ||
                                           'Detalle del mensaje : ' || replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ) || chr(10) ||
                                           'Se genero un Nuevo Periodo con el Codigo: ' || v_nvo_cod_periodo ||'. Favor realizar las configuraciones necesarias en Horarios de Periodos SNP' || chr(10) ||
                                           chr(10) || chr(10) ||
                                           'Atentamente.';
               end if;
               it_mail.mail( fug_obt_dir_correo,
                             pam_dep.g_gru_dir_correo,
                             v_mai_titulo,
                             v_mensaje
                            );
            EXCEPTION
               when others then
                  NULL;
            END;
         end if;
         return '00' || '|' || 'MTn99' || '|' || ltrim(rtrim(v_campo_20)) || ' - Procesado OK';
      else -- Tiene errores
         if pam_dep.g_err_dir_correo is not null then
            it_mail.mail( fug_obt_dir_correo,
                          pam_dep.g_err_dir_correo,
                          vg_fecfor||'MTn99 - Error durante el proceso ',
                          'No se pudo procesar el MTn99 con los siguientes datos:' || chr(10) || chr(10) ||
                          'Nro. Referencia     : ' || v_campo_20                              || chr(10) ||
                          'Detalle del mensaje : ' || replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ) || chr(10) ||
                          'Error               : ' || pas_snp.g_det_msj_error                         || chr(10) ||
                          chr(10) || chr(10) ||
                          'Atentamente.'
                        );
         end if;
         return '00' || '|' || 'MTn99' || '|' || ltrim(rtrim(v_campo_20)) || ' - Procesado con errores';
      end if;
   EXCEPTION
     when others then
        raise;
   END;

EXCEPTION
  when others then
    return 99 || '|' || 'MTn99' || '|' || pas_snp.g_lugar || ' - ' || SQLERRM;
END FU_PRO_MSJ_MTN99;

FUNCTION FU_PRO_MSJ_MTN96(P_MENSAJE IN LONG) RETURN VARCHAR2
IS
/*
||   Procesa la mensajeria RECIBIDA MTn96
*/
   v_nro_referencia  ge_snp_mensajes.nro_referencia%type;
   v_nro_ref_externa ge_snp_mensajes.nro_ref_externa%type;
   v_cod_mensaje     sb_snp_mensajes_tmp.cod_mensaje%type;
   v_cod_msj_swift   ge_snp_transferencias.cod_msj_swift%type;
   v_dir_correo      ge_par_dinamicos.val_parametro%type := nvl( pam_dep.g_gru_dir_correo, pam_dep.g_err_dir_correo );
   v_sub_tip_mt      varchar2(30);
   v_error           varchar2(100) := 'No se han encontrado transacciones para procesar ';
   v_txt_mail        varchar2(4000);
   v_asunto          varchar2(4000);
   --GC; 23/03/2016  Envio de alertas por pagos a proveedores
    v_proveedores     ge_snp_transferencias.ben_dir_correo%type;
    v_nro_factura    varchar2(2000);
    v_mje_mail       LONG;
    v_concepto       ge_pag_proveedores.concepto%type;
    v_conn           utl_smtp.connection;
    v_texto          varchar2(4000);
    v_texto_detalle  varchar2(32000) := null;
    -- DDEVOLUT-40 -- CN: 12/2016 -- Se obtiene a partir de la funcion fug_gen_template
    v_membrete LONG := fug_gen_template('M')||chr(10);
    V_FIN      LONG := chr(10) ||fug_gen_template('F')|| chr(10);
    V_PIE      LONG := chr(10) ||fug_gen_template('P');
    rg_snp_tra        pas_snp.rg_msj;
    --Para marcar como recibido--
    v_cod_ejecucion md_dep_msj_automaticos.cod_ejecucion%type;
    v_nro_orden     md_dep_msj_automaticos.nro_orden%type;
    v_exi_msj_enviado varchar2(1);
    v_cod_msj_env_bcp sb_snp_tip_mensajes.cod_mensaje%type;
    v_hor_recepcion varchar2(8);
    v_msj_swift ge_snp_mensajes.msj_swift%type;
    v_cod_msj_swif_aux sb_snp_tip_mensajes.cod_mensaje%type;

    --
   cursor cu_msj_temporal is
      select a.cod_mensaje,
             a.campo,
             a.valor,
             a.descripcion,
             a.err_formato,
             a.orden
        from sb_snp_mensajes_tmp a
       where a.cod_mensaje = v_cod_mensaje
         and a.campo not in ('CAB', 'PIE')
         and a.descripcion is not null
       order by orden;

BEGIN

   v_cod_mensaje := pao_pmt.fu_obt_cod_mensaje(replace(p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto));

   for msj in cu_msj_temporal loop
     --Creo la cabecera del mail
      v_asunto := vg_fecfor||'Mensajeria '|| msj.cod_mensaje || ' Recibida' ||chr(10);
      --Se concatena los datos disponibles para el env¿o del Mail.
      v_txt_mail := v_txt_mail || chr(10) ||
                    msj.descripcion || ': '||
                    case when msj.campo = '76'
                          and msj.descripcion = 'Sub Tipo Respuesta'
                          and msj.cod_mensaje = 'MTn96/STAT' then --Cuando es campo "Respuesta" se traduce
                            fue_obt_des_referencia('SNP_TIP_RTA_N96_STAT',substr(msj.valor, 0, 4))||' ('||substr(msj.valor, 0, 4)||')'
                         else msj.valor end;
      --Se concatenan los errores de formato que pudieron ocurrir
      if msj.err_formato is not null then
         pas_snp.pr_set_texto( pas_snp.g_det_msj_error, msj.err_formato, pas_snp.fu_obt_salto );
      end if;
      --Se obtiene el campo 76 (Sub Tipo Respuesta)
      if msj.campo = '76' and msj.descripcion = 'Sub Tipo Respuesta' then
         v_sub_tip_mt := substr(msj.valor, 0, 4);
      end if;
      --Se obtiene el campo 76 (C¿digo de MT solicitado)
      if msj.campo = '11R' and msj.descripcion = 'Codigo de MT solicitado' then
         v_cod_msj_swift := msj.valor;
      end if;
   end loop;

   v_nro_referencia  := pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '20');
   v_nro_ref_externa := pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '21');

   if v_cod_mensaje = 'MTn96/STAT' and
      v_sub_tip_mt in ('NETS','NETR','WAIT','NETA')
   then
      if v_sub_tip_mt = 'NETS' then
        /*
         * MTn96/STAT NETS Confirmaci¿n de Lote.
         * Setea Situaci¿n = 'L' y Estado = 'A' al lote.
         */
        declare
          cursor cu_msj_tra is
           select ge.nro_referencia, ge.fec_valor, ge.nom_beneficiario, ge.nom_solicitante, ge.nro_cta_beneficiario,
                  ge.monto, ge.cod_moneda
             from ge_snp_transferencias ge
            where ge.nro_lote = v_nro_ref_externa
              and ge.cod_msj_swift = v_cod_msj_swift
              and ge.fec_recepcion is null
              and ge.estado = 'A'
              and ge.situacion = 'O';
        begin
            pas_snp.g_lugar := 'Recorre las Operaciones en Cursor cu_msj_tra, ';
            for reg in cu_msj_tra loop
               pas_snp.pr_ini_variables;

               -- Verifica que no tenga Workflow para liquidar autom¿ticamente.
               if not pas_snp.fu_ver_workflow( to_char( reg.nro_referencia ) ) then
                  v_error := null;
                  -- Cambia la situaci¿n del MT102 a LIQUIDADO y estado APROBADO.
                  -- Si no existen errores se actualiza el Estado del Mensaje Origen en GE_SNP_TRANSFERENCIAS
                  UPDATE ge_snp_transferencias
                     SET situacion = 'L',
                         estado    = 'A'
                   WHERE nro_referencia = reg.nro_referencia;
                   Begin
                       select a.ben_dir_correo, nvl(a.nro_factura,0), nvl(a.concepto,0)
                         into v_proveedores, v_nro_factura, v_concepto
                         from ge_pag_proveedores a
                        where a.nro_referencia = reg.nro_referencia
                          and a.fec_pago = reg.fec_valor
                          and a.for_pago='I';
                     EXCEPTION
                          WHEN others THEN
                             v_proveedores := null;
                      end;
                   if v_proveedores is not null then
                          v_texto := '<br><br>
                                       <br><br>
                                         Estimado Cliente: '||upper(reg.nom_beneficiario)||'
                                       <br><br>
                                         Le informamos que se realizo el credito en su cuenta por el servicio solicitado por la empresa: ' ||
                                                 upper(reg.nom_solicitante) || '.
                                       <br><br>
                                         Fecha: '||reg.fec_valor||'
                                       <br><br>
                                         Cuenta de Credito: '||reg.nro_cta_beneficiario||'
                                       <br><br>
                                         Monto: '||to_char(reg.monto,'999,999,999,999.99')||'
                                       <br><br>
                                         Moneda: '||reg.cod_moneda||'
                                       <br><br>
                                         Nro. Factura(s): '||v_nro_factura||'
                                       <br><br>
                                         Concepto: '||v_concepto||'
                                       <br><br>
                                         Atentamente.
                                       <br><br>
                                       <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                                       <br><br>
                                       <br><br>';
                            v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                                          chr(10) || chr(10) || chr(10) || V_FIN|| chr(10)|| V_PIE;
                           BEGIN
                             v_conn     := it_mail.begin_mail(fug_obt_pardinamico('CAN_MAR_DIR_MAIL'),
                                                               v_proveedores,
                                                               'Acreditacion en Cuenta - Pago a proveedores via SNP',
                                                               IT_MAIL.MULTIPART_MIME_TYPE);
                              it_mail.attach_text(v_conn, v_mje_mail, 'text/html');
                              it_mail.write_text(v_conn, v_texto_detalle);
                              it_mail.end_mail(v_conn);
                            EXCEPTION
                               when others then
                                    insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                                    values (fug_obt_pardinamico('CAN_MAR_DIR_MAIL'), v_proveedores, 'Acreditacion en Cuenta - Pago a proveedores via SNP', v_texto, sysdate, user)  ;
                            end;
                     end if;
               end if ;
            end loop;
            pas_snp.pr_set_texto( pas_snp.g_det_msj_error, v_error, pas_snp.fu_obt_salto );
        end;
        v_txt_mail := 'Confirmacion de Lote MT' || v_cod_msj_swift || v_txt_mail;
      elsif v_sub_tip_mt = 'WAIT' then
         /*
         * MTn96/STAT WAIT Transferencia en Demora.
         * Setea Situaci¿n = 'D'.
         */
         v_nro_ref_externa := pas_snp.fu_obt_nro_ref_relacionada(v_nro_ref_externa);
         pas_snp.pr_obt_mensaje( v_nro_ref_externa, 'N' );
         if pas_snp.fu_obt_cod_error = 0 then
            pas_snp.g_msj.situacion := 'D';
            pas_snp.pr_set_transferencias ( pas_snp.g_msj );
            v_asunto := vg_fecfor||'Mensajeria en Demora - SNP.';
            v_txt_mail := 'Transferencia en Demora' || v_txt_mail;
            v_txt_mail := v_txt_mail || chr(10) || chr(10) || 'Datos de la Transferencia Original: ' || chr(10) ||
            'Nro. Cuenta    : ' || pas_snp.g_msj.nro_cta_pte_solicitante || chr(10) ||
            'Nro. Referencia: ' || pas_snp.g_msj.nro_referencia || chr(10) ||
            'Fecha Valor    : ' || to_char(pas_snp.g_msj.fec_valor,'DD/MM/YYYY') || chr(10) ||
            'Tipo Operacion : ' || pas_snp.fu_obt_des_tip_operacion( pas_snp.g_msj.cod_msj_swift,
                                                                     pas_snp.g_msj.cod_tip_operacion,
                                                                     pas_snp.g_msj.cod_sub_tip_operacion) || chr(10) ||
            'Moneda         : ' || pas_snp.g_msj.cod_moneda || chr(10) ||
            'Monto          : ' || trim(to_char(pas_snp.g_msj.monto,'999,999,999,999,999.99'));
         else -- Tiene Errores
            pas_snp.g_msj_error := v_error || ', ' || pas_snp.fu_obt_msj_error;
            pas_snp.pr_set_texto( pas_snp.g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            pas_snp.pr_ini_variables;
         end if;
      elsif v_sub_tip_mt in ('NETR', 'NETA') then
         /*
         * MTn96/STAT NETR Precompensacion OK.
         * Mensaje aceptado para el Neteo de hoy. Puede ser cancelado por el participante.
         * Setea Situaci¿n = 'O' para los MT102 Enviados.
         */
         pas_snp.g_lugar := 'Actualizando Situacion a Pre-Proceso OK, ';
         UPDATE ge_snp_transferencias
            SET situacion = 'O'
         WHERE nro_lote = v_nro_ref_externa;
         if sql%rowcount > 0 then
            v_txt_mail := 'Precompensacion OK '|| v_txt_mail;
         else
            v_txt_mail := v_error || 'Error: No se encontro lote '||v_nro_ref_externa;
            pas_snp.g_msj_error := v_error || ', ' || ' Error: No se encontro lote '||v_nro_ref_externa;
            pas_snp.pr_set_texto( pas_snp.g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            pas_snp.pr_ini_variables;
         end if;
      end if;
   elsif v_cod_mensaje = 'MTn96/AUTH' then
      /*
      * MTn96/AUTH Mensaje de autorizaci¿n.
      * Setea Situaci¿n = 'A'.
      */
      if v_sub_tip_mt != 'ERRC' then
         pas_snp.pr_obt_mensaje( v_nro_ref_externa, 'N' );
         if pas_snp.fu_obt_cod_error = 0 then
            pas_snp.g_msj.situacion := 'A';
            pas_snp.pr_set_transferencias ( pas_snp.g_msj );
            if pas_snp.g_msj.cod_msj_swift = 202
             and pas_snp.g_msj.cod_tip_operacion in ('002','003') then
               v_dir_correo := pam_dep.g_err_dir_mesa;
               v_asunto := vg_fecfor||'Aprobacion Tesoreria BCP - RETIRO/DEPOSITO en EFECTIVO.';
            end if;
            v_txt_mail := 'Mensaje de Autorizacion del BCP (AUTH) ' || v_txt_mail;
            v_txt_mail := v_txt_mail || chr(10) || chr(10) || 'Datos de la Transferencia Original: ' || chr(10) ||
            'Nro. Cuenta    : ' || pas_snp.g_msj.nro_cta_pte_solicitante || chr(10) ||
            'Nro. Referencia: ' || pas_snp.g_msj.nro_referencia || chr(10) ||
            'Fecha Valor    : ' || to_char(pas_snp.g_msj.fec_valor,'DD/MM/YYYY') || chr(10) ||
            'Tipo Operacion : ' || pas_snp.fu_obt_des_tip_operacion( pas_snp.g_msj.cod_msj_swift,
                                                                     pas_snp.g_msj.cod_tip_operacion,
                                                                     pas_snp.g_msj.cod_sub_tip_operacion) || chr(10) ||
            'Moneda         : ' || pas_snp.g_msj.cod_moneda || chr(10) ||
            'Monto          : ' || trim(to_char(pas_snp.g_msj.monto,'999,999,999,999,999.99'));
         else -- Tiene Errores
            pas_snp.g_msj_error := v_error || ', ' || pas_snp.fu_obt_msj_error;
            pas_snp.pr_set_texto( pas_snp.g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            pas_snp.pr_ini_variables;
         end if;
      end if;
   elsif v_cod_mensaje = 'MTn96/NAUT' then
      /*
       * MTn96/NAUT Transferencia rechazada
       * Marca como cancelado (estado = 'C'), Reversa el Movimiento.
       */
      if v_sub_tip_mt != 'ERRC' then
         begin
            --Obtiene los datos del mensaje.
            pas_snp.pr_obt_mensaje( v_nro_ref_externa, 'N' );
            if pas_snp.fu_obt_cod_error = 0 then
               --CANCELA SWIFT POR MTn96.
               pas_snp.g_lugar := 'MTn96: Rechazo de SWIFT por BCP.';
               if pas_snp.g_msj.cod_msj_swift = 202
                 and pas_snp.g_msj.cod_tip_operacion in ('002','003') then
                  --Si es MT202 RETIRO/DEPOSITO en EFECTIVO actualizar situaci¿n a X=Rechazo de Tesorer¿a BCP
               pas_snp.g_msj.situacion := 'X';
               v_dir_correo := pam_dep.g_err_dir_mesa;
               end if;
               --CANCELA EL SWIFT
               pas_snp.g_lugar := 'MTn96: Cancelacion de SWIFT .';
               pas_snp.g_msj.estado := 'C';
               pas_snp.pr_set_transferencias ( pas_snp.g_msj );
               --Si es del d¿a Cancela el Movimiento
               if pas_snp.g_msj.fec_valor = pas_snp.g_fec_actual then
                  if pas_snp.g_msj.fecha is not null
                    and pas_snp.g_msj.hora is not null
                    and pas_snp.g_msj.cod_usuario is not null then
                     --REVERSA LA OPERACION RELACIONADA AL MENSAJE
                     pas_snp.pr_rev_ope_con_swift( v_nro_ref_externa, 'Rev. Automat. CANC. - SNP' );
                     -- Si la reversi¿n tiene ERRORES se adjunta el error en la mensajer¿a.
                     if pas_snp.fu_obt_cod_error <> 0 then
                        raise pas_snp.ex_salir;
                     end if;
                  end if;
               end if ;
               v_txt_mail := 'Mensaje de Rechazo (NAUT) ' || v_txt_mail;
               v_txt_mail := v_txt_mail || chr(10) || chr(10) || 'Datos de la Transferencia Original: ' || chr(10) ||
               'Nro. Cuenta    : ' || pas_snp.g_msj.nro_cta_pte_solicitante || chr(10) ||
               'Nro. Referencia: ' || pas_snp.g_msj.nro_referencia || chr(10) ||
               'Fecha Valor    : ' || to_char(pas_snp.g_msj.fec_valor,'DD/MM/YYYY') || chr(10) ||
               'Tipo Operacion : ' || pas_snp.fu_obt_des_tip_operacion( pas_snp.g_msj.cod_msj_swift,
                                                                        pas_snp.g_msj.cod_tip_operacion,
                                                                        pas_snp.g_msj.cod_sub_tip_operacion) || chr(10) ||
               'Moneda         : ' || pas_snp.g_msj.cod_moneda || chr(10) ||
               'Monto          : ' || trim(to_char(pas_snp.g_msj.monto,'999,999,999,999,999.99'));
            else -- Tiene Errores
               pas_snp.g_msj_error := v_error || ', ' || pas_snp.fu_obt_msj_error;
               pas_snp.pr_set_texto( pas_snp.g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
               pas_snp.pr_ini_variables;
            end if;
         exception
            when pas_snp.ex_salir then
               pas_snp.pr_set_texto( pas_snp.g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
               pas_snp.pr_ini_variables;
            when others then
               pas_snp.pr_set_texto( pas_snp.g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
               pas_snp.pr_ini_variables;
         end;
      end if;
   elsif v_cod_mensaje = 'MTn96/PRTY' then
     /*
      * MTn96/PRTY Cambio de prioridad.
      * Actualiza prioridad.
      */
      BEGIN
        if v_sub_tip_mt != 'ERRC' then
           --
           pas_snp.g_lugar  := 'Obteniendo datos del Nro. Ref.: ' || v_nro_referencia || ', ';
           v_nro_ref_externa := pas_snp.fu_obt_nro_ref_relacionada(v_nro_ref_externa);
           pas_snp.pr_obt_mensaje( v_nro_ref_externa, 'N' );
           if pas_snp.fu_obt_cod_error = 0 then
              -- Si no existen errores se actualiza la prioridad en GE_SNP_TRANSFERENCIAS
              UPDATE ge_snp_transferencias
                 SET prioridad       = v_sub_tip_mt
               WHERE nro_referencia  = v_nro_ref_externa;
              --
              if sql%found then
                 v_txt_mail := 'Mensaje de Cambio de Prioridad ' || v_txt_mail;
                 v_txt_mail := v_txt_mail || chr(10) || chr(10) || 'Datos de la Transferencia Original: ' || chr(10) ||
                 'Nro. Cuenta    : ' || pas_snp.g_msj.nro_cta_pte_solicitante || chr(10) ||
                 'Nro. Referencia: ' || pas_snp.g_msj.nro_referencia || chr(10) ||
                 'Fecha Valor    : ' || to_char(pas_snp.g_msj.fec_valor,'DD/MM/YYYY') || chr(10) ||
                 'Tipo Operacion : ' || pas_snp.fu_obt_des_tip_operacion( pas_snp.g_msj.cod_msj_swift,
                                                                          pas_snp.g_msj.cod_tip_operacion,
                                                                          pas_snp.g_msj.cod_sub_tip_operacion) || chr(10) ||
                 'Moneda         : ' || pas_snp.g_msj.cod_moneda || chr(10) ||
                 'Monto          : ' || trim(to_char(pas_snp.g_msj.monto,'999,999,999,999,999.99'));
              end if;
           else -- Tiene Errores
              pas_snp.g_msj_error := v_error || ', ' || pas_snp.fu_obt_msj_error;
              pas_snp.pr_set_texto( pas_snp.g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
              pas_snp.pr_ini_variables;
           end if;
        end if;
      EXCEPTION
         when no_data_found then
            pas_snp.g_det_msj_error := pas_snp.g_lugar||' No se ha encontrado datos del MT Original';
         when others then
            pas_snp.g_det_msj_error := pas_snp.g_lugar||sqlerrm;
      END;
   elsif v_cod_mensaje = 'MTn96/ERRC'
     or (v_cod_mensaje = 'MTn96/STAT' and v_sub_tip_mt in('ERRC','ERRP')) then
      BEGIN
        /*
         * MTn96/STAT ERRC ERRP o MTn96/ERRC
         * Marca con estado 'E', reversa operaci¿n.
         * Alto y Bajo Valor
         */
         if v_cod_msj_swift in (103,202) then
            --ALTO VALOR
            pas_snp.g_lugar  := 'Obteniendo datos de la mensajeria. Nro. Ref.:'||v_nro_ref_externa||', ';
            pas_snp.pr_obt_mensaje( v_nro_ref_externa, 'N' );
            if pas_snp.fu_obt_cod_error = 0 then
               pas_snp.g_lugar := 'MTn96: Intentando cancelar el SWIFT por error, ';
               if not ( pas_snp.g_msj.estado = 'A' and pas_snp.g_msj.situacion = 'L' )
                 /*and ( pas_snp.g_fec_actual - pas_snp.g_dia_max_reversion ) <= pas_snp.g_msj.fec_valor*/ then
                  --CANCELA EL SWIFT SI NO EST¿ LIQUIDADO Y SI LA FECHA VALOR DEL MENSAJE
                  --SE ENCUENTRA DENTRO DE LO PERMITIDO SEG¿N PAR¿METRO DE CANTIDAD DE DIAS M¿XIMO PARA REVERSI¿N
                  pas_snp.g_msj.estado := 'E';
                  pas_snp.pr_set_transferencias ( pas_snp.g_msj );
                  --Si tuvo Movimiento Reversa la operaci¿n
                  if pas_snp.g_msj.fecha is not null
                    and pas_snp.g_msj.hora is not null
                    and pas_snp.g_msj.cod_usuario is not null then
                     pas_snp.pr_rev_ope_con_swift( v_nro_ref_externa, 'Rev. Automat. ERROR - SNP' );
                     -- Si la reversi¿n tiene ERRORES se adjunta el error en la mensajer¿a.
                     if pas_snp.fu_obt_cod_error <> 0 then
                        raise pas_snp.ex_salir;
                     end if;
                  end if;
                  if pas_snp.g_msj.cod_msj_swift = 202
                    and pas_snp.g_msj.cod_tip_operacion in ( '002', '003' )then
                     v_asunto := vg_fecfor||'Rechazo por Error - RETIRO/DEPOSITO en EFECTIVO.';
                     v_dir_correo := pam_dep.g_err_dir_mesa;
                  else
                     v_asunto := vg_fecfor||'Cancelacion por Error.';
                  end if;
               end if;
               v_txt_mail := 'Mensajeria Alto Valor con error ('|| v_sub_tip_mt || ') ' || v_txt_mail;
               v_txt_mail := v_txt_mail || chr(10) || chr(10) || 'Datos de la Transferencia Original: ' || chr(10) ||
               'Nro. Cuenta    : ' || pas_snp.g_msj.nro_cta_pte_solicitante || chr(10) ||
               'Nro. Referencia: ' || pas_snp.g_msj.nro_referencia || chr(10) ||
               'Fecha Valor    : ' || to_char(pas_snp.g_msj.fec_valor,'DD/MM/YYYY') || chr(10) ||
               'Tipo Operacion : ' || pas_snp.fu_obt_des_tip_operacion( pas_snp.g_msj.cod_msj_swift,
                                                                        pas_snp.g_msj.cod_tip_operacion,
                                                                        pas_snp.g_msj.cod_sub_tip_operacion) || chr(10) ||
               'Moneda         : ' || pas_snp.g_msj.cod_moneda || chr(10) ||
               'Monto          : ' || trim(to_char(pas_snp.g_msj.monto,'999,999,999,999,999.99'));
            else -- Tiene Errores
               pas_snp.g_msj_error := v_error || ', ' || pas_snp.fu_obt_msj_error;
               pas_snp.pr_set_texto( pas_snp.g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
               pas_snp.pr_ini_variables;
            end if;
         elsif v_cod_msj_swift in(102, 104) then
            --BAJO VALOR
            declare
               v_error varchar2(60) := 'Error al procesar '||v_cod_mensaje||' Lote '||v_nro_ref_externa||' No encontrado';
               cursor cu_nro_referencias is
                  select ge.nro_referencia,
                         ge.fecha,
                         ge.hora,
                         ge.cod_usuario
                    from ge_snp_transferencias ge
                   where ge.cod_msj_swift = v_cod_msj_swift
                     and ge.fec_recepcion is null
                     and ge.nro_lote = v_nro_ref_externa;
            begin
               for reg in cu_nro_referencias loop
                  -- ACTUALIZA EL SWIFT POR ERROR
                  pas_snp.g_lugar := 'MTn96: Cancelacion de SWIFT por Error.';
                  update ge_snp_transferencias
                     set estado = 'E',
                         situacion = 'C'
                   where nro_referencia = reg.nro_referencia;
                  if reg.fecha is not null and
                     reg.hora is not null and
                     reg.cod_usuario is not null
                  then
                     -- REVERSA LA OPERACION RELACIONADA AL MENSAJE
                     pas_snp.pr_rev_ope_con_swift( reg.nro_referencia, 'Rev Automat. ERR MT '||v_cod_msj_swift|| ' - SNP' );
                     if pas_snp.fu_obt_cod_error <> 0 then
                        pas_snp.pr_ini_variables;
                     end if;
                  end if;
                  v_error := null;
                  --25/05 filtros para perfomance
                  if v_cod_msj_swift = 102 then
                     update ge_pag_proveedores
                        set estado = 'A'
                      where nro_referencia = reg.nro_referencia
                        and fec_pago= pag_cal.FU_OBT_FEC_ACTUAL(1)
                        and for_pago='I';
                  end if;
               end loop;
               v_asunto := vg_fecfor||'Cancelacion de la Mensajeria MT '||v_cod_msj_swift|| ' por Error - SNP.';
               v_txt_mail := v_error||chr(10)||'Mensajeria Bajo Valor Enviado con Error ' || v_txt_mail;
            exception
               when others then
                  raise;
            end;
         end if;
      EXCEPTION
         when pas_snp.ex_salir then
            pas_snp.pr_set_texto( pas_snp.g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            pas_snp.pr_ini_variables;
         when others then
            pas_snp.pr_set_texto( pas_snp.g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            pas_snp.pr_ini_variables;
      END;
   elsif v_cod_mensaje = 'MTn96/CANC'
     or (v_cod_mensaje = 'MTn96/STAT' and v_sub_tip_mt = 'CANC') then
     /*
      * MTn96/STAT CANC o MTn96/CANC
      * Marca como cancelado (estado = 'C'), Reversa el Movimiento.
      */
      BEGIN
        v_asunto := vg_fecfor||'Respuesta por Solicitud de Cancelacion';
        if v_sub_tip_mt != 'ERRC' then
           v_txt_mail := 'Se ha Procesado la Peticion de Cancelacion' || v_txt_mail;
           if v_cod_msj_swift in (103,202) then -- Alto Valor
              --Obtiene los datos del mensaje.
              pas_snp.pr_obt_mensaje( v_nro_ref_externa, 'N' );
              if pas_snp.fu_obt_cod_error = 0 then
                 pas_snp.g_lugar := 'MTn96: Intentando cancelar el SWIFT, ';
                 if not ( pas_snp.g_msj.estado = 'A' and pas_snp.g_msj.situacion = 'L' )
                   /*and ( pas_snp.g_fec_actual - pas_snp.g_dia_max_reversion ) <= pas_snp.g_msj.fec_valor*/
                 then
                    --CANCELA EL SWIFT SI NO EST¿ LIQUIDADO Y SI LA FECHA VALOR DEL MENSAJE
                    --SE ENCUENTRA DENTRO DE LO PERMITIDO SEG¿N PAR¿METRO DE CANTIDAD DE DIAS M¿XIMO PARA REVERSI¿N
                    pas_snp.g_msj.estado := 'C';
                    pas_snp.g_msj.situacion := 'E';
                    pas_snp.pr_set_transferencias ( pas_snp.g_msj );
                    if pas_snp.g_msj.fecha is not null and
                       pas_snp.g_msj.hora is not null and
                       pas_snp.g_msj.cod_usuario is not null
                    then
                       --REVERSA LA OPERACION RELACIONADA AL MENSAJE
                       pas_snp.pr_rev_ope_con_swift( v_nro_ref_externa, 'Rev. Automat. CANC. - SNP' );
                       -- Si la reversi¿n tiene ERRORES se adjunta el error en la mensajer¿a.
                       if pas_snp.fu_obt_cod_error <> 0 then
                          raise pas_snp.ex_salir;
                       end if;
                    end if;
                 else
                   pas_snp.g_cod_error:= 55;
                   pas_snp.g_msj_error:= pas_snp.g_lugar || 'Se intento reversar una transferencia ya liquidada o bien la fecha de la misma no permite su reversion';
                 end if;
                 v_txt_mail := v_txt_mail || chr(10) || chr(10) || 'Datos de la Transferencia Original: ' || chr(10) ||
                 'Nro. Cuenta    : ' || pas_snp.g_msj.nro_cta_pte_solicitante || chr(10) ||
                 'Nro. Referencia: ' || pas_snp.g_msj.nro_referencia || chr(10) ||
                 'Fecha Valor    : ' || to_char(pas_snp.g_msj.fec_valor,'DD/MM/YYYY') || chr(10) ||
                 'Tipo Operacion : ' || pas_snp.fu_obt_des_tip_operacion( pas_snp.g_msj.cod_msj_swift,
                                                                          pas_snp.g_msj.cod_tip_operacion,
                                                                          pas_snp.g_msj.cod_sub_tip_operacion) || chr(10) ||
                 'Moneda         : ' || pas_snp.g_msj.cod_moneda || chr(10) ||
                 'Monto          : ' || trim(to_char(pas_snp.g_msj.monto,'999,999,999,999,999.99'));
              else -- Tiene Errores
                 pas_snp.g_msj_error := v_error || ', ' || pas_snp.fu_obt_msj_error;
                 pas_snp.pr_set_texto( pas_snp.g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
                 pas_snp.pr_ini_variables;
              end if;
           elsif v_cod_msj_swift in (102, 104) then -- Bajo Valor
             declare
               cursor cu_msj_tra(p_nro_lote ge_snp_transferencias.nro_lote%type) is
                  select ge.nro_referencia
                    from ge_snp_transferencias ge
                   where ge.nro_lote = p_nro_lote;
             begin
               pas_snp.g_lugar := 'Intentando reversar operaciones en LP_PRO_CAN_MT102, ';
               for reg in cu_msj_tra(v_nro_ref_externa) loop
                  -- Obtiene los datos del mensaje.
                  pas_snp.pr_obt_mensaje( reg.nro_referencia, 'N' );
                  if pas_snp.fu_obt_cod_error = 0 then
                     pas_snp.g_lugar := 'MTn96: Intentando cancelar la transferencia '||reg.nro_referencia||', ';
                     if not ( pas_snp.g_msj.estado = 'A' and pas_snp.g_msj.situacion = 'L' )
                      /* and ( pas_snp.g_fec_actual - pas_snp.g_dia_max_reversion ) <= pas_snp.g_msj.fec_valor*/ then
                        --CANCELA EL SWIFT SI NO EST¿ LIQUIDADO Y SI LA FECHA VALOR DEL MENSAJE
                        --SE ENCUENTRA DENTRO DE LO PERMITIDO SEG¿N PAR¿METRO DE CANTIDAD DE DIAS M¿XIMO PARA REVERSI¿N
                        pas_snp.g_msj.estado := 'C';
                        pas_snp.pr_set_transferencias ( pas_snp.g_msj );
                        if pas_snp.g_msj.fecha is not null
                          and pas_snp.g_msj.hora is not null
                          and pas_snp.g_msj.cod_usuario is not null then
                            -- REVERSA LA OPERACION RELACIONADA AL MENSAJE
                            pas_snp.pr_rev_ope_con_swift( reg.nro_referencia, 'Rev. Automat. CANC MT102 - SNP' );
                            if pas_snp.fu_obt_cod_error <> 0 then
                               pas_snp.pr_ini_variables;
                            end if;
                        end if;
                        --25/05 PARA PERFOMANCE
                        if v_cod_msj_swift = 102 then
                           update ge_pag_proveedores
                              set estado = 'A'
                            where nro_referencia = reg.nro_referencia
                              and fec_pago= pag_cal.fu_obt_fec_actual(1)
                              and for_pago='I';
                        end if;
                     else
                       pas_snp.g_det_msj_error := 'La transferencia '||reg.nro_referencia||' se encuentra liquidada o bien la Fecha Valor no permite su reversion';
                     end if;
                  end if;
               end loop;
             exception
                when others then
                  raise;
             end;
           end if;
        end if;
      EXCEPTION
         when pas_snp.ex_salir then
            pas_snp.pr_set_texto( pas_snp.g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            pas_snp.pr_ini_variables;
         when others then
            pas_snp.pr_set_texto( pas_snp.g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            pas_snp.pr_ini_variables;
      END;
   end if;

   begin
      --Cancela el Mensaje Generado--
      rg_snp_tra.nro_referencia := v_nro_ref_externa;
      rg_snp_tra.estado := 'C';
      rg_snp_tra.situacion := 'C';
      pas_snp.pr_set_transferencias(rg_snp_tra);
      if pas_snp.fu_obt_cod_error <> 0 then
         --Si Tiene Error--
         null;
      end if;
      --Cancela la Operacion Temporal--
      pam_dep.PR_PRO_CAN_OPE_ENVIADO (v_nro_ref_externa);
      --------------------------------------------------
      --Actualizar Registro de Mensajes--
      v_msj_swift := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
      pas_snp.g_lugar :=  'Insertando en GE_SNP_MENSAJES, ';

      pas_snp.g_lugar :=  'Insertando MTn96, ';
      insert into ge_snp_mensajes ( nro_referencia,
                                    nro_ref_externa,
                                    cod_msj_swift,
                                    fec_valor,
                                    msj_swift,
                                    error,
                                    fec_recepcion,
                                    msj_swi_original)
                           values ( v_nro_referencia,
                                    v_nro_ref_externa,
                                    substr( p_mensaje, instr( p_mensaje, '{2:' ) + 4, 3 ),
                                    pas_snp.g_fec_actual,
                                    replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ),
                                    pas_snp.g_det_msj_error,
                                    sysdate,
                                    replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ));

        --Actualiza Archivo Recibido--
      v_cod_msj_swif_aux := 'MT'||substr( p_mensaje, instr( p_mensaje, '{2:' ) + 4, 3 );

      PAM_DEP.PR_OBT_DAT_MSJ_ACTUAL(v_cod_msj_swif_aux, 'E', v_nro_ref_externa, v_exi_msj_enviado, v_cod_ejecucion, v_nro_orden, v_cod_msj_env_bcp);
      if v_exi_msj_enviado = 'S' then
         v_hor_recepcion := TO_CHAR(SYSDATE,'HH24:MI:SS');
         PR_CON_ENV_AUTOMATICO('R', v_nro_ref_externa, v_hor_recepcion, v_cod_ejecucion, v_nro_orden, v_cod_msj_swif_aux, v_nro_referencia);
         if v_nro_orden = 2 then
            PR_VAL_RES_REC_BCP(v_msj_swift, 'EDE');
         end if;
      end IF;

   exception
      when dup_val_on_index then
         pas_snp.g_cod_error := 55;
         pas_snp.g_msj_error := 'Ya existen registros en GE_SNP_MENSAJES para el numero de Ref.Externa '|| v_nro_ref_externa ||'!';
         raise pas_snp.ex_salir;
      when others then
         pas_snp.g_cod_error := 55;
         pas_snp.g_msj_error := SQLERRM;
         raise pas_snp.ex_salir;
   end;

   /*
   || Env¿a Correo con los detalles de la mensajer¿a recibida
   */
   BEGIN
      if v_dir_correo is not null then
         if v_asunto is null then
            v_asunto := vg_fecfor||'Detalle de MT'||v_cod_mensaje||' recibido';
         end if;
         it_mail.mail( fug_obt_dir_correo,
                       v_dir_correo,
                       v_asunto,
                       v_txt_mail || chr(10) || chr(10) ||
                        'MT Recibido: ' || chr(10) ||
                       p_mensaje || chr(10) || chr(10) || 'Atentamente.'
                     );
      end if;
   EXCEPTION
     when others then
        NULL;
   END;

   if pas_snp.g_det_msj_error is NULL then
      return '00' || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Procesado OK';
   else
      return '00' || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Error ' || pas_snp.g_det_msj_error;
   end if;

EXCEPTION
   when pas_snp.ex_salir then
      return '99' || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Error ' || pas_snp.fu_obt_msj_error;
   when others then
      return '99' || '|' || v_cod_mensaje || '|' || SQLERRM;
END FU_PRO_MSJ_MTN96;

FUNCTION FU_PRO_MSJ_MT545  (P_MENSAJE          IN CLOB,
                            P_IND_MSJ_RECIBIDO IN VARCHAR2 DEFAULT 'S',
                            P_ENV_MAIL         IN VARCHAR2 DEFAULT 'S') RETURN VARCHAR2
is

   v_cod_mensaje      sb_snp_mensajes_tmp.cod_mensaje%type;
   v_nro_referencia   ge_snp_mensajes.nro_referencia%type;
   v_nro_ref_externa  ge_snp_mensajes.nro_referencia%type;
   v_dir_correo      ge_par_dinamicos.val_parametro%type := nvl( pam_dep.g_gru_dir_correo, pam_dep.g_err_dir_correo );
   v_txt_mail        varchar2(4000);
   v_asunto          varchar2(4000);
   v_msj_swift       varchar2(4000);
   v_msj_swi_original  clob := null;
   v_contador        number:=0;
   v_lugar varchar2(200);
   --Para marcar como recibido--
   v_hor_recepcion VARCHAR2(8);
   v_cod_ejecucion md_dep_msj_automaticos.cod_ejecucion%type;
   v_nro_orden     md_dep_msj_automaticos.nro_orden%type;
   v_cod_msj_swift sb_snp_mensajes.cod_mensaje%type;
   v_exi_msj_enviado varchar2(1);
   v_cod_msj_env_bcp sb_snp_tip_mensajes.cod_mensaje%type;

   cursor c_msj_temporal is
   select a.cod_mensaje,
     a.campo,
     a.valor,
     a.descripcion,
     a.err_formato,
     a.orden
   from sb_snp_mensajes_tmp a
   where a.campo not in ('CAB', 'PIE')
     and a.descripcion is not null
   order by orden;

begin

   select count(*)
   into v_contador
   from sb_snp_mensajes_tmp;

   if v_contador=0 then
      -- Se recuperar valores para la insercion en GE_SNP_MENSAJES cuando no está esquematizado.
      v_cod_mensaje := pao_pmt.fu_obt_cod_msj_swift( pao_pmt.fu_obt_linea(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), 1) );
      v_msj_swift := dbms_lob.substr(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ),200,1)||
                 pas_snp.fu_obt_salto||
                 '. . . .'||
                 pas_snp.fu_obt_salto||
                 '. . . .'||
                 pas_snp.fu_obt_salto||
                 '. . . .';
      v_msj_swi_original := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
      v_nro_referencia := PAM_DEP.fu_obt_val_cam_esp(v_msj_swift,':20C::SEME//');
      v_nro_ref_externa := PAM_DEP.fu_obt_val_cam_esp(v_msj_swift,':20C::RELA//');
      v_asunto := vg_fecfor||'Se recibió un Mensaje sin formato';
      v_txt_mail := 'Se recibió un MT con el siguiente detalle:' || chr(10) || chr(10) ||
               'Nro. Referencia     : ' || v_nro_referencia || chr(10) ||
               'Nro. Ref. Original  : ' || v_nro_ref_externa || chr(10) ||
               'Detalle del mensaje : ' || replace( dbms_lob.substr(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ),3000,1)
                          ||pas_snp.fu_obt_salto
                          ||'. . . .'
                          ||pas_snp.fu_obt_salto
                          ||'. . . .'
                          ||pas_snp.fu_obt_salto
                          ||'. . . .',
                          pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ) || chr(10) || chr(10) || chr(10) ||
               'Atentamente.';

   else
    for msj in c_msj_temporal loop
        --Creo la cabecera del mail
         v_asunto := vg_fecfor||'Mensajería '|| msj.cod_mensaje || ' Recibida' ||chr(10);
         v_cod_mensaje := msj.cod_mensaje;
         --Se concatena los datos disponibles para el envío del Mail.
         v_txt_mail := v_txt_mail || chr(10) ||
                    msj.descripcion || ': '||
                    msj.valor;
         --Se concatenan los errores de formato que pudieron ocurrir
         if msj.err_formato is not null then
            pas_snp.pr_set_texto( pas_snp.g_det_msj_error, msj.err_formato, pas_snp.fu_obt_salto );
         end if;
         v_nro_referencia := PAM_DEP.FU_OBT_VAL_CAM_ESP(p_mensaje,':20C::SEME//');
         v_nro_ref_externa := PAM_DEP.FU_OBT_VAL_CAM_ESP(p_mensaje,':20C::RELA//');
      end loop;
    v_cod_mensaje := pao_pmt.fu_obt_cod_msj_swift( pao_pmt.fu_obt_linea(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), 1) );
    v_msj_swift := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
    v_msj_swi_original := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
    v_txt_mail := v_txt_mail || chr(10) || chr(10) || 'MT Recibido: ' || chr(10) || v_msj_swift || chr(10) || chr(10) || 'Atentamente.';
   end if;

   begin
      v_nro_referencia := PAM_DEP.FU_OBT_VAL_CAM_ESP(v_msj_swift,':20C::SEME//');
      v_nro_ref_externa := PAM_DEP.FU_OBT_VAL_CAM_ESP(v_msj_swift,':20C::RELA//');

     insert into ge_snp_mensajes
          ( cod_msj_swift,
            nro_referencia,
            nro_ref_externa,
            fec_valor,
            msj_swift,
            msj_swi_original,
            error,
            fec_recepcion,
            situacion
          )
     values
          ( v_cod_mensaje,
            v_nro_referencia,
            v_nro_ref_externa,
            pas_snp.g_fec_actual,
            v_msj_swift,
            v_msj_swi_original,
            pas_snp.g_det_msj_error,
            case when p_ind_msj_recibido='S' then sysdate else NULL end,
            case when p_ind_msj_recibido='S' then 'R' else 'P' end
          );

      --Actualiza Archivo Recibido--
      v_cod_msj_swift := 'MT'||v_cod_mensaje;
      PAM_DEP.PR_OBT_DAT_MSJ_ACTUAL('MT541', 'E', v_nro_ref_externa, v_exi_msj_enviado, v_cod_ejecucion, v_nro_orden, v_cod_msj_env_bcp);
      if v_exi_msj_enviado = 'S' then
         v_hor_recepcion := TO_CHAR(SYSDATE,'HH24:MI:SS');
         PAM_DEP.PR_CON_ENV_AUTOMATICO('R', v_nro_ref_externa, v_hor_recepcion, v_cod_ejecucion, v_nro_orden,
                                       v_cod_msj_swift, v_nro_referencia);
         if v_nro_orden = 2 then
            PR_VAL_RES_REC_BCP(v_msj_swift, 'CDE');
            PAM_DEP.PR_FPD_REC_CON_AUT(v_nro_ref_externa);
         end if;
      end IF;

   exception
      when dup_val_on_index then
         pas_snp.g_cod_error := 55;
         pas_snp.g_msj_error := 'Ya existen registros en GE_SNP_MENSAJES para el número de Ref.Externa '|| v_nro_ref_externa ||'!';
         raise pas_snp.ex_salir;
      when others then
         pas_snp.g_cod_error := 55;
         pas_snp.g_msj_error := SQLERRM;
         raise pas_snp.ex_salir;
   end;

   /*
   || Envía Correo con los detalles de la mensajería recibida
   */
   BEGIN
      if p_env_mail = 'S' and v_dir_correo is not null then
         if v_asunto is null then
            v_asunto := vg_fecfor||'Detalle de '||v_cod_msj_swift||' recibido';
         end if;
         it_mail.mail( fug_obt_dir_correo,
                       v_dir_correo,
                       v_asunto,
                       v_txt_mail
                     );
      end if;
   EXCEPTION
     when others then
        NULL;
   END;

   if pas_snp.g_det_msj_error is NULL then
      return '00' ||v_lugar || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Procesado OK';
   else
      return '00' ||v_lugar || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Error ' || pas_snp.g_det_msj_error;
   end if;

EXCEPTION
   when pas_snp.ex_salir then
      return '99x' ||v_lugar || '|' || v_cod_mensaje || '|' || rpad(v_nro_ref_externa,20,'X') || ' - Error ' || pas_snp.fu_obt_msj_error;
   when others then
      return '99y' ||v_lugar || '|' || v_cod_mensaje || '|' || SQLERRM;
end  FU_PRO_MSJ_MT545;

FUNCTION FU_PRO_MSJ_MT548  (P_MENSAJE          IN CLOB,
                            P_IND_MSJ_RECIBIDO IN VARCHAR2 DEFAULT 'S',
                            P_ENV_MAIL         IN VARCHAR2 DEFAULT 'S') RETURN VARCHAR2
is

   v_cod_mensaje      sb_snp_mensajes_tmp.cod_mensaje%type;
   v_nro_referencia   ge_snp_mensajes.nro_referencia%type;
   v_nro_ref_externa  ge_snp_mensajes.nro_referencia%type;
   v_dir_correo      ge_par_dinamicos.val_parametro%type := nvl( pam_dep.g_gru_dir_correo, pam_dep.g_err_dir_correo );
   v_txt_mail        varchar2(4000);
   v_asunto          varchar2(4000);
   v_msj_swift       varchar2(4000);
   v_msj_swi_original  clob := null;
   v_contador      number:=0;
   v_lugar varchar2(200);

   --Para marcar como recibido--
   v_hor_recepcion VARCHAR2(8);
   v_cod_ejecucion md_dep_msj_automaticos.cod_ejecucion%type;
   v_nro_orden     md_dep_msj_automaticos.nro_orden%type;
   v_cod_msj_swift sb_snp_mensajes.cod_mensaje%type;
   v_exi_msj_enviado varchar2(1);
   v_cod_msj_env_bcp sb_snp_tip_mensajes.cod_mensaje%type;

   cursor c_msj_temporal is
   select a.cod_mensaje,
     a.campo,
     a.valor,
     a.descripcion,
     a.err_formato,
     a.orden
   from sb_snp_mensajes_tmp a
   where a.campo not in ('CAB', 'PIE')
     and a.descripcion is not null
   order by orden;

begin

   v_lugar := 'Pasa por 001';
   select count(*)
   into v_contador
   from sb_snp_mensajes_tmp;

   if v_contador=0 then
      v_lugar := 'Pasa por 100';
      -- Se recuperar valores para la insercion en GE_SNP_MENSAJES cuando no está esquematizado.
      v_cod_mensaje := pao_pmt.fu_obt_cod_msj_swift( pao_pmt.fu_obt_linea(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), 1) );
      v_msj_swift := dbms_lob.substr(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ),200,1)||
                   pas_snp.fu_obt_salto||
                   '. . . .'||
                   pas_snp.fu_obt_salto||
                   '. . . .'||
                   pas_snp.fu_obt_salto||
                   '. . . .';
      v_msj_swi_original := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
      v_nro_referencia := PAM_DEP.fu_obt_val_cam_esp(v_msj_swift,':20C::SEME//');
      v_nro_ref_externa := PAM_DEP.fu_obt_val_cam_esp(v_msj_swift,':20C::RELA//');
      v_asunto := vg_fecfor||'Se recibió un Mensaje sin formato';
      v_txt_mail := 'Se recibió un MT con el siguiente detalle:' || chr(10) || chr(10) ||
               'Nro. Referencia     : ' || v_nro_referencia || chr(10) ||
               'Nro. Ref. Original  : ' || v_nro_ref_externa || chr(10) ||
               'Detalle del mensaje : ' || replace( dbms_lob.substr(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ),3000,1)
                          ||pas_snp.fu_obt_salto
                          ||'. . . .'
                          ||pas_snp.fu_obt_salto
                          ||'. . . .'
                          ||pas_snp.fu_obt_salto
                          ||'. . . .',
                          pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ) || chr(10) || chr(10) || chr(10) ||
               'Atentamente.';

   else
      v_lugar := 'Pasa por 200';
      for msj in c_msj_temporal loop
          v_lugar := 'Pasa por 201';
          --Creo la cabecera del mail
           v_asunto := vg_fecfor||'Mensajería '|| msj.cod_mensaje || ' Recibida' ||chr(10);
           v_cod_mensaje := msj.cod_mensaje;
           v_lugar := 'Pasa por 202';
           --Se concatena los datos disponibles para el envío del Mail.
           v_txt_mail := v_txt_mail || chr(10) ||
                      msj.descripcion || ': '||
                      msj.valor;
           v_lugar := 'Pasa por 203';
           --Se concatenan los errores de formato que pudieron ocurrir
           if msj.err_formato is not null then
              v_lugar := 'Pasa por 204';
              pas_snp.pr_set_texto( pas_snp.g_det_msj_error, msj.err_formato, pas_snp.fu_obt_salto );
           end if;
      end loop;
      v_lugar := 'Pasa por 205';
      v_cod_mensaje := pao_pmt.fu_obt_cod_msj_swift( pao_pmt.fu_obt_linea(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), 1) );
      v_msj_swift := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
      v_lugar := 'Pasa por 207';
      v_msj_swi_original := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
      v_txt_mail := v_txt_mail || chr(10) || chr(10) || 'MT Recibido: ' || chr(10) || v_msj_swift || chr(10) || chr(10) || 'Atentamente.';
   end if;

   begin
      v_lugar := 'Pasa por 300';
      v_nro_referencia := trim(PAM_DEP.FU_OBT_VAL_CAM_ESP(v_msj_swift,':20C::SEME//'));
      v_nro_ref_externa := trim(PAM_DEP.FU_OBT_VAL_CAM_ESP(v_msj_swift,':20C::RELA//'));

      ---------------------------------------------------
      v_lugar := 'Pasa por 600';
      insert into ge_snp_mensajes
          ( cod_msj_swift,
            nro_referencia,
            nro_ref_externa,
            fec_valor,
            msj_swift,
            msj_swi_original,
            error,
            fec_recepcion,
            situacion
          )
     values
          ( v_cod_mensaje,
            v_nro_referencia,
            v_nro_ref_externa,
            pas_snp.g_fec_actual,
            v_msj_swift,
            v_msj_swi_original,
            pas_snp.g_det_msj_error,
            case when p_ind_msj_recibido='S' then sysdate else NULL end,
            case when p_ind_msj_recibido='S' then 'R' else 'P' end
          );

      --Actualiza archivo enviado--
      v_cod_msj_swift := 'MT'||v_cod_mensaje;
      PAM_DEP.PR_OBT_DAT_MSJ_ACTUAL('MT541', 'E', v_nro_ref_externa, v_exi_msj_enviado, v_cod_ejecucion, v_nro_orden, v_cod_msj_env_bcp);
      if v_exi_msj_enviado = 'S' then
         v_hor_recepcion := TO_CHAR(SYSDATE,'HH24:MI:SS');
         --Cancela la Operacion Temporal--
         pam_dep.PR_PRO_CAN_OPE_ENVIADO(v_nro_ref_externa);
         PAM_DEP.PR_CON_ENV_AUTOMATICO('R', v_nro_ref_externa, v_hor_recepcion, v_cod_ejecucion, v_nro_orden,
                                       v_cod_msj_swift, v_nro_referencia);
         if v_nro_orden = 2 then
            PR_VAL_RES_REC_BCP(v_msj_swift, 'EDE');
         end if;
      end IF;

   exception
      when dup_val_on_index then
         pas_snp.g_cod_error := 55;
         pas_snp.g_msj_error := 'Ya existen registros en GE_SNP_MENSAJES para el número de Ref.Externa '|| v_nro_ref_externa ||'!';
         raise pas_snp.ex_salir;
      when others then
         pas_snp.g_cod_error := 55;
         pas_snp.g_msj_error := SQLERRM;
         raise pas_snp.ex_salir;
   end;

   /*
   || Envía Correo con los detalles de la mensajería recibida
   */
   BEGIN
      if p_env_mail = 'S' and v_dir_correo is not null then
         if v_asunto is null then
            v_asunto := vg_fecfor||'Detalle de MT'||v_cod_mensaje||' recibido';
         end if;
         it_mail.mail( fug_obt_dir_correo,
                       v_dir_correo,
                       v_asunto,
                       v_txt_mail
                     );
      end if;
   EXCEPTION
     when others then
        NULL;
   END;

   if pas_snp.g_det_msj_error is NULL then
      return '00'||v_lugar || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Procesado OK';
   else
      return '00'||v_lugar || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Error ' || pas_snp.g_det_msj_error;
   end if;

EXCEPTION
   when pas_snp.ex_salir then
      return '99' ||v_lugar ||'-'||v_nro_ref_externa ||'|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Error ' || pas_snp.fu_obt_msj_error;
   when others then
      return '99' ||v_lugar ||'-'||v_nro_ref_externa ||'|' || v_cod_mensaje || '|' || SQLERRM;
end  FU_PRO_MSJ_MT548;

FUNCTION FU_PRO_MSJ_MT543  (P_MENSAJE          IN CLOB,
                            P_IND_MSJ_RECIBIDO IN VARCHAR2 DEFAULT 'S',
                            P_ENV_MAIL         IN VARCHAR2 DEFAULT 'S') RETURN VARCHAR2
is

   v_cod_mensaje      sb_snp_mensajes_tmp.cod_mensaje%type;
   v_nro_referencia   ge_snp_mensajes.nro_referencia%type;
   v_nro_ref_externa  ge_snp_mensajes.nro_referencia%type;
   v_dir_correo      ge_par_dinamicos.val_parametro%type := nvl( pam_dep.g_gru_dir_correo, pam_dep.g_err_dir_correo );
   v_txt_mail        varchar2(4000);
   v_asunto          varchar2(4000);
   v_msj_swift       varchar2(4000);
   v_msj_swi_original  clob := null;
   v_contador      number:=0;
   v_lugar varchar2(200);

   cursor c_msj_temporal is
   select a.cod_mensaje,
     a.campo,
     a.valor,
     a.descripcion,
     a.err_formato,
     a.orden
   from sb_snp_mensajes_tmp a
   where a.campo not in ('CAB', 'PIE')
     and a.descripcion is not null
   order by orden;

begin

   v_lugar := 'Pasa por 001';
   select count(*)
   into v_contador
   from sb_snp_mensajes_tmp;

   if v_contador = 0 then
      v_lugar := 'Pasa por 100';
      -- Se recuperar valores para la insercion en GE_SNP_MENSAJES cuando no está esquematizado.
      v_cod_mensaje := pao_pmt.fu_obt_cod_msj_swift( pao_pmt.fu_obt_linea(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), 1) );
      v_msj_swift := dbms_lob.substr(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ),200,1)||
                   pas_snp.fu_obt_salto||
                   '. . . .'||
                   pas_snp.fu_obt_salto||
                   '. . . .'||
                   pas_snp.fu_obt_salto||
                   '. . . .';
      v_msj_swi_original := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
      v_nro_referencia := PAM_DEP.fu_obt_val_cam_esp(v_msj_swift,':20C::SEME//');
      v_nro_ref_externa := PAM_DEP.fu_obt_val_cam_esp(v_msj_swift,':20C::RELA//');
      v_asunto := vg_fecfor||'Se recibió un Mensaje sin formato';
      v_txt_mail := 'Se recibió un MT con el siguiente detalle:' || chr(10) || chr(10) ||
               'Nro. Referencia     : ' || v_nro_referencia || chr(10) ||
               'Nro. Ref. Original  : ' || v_nro_ref_externa || chr(10) ||
               'Detalle del mensaje : ' || replace( dbms_lob.substr(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ),3000,1)
                          ||pas_snp.fu_obt_salto
                          ||'. . . .'
                          ||pas_snp.fu_obt_salto
                          ||'. . . .'
                          ||pas_snp.fu_obt_salto
                          ||'. . . .',
                          pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ) || chr(10) || chr(10) || chr(10) ||
               'Atentamente.';

   else
      v_lugar := 'Pasa por 200';
      for msj in c_msj_temporal loop
          v_lugar := 'Pasa por 201';
          --Creo la cabecera del mail
           v_asunto := vg_fecfor||'Mensajería '|| msj.cod_mensaje || ' Recibida' ||chr(10);
           v_cod_mensaje := msj.cod_mensaje;
           v_lugar := 'Pasa por 202';
           --Se concatena los datos disponibles para el envío del Mail.
           v_txt_mail := v_txt_mail || chr(10) ||
                      msj.descripcion || ': '||
                      msj.valor;
           v_lugar := 'Pasa por 203';
           --Se concatenan los errores de formato que pudieron ocurrir
           /*if msj.err_formato is not null then
              v_lugar := 'Pasa por 204';
              pas_snp.pr_set_texto( pas_snp.g_det_msj_error, msj.err_formato, pas_snp.fu_obt_salto );
           end if;*/
      end loop;
      v_lugar := 'Pasa por 205';
      v_cod_mensaje := pao_pmt.fu_obt_cod_msj_swift( pao_pmt.fu_obt_linea(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), 1) );
      v_msj_swift := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
      v_lugar := 'Pasa por 207';
      v_msj_swi_original := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
      v_txt_mail := v_txt_mail || chr(10) || chr(10) || 'MT Recibido: ' || chr(10) || v_msj_swift || chr(10) || chr(10) || 'Atentamente.';
   end if;

   begin
      v_lugar := 'Pasa por 300';
      v_nro_referencia := trim(PAM_DEP.FU_OBT_VAL_CAM_ESP(v_msj_swift,':20C::SEME//'));
      v_nro_ref_externa := trim(PAM_DEP.FU_OBT_VAL_CAM_ESP(v_msj_swift,':20C::RELA//'));

     /* v_lugar := 'Pasa por 400';
      --Actualizar Mensajeria--
      --rg_snp_tra := null;
      v_lugar := 'Pasa por 401';
      rg_snp_tra.nro_referencia := v_nro_ref_externa;
      v_lugar := 'Pasa por 402';
      rg_snp_tra.estado := 'C';
      v_lugar := 'Pasa por 403';
      rg_snp_tra.situacion := 'C';
      v_lugar := 'Pasa por 404';

      v_lugar := 'Pasa por 500';
      pas_snp.pr_set_transferencias(rg_snp_tra);
      if pas_snp.fu_obt_cod_error <> 0 then
         --Si Tiene Error--
         null;
      end if;*/
      ------

      v_lugar := 'Pasa por 600';
      insert into ge_snp_mensajes
          ( cod_msj_swift,
            nro_referencia,
            nro_ref_externa,
            fec_valor,
            msj_swift,
            msj_swi_original,
            error,
            fec_recepcion,
            situacion
          )
     values
          ( v_cod_mensaje,
            v_nro_referencia,
            v_nro_ref_externa,
            pas_snp.g_fec_actual,
            v_msj_swift,
            v_msj_swi_original,
            pas_snp.g_det_msj_error,
            case when p_ind_msj_recibido='S' then sysdate else NULL end,
            case when p_ind_msj_recibido='S' then 'R' else 'P' end
          );
   exception
      when dup_val_on_index then
         pas_snp.g_cod_error := 55;
         pas_snp.g_msj_error := 'Ya existen registros en GE_SNP_MENSAJES para el número de Ref.Externa '|| v_nro_ref_externa ||'!';
         raise pas_snp.ex_salir;
      when others then
         pas_snp.g_cod_error := 55;
         pas_snp.g_msj_error := SQLERRM;
         raise pas_snp.ex_salir;
   end;

   /*
   || Envía Correo con los detalles de la mensajería recibida
   */
   BEGIN
      if p_env_mail = 'S' and v_dir_correo is not null then
         if v_asunto is null then
            v_asunto := vg_fecfor||'Detalle de MT'||v_cod_mensaje||' recibido';
         end if;
         it_mail.mail( fug_obt_dir_correo,
                       v_dir_correo,
                       v_asunto,
                       v_txt_mail
                     );
      end if;
   EXCEPTION
     when others then
        NULL;
   END;

   if pas_snp.g_det_msj_error is NULL then
      return '00'||v_lugar || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Procesado OK';
   else
      return '00'||v_lugar || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Error ' || pas_snp.g_det_msj_error;
   end if;

EXCEPTION
   when pas_snp.ex_salir then
      return '99' ||v_lugar ||'-'||v_nro_ref_externa ||'|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Error ' || pas_snp.fu_obt_msj_error;
   when others then
      return '99' ||v_lugar ||'-'||v_nro_ref_externa ||'|' || v_cod_mensaje || '|' || SQLERRM;
end  FU_PRO_MSJ_MT543;

FUNCTION FU_PRO_MSJ_MT547  (P_MENSAJE          IN CLOB,
                            P_IND_MSJ_RECIBIDO IN VARCHAR2 DEFAULT 'S',
                            P_ENV_MAIL         IN VARCHAR2 DEFAULT 'S') RETURN VARCHAR2
is

   v_cod_mensaje      sb_snp_mensajes_tmp.cod_mensaje%type;
   v_nro_referencia   ge_snp_mensajes.nro_referencia%type;
   v_nro_ref_externa  ge_snp_mensajes.nro_referencia%type;
   v_dir_correo      ge_par_dinamicos.val_parametro%type := nvl( pam_dep.g_gru_dir_correo, pam_dep.g_err_dir_correo );
   v_txt_mail        varchar2(4000);
   v_asunto          varchar2(4000);
   v_msj_swift       varchar2(4000);
   v_msj_swi_original  clob := null;
   v_contador      number:=0;
   v_lugar varchar2(200);

   cursor c_msj_temporal is
   select a.cod_mensaje,
     a.campo,
     a.valor,
     a.descripcion,
     a.err_formato,
     a.orden
   from sb_snp_mensajes_tmp a
   where a.campo not in ('CAB', 'PIE')
     and a.descripcion is not null
   order by orden;

begin

   v_lugar := 'Pasa por 001';
   select count(*)
   into v_contador
   from sb_snp_mensajes_tmp;

   if v_contador=0 then
      v_lugar := 'Pasa por 100';
      -- Se recuperar valores para la insercion en GE_SNP_MENSAJES cuando no está esquematizado.
      v_cod_mensaje := pao_pmt.fu_obt_cod_msj_swift( pao_pmt.fu_obt_linea(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), 1) );
      v_msj_swift := dbms_lob.substr(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ),200,1)||
                   pas_snp.fu_obt_salto||
                   '. . . .'||
                   pas_snp.fu_obt_salto||
                   '. . . .'||
                   pas_snp.fu_obt_salto||
                   '. . . .';
      v_msj_swi_original := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
      v_nro_referencia := PAM_DEP.fu_obt_val_cam_esp(v_msj_swift,':20C::SEME//');
      v_nro_ref_externa := PAM_DEP.fu_obt_val_cam_esp(v_msj_swift,':20C::RELA//');
      v_asunto := vg_fecfor||'Se recibió un Mensaje sin formato';
      v_txt_mail := 'Se recibió un MT con el siguiente detalle:' || chr(10) || chr(10) ||
               'Nro. Referencia     : ' || v_nro_referencia || chr(10) ||
               'Nro. Ref. Original  : ' || v_nro_ref_externa || chr(10) ||
               'Detalle del mensaje : ' || replace( dbms_lob.substr(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ),3000,1)
                          ||pas_snp.fu_obt_salto
                          ||'. . . .'
                          ||pas_snp.fu_obt_salto
                          ||'. . . .'
                          ||pas_snp.fu_obt_salto
                          ||'. . . .',
                          pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ) || chr(10) || chr(10) || chr(10) ||
               'Atentamente.';

   else
      v_lugar := 'Pasa por 200';
      for msj in c_msj_temporal loop
          v_lugar := 'Pasa por 201';
          --Creo la cabecera del mail
           v_asunto := vg_fecfor||'Mensajería '|| msj.cod_mensaje || ' Recibida' ||chr(10);
           v_cod_mensaje := msj.cod_mensaje;
           v_lugar := 'Pasa por 202';
           --Se concatena los datos disponibles para el envío del Mail.
           v_txt_mail := v_txt_mail || chr(10) ||
                      msj.descripcion || ': '||
                      msj.valor;
           v_lugar := 'Pasa por 203';
           --Se concatenan los errores de formato que pudieron ocurrir
           /*if msj.err_formato is not null then
              v_lugar := 'Pasa por 204';
              pas_snp.pr_set_texto( pas_snp.g_det_msj_error, msj.err_formato, pas_snp.fu_obt_salto );
           end if;*/
      end loop;
      v_lugar := 'Pasa por 205';
      v_cod_mensaje := pao_pmt.fu_obt_cod_msj_swift( pao_pmt.fu_obt_linea(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), 1) );
      v_msj_swift := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
      v_lugar := 'Pasa por 207';
      v_msj_swi_original := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
      v_txt_mail := v_txt_mail || chr(10) || chr(10) || 'MT Recibido: ' || chr(10) || v_msj_swift || chr(10) || chr(10) || 'Atentamente.';
   end if;

   begin
      v_lugar := 'Pasa por 300';
      v_nro_referencia := trim(PAM_DEP.FU_OBT_VAL_CAM_ESP(v_msj_swift,':20C::SEME//'));
      v_nro_ref_externa := trim(PAM_DEP.FU_OBT_VAL_CAM_ESP(v_msj_swift,':20C::RELA//'));

      v_lugar := 'Pasa por 600';
      insert into ge_snp_mensajes
          ( cod_msj_swift,
            nro_referencia,
            nro_ref_externa,
            fec_valor,
            msj_swift,
            msj_swi_original,
            error,
            fec_recepcion,
            situacion
          )
     values
          ( v_cod_mensaje,
            v_nro_referencia,
            v_nro_ref_externa,
            pas_snp.g_fec_actual,
            v_msj_swift,
            v_msj_swi_original,
            pas_snp.g_det_msj_error,
            case when p_ind_msj_recibido='S' then sysdate else NULL end,
            case when p_ind_msj_recibido='S' then 'R' else 'P' end
          );
   exception
      when dup_val_on_index then
         pas_snp.g_cod_error := 55;
         pas_snp.g_msj_error := 'Ya existen registros en GE_SNP_MENSAJES para el número de Ref.Externa '|| v_nro_ref_externa ||'!';
         raise pas_snp.ex_salir;
      when others then
         pas_snp.g_cod_error := 55;
         pas_snp.g_msj_error := SQLERRM;
         raise pas_snp.ex_salir;
   end;

   /*
   || Envía Correo con los detalles de la mensajería recibida
   */
   BEGIN
      if p_env_mail = 'S' and v_dir_correo is not null then
         if v_asunto is null then
            v_asunto := vg_fecfor||'Detalle de MT'||v_cod_mensaje||' recibido';
         end if;
         it_mail.mail( fug_obt_dir_correo,
                       v_dir_correo,
                       v_asunto,
                       v_txt_mail
                     );
      end if;
   EXCEPTION
     when others then
        NULL;
   END;

   if pas_snp.g_det_msj_error is NULL then
      return '00'||v_lugar || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Procesado OK';
   else
      return '00'||v_lugar || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Error ' || pas_snp.g_det_msj_error;
   end if;

EXCEPTION
   when pas_snp.ex_salir then
      return '99' ||v_lugar ||'-'||v_nro_ref_externa ||'|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Error ' || pas_snp.fu_obt_msj_error;
   when others then
      return '99' ||v_lugar ||'-'||v_nro_ref_externa ||'|' || v_cod_mensaje || '|' || SQLERRM;
end  FU_PRO_MSJ_MT547;

PROCEDURE PR_PRO_CAN_OPE_ENVIADO(P_NRO_REFERENCIA IN VARCHAR2) IS
  rg_snp_tra        pas_snp.rg_msj;
  v_val_numerico    varchar2(1);
BEGIN
  --Cancela la Mensajaria--
  v_val_numerico := fug_val_es_numerico(P_NRO_REFERENCIA);
  if v_val_numerico = 'S' then --Es una cancelacion por una MT541 enviada--
     rg_snp_tra := null;
     rg_snp_tra.nro_referencia := P_NRO_REFERENCIA;
     rg_snp_tra.estado := 'C';
     rg_snp_tra.situacion := 'C';
     pas_snp.pr_set_transferencias(rg_snp_tra);
     if pas_snp.fu_obt_cod_error <> 0 then
        --Hay error--
        raise pas_snp.ex_salir;
     end if;

      --Cancela la Operacion Temporal--
     update md_dep_cta_documentos y
        set y.estado = 'C' --Cancela la Operacion por Recibir MT de error--
      where y.nro_referencia = P_NRO_REFERENCIA;
  end if;
END;

PROCEDURE PR_VAL_APE_MOD_DEPO(p_des_periodo in varchar2,
                              p_cod_per_actualizado in number) is
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  V_COD_PER_INI_FPD md_dep_horarios.cod_periodo%type;
  V_COD_PER_FIN_FPD md_dep_horarios.cod_periodo%type;
  V_COD_PER_INI_DIA md_dep_horarios.cod_periodo%type;
  V_COD_PER_FIN_DIA md_dep_horarios.cod_periodo%type;
  V_IND_ENV_AUT_FPD ge_par_dinamicos.val_parametro%type;
  v_fec_minima date;
  v_can_dia_pro_aut number(6);
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  --Inicio Registro del Log--
  V_LUG_PRO_LOC := 'PR_VAL_MOD_BCP_DEPO';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
  -------------------------
  V_COD_PER_INI_FPD := to_number(fug_obt_pardinamico('DEP_AUT_INI_FPD_OPE'));
  V_COD_PER_FIN_FPD := to_number(fug_obt_pardinamico('DEP_AUT_FIN_FPD_OPE'));
  V_COD_PER_INI_DIA := to_number(fug_obt_pardinamico('DEP_AUT_INI_DIA_OPE'));
  V_COD_PER_FIN_DIA := to_number(fug_obt_pardinamico('DEP_AUT_FIN_DIA_OPE'));
  if p_cod_per_actualizado = V_COD_PER_INI_FPD then
     --Verificar Parametro si envio Automatico esta en S=SI--
     V_IND_ENV_AUT_FPD := fug_obt_pardinamico('DEP_AUT_ENV_AUT_OPE');
     if nvl(V_IND_ENV_AUT_FPD,'N') = 'S' then
        PAM_DEP.PR_FPD_INI_OPE_AUT;
        --SPI si el parametro esta habilitado sel realiza la colocacion desde la cuenta SPI
        if fug_obt_pardinamico('SPI_HAB_DEPO') = 'S' then
           PAM_DEP.PR_FPD_INI_OPE_AUT('SPI');
        end if;
     end if;
  elsif p_cod_per_actualizado = V_COD_PER_FIN_FPD then
     update md_dep_horarios a
        set a.estado = 'C' --Cierra FPD cuando recibe modulo siguiente indicador--
      where a.cod_periodo = V_COD_PER_INI_FPD;
  elsif p_cod_per_actualizado = V_COD_PER_INI_DIA then
     update md_dep_horarios a
        set a.estado = 'C' --Cierra Fin del Dia -  Queda Cerrado (Ver Circular BCP)--
      where a.cod_periodo = V_COD_PER_FIN_DIA;
  elsif p_cod_per_actualizado = V_COD_PER_FIN_DIA then
     --Cierra todos los modulos, menos el del Cierre y Depp ya Cerrado--
     update md_dep_horarios a
        set a.estado = 'C' --Cierra Todos los Modulos menos Fin del Dia - Queda Activo--
      where a.cod_periodo <> p_cod_per_actualizado;

     --Elimina Registros de Procesos Automaticos--
     v_can_dia_pro_aut := to_number(fug_obt_pardinamico('DEP_AUT_CAN_DLO_OPE'));
     select min(a.fecha)
       into v_fec_minima
       from ge_pro_automaticos_det a;
     if ((v_fec_minima is not null) and ((vg_fecha - v_fec_minima) > v_can_dia_pro_aut)) then
        delete from ge_pro_automaticos_det x
         where x.fecha < (vg_fecha - v_can_dia_pro_aut);
     end if;
  end if;
  -------------------------
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC, vg_nro_referencia,NULL,NULL,NULL,vg_nro_cuenta,vg_des_operacion);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC||'-'||p_des_periodo, vg_nro_cuenta,vg_des_operacion);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||'-'||p_des_periodo||' - '||SQLERRM);
END PR_VAL_APE_MOD_DEPO;

PROCEDURE PR_GEN_ARC_SWI_SERV ( p_mensaje in long ) IS
  v_resp     long;
  v_ok       varchar2(1) := 'N';
  v_lugar    varchar2(2000);
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
BEGIN
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'PR_GEN_ARC_SWI_SERV';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);

  --Proceso de Envio--
   /*
   || Envía la mensajería en batch al socket
   */

   /*Inicializa la aplicacion y el modulo*/
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;

   --v_lugar := 'Conect al socket, '||pas_snp.g_servidor||'-'||pam_dep.g_pue_con_depo;
   -- Envia el mensaje al servidor
   --v_ok := fue_env_tcp_mensajes(p_servidor   => pas_snp.g_servidor,      --direccion ip del servidor
                               /* p_puerto     => pam_dep.g_pue_con_depo,  --nro. de puerto
                                p_tie_espera => vg_tie_espera, --pas_snp.g_tie_espera, --tiempo de espera en segundos
                                p_mensaje    => pas_snp.fu_con_mensaje(p_mensaje), --mensaje a enviar
                                p_respuesta  => v_resp                   --valor de retorno
                               );*/
   if v_ok != 'S' THEN
      -- Hubo problema en el envio
      pas_snp.g_cod_error := 36;
      pas_snp.g_msj_error := v_lugar || ' error durante la conexion: ' || substr( v_resp,1,1000 );
      PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, substr( v_resp,1,2000 ), SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
      raise_application_error(-20001, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error );
   end if;

   --Fin Registro del Log--
   V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
   PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC, vg_nro_referencia,NULL,substr( v_resp,1,2000 ),NULL,vg_nro_cuenta,vg_des_operacion);
   PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

EXCEPTION
  when others then
    if sqlcode <= -20000 then
       PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
       raise;
    else
       pas_snp.g_cod_error := 36;
       pas_snp.g_msj_error := 'Error en PAS_SNP.PR_GEN_ARC_SWI_SERV: ' || v_lugar || sqlerrm;
       PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, substr( v_resp,1,2000 ), SQLERRM||'-'||V_LUG_PRO_LOC);
       raise_application_error ( -20001, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error );
    end if;
END;

PROCEDURE PR_GEN_MOV_DES_COL (P_NRO_REFERENCIA IN VARCHAR2) IS
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  v_cta_inicial  ge_snp_transferencias.nro_cta_pte_solicitante%type;
BEGIN
  --Inicio Registro del Log--
  V_LUG_PRO_LOC  := 'PR_GEN_MOV_DES_COL';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
  --Generar Desembolso--
  vg_mto_desembolsar := vg_mto_operacion;
  vg_hora := fug_obt_hor_disponible(vg_fecha,vg_hora,user,vg_es_nocturno);
  vg_mto_garantia := 0;
  vg_nro_secuencia := 0;
  pam_doc.pr_com_documentos(vg_nro_cuenta, vg_mto_desembolsar, vg_cod_ofi_ope,
                            vg_mto_garantia, vg_fecha,
                            vg_hora, vg_nro_secuencia);
  --SPI Obtener cuenta de origen
  v_cta_inicial:= fu_obt_cta_bancaria(p_nro_referencia, '541');
  /*if v_cta_inicial = g_cta_ban_spi then
    vg_ref_cre_ope := vg_ref_cre_spi;
  end if;   */       

  --Generar Movimientos--
  vg_cotizacion := null;
  vg_cod_rubro  := vg_ref_cre_ope;
  if vg_cod_rubro is not null then
     r_gmovi.cod_usuario := user;
     r_gmovi.hora        := vg_hora;
     r_gmovi.fecha       := vg_fecha;
     -- Aumento la secuencia
     vg_nro_secuencia        := vg_nro_secuencia + 1;
     r_gmovi.nro_secuencia   := vg_nro_secuencia;     --
     r_gmovi.cod_modulo      := vg_cod_modulo;
     r_gmovi.cod_modalidad   := vg_cod_mad_ope;
     r_gmovi.cod_oficina     := vg_cod_ofi_ope;
     r_gmovi.cod_moneda      := vg_cod_moneda;
     r_gmovi.fec_valor       := vg_fecha;
     r_gmovi.cod_tra_padre   := 101;
     r_gmovi.cod_mod_padre   := vg_cod_modulo;
     r_gmovi.cod_mad_padre   := vg_cod_mad_ope;
     r_gmovi.cod_transaccion := 741;
     r_gmovi.monto           := vg_mto_desembolsar;
     r_gmovi.nro_documento   := vg_nro_cuenta;
     r_gmovi.cod_ofi_origen  := vg_cod_ofi_ope;
     r_gmovi.emi_aviso       := 'N';
     r_gmovi.concepto        := 'Compra Documento ' ||vg_nro_cuenta;
     r_gmovi.estado          := 'N';
     r_gmovi.reversado       := 'N';
     r_gmovi.cod_rubro       := vg_cod_rubro;
     r_gmovi.nro_cuenta      := null;
     r_gmovi.tip_mov_rubro   := 'C';
     r_gmovi.cotizacion      := vg_cotizacion;
     r_gmovi.mto_equ_local   := round(r_gmovi.monto * vg_cotizacion);
     PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,vg_es_nocturno);
  end if;

  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC, vg_nro_referencia,NULL,NULL,NULL,vg_nro_cuenta,vg_des_operacion);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END;

PROCEDURE PR_GEN_SNP_MENSAJES ( p_mensaje in long ) IS
  rg_ge_snp_trans       pas_snp.rg_msj;
  BEGIN
    NULL;
    rg_ge_snp_trans.nro_referencia        := vg_nro_referencia;
    rg_ge_snp_trans.cod_modulo            := pas_snp.fu_obt_cod_mod_padre;
    rg_ge_snp_trans.cod_modalidad         := pas_snp.fu_obt_cod_mad_padre;
    rg_ge_snp_trans.cod_oficina           := vg_cod_ofi_ope;
    rg_ge_snp_trans.cod_msj_swift         := vg_cod_msj_swift;
    if vg_cta_origen = 'SPI' then
      rg_ge_snp_trans.cod_tip_operacion     := '031';
      rg_ge_snp_trans.cod_sub_tip_operacion := '001'; 
    else
      rg_ge_snp_trans.cod_tip_operacion     := '001';
      rg_ge_snp_trans.cod_sub_tip_operacion := '001';
    end if;
    ---
    rg_ge_snp_trans.msj_swift             := p_mensaje;
    rg_ge_snp_trans.fec_valor             := vg_fecha;
    rg_ge_snp_trans.fec_ingreso           := vg_fecha;
    rg_ge_snp_trans.cod_moneda            := vg_cod_moneda;
    rg_ge_snp_trans.monto                 := vg_mto_operacion;
    -----
    rg_ge_snp_trans.cod_per_solicitante   := vg_cod_per_entidad;
    rg_ge_snp_trans.nom_solicitante       := fue_obt_nom_persona(vg_cod_per_entidad);
    rg_ge_snp_trans.dir_solicitante       := fue_obt_dir_principa(vg_cod_per_entidad);
    rg_ge_snp_trans.cod_swi_pte_solicitante := vg_bic_entidad;
    rg_ge_snp_trans.nro_cta_pte_solicitante := vg_cta_ban_entidad;
    rg_ge_snp_trans.cod_per_beneficiario    := vg_cod_per_ope;
    rg_ge_snp_trans.nom_beneficiario        := fue_obt_nom_persona(vg_cod_per_ope);
    rg_ge_snp_trans.dir_beneficiario        := fue_obt_dir_principa(vg_cod_per_ope);
    -----
    rg_ge_snp_trans.nro_cta_pte_beneficiario := vg_cta_ban_beneficiario;
    rg_ge_snp_trans.cod_swi_pte_beneficiario := vg_bic_beneficiario;
    rg_ge_snp_trans.concepto    := 'Trx.BCP Ref: '||vg_nro_referencia;
    rg_ge_snp_trans.OBSERVACION := 'FPD BBVA Diario';
    rg_ge_snp_trans.IND_VALOR   := 'S';
    rg_ge_snp_trans.SITUACION   := 'V'; --Enviado al BCP--
    rg_ge_snp_trans.ESTADO      := 'A'; --Aprobado--
    -----
    rg_ge_snp_trans.PRIORIDAD      := 20;
    rg_ge_snp_trans.TIP_MENSAJE    := 'CRED';
    rg_ge_snp_trans.ORIGEN         := 'I';
    rg_ge_snp_trans.PLATAFORMA     := 'X';
    rg_ge_snp_trans.INDEMNIZADO    := 'N';
    rg_ge_snp_trans.COD_TRA_PADRE  := 101;

    --Insertar la Transferencia--
    pas_snp.pr_ins_transferencias(rg_ge_snp_trans);

  END;

PROCEDURE PR_ENV_ARC_DEP_BCP(P_COD_EJECUCION IN VARCHAR2, P_NRO_CTA IN VARCHAR2 DEFAULT NULL) IS
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
  V_NRO_REF_SOLICITUD GE_SNP_MENSAJES.NRO_REFERENCIA%TYPE;
  --Para marcar el envio--
  v_hor_envio VARCHAR2(8);
  v_cod_ejecucion md_dep_msj_automaticos.cod_ejecucion%type;
  v_nro_orden     md_dep_msj_automaticos.nro_orden%type;
  v_cod_msj_swift sb_snp_mensajes.cod_mensaje%type;
  v_exi_msj_enviado varchar2(1);
  v_cod_msj_env_bcp sb_snp_tip_mensajes.cod_mensaje%type;
BEGIN
  --Variables Principales--
  vg_nro_orden    := 0;

  --Inicio Registro del Log--
  V_LUG_PRO_LOC := 'PR_ENV_ARC_DEP_BCP';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);
  
  --SPI verificar antes de cargar los parametros iniciales
  /*if nvl(p_nro_cta,'X') = g_cta_ban_spi then
    vg_cta_origen:= 'SPI';
  end if;*/

  --Proceso Principal--
  PAM_DEP.PR_CAR_VAR_PARAMETROS;

    
  PAM_DEP.PR_CAL_BCP_DEPOSITO(P_COD_EJECUCION);
  if vg_mto_operacion > 0 then -- solo si es mayor a 0
     PAM_DEP.PR_CAL_BCP_INTERES;
     PAM_DEP.PR_INS_OPE_BCP_TMP;
     PAM_DEP.PR_GEN_MSJ_SWI_MT541(V_NRO_REF_SOLICITUD);
  
    --Actualiza archivo enviado--
    v_cod_msj_swift := 'MT541';
    v_hor_envio := to_char(sysdate, 'hh24:mi:ss');
    v_cod_ejecucion := P_COD_EJECUCION;
    PAM_DEP.PR_OBT_DAT_MSJ_ACTUAL(v_cod_msj_swift, 'I', V_NRO_REF_SOLICITUD, v_exi_msj_enviado, v_cod_ejecucion, v_nro_orden, v_cod_msj_env_bcp);
    if v_exi_msj_enviado = 'S' then
       PR_CON_ENV_AUTOMATICO('E', V_NRO_REF_SOLICITUD, v_hor_envio, v_cod_ejecucion, v_nro_orden);
       PR_GEN_ENV_DEPOSITO(V_NRO_REF_SOLICITUD);
    end if;
  end if;


  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC, vg_nro_referencia,NULL,NULL,NULL,vg_nro_cuenta,vg_des_operacion);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END;

/* Genera Operacion Automatica de Facilidad Permanente de Depositos - (FPD)*/
PROCEDURE PR_FPD_INI_OPE_AUT (P_CTA_ORIGEN VARCHAR2 DEFAULT NULL) IS
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
BEGIN
  --Variables Principales--
  vg_nro_orden    := 0;
  vg_cta_origen   := p_cta_origen; -- el valor del parametro es SPI

  --Inicio Registro del Log--
  V_LUG_PRO_LOC := 'PR_GEN_OPE_FPD_AUT';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);

  --Proceso Principal--
  PAM_DEP.PR_CAR_VAR_PARAMETROS;
  PAM_DEP.PR_CON_ENV_AUTOMATICO('I');
  PAM_DEP.PR_OBT_SAL_CTA_SIPAP(vg_cod_ejecucion);

  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC, vg_nro_referencia,NULL,NULL,NULL,vg_nro_cuenta,vg_des_operacion);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END PR_FPD_INI_OPE_AUT;

PROCEDURE PR_FPD_REC_CON_AUT(P_NRO_REFERENCIA IN VARCHAR2) IS
  V_HOR_INI_LOC VARCHAR2(8);
  V_HOR_FIN_LOC VARCHAR2(8);
  V_LUG_PRO_LOC VARCHAR2(250);
  V_NRO_ORD_LOC GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
BEGIN
  --Variables Principales--
  vg_nro_orden    := 100;

  --Inicio Registro del Log--
  V_LUG_PRO_LOC := 'PR_GEN_OPE_FPD_AUT';
  vg_nro_orden   := NVL(vg_nro_orden,0) + 1;
  V_NRO_ORD_LOC := vg_nro_orden;
  V_HOR_INI_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'I', V_HOR_INI_LOC);

  --Proceso Principal--
  PAM_DEP.PR_CAR_VAR_PARAMETROS;
  PAM_DEP.PR_GEN_OPE_BCP_COL(P_NRO_REFERENCIA);
  PAM_DEP.PR_GEN_MOV_APE_COL;
  PAM_DEP.PR_GEN_MOV_DES_COL(P_NRO_REFERENCIA);
  PAM_DEP.PR_GEN_CON_DEPOSITO(P_NRO_REFERENCIA);

  --Fin Registro del Log--
  V_HOR_FIN_LOC := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_AUTOMATICOS(vg_cod_programa, V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'F', V_HOR_FIN_LOC, vg_nro_referencia,NULL,NULL,NULL,vg_nro_cuenta,vg_des_operacion);
  PRG_ACT_LOG_PROCESOS(vg_cod_programa, V_LUG_PRO_LOC, vg_fecha, V_HOR_INI_LOC, V_HOR_FIN_LOC);

EXCEPTION
  WHEN OTHERS THEN
    PRG_CON_PRO_AUTOMATICOS(vg_cod_programa,  V_LUG_PRO_LOC, V_NRO_ORD_LOC, vg_fecha,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), vg_nro_referencia, NULL, NULL, SQLERRM||'-'||V_LUG_PRO_LOC, vg_nro_cuenta,vg_des_operacion);
    RAISE_APPLICATION_ERROR(-20002, 'ERROR EN '||V_LUG_PRO_LOC||' - '||SQLERRM);
END PR_FPD_REC_CON_AUT;
BEGIN
  --Ver estado modulo y cargar fecha--
  prg_ver_est_modulo(10, vg_es_nocturno, vg_fecha);
  vg_fecfor := 'DEPO '||to_char(vg_fecha,'dd/mm/yyyy')||' - ';
END PAM_DEP;
/

