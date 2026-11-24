CREATE OR REPLACE PROCEDURE IT.pra_con_dia_tra_gp IS
  v_cod_ofi_matriz    ba_oficinas.cod_oficina%TYPE;
  v_fec_actual        ge_calendarios.fec_actual%TYPE;
  --
  v_cta_credito       ge_cuentas.nro_cuenta%TYPE;
  v_cta_fon_glo       ge_cuentas.nro_cuenta%TYPE;
  v_cod_rub_deb       ge_movimientos.cod_rubro%TYPE;
  v_mod_con_deb       ge_movimientos.cod_modulo%TYPE;
  v_mad_con_deb       ge_movimientos.cod_modalidad%TYPE;
  v_nro_cta_fic       ge_movimientos.nro_cuenta%TYPE;
  v_cod_moneda        ba_monedas.cod_moneda%TYPE;
  v_cod_modulo        ge_cuentas.cod_modulo%TYPE;
  v_cod_modalidad     ge_cuentas.cod_modalidad%TYPE;
  v_cod_oficina       ge_cuentas.cod_oficina%TYPE;
  v_cod_banco         ge_bancos.cod_banco%type;
  --
  v_hora              ge_movimientos.hora%TYPE := fug_ini_hora(SYSDATE,'HH24:MI:SS');
  v_cod_tra_padre     ge_movimientos.cod_tra_padre%TYPE;
  v_cod_tra_pad_sipap ge_movimientos.cod_tra_padre%type;
  v_nro_secuencia     ge_movimientos.nro_secuencia%TYPE := 0;
  v_swift             ge_bancos.cod_swift%TYPE;
  v_cod_usuario       ba_usuarios.cod_usuario%TYPE;
  v_hab_tra_sipap     varchar2(1) := nvl(fug_obt_pardinamico('IND_CON_HAB_TRA_SIPAP'), 'N');
  v_hab_tra_def       varchar2(1) := nvl(fug_obt_pardinamico('IND_CON_HAB_TAB_DEF'), 'N');
  v_msj               varchar2(250);
  v_nro_cta_bancaria  cc_cta_bancarias.nro_cta_bancaria%type;
  v_nro_cta_cre_glo   ge_snp_transferencias.nro_cta_beneficiario%type;
  v_nro_proceso  ah_con_dia_cab.nro_con_dia%type;
  v_cod_persona       ba_personas.cod_persona%type;
  v_exi_arc_fecha     varchar2(1);
  v_fec_pro_arc       ah_con_dia_cab.fec_proceso%type;
  --
  v_nro_ref_snp       ge_snp_transferencias.nro_referencia%TYPE := NULL;
  r_gmovi             ge_movimientos%ROWTYPE;
  v_es_nocturno       VARCHAR2(1) := 'N';
  v_can_registros     number;
  v_can_reg_tmp       ah_con_dia_res_tmp.can_registro%type;
  --
  v_lugar             varchar2(50);
  r_log               ta_logs%ROWTYPE;
  v_error            ah_con_dia_det.error%TYPE;
  --Liquidacion de tarjeta de Debito virtual, debito y combo
  CURSOR c_mov_gp IS
    SELECT cod_mon_original cod_moneda, sum(decode(t.cod_deb_cre, 0, imp_tot_movimiento,imp_tot_movimiento*-1 )) mto_total
      FROM ah_con_dia_det_tmp t
       WHERE t.tip_producto in (select distinct p.ref_externa from ta_tipos p
                                 where p.cod_ent_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL'))
     GROUP BY cod_mon_original
     ORDER BY 1;

PROCEDURE pr_ins_transferencia(p_hora                 IN VARCHAR2,
                                 p_fecha                IN DATE DEFAULT NULL,
                                 p_cod_usuario          IN VARCHAR2 DEFAULT NULL,
                                 p_plataforma           IN ge_snp_transferencias.plataforma%TYPE DEFAULT 'X', --X-Adapter
                                 p_ind_enviado          IN VARCHAR2 DEFAULT 'S',
                                 p_swi_pte_beneficiario IN VARCHAR2,
                                 p_beneficiario         IN VARCHAR2,
                                 p_cod_persona          IN ba_personas.cod_persona%type,
                                 p_cta_beneficiario     IN VARCHAR2,
                                 p_nro_cta_bancaria     IN VARCHAR2,
                                 p_nro_cta_ban_glo      IN VARCHAR2) IS
    v_fecha           DATE := p_fecha;
    v_cod_usuario     VARCHAR2(30) := p_cod_usuario;
    v_cod_programa    VARCHAR2(50) := NULL;
    v_gen_workflow    VARCHAR2(1) := 'N';
    v_nro_referencia  ge_snp_transferencias.nro_referencia%TYPE := NULL;
    v_nro_ref_externa ge_snp_transferencias.nro_ref_externa%TYPE := NULL;
    v_msj_swift       VARCHAR2(4000);
    v_cod_tip_documento ba_personas.cod_tip_documento%type;
    v_nro_documento ba_personas.nro_documento%type;
    v_direccion ba_direcciones.direccion%type;
  BEGIN
    begin
        pas_snp.pr_gen_mov_snp(p_hora            => p_hora,
                             p_fecha           => v_fecha,
                             p_cod_usuario     => v_cod_usuario,
                             p_gen_workflow    => v_gen_workflow,
                             p_origen          => 'I',
                             p_plataforma      => p_plataforma,
                             p_nro_ref_externa => v_nro_ref_externa,
                             p_ind_enviado     => p_ind_enviado,
                             p_cod_programa    => v_cod_programa,
                             p_nro_referencia  => v_nro_referencia);
    exception
      when others then
        raise_application_error(-20000, 'No se ah podido generar la transferencia de sipap. ' || sqlerrm);
    end;
    begin
      select d.cod_tip_documento, d.nro_documento
        into v_cod_tip_documento, v_nro_documento
        from ba_personas d
       where cod_persona = p_cod_persona;
    exception
      when others then
        raise_application_error(-20000, 'No se encuentra el numero de documento. '||sqlerrm);
    end;

    begin
      select d.direccion
        into v_direccion
        from ba_direcciones d
       where cod_persona = p_cod_persona
         and d.principal = 'S';
    exception
      when others then
        raise_application_error(-20000, 'No se encuentra la direccion. '||sqlerrm);
    end;

    begin
      UPDATE ge_snp_transferencias
         SET cod_swi_pte_beneficiario = p_swi_pte_beneficiario,
             cod_per_beneficiario     = p_cod_persona,
             nom_beneficiario         = p_beneficiario,
             dir_beneficiario         = v_direccion,
             cod_tip_doc_beneficiario = v_cod_tip_documento,
             nro_doc_beneficiario     = v_nro_documento,
             nro_cta_beneficiario     = p_cta_beneficiario,
             tip_mensaje              = 'CRED',
             nro_cta_pte_solicitante  = p_nro_cta_bancaria,
             nro_cta_pte_beneficiario = p_nro_cta_ban_glo
       WHERE nro_referencia = v_nro_referencia;
    exception
      when others then
        raise_application_error(-20000, 'No se ha podido actualizar la transferencia de sipap. ' || sqlerrm);
    end;

    IF pas_snp.fu_obt_cod_error <> 0 THEN
       raise_application_error(-20000,
                                'Error en proceso sipap. ' ||
                                pas_snp.fu_obt_cod_error || '-' ||
                                pas_snp.fu_obt_msj_error);
    END IF;
    v_msj_swift := pas_snp.fu_obt_msj_mt103(v_nro_referencia, 'N');
    begin
      UPDATE ge_snp_transferencias
         SET msj_swift = v_msj_swift
       WHERE nro_referencia = v_nro_referencia;
    exception
      when others then
        raise_application_error(-20000, 'No se ha podido actualizar la transferencia de sipap(msj_swift). ' || sqlerrm);
    end;

    pas_snp.pr_gen_arc_swift(v_nro_referencia);
    v_nro_ref_snp := v_nro_referencia;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'No se ha podido procesar la transferencia de sipap. ' || sqlerrm);
  END;
  --
  PROCEDURE pr_ins_mov_no_gen IS
    v_fec_anterior ge_calendarios.fec_anterior%type := pag_cal.FU_OBT_FEC_ANTERIOR(1);
    CURSOR c_mov_no_gen IS
      SELECT a.request_id,
             a.imp_mon_original,
             a.cod_comercio,
             a.nom_comercio,
             a.fec_operacion,
             a.hor_operacion,
             to_char(a.cod_mon_original) cod_mon_original,
             'MOVIMIENTOS NO PROCESADOS EN ITGF' observacion
        FROM ah_con_dia_det_tmp a
       WHERE a.tip_producto in (select distinct p.ref_externa from ta_tipos p
                                where p.cod_ent_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL'))
         and not exists
         (SELECT 'S'
                FROM cj_log_glo_pro c
               WHERE a.request_id = c.nro_transaccion
                 AND c.cod_estado = 200
                 AND c.fecha = v_fec_anterior)
      UNION
      SELECT c.nro_transaccion,
             c.mto_total,
             null,
             c.nom_comercio,
             c.fecha, --to_char(c.fecha, 'yyyymmdd'),
             c.hora,
             c.cod_moneda,
             'MOVIMIENTOS NO PROCESADOS EN GLOBAL PROCESSING'
        FROM cj_log_glo_pro c
       WHERE c.fecha = v_fec_anterior
         AND cod_estado = 200
         AND not exists
       (SELECT 'S'
                FROM ah_con_dia_det_tmp a
               WHERE a.tip_producto in (select distinct p.ref_externa from ta_tipos p
                                         where p.cod_ent_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL'))
                 and a.request_id = c.nro_transaccion);
  BEGIN
    FOR c IN c_mov_no_gen LOOP
      begin
        insert into it.ge_mov_no_pro_gp
          (nro_transaccion,
           fec_proceso,
           hor_proceso,
           monto,
           cod_comercio,
           nom_comercio,
           cod_moneda,
           OBSERVACION)
        values
          (c.request_id,
           c.fec_operacion,
           c.hor_operacion,
           c.imp_mon_original,
           c.cod_comercio,
           c.nom_comercio,
           c.cod_mon_original,
           c.observacion);
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000, 'No se ha podido insertar la conciliacion. ' || sqlerrm);
      END;
    END LOOP;
  END;

  --
PROCEDURE lp_val_imp_archivo(p_nro_con_dia ah_con_dia_cab.nro_con_dia%type) IS
    CURSOR c_tmp_cab IS
      SELECT c.tip_registro, c.cod_marca, c.cod_ent_emisora, c.fec_proceso,c.hor_proceso, c.archivo, c.des_archivo, c.filtros
        from AH_CON_DIA_CAB_TMP c;
  BEGIN
    --configuracion prueba
    Begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
    end;
    FOR tc IN c_tmp_cab LOOP
      BEGIN
        insert into AH_CON_DIA_CAB (nro_con_dia, tip_registro, cod_marca, cod_ent_emisora, fec_proceso, hor_proceso, archivo, des_archivo, filtros)
        values (p_nro_con_dia, tc.tip_registro, tc.cod_marca, tc.cod_ent_emisora, to_char(to_date(tc.fec_proceso, 'yyyymmdd'), 'dd/mm/yyyy'), tc.hor_proceso, tc.archivo, tc.des_archivo, tc.filtros);
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000, 'Error al insertar la cabecera de la conciliacion diaria. ' || sqlerrm);
      END;
    END LOOP;

    if nvl(v_hab_tra_def, 'N') = 'S' then
       BEGIN
            insert into AH_CON_DIA_DET (nro_con_dia,
                                        tip_registro,
                                        nro_tarjeta,
                                        cod_marca,
                                        cod_ent_emisora,
                                        cod_oficina,
                                        nro_cuenta,
                                        tip_socio,
                                        cod_gru_cta_cte,
                                        cod_tip_transaccion,
                                        cod_comercio,
                                        nom_comercio,
                                        cod_pos_comercio,
                                        cod_autorizacion,
                                        cod_ica_adquiriente,
                                        cod_movimiento,
                                        des_movimiento,
                                        nro_comprobante,
                                        cod_tip_plan,
                                        can_pla_cuotas,
                                        nro_cuo_vigente,
                                        fec_operacion,
                                        hor_operacion,
                                        fec_presentacion,
                                        fec_cie_cta_cte,
                                        fec_clearing,
                                        fec_diferimiento,
                                        mcc,
                                        cod_mon_movimiento,
                                        imp_mon_movimiento,
                                        cod_mon_original,
                                        imp_mon_original,
                                        imp_interes,
                                        imp_iva,
                                        imp_tot_movimiento,
                                        imp_desc_fin_otorgado,
                                        imp_desc_fin_oto_iva,
                                        imp_cuota,
                                        imp_int_cuota,
                                        imp_iva_cuota,
                                        imp_tot_cuota,
                                        cod_deb_cre,
                                        tip_amortizacion,
                                        tip_tarjeta,
                                        tna,
                                        tae,
                                        tai,
                                        imp_ara_emisor,
                                        sig_iva_arancel,
                                        imp_iva_ara_emisor,
                                        sig_iva_arancel2,
                                        mot_mensaje,
                                        imp_compensacion,
                                        sig_imp_compensacion,
                                        imp_percep,
                                        sig_percep,
                                        tip_producto,
                                        fec_cie_comercios,
                                        plan,
                                        mon_compensacion,
                                        imp_autorizacion,
                                        sig_imp_autorizacion,
                                        mon_autorizacion,
                                        imp_aut_convenio,
                                        sig_imp_aut_convenio,
                                        mon_aut_convenio,
                                        imp_ipm_de6,
                                        sig_imp_ipm,
                                        mon_ipm,
                                        id_auto,
                                        id_cod_auto,
                                        cta_externa,
                                        request_id,
                                        imp_percep_27,
                                        sig_percep_27,
                                        imp_iva_ser_digitales,
                                        sig_imp_iva_ser_dig,
                                        imp_iibb,
                                        sig_imp_iibb,
                                        cod_pcia_iibb,
                                        estado,
                                        filter,
                                        procesado,
                                        error,
                                        imp_rg4815,
                                        sig_rg4815,
                                        extracash,
                                        imp_extracash,
                                        sig_extracash,
                                        tra_tokenizada,
                                        tas_isa,
                                        tra_origen,
                                        imp_rg5272,
                                        sig_imp_rg5272,
                                        fec_transferencia,
                                        ref_adquiriente,
                                        id_adquiriente,
                                        nro_ref_recupero,
                                        id_terminal,
                                        nom_terminal,
                                        id_transaccion,
                                        token,
                                        billetera,
                                        per_tra_fondos)
                               select p_nro_con_dia,
                                        c.tip_registro,
                                        c.nro_tarjeta,
                                        c.cod_marca,
                                        c.cod_ent_emisora,
                                        c.cod_oficina,
                                        c.nro_cuenta,
                                        c.tip_socio,
                                        c.cod_gru_cta_cte,
                                        c.cod_tip_transaccion,
                                        trim(c.cod_comercio),
                                        trim(c.nom_comercio),
                                        trim(c.cod_pos_comercio),
                                        c.cod_autorizacion,
                                        c.cod_ica_adquiriente,
                                        c.cod_movimiento,
                                        trim(c.des_movimiento),
                                        c.nro_comprobante,
                                        c.cod_tip_plan,
                                        c.can_pla_cuotas,
                                        c.nro_cuo_vigente,
                                        c.fec_operacion,
                                        c.hor_operacion,
                                        c.fec_presentacion,
                                        c.fec_cie_cta_cte,
                                        c.fec_clearing,
                                        c.fec_diferimiento,
                                        c.mcc,
                                        c.cod_mon_movimiento,
                                        trunc(c.imp_mon_movimiento), --30
                                        c.cod_mon_original,
                                        c.imp_mon_original,
                                        c.imp_interes,
                                        c.imp_iva,
                                        c.imp_tot_movimiento,
                                        c.imp_desc_fin_otorgado,
                                        c.imp_desc_fin_oto_iva,
                                        c.imp_cuota,
                                        c.imp_int_cuota,
                                        c.imp_iva_cuota,
                                        c.imp_tot_cuota,
                                        c.cod_deb_cre,
                                        c.tip_amortizacion,
                                        c.tip_tarjeta,
                                        c.tna,
                                        c.tae,
                                        c.tai,
                                        c.imp_ara_emisor,
                                        c.sig_iva_arancel,
                                        c.imp_iva_ara_emisor,
                                        c.sig_iva_arancel2,
                                        c.mot_mensaje,
                                        c.imp_compensacion,
                                        c.sig_imp_compensacion,
                                        c.imp_percep,
                                        c.sig_percep,
                                        c.tip_producto,
                                        c.fec_cie_comercios,
                                        trim(c.plan),
                                        c.mon_compensacion,
                                        c.imp_autorizacion,
                                        c.sig_imp_autorizacion,
                                        c.mon_autorizacion,
                                        c.imp_aut_convenio,
                                        c.sig_imp_aut_convenio,
                                        c.mon_aut_convenio,
                                        c.imp_ipm_de6,
                                        c.sig_imp_ipm,
                                        c.mon_ipm,
                                        c.id_auto,
                                        trim(c.id_cod_auto),
                                        trim(c.cta_externa),
                                        trim(c.request_id),
                                        c.imp_percep_27,
                                        c.sig_percep_27,
                                        trunc(c.imp_iva_ser_digitales),
                                        c.sig_imp_iva_ser_dig,
                                        c.imp_iibb,
                                        c.sig_imp_iibb,
                                        c.cod_pcia_iibb,
                                        c.estado,
                                        trim(c.filter),
                                        'N',
                                        decode(
                            (select distinct '1'
                            from ge_cta_clientes s
                            where s.relacion = 'P'
                            and s.nro_cuenta=c.cta_externa),'1',null,'Cuenta inválida') error,
                                        imp_rg4815,
                                        sig_rg4815,
                                        extracash,
                                        imp_extracash,
                                        sig_extracash,
                                        tra_tokenizada,
                                        tas_isa,
                                        tra_origen,
                                        imp_rg5272,
                                        sig_imp_rg5272,
                                        fec_transferencia,
                                        ref_adquiriente,
                                        id_adquiriente,
                                        nro_ref_recupero,
                                        id_terminal,
                                        nom_terminal,
                                        id_transaccion,
                                        token,
                                        billetera,
                                        per_tra_fondos
                                        from AH_CON_DIA_DET_TMP c;
          EXCEPTION
            WHEN OTHERS THEN
              raise_application_error(-20000, 'Error al insertar el detalle de la conciliacion diaria. ' || sqlerrm);
          END;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
       raise_application_error(-20000, 'Error al insertar en las tablas definitivas. ' || sqlerrm);
  END;
  PROCEDURE pr_trg_activar(p_accion in number) is
  v_mensaje varchar2(500);
