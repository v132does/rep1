CREATE OR REPLACE PROCEDURE IT.PRS_GEN_ARC_CAT_CODEUDORES(p_fecha ge_calendarios.fec_actual%type default null) is
  v_fec_actual      ge_calendarios.fec_actual%type;
  v_ext_archivo     ge_par_entes.val_parametro%type;
  v_tip_proceso     varchar2(1) := 'C';
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
  g_ip              VARCHAR2(100) :=  fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port            VARCHAR2(100) := '21';
  g_user            VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  g_pass            VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  v_directorio      VARCHAR2(100);
  v_tip_vinculo     sb_reg_arc_cat_codeudor.tip_vinculo%type;
  v_cod_vinculo     sb_reg_arc_cat_codeudor.cod_vinculo%type;
  v_tip_rubro       varchar2(1);
  v_tip_per_principal ba_personas.tipo%type;
  v_cta_con_capital sb_crc_operaciones_det.cta_con_cap_original%type;
  v_tip_operacion sb_crc_operaciones_det.tip_operacion%type;
  v_dia_atraso number := 0;
  v_tip_descuento varchar2(1);

  CURSOR c_datos is
  select distinct fug_obt_cod_entidad entidad, to_char(v_fec_actual, 'yyyymmdd') fecha,
         decode(fue_obt_tip_doc_abreviatura(p.cod_tip_documento), 'DNI', 'CRC', 'PAS', 'CRC', 'SW', 'CRC', 'OTR', 'CRC', 'PJ', 'CRC',
                fue_obt_tip_doc_abreviatura(p.cod_tip_documento)) tip_documento,
         p.nro_documento, v.sal_capital sal_capital , v.dev_no_cobrado sal_int_dev_no_cobrado,
         v.sal_capital + v.dev_no_cobrado total_riesgo, t.dia_atraso,
         nvl(decode(t.cat_automatica, 1.1, '1a', 1.2, '1b', to_number(t.cat_automatica)),1) cla_riesgo,
         null empresa_bt, null sucursal_bt, null moneda_bt, null cuenta_bt, null sub_operacion_bt,
         null modulo_bt, null tip_operacion_bt, null origen,  v.relacion relacion,0 cod_vinculo,
         v.cod_persona, t.cod_oficina, null tip_operacion, v.nro_operacion, m.cod_mon_iso cod_mon_iso,
         null cta_con_capital, v.nro_cuenta, 'D' tipo, t.cod_modalidad, v.afe_cheque, v.fec_vencimiento
    from ge_cla_operaciones t, SV_CON_CODEUDORES_DET v, ba_personas p, ba_monedas m
   where v.cod_persona = p.cod_persona
     and t.nro_cuenta = v.nro_cuenta
     and v_tip_proceso = 'C'
     and t.cod_moneda = m.cod_moneda
     and EXISTS (SELECT 0
                    FROM ge_cuentas c
                   WHERE c.nro_cuenta = t.nro_cuenta
                     AND ((c.cod_modulo IN (6, 10) AND c.estado <> 'N') OR
                         (c.cod_modulo NOT IN (6, 10) AND c.estado <> 'C')))
  union all
  select distinct fug_obt_cod_entidad entidad, to_char(s.fecha, 'yyyymmdd') fecha, t.tip_documento, t.nro_documento, s.sal_capital,
         s.sal_int_dev_no_cobrado,
         s.sal_capital + sal_int_dev_no_cobrado total_riesgo, s.dia_atraso, s.cla_riesgo,
         null empresa_bt, null sucursal_bt, null moneda_bt, null cuenta_bt, null sub_operacion_bt,
         null modulo_bt, null tip_operacion_bt, null origen,  null relacion, v.tip_vinculo cod_vinculo,
         v.cod_persona, s.cod_oficina, s.tip_operacion, s.nro_operacion, s.con_mon_iso,
         s.rub_con_capital, s.nro_operacion, 'M', s.cod_modalidad, null, null
    from sb_crc_clasificaciones_det t, sb_crc_saldos_det s, sb_crc_vinculos_det v, ba_cod_referencias r--, sb_crc_operaciones_det od
   where  t.fecha = v_fec_actual
     and v_tip_proceso = 'M'
     and t.tot_tc = 0
     and t.tot_dc = 0
     and t.tot_tr = 0 -- titulares cuentas
     and t.tot_dr = 0 -- titulares descuento
     and t.tot_er = 0 -- contingente
     and t.mto_rie_contingente = 0 -- venta cartera
     and t.mto_riesgo = 0 --incobrables
     and t.tot_sr > 0
     and t.nro_documento = v.nro_documento
     and t.fecha = s.fecha
     and s.tip_operacion = v.tip_operacion
     and s.nro_operacion = v.nro_operacion
     and r.dominio = 'INC_CAT_RIE_CODEUDORES'
     and r.val_minimo = v.tip_vinculo
     and (s.cod_modulo <> 15 or (s.cod_modulo = 15 and s.cod_modalidad = 152))--solo trae operaciones vencidas de sobregiros vencidos
     and substr(s.rub_con_capital,1,1) in (1,5)
     and not exists (select 1 from ba_cod_referencias t
     where t.dominio = 'EXC_OPE_CODEUDORIA'
     and t.val_minimo = s.nro_operacion
     and t.val_maximo = t.nro_documento)
     and nvl(s.sal_capital,0) + nvl(sal_int_dev_no_cobrado, 0) > 0
     and v.fecha = (select max(fecha) from sb_crc_vinculos_det vv
                     where vv.tip_operacion = v.tip_operacion
                       and vv.nro_operacion = v.nro_operacion
                       and vv.tip_documento = v.tip_documento
                       and vv.nro_documento = v.nro_documento)
                       --and vv.tip_vinculo in v.tip_vinculo)
  union all -- considerando relacion de vinculos
  select distinct fug_obt_cod_entidad entidad, to_char(s.fecha, 'yyyymmdd') fecha, t.tip_documento, t.nro_documento, s.sal_capital,
         s.sal_int_dev_no_cobrado,
         s.sal_capital + sal_int_dev_no_cobrado total_riesgo, s.dia_atraso, s.cla_riesgo,
         null empresa_bt, null sucursal_bt, null moneda_bt, null cuenta_bt, null sub_operacion_bt,
         null modulo_bt, null tip_operacion_bt, null origen,  null relacion, v.tip_vinculo cod_vinculo,
         v.cod_persona, s.cod_oficina, s.tip_operacion, s.nro_operacion, s.con_mon_iso,
         s.rub_con_capital, s.nro_operacion, 'M', s.cod_modalidad, null, null
    from sb_crc_clasificaciones_det t, sb_crc_saldos_det s, sb_crc_vinculos_det v, ba_cod_referencias r, ba_cod_referencias n
   where  t.fecha = v_fec_actual
     and v_tip_proceso = 'M'
     and t.tot_tc = 0
     and t.tot_dc = 0
     and t.tot_tr = 0 -- titulares cuentas
     and t.tot_dr = 0 -- titulares descuento
     and t.tot_er = 0 -- contingente
     and t.mto_rie_contingente = 0 -- venta cartera
     and t.mto_riesgo = 0 --incobrables
     and t.tot_sr > 0
     and n.dominio = 'REL_DOC_VIN'
     and n.val_minimo = v.nro_documento
     and n.val_maximo = t.nro_documento
     and t.fecha = s.fecha
     and s.tip_operacion = v.tip_operacion
     and s.nro_operacion = v.nro_operacion
     and r.dominio = 'INC_CAT_RIE_CODEUDORES'
     and r.val_minimo = v.tip_vinculo
     and (s.cod_modulo <> 15 or (s.cod_modulo = 15 and s.cod_modalidad = 152))--solo trae operaciones vencidas de sobregiros vencidos
     and substr(s.rub_con_capital,1,1) in (1,5)
     and not exists (select 1 from ba_cod_referencias t
     where t.dominio = 'EXC_OPE_CODEUDORIA'
     and t.val_minimo = s.nro_operacion
     and t.val_maximo = t.nro_documento)
     and nvl(s.sal_capital,0) + nvl(sal_int_dev_no_cobrado, 0) > 0
     and v.fecha = (select max(fecha) from sb_crc_vinculos_det vv
                     where vv.tip_operacion = v.tip_operacion
                       and vv.nro_operacion = v.nro_operacion
                       and vv.tip_documento = v.tip_documento
                       and vv.nro_documento = v.nro_documento)
                       --and vv.tip_vinculo in v.tip_vinculo)

   order by 19;
   v_can_reg number;
