CREATE OR REPLACE PROCEDURE IT.PRG_GEN_ARC_DET_TAS_SEM(p_periodo number) is
  v_fec_actual      date  default pag_cal.fu_obt_fec_actual(1);
  v_ext_archivo     ge_par_entes.val_parametro%type;
  v_adjunto         varchar2(32000);
  v_cabecera        clob;
  v_file            UTL_FILE.FILE_TYPE;
  v_name            VARCHAR2(128);-- nombre del archivo
  v_hora            varchar2(12);
  v_error           varchar2(3000);
  -- FTP
  v_hini_ftp        ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp        ge_ra_log_ftp.hor_fin%type;
  v_respuesta       VARCHAR2(4000);
  /* -- Variables coneccion*/
  v_repository      VARCHAR2(100);
  g_ip              VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port            VARCHAR2(100) := '21';
  g_user            VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  g_pass            VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  v_directorio      VARCHAR2(100);
  v_sal_ponderar    VARCHAR2(100);
  v_sal_promedio    number;
  v_cod_entidad     ge_par_generales.cod_entidad%TYPE := fug_obt_cod_entidad;
  v_tipo            varchar2(1);
  v_fec_pri_dia ge_calendarios.fec_actual%type;
  v_periodo         mi_sb_tas_ape_semanales.periodo%type;
  v_tip_cap         ah_cta_vistas.tip_capitalizacion%type;
  v_cod_cta         mi_sb_tas_ape_semanales.codcta%type;
  v_cod_rubro       cb_rubros.cod_rubro%type;
  --v_mto_linea       cc_lin_sobregiros.monto%type;

  CURSOR c_datos is
  select c.corcod, c.cod_modulo, c.cod_modalidad, c.nro_cuenta, c.entcod, c.codcta,
         c.cod_moneda, c.acod, c.fec_apertura, c.fecha, c.val_tas_nominal, c.monto,
         c.periodo, c.tasreg, c.tae
    from sv_mi_sb_tas_ape_semanales_det c
   where c.corcod like p_periodo||'%'
  union
  select c.corcod, c.cod_modulo, c.cod_modalidad, c.nro_cuenta, v_cod_entidad, c.codcta,
         c.cod_moneda, c.acod, to_char(c.fec_apertura, 'DDMMYYYY') fec_apertura, c.fec_apertura,
         trim(replace(to_char(c.val_tas_nominal, '00.99'), '.', '')) val_tas_nominal,
         trim(to_char(round(c.monto, 0), '999999999999999')) || '00' monto,
         lpad(trim(to_char(c.periodo, '9999')), 4, '0'), c.tasreg,
         trim(replace(to_char(fus_obt_tae_tasa(c.VAL_TAS_NOMINAL,c.PERIODO,c.TASREG), '00.99'),'.','')) tae
    from MI_SB_PRO_DET_TAS_SEM c
   where c.fil_periodo = p_periodo
   order by 4;

   procedure pr_ins_pro_tas_sem is
     cursor c_datos is
     select t.nro_cuenta, t.cod_modulo, t.cod_modalidad, w.cod_oficina, w.cod_moneda,
            decode(w.cod_moneda, 'GS', 6900, 6200) moneda,
            a.val_tasa, a.tas_personalizada, a.cod_tasa, t.sal_fin_mes
       from ah_sal_mensuales t, ge_cuentas a, ah_cta_vistas w
      where t.mes = to_number(substr(p_periodo, 5,2))
       and w.nro_cuenta = t.nro_cuenta
       and w.nro_cuenta = a.nro_cuenta
       and t.ano = substr(p_periodo, 1, 4)
       and t.cod_modalidad = 31
       and t.sal_acu_diario > 0
       and not exists (select 1 from mi_sb_tas_ape_semanales a
                        where a.corcod like p_periodo||'%'
                        and a.nro_cuenta = t.nro_cuenta)
    union all
     select t.nro_cuenta, t.cod_modulo, t.cod_modalidad, w.cod_oficina, w.cod_moneda,
            decode(w.cod_moneda, 'GS', 6900, 6200) moneda,
            a.val_tasa, a.tas_personalizada, a.cod_tasa, t.sal_fin_mes
       from cc_sal_mensuales t, ge_cuentas a, cc_cta_corrientes w
      where t.mes = to_number(substr(p_periodo, 5,2))
       and w.nro_cuenta = t.nro_cuenta
       and w.nro_cuenta = a.nro_cuenta
       and t.ano = substr(p_periodo, 1, 4)
       and t.cod_modalidad = 41
       and t.sal_acu_deudor > 0
       and not exists (select 1 from mi_sb_tas_ape_semanales a
                        where a.corcod like p_periodo||'%'
                        and a.nro_cuenta = t.nro_cuenta)
   union all
     select w.nro_cuenta, w.cod_modulo, w.cod_modalidad, w.cod_oficina, w.cod_moneda,
            decode(w.cod_moneda, 'GS', 6900, 6200) moneda,
            a.val_tasa, a.tas_personalizada, a.cod_tasa,
            nvl(s.sal_financiado, 0) + nvl(s.sal_facturado, 0) + nvl(s.sal_facturar, 0) - nvl(s.sal_cuo_pendientes,0)
       from ta_sal_mensuales s, ge_cuentas a, ta_cta_tarjetas w
      where s.mes = to_number(substr(p_periodo, 5,2))
       and w.nro_cuenta = s.nro_cuenta
       and w.nro_cuenta = a.nro_cuenta
       and s.ano = substr(p_periodo, 1, 4)
       and nvl(s.acu_sal_financiado, 0) + nvl(s.acu_sal_facturado, 0) + nvl(s.acu_sal_facturar, 0) - nvl(s.acu_sal_cuo_pendiente,0) > 0
       and not exists (select 1 from mi_sb_tas_ape_semanales a
                        where a.corcod like p_periodo||'%'
                        and a.nro_cuenta = w.nro_cuenta);


   cursor c_cap(p_nro_cuenta ge_cuentas.nro_cuenta%type) is
   select tip_capitalizacion
   from ah_cta_vistas
   where nro_cuenta = p_nro_cuenta
   union
   select tip_capitalizacion
     from ah_cta_plazos
    where nro_cuenta = p_nro_cuenta
   union
   select tip_capitalizacion
     from ah_cta_certificados
    where nro_cuenta = p_nro_cuenta;

    V_MONTO SB_TAS_APE_SEMANALES.MONTO%TYPE;
    V_TASA_NOMINAL SB_TAS_APE_SEMANALES.VAL_TAS_NOMINAL%TYPE;
    V_TIP_CAPITALIZACION AH_CTA_CERTIFICADOS.TIP_CAPITALIZACION%TYPE;
    V_TASA_EFECTIVA SB_TAS_APE_SEMANALES.VAL_TAS_EFECTIVA%TYPE;
    V_PLAZO GE_PLZ_CONTABLES.COD_PLAZO%TYPE;
    v_fec_apertura ge_calendarios.fec_actual%type;
    v_periodo mi_sb_tas_ape_semanales.periodo%type;
    v_sal_acumulado      cc_sal_mensuales.sal_acu_deudor%type;
    v_sal_promedio       cc_sal_mensuales.sal_acu_deudor%type;
    v_can_dia_acumulado  ah_sal_mensuales.can_dia_acumulado%type;
    v_val_tasa           ge_tas_fechas.val_tasa%type;
    v_acod               varchar2(5);
    v_codcta             mi_sb_tas_ape_semanales.codcta%type;
    v_tasreg             mi_sb_tas_ape_semanales.tasreg%type;
    v_corcod             varchar2(10);
    v_can_registros      number;
  begin
    begin
      select count(*)
        into v_can_registros
        from MI_SB_PRO_DET_TAS_SEM
       where fil_periodo = p_periodo;
    exception
      when others then
        v_can_registros := 0;
    end;

    if v_can_registros > 0 then
      begin
        delete from MI_SB_PRO_DET_TAS_SEM
        where fil_periodo = p_periodo;
      exception
        when others then
          v_error := SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
          INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES
                (FECHA_PROCESO, ERROR, MENSAJE)
          VALUES
                (SYSDATE, v_error, 'Error al insertar MI_SB_PRO_DET_TAS_SEM');
      end;
    end if;

    begin
      select trunc(decode(to_char(pag_cal.FU_OBT_FEC_HABIL(last_day(v_fec_pri_dia),1,1), 'yyyymm'), substr(p_periodo,1,6), pag_cal.FU_OBT_FEC_HABIL(last_day(v_fec_pri_dia),1,1),
             pag_cal.FU_OBT_FEC_ANT_HAB(last_day(v_fec_pri_dia),1)))
        into v_fec_apertura
        from dual;
    exception
      when others then
       v_fec_apertura := last_day(v_fec_pri_dia);
    end;


      BEGIN
        SELECT SEMANA
          INTO v_corcod
          FROM SB_SEMANAS
         WHERE v_fec_apertura BETWEEN DESDE AND HASTA;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_error := SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
          INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES
            (FECHA_PROCESO, ERROR, MENSAJE)
          VALUES
            (SYSDATE, v_error, 'La fecha ingresada no es válida');
        WHEN OTHERS THEN
          v_error := SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
          INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES
            (FECHA_PROCESO, ERROR, MENSAJE)
          VALUES
            (SYSDATE, v_error, 'Problemas al determinar semana');
      END;


    for c in c_datos loop
      v_tasa_nominal := null;

      If c.val_tasa is null and c.cod_tasa is not null then
         v_tasa_nominal := FUG_OBT_VAL_TASA(c.cod_modulo,c.cod_modalidad,
                              c.cod_oficina,c.nro_cuenta,c.cod_moneda,c.sal_fin_mes,c.tas_personalizada,
                              c.cod_tasa,null,v_fec_apertura);
      else
         If c.cod_modulo = 4 then
            v_tasa_nominal := 0;
         Else
            v_tasa_nominal := c.val_tasa;
         End if;
      End if;

      --v_dias := nvl(c.fec_vencimiento,cuo.fec_apertura + 1) - cuo.fec_apertura ;
      If c.cod_modalidad in (31, 41) then
         v_plazo := 1;
      /*else
         v_plazo := FUG_OBT_PLZ_CONTABLE(v_dias);*/
      end if;

     If c.cod_modulo = 3 then
        for ca in c_cap(c.nro_cuenta) loop
          v_tip_capitalizacion := ca.tip_capitalizacion;
        end loop;
     end if;

      if c.cod_modalidad = 31 then
          v_periodo := 30;
          v_tasa_efectiva := round(pas_bcp.fu_obt_tae(v_tasa_nominal, v_periodo),2);
      elsif c.cod_modulo = 4 then
        --obtiene saldo promedio
        pag_cta.pr_obt_sal_promedio(c.cod_modulo,c.cod_modalidad,c.cod_oficina,
        c.nro_cuenta,v_fec_actual,v_fec_actual, v_sal_acumulado, v_sal_promedio,
        v_can_dia_acumulado);
        v_val_tasa := fug_obt_val_tasa(c.cod_modulo, c.cod_modalidad, c.cod_oficina,
                      c.nro_cuenta, c.cod_moneda, v_SAL_PROMEDIO, c.tas_personalizada,
                           null, 550, v_fec_apertura);--busca x la transacciòn de sobregiro
            v_tasa_efectiva := pas_bcp.FU_OBT_TAE(v_val_tasa,30);
            v_tasa_nominal  := v_val_tasa;
      elsif c.cod_modulo = 5 then
        --TAE de tarjetas no se calcula porque viene de la procesadora 20061206 JCLG
        v_tasa_efectiva := round(pas_bcp.fu_obt_tae(v_tasa_nominal, 30),2);
      end if;
      /* CODCTA: Es el tipo de operación cartera relacionada con contabilidad,
      solo 156000, en este caso (CDA)
      if C.cod_modalidad = 34 then
        v_codcta := '214000';*/
      if c.cod_modalidad = 41 then
        v_codcta := '189000';
      elsif c.cod_modulo = 5 then
        v_codcta := '205002';
        -- BBVANOR-90
      elsif fug_obt_pardinamico('MDD_MAD_EMI_CALLMONEY',
                                c.cod_modulo,
                                c.cod_modalidad,
                                null,
                                null,
                                null) = 'S' then
        v_codcta := '391000';
        v_acod   := 1046;
      elsif fug_obt_pardinamico('MDD_MAD_REC_CALLMONEY',
                                c.cod_modulo,
                                c.cod_modalidad,
                                null,
                                null,
                                null) = 'S' then
        v_codcta := '304000';
        v_acod   := 2150;
      else
        --- Prestamos, ah.vista y CDA
        v_codcta := fug_obt_mod_sup_rubro(c.cod_modulo, c.nro_cuenta);
        v_codcta := rpad(substr(v_codcta, 1, 3), 6, '0');
        if nvl(fup_obt_tip_descuento(c.cod_modalidad), 'x') in ('F', 'C') then
          v_codcta := '405001'; -- descuento de cheques
        elsif nvl(fup_obt_tip_descuento(c.cod_modalidad), 'x') = 'D' then
          v_codcta := '351000'; -- descuento de documentos   Pedido 79/08 (Modif. T)
        end if;
      end if;
      if c.cod_modulo = 5 then
        v_tasreg  := 'V';
        v_acod    := fus_obt_are_bcp_cta(c.nro_cuenta, c.cod_modulo);
        v_periodo := 30;
      end if;
      --- Sobregiros
      if c.cod_modulo = 4 then
        v_tasreg  := 'V';
        v_acod    := fus_obt_are_bcp_cta(c.nro_cuenta, c.cod_modulo);
        v_periodo := 30;
      end if;
      
      if c.cod_modalidad = 31 then
         /* TASREG: Vencida o Adelantada, en este caso solamente Vencida (V) */
         v_tasreg := 'V';
         /* ACOD: Es el área que corresponde, de acuerdo al plazo de la operación */
        v_acod    := fus_obt_are_bcp_cta(c.nro_cuenta, c.cod_modulo);
        v_periodo := 30;
      end if;
      --- Verificar el monto
      if v_monto < 1 then
        v_monto := 1;
      end if;

      begin
        insert into MI_SB_PRO_DET_TAS_SEM(NRO_CUENTA,
                                          COD_MODULO,
                                          COD_MODALIDAD,
                                          COD_MON_ORIGINAL,
                                          COD_MONEDA,
                                          FEC_APERTURA,
                                          COD_OFICINA,
                                          MONTO,
                                          VAL_TAS_NOMINAL,
                                          VAL_TAS_EFECTIVA,
                                          COD_PLAZO,
                                          CORCOD,
                                          CODCTA,
                                          ACOD,
                                          PERIODO,
                                          TASREG,
                                          FIL_PERIODO)
                                   values(c.nro_cuenta,
                                          c.cod_modulo,
                                          c.cod_modalidad,
                                          c.cod_moneda,
                                          c.moneda,
                                          v_fec_apertura,
                                          c.cod_oficina,
                                          c.sal_fin_mes,
                                          V_TASA_NOMINAL,
                                          V_TASA_EFECTIVA,
                                          V_PLAZO,
                                          v_corcod,
                                          v_codcta,
                                          v_acod,
                                          v_periodo,
                                          v_tasreg,
                                          p_periodo);
       exception
         when others then
            v_error := 'Cuenta: ' || c.nro_cuenta || ' - ' ||
                       SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
            INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES
              (FECHA_PROCESO, ERROR, MENSAJE)
            VALUES
              (SYSDATE, v_error, 'Error al insertar MI_SB_PRO_DET_TAS_SEM');
       end;
     end loop;
     commit;
  end;