begin
  --Accion
  --0 Desactivar
  --1 Activar
    if p_accion=0 then
      sql_util.ejecute_dml('ALTER TRIGGER AA_AH_CON_DIA_DET DISABLE', v_mensaje);
      sql_util.ejecute_dml('ALTER TRIGGER AB_AH_CON_DIA_DET DISABLE', v_mensaje);
    elsif p_accion=1 then
      sql_util.ejecute_dml('ALTER TRIGGER AA_AH_CON_DIA_DET ENABLE', v_mensaje);
      sql_util.ejecute_dml('ALTER TRIGGER AB_AH_CON_DIA_DET ENABLE', v_mensaje);
    end if;
    if v_mensaje is not null then
      r_log.comentario:=v_mensaje;
      pat_igp.pr_ins_log(r_log);
    end if;
exception
  when others then
      sql_util.ejecute_dml('ALTER TRIGGER AA_AH_CON_DIA_DET ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_AH_CON_DIA_DET ENABLE', r_log.comentario);
      pat_igp.pr_ins_log(r_log);
end;
  PROCEDURE pr_env_mai_conciliacion (p_nro_con_dia ah_con_dia_res.nro_con_dia%type) IS
    cursor c_res is
    select r.fecha, r.cod_moneda, r.monto
      from ah_con_dia_res r
     where r.nro_con_dia = p_nro_con_dia;
    v_dir_correo ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('MAI_CON_LIQ_GLOBAL');
  BEGIN
    if v_dir_correo is not null then
      if p_nro_con_dia = 0 then
         it_mail.mail(fug_obt_dir_correo,
                       v_dir_correo,
                       'Error Liquidacion Mastercard',
                       'Ha ocurrido un error en el proceso de Liquidacion. Favor verificar en el log.');
      else
        for c in c_res loop
          it_mail.mail(fug_obt_dir_correo,
                       v_dir_correo,
                       'Liquidacion Mastercard',
                       'Se ha procesado el archivo de transacciones diarias de Global Procesing. A continuacion los datos para la liquidacion: ' ||
                       chr(10) || 'Fecha: ' || to_char(v_fec_actual, 'dd/mm/yyyy') || chr(10) ||
                       'Monto: ' || TRIM(to_char(c.monto, '999,999,999,999,999.99')) ||' '||c.cod_moneda||
                       chr(10) || chr(10) || 'Atentamente.');
        end loop;
     end if;
    end if;
  END;
  --