begin
  pag_cal.PR_OBT_DAT_CALENDAR(1);
  v_repository:= null;
  v_directorio:= null;
  v_repository:= fug_obt_pardinamico('DIR_REP_ARC_CODEUDORES');--'MAIL';
  v_directorio:= fug_obt_pardinamico('DIR_DEP_ARC_CODEUDORES');--'ramail\DYD\';
  v_ext_archivo := nvl(fug_obt_pardinamico('TIPO_ARC_CODEUDORES'), 'txt');--'xls';

  if p_fecha is null then
     v_fec_actual :=  pag_cal.fu_obt_fec_actual(1);
     v_tip_proceso := 'C';
  else
     v_fec_actual := p_fecha;
     v_tip_proceso := 'M';
  end if;

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

  v_name := 'CODEUDORIA-'||to_char(v_fec_actual, 'YYYYMMDD');
  if v_directorio is null then
     --Insertamos en la tabla de logs, para que no caiga el proceso de Cierre
     INSERT INTO ge_ra_log_mail(fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
     VALUES(SYSDATE, v_name, 'ERROR', 'Generacion Archivo Clasif. Codeudores', 'No tiene parametrizado el Directorio',v_hora , v_hora);
  end if;
  if v_repository is null then
     --Insertamos en la tabla de logs, para que no caiga el proceso de Cierre
     INSERT INTO ge_ra_log_mail(fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
     VALUES(SYSDATE, v_name, 'ERROR', 'Generacion Archivo Clasif. Codeudores', 'No tiene parametrizado el Repositorio',v_hora , v_hora);

  end if;
  -- Abrir archivo
  if v_repository is not null and v_directorio is not null then
     v_file := UTL_FILE.FOPEN(v_repository,
                              v_name || '.'||lower(v_ext_archivo),
                              'W',
                              32767);
  end if;

  if nvl(lower(v_ext_archivo),'xls') = 'xls' then
     v_cabecera := 'Entidad' || chr(9) || 'Fecha' || chr(9) || 'Tipo de Documento' || chr(9) || 'Nro. de Documento' || chr(9) ||
                   'Empresa BT'||chr(9) || 'Sucursal BT'||chr(9) || 'Moneda BT'||chr(9)||
                   'Cuenta BT' ||chr(9) || 'Operacion BT' ||chr(9) ||
                   'Sub Operacion BT' ||chr(9) || 'Modulo BT' ||chr(9) || 'Tipo Operacion BT'||chr(9) ||
                   'Origen BT' ||chr(9) ||
                   'Saldo Capital' || chr(9) ||'Interes Devengado No Cobrado' || chr(9) ||
                   'Total Riesgo' || chr(9) ||'Dia de Atraso' || chr(9) || 'Cat. Riesgo'|| chr(9)||
                   'Cod. Vinculo' ||chr(9) || 'Tipo de Vinculo'||chr(9) ||
                   'Cod. de Persona' ||chr(9) || 'Sucursal'||chr(9) ||'Tipo de Operacion'||chr(9) ||
                   'Nro. de Operacion'||chr(9) ||'Cod. Moneda ISO'||chr(9) ||
                   'Auxiliar1'||chr(9) ||'Auxiliar2'||chr(9) ||'Auxiliar3'||chr(9) ||'Auxiliar4'||chr(9) ||
                   'Auxiliar5'||chr(9) ||'Auxiliar6'||chr(9) ||'Auxiliar7'||chr(9) ||'Auxiliar8'||chr(9);
  else
     v_cabecera := 'Entidad' || '|' || 'Fecha' || '|' ||'Tipo de Documento' || '|' ||'Nro. de Documento'|| '|' ||
                   'Empresa BT'|| '|' ||'Sucursal BT'|| '|' || 'Moneda BT'|| '|' ||
                   'Cuenta BT' || '|' || 'Operacion BT' || '|' || 'Sub Operacion BT' || '|' ||
                   'Modulo BT' || '|' || 'Tipo Operacion BT'|| '|' ||'Origen BT'|| '|' ||
                   'Saldo Capital' || '|' ||'Interes Devengado No Cobrado' || '|' ||
                   'Total Riesgo' || '|' ||'Dia de Atraso' || '|' ||'Cat. Riesgo'|| '|' ||
                   'Cod. Vinculo' || '|' || 'Tipo de Vinculo'|| '|' ||
                   'Cod. de Persona' || '|' || 'Sucursal'|| '|' ||'Tipo de Operacion'|| '|' ||
                   'Nro. de Operacion'|| '|' ||'Cod. Moneda ISO'|| '|' ||
                   'Auxiliar1'|| '|' ||'Auxiliar2'|| '|' ||'Auxiliar3'|| '|' ||'Auxiliar4'|| '|' ||
                   'Auxiliar5'|| '|' ||'Auxiliar6'|| '|' ||'Auxiliar7'|| '|' ||'Auxiliar8'|| '|';

  end if;

  if v_repository is not null and v_directorio is not null then

  --*****************Para Depositar en archivo**********************
    Begin
      --*********Para Grabar Cabecera ***************************
      UTL_FILE.PUT_LINE(v_file, v_cabecera);

      pre_cam_for_numerico('.,');

      begin
        select count(*)
          into v_can_reg
          from sb_reg_arc_cat_codeudor
         where fecha = to_char(v_fec_actual, 'yyyymmdd');
      exception
        when others then
          v_can_reg := 0;
      end;

      if nvl(v_can_reg, 0) > 0 then
         begin
           delete from sb_reg_arc_cat_codeudor
           where fecha = to_char(v_fec_actual, 'yyyymmdd');
         exception
           when others then
             UTL_FILE.FCLOSE(v_file);
             RAISE_APPLICATION_ERROR(-20060, 'Error al eliminar en la tabla de categorizacion de codeudoria. ' || sqlerrm);
         end;
         begin
           delete from SB_LOG_DIF_CODEUDORIA
           where fecha = v_fec_actual;
         exception
           when others then
             UTL_FILE.FCLOSE(v_file);
             RAISE_APPLICATION_ERROR(-20060, 'Error al eliminar en la tabla de categorizacion de codeudoria. ' || sqlerrm);
         end;

      end if;

      for w in c_datos loop
         v_adjunto:=null;

         --2,5,4,2,11 solo lo que debe t
         if w.cod_vinculo = 0 then
           if w.relacion IN ('Y','O') THEN
              v_tip_rubro := nvl(substr(w.cta_con_capital, 1, 1), 1);
              begin
                SELECT p.tipo
                  INTO v_tip_per_principal
                  FROM ge_cta_clientes c, ba_personas p
                 WHERE nro_cuenta = w.nro_cuenta
                   AND relacion = 'P'
                   AND p.cod_persona = c.cod_persona;
              exception
                when others then
                   v_tip_per_principal := 'F';
              end;
              IF v_tip_per_principal = 'F' THEN
                 v_cod_vinculo := 2;
              ELSE
                 v_cod_vinculo := null;
              end if;
           ELSIF w.relacion = 'E' THEN
             v_cod_vinculo := 7; -- no debo generar
           ELSIF w.relacion = 'C' THEN
             v_cod_vinculo  := 2;
           ELSIF w.relacion = 'L' THEN
             v_cod_vinculo := 6;
           ELSE
             v_cod_vinculo := 4;
           END IF;
         else
           v_cod_vinculo := w.cod_vinculo;
         end if;
         begin
           select val_maximo
             into v_tip_vinculo
             from ba_cod_referencias
            where dominio = 'INC_CAT_RIE_CODEUDORES'
              and val_minimo = v_cod_vinculo;
         exception
           when others then
              v_tip_vinculo := null;
         end;

         if w.tipo = 'D' then
           if w.cod_modalidad = 41 then
              if w.cod_mon_iso = 'PYG' then
                 v_cta_con_capital := '142101890211199';
              else
                 v_cta_con_capital := '142101890211105';
              end if;
           else
              v_cta_con_capital := fus_obt_cod_rubro(w.nro_cuenta, 'C');
           end if;
            v_tip_operacion := substr(v_cta_con_capital, 6, 3);

            if w.afe_cheque = 'S' then
              begin
                v_dia_atraso :=  v_fec_actual - w.fec_vencimiento;
              exception
                when others then
                  v_dia_atraso := null;
              end;
              if v_dia_atraso is null then
                 v_dia_atraso := w.dia_atraso;
              elsif v_dia_atraso < 0 then
                 v_dia_atraso := 0;
              end if;
            else
              v_dia_atraso := w.dia_atraso;
            end if;
         else
            v_cta_con_capital := w.cta_con_capital;
            v_tip_operacion := w.tip_operacion;
            begin
              v_tip_descuento := fup_obt_tip_descuento(w.cod_modalidad);
            exception
              when others then
                v_tip_descuento := 'x';
            end;
            if v_tip_descuento in ('F', 'C', 'D') and w.cod_modalidad <> 613 then
               begin
                 select v_fec_actual - fec_vencimiento
                   into v_dia_atraso
                   from pr_cuotas
                  where nro_cuenta = substr(w.nro_operacion,1,instr(w.nro_operacion,'#')-1)
                    and nro_cuota = to_number(substr(w.nro_operacion,instr(w.nro_operacion,'#')+1,((instr(w.nro_operacion,'#',instr(w.nro_operacion,'#')+1) - instr(w.nro_operacion,'#'))-1))); --w.nro_operacion like nro_cuenta||'#'||nro_cuota||'#%';
               exception
                 when others then
                   v_dia_atraso := null;
               end;
               if v_dia_atraso is null then
                  v_dia_atraso := w.dia_atraso;
               elsif v_dia_atraso < 0 then
                  v_dia_atraso := 0;
               end if;
            else
              v_dia_atraso := w.dia_atraso;
            end if;
         end if;

         begin
            insert into sb_reg_arc_cat_codeudor(cod_entidad, fecha, tip_documento, nro_documento,
                                                 sal_capital_ml, sal_int_devengado_ml, tot_riesgo_ml, dia_atraso,
                                                 cat_operacion, cod_vinculo, tip_vinculo, cod_persona,
                                                 cod_sucursal, tip_operacion, nro_operacion, cod_moneda,fec_archivo, dia_atr_cuenta)
                                         values (w.entidad, w.fecha, w.tip_documento, w.nro_documento,
                                                 w.sal_capital, w.sal_int_dev_no_cobrado, w.total_riesgo, v_dia_atraso,
                                                 w.cla_riesgo, v_cod_vinculo, v_tip_vinculo, w.cod_persona,
                                                 w.cod_oficina, v_tip_operacion, w.nro_operacion, w.cod_mon_iso, v_fec_actual, w.dia_atraso);
         exception
           when others then
             UTL_FILE.FCLOSE(v_file);
             RAISE_APPLICATION_ERROR(-20060, 'Error al insertar en la tabla de categorizacion de codeudoria. ' || sqlerrm);
         end;


         if nvl(lower(v_ext_archivo),'xls') = 'xls' then
            v_adjunto := w.entidad || chr(9) ||
                         w.fecha || chr(9)||
                         w.tip_documento || chr(9)||
                         w.nro_documento || chr(9) ||
                         w.empresa_bt || chr(9) ||
                         w.sucursal_bt || chr(9) ||
                         w.moneda_bt|| chr(9) ||
                         w.cuenta_bt|| chr(9) ||
                         null|| chr(9) ||
                         w.sub_operacion_bt || chr(9) ||
                         w.modulo_bt || chr(9) ||
                         w.tip_operacion_bt || chr(9) ||
                         w.origen || chr(9) ||
                         w.sal_capital || chr(9) ||
                         w.sal_int_dev_no_cobrado ||chr(9) ||
                         w.total_riesgo || chr(9) ||
                         v_dia_atraso || chr(9) ||
                         w.cla_riesgo||chr(9) ||
                         v_cod_vinculo || chr(9) ||
                         v_tip_vinculo || chr(9) ||
                         w.cod_persona || chr(9) ||
                         w.cod_oficina || chr(9) ||
                         v_tip_operacion || chr(9) ||
                         w.nro_operacion || chr(9) ||
                         w.cod_mon_iso|| chr(9) ||
                         null || chr(9) ||
                         null || chr(9) ||
                         null || chr(9) ||
                         null || chr(9) ||
                         null || chr(9) ||
                         null || chr(9) ||
                         null || chr(9) ||
                         null|| chr(9);
         else
            v_adjunto := w.entidad || '|' ||
                         w.fecha || '|' ||
                         w.tip_documento || '|' ||
                         w.nro_documento || '|' ||
                         w.empresa_bt || '|' ||
                         w.sucursal_bt || '|' ||
                         w.moneda_bt || '|' ||
                         w.cuenta_bt|| '|' ||
                         null|| '|' ||
                         w.sub_operacion_bt || '|' ||
                         w.modulo_bt || '|' ||
                         w.tip_operacion_bt || '|' ||
                         w.origen || '|' ||
                         w.sal_capital|| '|' ||
                         w.sal_int_dev_no_cobrado || '|' ||
                         w.total_riesgo || '|' ||
                         v_dia_atraso || '|' ||
                         w.cla_riesgo|| '|' ||
                         v_cod_vinculo || '|' ||
                         v_tip_vinculo || '|' ||
                         w.cod_persona || '|' ||
                         w.cod_oficina || '|' ||
                         v_tip_operacion || '|' ||
                         w.nro_operacion || '|' ||
                         w.cod_mon_iso|| '|' ||
                         null || '|' ||
                         null || '|' ||
                         null || '|' ||
                         null || '|' ||
                         null || '|' ||
                         null || '|' ||
                         null || '|' ||
                         null|| '|' ;
         end if;
         UTL_FILE.PUT_LINE(v_file, v_adjunto);
      end loop;
    EXCEPTION
      when others then
        UTL_FILE.FCLOSE(v_file);
        v_error:= substr(to_char(sqlerrm),1,3000);
        INSERT INTO ge_ra_log_mail(fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
        VALUES(SYSDATE, v_name, 'ERROR', 'Generacion Archivo Clasif. Codeudores', v_error,v_hora , v_hora);
    END;
    UTL_FILE.FCLOSE(v_file);
    COMMIT;

    begin
      insert into SB_LOG_DIF_CODEUDORIA (fecha, nro_documento, tot_riesgo, tot_sr, diferencia, observacion, cod_persona)
      (select v_fec_actual, t.nro_documento, sum(d.tot_riesgo_ml), t.tot_sr, sum(d.tot_riesgo_ml) - t.tot_sr, 'DIFERENCIA ENTRE CLASIFICA Y OPERACIONES',
              t.cod_persona
        from sb_reg_arc_cat_codeudor d, sb_crc_clasificaciones_det t
        where t.fecha = v_fec_actual
        and t.fecha = d.fec_archivo
        and t.nro_documento = d.nro_documento
        and t.tot_tc = 0
        and t.tot_dc = 0
             and t.tot_tr = 0 -- titulares cuentas
             and t.tot_dr = 0 -- titulares descuento
             and t.tot_er = 0 -- contingente
             and t.mto_rie_contingente = 0 -- venta cartera
             and t.mto_riesgo = 0 --incobrables
             and t.tot_sr > 0
        group by t.nro_documento, t.tot_sr, t.cod_persona
        having sum(d.tot_riesgo_ml) - t.tot_sr <> 0
        --having sum(d.tot_riesgo_ml) - t.tot_sr NOT BETWEEN -5 AND 5
        union
        select v_fec_actual, t.nro_documento, 0, t.tot_sr, 0- t.tot_sr, 'SE ENCUENTRA EN CLASIFICA Y NO EN OPERACIONES', t.cod_persona
         from sb_crc_clasificaciones_det t
        where t.fecha = v_fec_actual
          and t.fecha = v_fec_actual
          and t.tot_tc = 0
          and t.tot_dc = 0
          and t.tot_tr = 0 -- titulares cuentas
          and t.tot_dr = 0 -- titulares descuento
          and t.tot_er = 0 -- contingente
          and t.mto_rie_contingente = 0 -- venta cartera
          and t.mto_riesgo = 0 --incobrables
          and t.tot_sr > 0
          and not exists (select 1 from sb_reg_arc_cat_codeudor x
                          where x.fec_archivo = v_fec_actual
                            and x.fec_archivo = t.fecha
                            and x.nro_documento = t.nro_documento));
    end;

    v_hini_ftp := to_char(sysdate, 'hh24:mi:ss');
    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_binary(g_ip,
                                             g_port,
                                             g_user,
                                             g_pass,
                                             v_repository,
                                             v_name || '.'||lower(v_ext_archivo),
                                             lower(v_directorio) || v_name|| '.'||lower(v_ext_archivo));

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
     UTL_FILE.FCLOSE(v_file);
     raise_application_error(-20000,'PRG_GEN_ARC_CAT_CODEUDORES '||sqlerrm);
END PRS_GEN_ARC_CAT_CODEUDORES;
/