begin
  pag_cal.PR_OBT_DAT_CALENDAR(1);
  v_repository:= null;
  v_directorio:= null;
  v_repository:= fug_obt_pardinamico('DIR_REP_ARC_TAS_SEM_DET');--'MAIL';
  v_directorio:= fug_obt_pardinamico('DIR_DEP_ARC_TAS_SEM_DET');--'ramail\DYD\';
  v_ext_archivo := nvl(fug_obt_pardinamico('TIPO_ARC_TAS_SEM_DET'), 'xls');--'xls';
  v_fec_pri_dia := to_date(substr(p_periodo,1,6)||'01', 'yyyymmdd');
  pr_ins_pro_tas_sem;
  -- Tipo de Archivo
  if v_ext_archivo is not null then
     if lower(v_ext_archivo) != 'xls' or lower(v_ext_archivo) != 'txt' then
        if lower(v_ext_archivo) like '%xls%' then
           v_ext_archivo := 'xls';
        end if;
        if lower(v_ext_archivo) like '%txt%' then
           v_ext_archivo := 'txt';
        end if;
        if lower(v_ext_archivo) like '%csv%' then
           v_ext_archivo := 'csv';
        end if;

     end if;
     if v_ext_archivo not in ('xls','txt', 'csv') then
        v_ext_archivo := 'xls';
     end if;
  else
    v_ext_archivo := 'xls';
  end if;

  v_name := 'Det_tas_sem_'||p_periodo;
  v_name:=lower(v_name);
  if v_directorio is null then
     --Insertamos en la tabla de logs, para que no caiga el proceso de Cierre
     INSERT INTO ge_ra_log_mail(fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
     VALUES(SYSDATE, v_name, 'ERROR', 'Generacion Archivo Detalle de tasas Semanales', 'No tiene parametrizado el Directorio',v_hora , v_hora);
  end if;
  if v_repository is null then
     --Insertamos en la tabla de logs, para que no caiga el proceso de Cierre
     INSERT INTO ge_ra_log_mail(fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
     VALUES(SYSDATE, v_name, 'ERROR', 'Generacion Archivo Detalle de tasas Semanales', 'No tiene parametrizado el Repositorio',v_hora , v_hora);
  end if;
  -- Abrir archivo
  if v_repository is not null and v_directorio is not null then
     v_file := UTL_FILE.FOPEN(v_repository,
                              lower(v_name) || '.'||lower(v_ext_archivo),
                              'W',
                              32767);
  end if;


  if nvl(lower(v_ext_archivo),'xls') = 'xls'then
     v_cabecera := 'Corcod' || chr(9) || 'Cod. Modulo' || chr(9) || 'Cod. Modalidad' || chr(9) || 'Nro. Cuenta' || chr(9) ||
                   'Entcod' || chr(9) ||'Codcta' || chr(9) ||
                   'Cod. Moneda' || chr(9) ||'Acod' || chr(9) || 'Fec. Apertura'|| chr(9)||
                   'Valor tasa Nominal'||chr(9) || 'Monto'||chr(9) ||'Saldo a Ponderar'||chr(9) ||'Periodo'||chr(9)||
                   'Tasreg' ||chr(9) || 'Tae';
  elsif nvl(lower(v_ext_archivo), 'csv') in ('csv', 'txt') then
     v_cabecera := 'Corcod' ||';'|| 'Cod. Modulo' ||';'|| 'Cod. Modalidad' ||';'|| 'Nro. Cuenta' ||';'||
                   'Entcod' ||';'|| 'Codcta' ||';'||
                   'Cod. Moneda' ||';'||'Acod' ||';'|| 'Fec. Apertura'||';'||
                   'Valor tasa Nominal'||';'|| 'Monto'||';'||'Saldo a Ponderar'||';' || 'Periodo'||';'||
                   'Tasreg' ||';'|| 'Tae'||';';
  end if;

  if v_repository is not null and v_directorio is not null then

  --*****************Para Depositar en archivo**********************
    Begin
      --*********Para Grabar Cabecera ***************************
      UTL_FILE.PUT_LINE(v_file, v_cabecera);

      pre_cam_for_numerico('.,');

      for w in c_datos loop
        if w.cod_modulo = 3 and w.cod_modalidad = 31 then
           begin
             select round(decode(a.cod_moneda, 'GS', decode(s.can_dia_acumulado, 0, s.sal_acu_diario, s.sal_acu_diario/s.can_dia_acumulado),
                                                            decode(s.can_dia_acumulado, 0, s.sal_acu_diario * pag_gen.FU_OBT_COTIZACION(a.cod_moneda, TRUNC(w.fecha)),
                                                                            s.sal_acu_diario * pag_gen.FU_OBT_COTIZACION(a.cod_moneda, TRUNC(w.fecha))/s.can_dia_acumulado))/1000,0),
                    a.tip_capitalizacion
               into v_sal_promedio, v_tip_cap
               from ah_sal_mensuales s, ah_cta_vistas a
              where s.nro_cuenta = w.nro_cuenta
                and s.nro_cuenta = a.nro_cuenta
                and s.ano =  substr(w.corcod, 1, 4)
                and s.mes = to_number(substr(w.corcod, 5,2));
           exception
             when others then
               v_sal_promedio := 0;
           end;
           v_tipo := 'P';


           v_periodo := 30;
       elsif w.cod_modulo = 4 then
           begin
             select round(decode(a.cod_moneda, 'GS', decode(s.can_dia_deudor, 0, s.sal_acu_deudor, s.sal_acu_deudor/s.can_dia_deudor),
                                                            decode(s.can_dia_deudor, 0, s.sal_acu_deudor * pag_gen.FU_OBT_COTIZACION(a.cod_moneda, TRUNC(w.fecha)),
                                                                            s.sal_acu_deudor * pag_gen.FU_OBT_COTIZACION(a.cod_moneda, TRUNC(w.fecha))/s.can_dia_deudor))/1000,0)
               into v_sal_promedio
               from cc_sal_mensuales s, cc_cta_corrientes a
              where s.nro_cuenta = w.nro_cuenta
                and s.nro_cuenta = a.nro_cuenta
                and s.ano =  substr(w.corcod, 1, 4)
                and s.mes = to_number(substr(w.corcod, 5,2));
           exception
             when others then
               v_sal_promedio := 0;
           end;

           v_periodo := w.periodo;

           /*begin
             select decode(a.cod_moneda, 'GS', s.sal_acu_diario * -1,
                           round(s.sal_acu_diario * -1 * pag_gen.FU_OBT_COTIZACION(a.cod_moneda, TRUNC(w.fecha))))
               into v_sal_promedio
               from cc_sal_mensuales s, cc_cta_corrientes a
              where s.nro_cuenta = w.nro_cuenta
                and s.nro_cuenta = a.nro_cuenta
                and s.ano||lpad(s.mes, 2, '0') = substr(w.corcod, 1, 6) ;
           exception
             when others then
               v_sal_promedio := 0;
           end;
           v_tipo := 'P';
           if v_sal_promedio > 0 then
              begin
               select count(*)
                 into v_can_dia_sob
                 from cc_sobregiros
                where nro_cuenta = w.nro_cuenta
                  and fecha BETWEEN  v_fec_pri_dia and w.fec_apertura;
             exception
               when others then
                 v_can_dia_sob := 0;
             end;
             if v_can_dia_sob > 0 then
               v_sal_promedio := round((v_sal_promedio / v_can_dia_sob)/1000,0);
             else
               v_sal_promedio := round(v_sal_promedio/1000);
               INSERT INTO ge_ra_log_mail(fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
               VALUES(SYSDATE, v_name, 'ERROR', 'Generacion Archivo Detalle de tasas Semanales', 'Dia de sobregiro igual a 0 '||w.nro_cuenta,v_hora , v_hora);
             end if;
           end if;*/
           v_tipo := 'P';
       elsif w.cod_modulo = 5 then
           begin
             select round(decode(a.cod_moneda, 'GS', decode(s.can_dia_acumulado, 0, nvl(s.acu_sal_financiado, 0) + nvl(s.acu_sal_facturado, 0) + nvl(s.acu_sal_facturar, 0) - nvl(s.acu_sal_cuo_pendiente,0),
                                                                                                 (nvl(s.acu_sal_financiado, 0) + nvl(s.acu_sal_facturado, 0) + nvl(s.acu_sal_facturar, 0) - nvl(s.acu_sal_cuo_pendiente,0))/s.can_dia_acumulado),
                                                            decode(s.can_dia_acumulado, 0, (nvl(s.acu_sal_financiado, 0) + nvl(s.acu_sal_facturado, 0) + nvl(s.acu_sal_facturar, 0) - nvl(s.acu_sal_cuo_pendiente,0)) * pag_gen.FU_OBT_COTIZACION(a.cod_moneda, TRUNC(w.fecha)),
                                                                            (nvl(s.acu_sal_financiado, 0) + nvl(s.acu_sal_facturado, 0) + nvl(s.acu_sal_facturar, 0) - nvl(s.acu_sal_cuo_pendiente,0)) * pag_gen.FU_OBT_COTIZACION(a.cod_moneda, TRUNC(w.fecha))/s.can_dia_acumulado))/1000,0)
               into v_sal_promedio
               from ta_sal_mensuales s, ta_cta_tarjetas a
              where s.nro_cuenta = w.nro_cuenta
                and s.nro_cuenta = a.nro_cuenta
                and s.ano||lpad(s.mes, 2, '0') = substr(w.corcod, 1, 6) ;
           exception
             when others then
               v_sal_promedio := 0;
           end;
           v_tipo := 'P';
           v_periodo := w.periodo;
         else
            v_tipo := 'S';
            v_periodo := w.periodo;
         end if;
         
         if w.cod_modalidad = 31 then
            v_cod_rubro := fus_obt_cod_rubro(w.nro_cuenta, 'C');
            v_cod_cta := substr(v_cod_rubro, 6, 3)||'01'||substr(v_cod_rubro, 9,1);            
         /*elsif w.cod_modalidad = 41 then
           
            v_fec_ult_dia_mes := pag_cal.FU_OBT_FEC_ANT_HAB(add_months(to_date(substr(w.corcod, 1, 6)||'01','yyyymmdd'),1), 1);  
            

            --if v_fec_ult_dia_mes > v_fec_actual then
               v_cod_rubro := pab_asi.fu_obt_rub_contable(w.nro_cuenta, 'C', 'S');
            --else
              -- v_cod_rubro := pab_asi.fu_obt_rub_con_his(w.nro_cuenta, 'C', v_fec_ult_dia_mes, 'S');
            --end if;
            v_cod_cta := substr(v_cod_rubro, 6, 3)||'01'||substr(v_cod_rubro, 9,1);*/
         else
            v_cod_cta := w.codcta;
         end if;
         v_adjunto:=null;
         if (v_tipo = 'S') or (v_tipo = 'P' and v_sal_promedio > 0)  then
              if v_tipo = 'S' then
                 v_sal_ponderar := w.monto;
              else
                 v_sal_ponderar := to_char(v_sal_promedio, '999999999999999')||'00';
              end if;
           if nvl(lower(v_ext_archivo),'xls') = 'xls' then
              v_adjunto := w.corcod || chr(9) ||
                           w.cod_modulo || chr(9)||
                           w.cod_modalidad || chr(9)||
                           w.nro_cuenta || chr(9) ||
                           w.entcod || chr(9) ||
                           v_cod_cta ||chr(9) ||
                           w.cod_moneda || chr(9) ||
                           w.acod || chr(9) ||
                           w.fec_apertura||chr(9) ||
                           w.val_tas_nominal||chr(9)||
                           w.monto||chr(9)||
                           v_sal_ponderar||chr(9)||
                           v_periodo || chr(9) ||
                           w.tasreg|| chr(9)||
                           w.tae || chr(9);
           elsif nvl(lower(v_ext_archivo),'xls') in ('csv', 'txt') then
              v_adjunto := w.corcod ||';'||
                           w.cod_modulo ||';'||
                           w.cod_modalidad ||';'||
                           w.nro_cuenta ||';'||
                           w.entcod ||';'||
                           v_cod_cta ||';'||
                           w.cod_moneda ||';'||
                           w.acod ||';'||
                           w.fec_apertura||';'||
                           w.val_tas_nominal||';'||
                           w.monto||';'||
                           v_sal_ponderar ||';'||
                           v_periodo ||';'||
                           w.tasreg||';'||
                           w.tae||';';
           end if;
           UTL_FILE.PUT_LINE(v_file, v_adjunto);
         end if;
      end loop;
    EXCEPTION
      when others then
        v_error:= substr(to_char(sqlerrm),1,3000);
        INSERT INTO ge_ra_log_mail(fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
        VALUES(SYSDATE, v_name, 'ERROR', 'Generacion Archivo Detalle de tasas Semanales', v_error,v_hora , v_hora);
    END;

    --Cerrar el handler al fichero
    UTL_FILE.FCLOSE(v_file);
    COMMIT;
    v_hini_ftp := to_char(sysdate, 'hh24:mi:ss');
    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_binary(g_ip,
                                             g_port,
                                             g_user,
                                             g_pass,
                                             v_repository,
                                             lower(v_name) || '.'||lower(v_ext_archivo),
                                             lower(v_directorio) || lower(v_name)|| '.'||lower(v_ext_archivo));

    v_hfin_ftp := to_char(sysdate, 'hh24:mi:ss');
    IF v_respuesta <> 'OK' THEN
       -- Insertamos el error del envio al directorio compartido
       INSERT INTO ge_ra_log_ftp(fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
                           VALUES (SYSDATE, v_name, v_respuesta, v_hini_ftp, v_hfin_ftp);
    end if;
    COMMIT;
  end if;

EXCEPTION
  WHEN UTL_FILE.INVALID_OPERATION THEN
    UTL_FILE.FCLOSE(v_file);
  WHEN UTL_FILE.INVALID_FILEHANDLE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20062, 'Manejador invalido ' || sqlerrm);
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063, 'Error de escritura ' || sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064, 'Modo invalido ' || sqlerrm);
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065, 'Internal Error ' || sqlerrm);
  WHEN OTHERS THEN
     raise_application_error(-20000,'PRG_GEN_ARC_DET_TAS_SEM '||sqlerrm);
END PRG_GEN_ARC_DET_TAS_SEM;
/