BEGIN
  --inicio
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  --v_hora       := pag_gen.fu_obt_sig_segundo(v_hora);
  v_fec_actual := pag_cal.fu_obt_fec_actual(5);
  v_cod_tra_padre   := 100; ---Transaccion Padre de la Operacion
  v_cod_tra_pad_sipap := 303;
  v_cod_usuario := user;
  --
  r_log.nom_proceso := 'PRA_CON_DIA_TRA_GP';
  r_log.fec_hor_ini := SYSDATE;
  r_log.comentario  := '*** Inicio proceso de archivo T2001D - Transacciones Diarias***';
  pat_igp.pr_ins_log(r_log, FALSE);
  --Deshabilitar TRIGGERS DE AUDITORIA --
  pr_trg_activar(0);

  begin
    select to_char(to_date(fec_proceso,'yyyy/mm/dd'),'dd/mm/yyyy')--fec_proceso
      into v_fec_pro_arc
      from ah_con_dia_cab_tmp;
  exception
    when others THEN
      r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || ' - '||'al buscar la cabecera del archivo'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm;
      pat_igp.pr_ins_log(r_log);
      raise_application_error(-20000, 'Error al buscar la cabecera del archivo. '||sqlerrm);
  end;

  begin
    select distinct 'S'
      into v_exi_arc_fecha
      from ah_con_dia_cab t
     where t.fec_proceso = v_fec_pro_arc;
  exception
    when others then
      v_exi_arc_fecha := 'N';
  end;

  if nvl(v_exi_arc_fecha, 'N')= 'S' THEN
    r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || ' - '||'El archivo ya fue conciliado'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm;
    pat_igp.pr_ins_log(r_log);
    raise_application_error(-20000, 'El archivo ya fue conciliado.');
  end if;

  begin
    select count(*)
      into v_can_reg_tmp
      from ah_con_dia_det_tmp;
  exception
    when others then
      v_can_reg_tmp := 0;
  end;

  begin
    select c.can_registro
      into v_can_registros
      from ah_con_dia_res_tmp c;
  exception
    when others THEN
      r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || ' - '||'Error al buscar el resumen del archivo'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm;
      pat_igp.pr_ins_log(r_log);
      raise_application_error(-20000,'Error al buscar el resumen del archivo. '||sqlerrm);
  end;

  if nvl(v_can_registros, 0) <> nvl(v_can_reg_tmp, 0) THEN
    r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || ' - '||'Cantidad de Detalle no coincide con el resumen'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm;
    pat_igp.pr_ins_log(r_log);
    raise_application_error(-20000, 'Cantidad de Detalle no coincide con el resumen.');
  end if;

  Begin
      Select cod_ofi_matriz into v_cod_ofi_matriz from ge_par_generales;
  exception
    when others then
      v_cod_ofi_matriz := 1;
  end;

  BEGIN
    select s_nro_con_dia.nextval
      into v_nro_proceso
      from dual;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al obtener el nro. de secuencia. ' || sqlerrm);
  END;

  --pr_ins_mov_no_gen;
  lp_val_imp_archivo(v_nro_proceso);
  commit;
  it.prt_pro_dev_con_gp();--proceso de devolucion contado concepto 801
  it.prt_reg_tra_tc_gp;--proceso de transacciones
  it.prt_env_mai_tra_gp(v_nro_proceso);--notificacion de las transacciones fallidas
  r_log.fec_hor_ini := SYSDATE;
  r_log.comentario  := '*** Finaliza proceso de archivo T2001D - Transacciones Diaras ***';
  pat_igp.pr_ins_log(r_log, FALSE);
  --Habilitar TRIGGERS DE AUDITORIA --
  pr_trg_activar(1);

EXCEPTION
  WHEN OTHERS THEN
    r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || ' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm;
    pat_igp.pr_ins_log(r_log);
    --pr_env_mai_conciliacion(0);
    prg_ins_log_programas('PRA_CON_DIA_TRA_GP',substr(sqlerrm,1,4000));
    --Habilitar TRIGGERS DE AUDITORIA --
    pr_trg_activar(1);
END;
/
