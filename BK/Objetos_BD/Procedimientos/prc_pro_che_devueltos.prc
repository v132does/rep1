CREATE OR REPLACE PROCEDURE IT.prc_pro_che_devueltos(p_cdofici     in number,
                                                  p_reg_pro     in out number,
                                                  p_reg_err     in out number,
                                                  p_reg_tot     in out number,
                                                  p_insertar    in varchar2 default 'N',
                                                  p_tip_importe in number,
                                                  p_cod_moneda  in varchar2) is

  /*
  -------------------------------------------------------------------------
  AVISO IMPORTANTE: IT CONSULTORES S.A. es titular de todos los derechos
  del Software IT GESTION FINANCIERA, incluyendo los derechos del autor
  sobre dicho software y por tanto, propietario del citado software y de
  cualquier modificación y/o copia del mismo. Por este motivo, este programa
  del Software IT GESTIÓN FINANCIERA debe ser mantenido bajo una adecuada
  seguridad, y asegurar con ello que no haya acceso a copias o utilización no
  autorizada por IT CONSULTORES S.A. COPYRIGHT IT CONSULTORES S.A. 2017.
  Todos los derechos reservados.
  ------------------------------------------------------------------------
  */

  v_fcdehoy date := pag_cal.FU_OBT_FEC_ACTUAL(4);
  -- Variables globales.
  g_modali       number(3) := 41;
  g_cuenta       varchar2(15) := '0';
  g_ok           varchar2(1) := 'N';
  g_error        varchar2(10000) := null;
  g_nro_boleta   ge_movimientos.nro_documento%type;
  g_cta_dep      ge_movimientos.nro_cuenta%type;
  g_mon_dep      ge_movimientos.cod_moneda%type;
  g_tiperr       varchar2(3);
  g_oficta       number(3) := to_number('0');
  g_est_che      varchar2(1);
  g_cuenta_cert  ge_cuentas.nro_cuenta%type;
  g_hora         ge_movimientos.hora%type;
  g_wk_nrsecuen  ge_movimientos.nro_secuencia%type := 0;
  v_compensacion varchar(1);
  v_pendiente    varchar2(1) := 'N';
  -- Datos de la Cuenta
  v_exi             varchar2(1) := 'N';
  v_cod_modalidad   ge_cuentas.cod_modalidad%type;
  v_cod_modulo      ge_cuentas.cod_modulo%type;
  v_cod_oficina     ge_cuentas.cod_oficina%type;
  v_cod_ofi_usuario ba_oficinas.cod_oficina%type;
  v_nro_cuenta      ge_cuentas.nro_cuenta%type;
  v_estado          ge_cuentas.estado%type;
  v_cod_moneda      ge_cuentas.cod_moneda%type;
  v_saldo           ge_cuentas.sal_contable%type;
  v_nro_che_inicial cc_chequeras.nro_che_inicial%type;
  v_cod_transaccion ge_transacciones.cod_transaccion%type;
  v_cod_banco       ge_bancos.cod_banco%type;
  v_cod_causa       varchar2(50);
  v_cod_cau_sec       varchar2(50);
  v_tipo            ge_bancos.tipo%type;
  v_tip_dev         varchar2(10);
  ---
  PROCEDURE pp_genera_movimiento(p_cod_transaccion in number,
                                 p_IMPORTE         IN NUMBER,
                                 p_NRCHEQU         IN NUMBER,
                                 p_fe_emision      in date,
                                 p_secuencia       out ge_movimientos.nro_secuencia%type) IS

    v_concepto ge_movimientos.concepto%type;
    r_gmovi    GE_MOVIMIENTOS%rowtype;
  BEGIN
    if nvl(v_compensacion, 'N') = 'S' then
      v_concepto := 'COMP. DIRECTA -' ||fug_obt_parcausales((pae_uti.FU_OBT_VALOR(v_cod_causa,1,'S')),
                                        'COD_DEV_BCP') || ' - ' ||fug_obt_des_causa(v_cod_causa);
    else
      v_concepto := fug_obt_parcausales((pae_uti.FU_OBT_VALOR(v_cod_causa,1,'S')),'COD_DEV_BCP') || '-' ||
                    fug_obt_des_causa(v_cod_causa);
    end if;

    g_wk_nrsecuen := to_number(g_wk_nrsecuen) + 1;
    g_hora        := pag_gen.fu_obt_sig_segundo(g_hora);

    r_gmovi.cod_usuario   := user;
    r_gmovi.hora          := g_hora;
    r_gmovi.nro_secuencia := g_wk_nrsecuen;
    r_gmovi.cod_oficina   := v_cod_oficina;
    If nvl(g_est_che, 'x') <> 'C' then
      r_gmovi.nro_cuenta    := v_nro_cuenta;
      r_gmovi.cod_modulo    := v_cod_modulo;
      r_gmovi.cod_modalidad := v_cod_modalidad;
    else
      r_gmovi.nro_cuenta    := g_cuenta_cert;
      r_gmovi.cod_modulo    := 4;
      r_gmovi.cod_oficina   := fug_obt_ofi_cuenta(g_cuenta_cert);
      r_gmovi.cod_modalidad := 44;
    end if;
    r_gmovi.cod_moneda := v_cod_moneda;
    if to_char(p_fe_emision, 'mmyyyy') = to_char(v_fcdehoy, 'mmyyyy') then
      r_gmovi.fec_valor := p_fe_emision;
    else
      r_gmovi.fec_valor := v_fcdehoy;
    end if;
    r_gmovi.fecha := v_fcdehoy;
    
    IF g_error like '%Cuenta Cancelada%' or g_error like '%Cuenta Cerrada%' or nvl(g_est_che, 'x') = 'O' then
      r_gmovi.cod_tra_padre   := 138;
      r_gmovi.cod_transaccion := 138;
      r_gmovi.concepto        := 'Devolución de cheq.:' || p_NRCHEQU;
    else
      r_gmovi.cod_tra_padre   := 322;
      r_gmovi.cod_transaccion := p_cod_transaccion;
      r_gmovi.concepto        := v_concepto;
    end if;

    r_gmovi.nro_documento  := p_NRCHEQU;
    r_gmovi.monto          := p_IMPORTE;
    r_gmovi.emi_aviso      := 'S';
    r_gmovi.cod_ofi_origen := fug_obt_ofi_usuario(user); -- oficina del usuario
    r_gmovi.estado         := 'N';
    r_gmovi.reversado      := 'N';
    r_gmovi.protegido      := 'N';
    r_gmovi.cod_causa      := v_cod_causa;
    r_gmovi.cod_banco      := v_cod_banco;
    r_gmovi.cod_mod_padre  := v_cod_modulo;
    r_gmovi.cod_mad_padre  := v_cod_modalidad;
    p_secuencia            := r_gmovi.nro_secuencia;

    PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N');

  exception
    when others then
      If sqlcode <= -20000 then
      
        raise;
      else
        raise_application_error(-20010,'Error en pp_gen_mov ' ||replace(sqlerrm, 'ORA-', ''));
      End if;
  END;

  PROCEDURE pp_genera_movimiento_cargo(p_cod_transaccion in number,
                                       p_IMPORTE         IN NUMBER,
                                       p_NRCHEQU         IN NUMBER,
                                       p_fe_emision      in date,
                                       p_nro_documento   in number,
                                       p_val_tasa        in number default null,
                                       p_cod_tasa        in number default null,
                                       p_secuencia       in out ge_movimientos.nro_secuencia%type) IS

    v_concepto ge_movimientos.concepto%type;
    r_gmovi    GE_MOVIMIENTOS%rowtype;

  BEGIN
    if p_cod_transaccion = 503 then
      r_gmovi.cod_oficina := v_cod_oficina;
      r_gmovi.nro_cuenta  := v_nro_cuenta;
      r_gmovi.emi_aviso   := 'S';
    else
      r_gmovi.cod_oficina := fug_obt_ofi_camara(v_cod_oficina);
      r_gmovi.referencia  := v_nro_cuenta;
      r_gmovi.emi_aviso   := 'N';
    end if;

    if to_char(p_fe_emision, 'mmyyyy') = to_char(v_fcdehoy, 'mmyyyy') then
      r_gmovi.fec_valor := p_fe_emision;
    else
      r_gmovi.fec_valor := v_fcdehoy;
    end if;
    g_wk_nrsecuen := g_wk_nrsecuen + 1;
    r_gmovi.nro_secuencia := g_wk_nrsecuen;-- + 1;
    IF p_cod_transaccion = 503 THEN
        pag_cta.pr_act_operacion(v_nro_cuenta,
                                 g_hora,
                                 'D',
                                 v_cod_moneda,
                                 p_importe,
                                 322,
                                 p_cod_transaccion,
                                 p_nro_documento,
                                 NULL,
                                 r_gmovi.cod_oficina, --:variables.wk_cdofici
                                 4, --:variables.wk_cdmodul
                                 41, --:variables.wk_cdmodal
                                 p_cod_tasa,
                                 p_val_tasa,
                                 p_nrchequ, --concepto
                                 r_gmovi.emi_aviso,
                                 r_gmovi.nro_secuencia,
                                 r_gmovi.fec_valor,
                                 null,
                                 null);
        if pag_cta.fu_obt_cod_error() <> 0 then
           g_error := pag_cta.fu_obt_cod_error() || ' - ' ||pag_cta.fu_obt_msj_error();
        end if;
    ELSE
        --r_gmovi.nro_secuencia := p_secuencia + 1;
        r_gmovi.cod_usuario   := user;
        r_gmovi.hora          := g_hora;

        r_gmovi.cod_mod_padre   := 4;
        r_gmovi.cod_mad_padre   := 41;
        r_gmovi.cod_tra_padre   := 322;
        r_gmovi.cod_transaccion := p_cod_transaccion;
        r_gmovi.cod_modulo      := v_cod_modulo;
        r_gmovi.cod_modalidad   := v_cod_modalidad;
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.fecha          := v_fcdehoy;
        r_gmovi.cod_tasa       := P_COD_TASA;
        r_gmovi.val_tasa       := P_VAL_TASA;
        r_gmovi.nro_documento  := p_nro_documento;
        r_gmovi.monto          := p_IMPORTE;
        r_gmovi.cod_ofi_origen := v_cod_oficina;
        r_gmovi.concepto       := p_NRCHEQU;
        r_gmovi.estado         := 'N';
        r_gmovi.reversado      := 'N';
        r_gmovi.protegido      := 'S';
        p_secuencia            := r_gmovi.nro_secuencia;

        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N');
    END IF;
  exception
    when others then
      If sqlcode <= -20000 then
        raise;
      else
        raise_application_error(-20010,
                                'Error en pp_gen_mov_car ' ||
                                replace(sqlerrm, 'ORA-', ''));
      End if;
  END;

  PROCEDURE pp_gen_mov_pendiente(p_mto_total       in number,
                                 p_cod_modulo      in number,
                                 p_cod_modalidad   in number,
                                 p_cod_transaccion in number,
                                 p_cod_moneda      in varchar2,
                                 p_cod_tasa        in number,
                                 p_val_tasa        in number,
                                 p_fec_emision     in date,
                                 p_hora            in varchar2,
                                 p_nro_cuenta      in varchar2,
                                 p_nro_documento   in number) IS
    v_nro_documento ge_mov_pendientes.nro_documento%type;
    v_concepto      ge_mov_pendientes.concepto%type;
    v_fec_vto       ge_mov_pendientes.fec_vencimiento%type := null;

  BEGIN

    --Obtener siguiente nro. de documento para la operacion
    begin
      select distinct substr(descripcion, 1, 35)
        into v_concepto
        from ge_transacciones t
       where t.cod_modulo = p_cod_modulo
         and t.cod_modalidad = p_cod_modalidad
         and t.cod_transaccion = p_cod_transaccion
         and t.cod_tasa is not null
         and t.rutina1 is null
         and nvl(t.afecta, 'N') = 'N'
         and fug_obt_tip_mov_contable(t.cod_modulo,
                                      t.cod_modalidad,
                                      t.cod_transaccion) = 'C';
    exception
      when no_data_found then
        v_concepto := null;
    end;

    if fug_ver_tra_comision(p_cod_modulo,p_cod_modalidad,p_cod_transaccion) = 'S' then
      begin
        select a.fec_vencimiento
          into v_fec_vto
          from ge_cuentas a
         where a.nro_cuenta = p_nro_cuenta;
      exception
        when no_data_found then
          v_fec_vto := null;
      end;
    end if;

    --Si esta todo Ok insertar en GE_MOV_PENDIENTES
    insert into ge_mov_pendientes
      (nro_cuenta,
       fecha,
       cod_modulo,
       cod_modalidad,
       cod_transaccion,
       cod_mod_padre,
       cod_mad_padre,
       cod_tra_padre,
       monto,
       saldo,
       hora,
       cod_usuario,
       cod_moneda,
       cod_oficina,
       estado,
       cod_ofi_origen,
       concepto,
       cod_tasa,
       val_tasa,
       nro_documento,
       observacion,
       car_manual,
       cod_persona,
       referencia,
       fec_vencimiento)
    values
      (p_nro_cuenta,
       P_FEC_EMISION,
       p_cod_modulo,
       p_cod_modalidad,
       p_cod_transaccion,
       p_cod_modulo,
       p_cod_modalidad,
       p_cod_transaccion,
       p_mto_total,
       p_mto_total,
       p_hora,
       substr(user, 1, 10),
       v_cod_moneda,
       v_cod_oficina,
       'I',
       v_cod_oficina,
       v_concepto,
       p_cod_tasa,
       p_val_tasa,
       p_nro_documento,
       'Insuficiencia de Saldo de la cuenta',
       'S',
       fug_obt_cli_principal(p_nro_cuenta),
       p_nro_cuenta,
       null /*v_fec_vto*/);
    ------------------------------------------------------------------------------------------------------------------
  exception
    when others then
      If sqlcode <= -20000 then
        raise;
      else
        raise_application_error(-20010,'Error en pp_gen_mov ' ||replace(sqlerrm, 'ORA-', ''));
      End if;
  END;

  procedure pp_actualizar_cuenta(p_oficina       in out number,
                                 p_cuenta        in out varchar2,
                                 p_importe       in number,
                                 p_cod_modalidad in number,
                                 p_proceso       in number) is
    v_nrcuent ge_cuentas.nro_cuenta%type;
  begin

    if p_proceso = 1 then
      If p_cod_modalidad = 41 then
        select nro_cuenta
          into v_nrcuent
          from cc_cta_corrientes
         where nro_cuenta = p_cuenta
           for update of cc_cta_corrientes.nro_cuenta;

        update cc_cta_corrientes a
           set fec_ult_movimiento = v_fcdehoy,
               hor_ult_movimiento = g_hora,
               sal_total          = nvl(sal_total, 0) + nvl(p_importe, 0)
         Where nro_cuenta = p_cuenta;

        If sql%notfound then
          Raise_application_error(-20004, 'Al actualizar CC_CTA_CORRIENTES ');
        End if;
      else
        update cc_cta_bancarias
           set fec_ult_movimiento = v_fcdehoy,
               hor_ult_movimiento = g_hora,
               sal_total          = nvl(sal_total, 0) + nvl(p_importe, 0)
         where nro_cuenta = p_cuenta;
        If sql%notfound then
          Raise_application_error(-20005, 'Al actualizar CC_CTA_BANCARIAS');
        End if;
      End if;
    else
      If p_cod_modalidad = 41 then
        select nro_cuenta
          into v_nrcuent
          from cc_cta_corrientes
         where nro_cuenta = p_cuenta
           for update of cc_cta_corrientes.nro_cuenta;

        update cc_cta_corrientes a
           set fec_ult_movimiento = v_fcdehoy,
               hor_ult_movimiento = g_hora,
               sal_total          = nvl(sal_total, 0) - nvl(p_importe, 0)
         Where nro_cuenta = p_cuenta;

        If sql%notfound then
          Raise_application_error(-20004, 'Al actualizar CC_CTA_CORRIENTES ');
        End if;
      else
        update cc_cta_bancarias
           set fec_ult_movimiento = v_fcdehoy,
               hor_ult_movimiento = g_hora,
               sal_total          = nvl(sal_total, 0) - nvl(p_importe, 0)
         where nro_cuenta = p_cuenta;
        If sql%notfound then
          Raise_application_error(-20005, 'Al actualizar CC_CTA_BANCARIAS');
        End if;
      End if;

    end if;
  exception
    when no_data_found then
      Raise_application_error(-20006,'Modalidad/Oficina/Cuenta ' ||to_char(v_cod_modalidad, '999') || '-' ||
                              to_char(p_oficina, '999') || '-' || p_cuenta ||' no existe!!!');
    when too_many_rows then
      Raise_application_error(-20007,'Existen varios registros para la cuenta ' ||p_cuenta);
    when others then
      If sqlcode <= -20000 then
        raise;
      else
        Raise_application_error(-20008,'Error en pp_act_cuenta ' ||replace(sqlerrm, 'ORA-', ''));
      End if;
  end;

  PROCEDURE pp_cheques_devueltos IS
    -- PROCESO PRINCIPAL DE DEVUELTOS
    ok                 boolean;
    v_est              varchar2(1);
    v_imp              number := 0;
    v_error            varchar2(1000);
    v_existe           number := 0;
    v_fecha            date;
    v_multa            cc_che_devueltos_tmp.multa%type := 0;
    v_cargo            ge_movimientos.cod_tra_padre%type;
    v_cod_tra_multa    ge_movimientos.cod_transaccion%type;
    v_cod_tas_multa    ge_movimientos.cod_tasa%type;
    v_val_tas_multa    ge_movimientos.val_tasa%type;
    v_val_multa        ge_movimientos.monto%type;
    v_cod_tra_impuesto ge_movimientos.cod_transaccion%type;
    v_cod_tas_impuesto ge_movimientos.cod_tasa%type;
    v_val_tas_impuesto ge_movimientos.val_tasa%type;
    v_val_impuesto     ge_movimientos.monto%type;
    p_val_multa        cc_che_devueltos_tmp.monto%type := 0;
    v_fec_valor        ge_movimientos.fec_valor%type;
    v_secuencia        ge_movimientos.nro_secuencia%type;
    v_mto_final        ge_movimientos.monto%type;
    v_iva_final        ge_movimientos.monto%type;
    v_estado           ge_movimientos.estado%type;
    --
    v_lugar varchar2(500);

 cursor clrec_cur is
 -- modificado 12/07/25
select che_dev.nro_cuenta,
             che_dev.nro_cheque,
             che_dev.fecha fecha,
             che_dev.hora,
             che_dev.usu_insercion, /*decode(p_cod_moneda,pag_gen.FU_OBT_MON_FUERTE, (nvl(monto,1) / 100) , monto)*/
             monto,
             che_dev.cod_ofi_camara,
             che_dev.cod_cau_principal,
             che_dev.tipo,
             che_dev.multa,
             che_dev.sal_multa,
             che_dev.cod_bco_receptor,
             che_dev.nro_caja,
             che_dev.regularizado,
             che_dev.dev_com_directa,
             che_dev.nro_linea,
             che_dev.cod_cau_secundaria,
             che_dev.tip_importe,
             che_dev.rowid registro,
             cuentas.cod_moneda,
             cuentas.cod_modulo,
             cuentas.cod_modalidad,
             cuentas.estado,
             che_dev.cod_sub_motivo
        from cc_che_devueltos_tmp che_dev, ge_cuentas cuentas
       where che_dev.nro_cuenta = cuentas.nro_cuenta
         and che_dev.cod_moneda = p_cod_moneda
         and not exists (select 1 from cc_che_dev_errores errores
                           where errores.nro_cuenta = che_dev.nro_cuenta
                             and errores.nro_cheque = che_dev.nro_cheque
                             and errores.msj_error like '%/Cheque ya devuelto%')
       order by nro_linea;
    ----
    clrec clrec_cur%rowtype;

    procedure lp_cal_cargo_impuesto(p_nro_cuenta      in varchar2,
                                    p_nro_cheque      in varchar2,
                                    p_fec_emision     in date,
                                    p_hora            in varchar2,
                                    p_secuencia       in number,
                                    p_cod_modulo      in varchar2,
                                    p_cod_modalidad   in varchar2,
                                    p_cod_moneda      in varchar2,
                                    p_cod_oficina     in varchar2,
                                    p_monto           in number,
                                    p_cod_transaccion in number,
                                    p_tipo            in varchar2) is
      v_cod_persona       ba_personas.cod_persona%type;
      v_fec_vigencia      ge_tas_fechas.fec_vigencia%type;
      v_tip_valor         ge_tasas.tip_valor%type := NULL;
      v_tipo              ge_tasas.tipo%type;
      v_porcen            number(10);
      v_redondeo          number(5);
      v_monto             ge_movimientos.monto%type;
      v_mto_final         ge_movimientos.monto%type;
      v_cod_tasa          ge_tasas.cod_tasa%type;
      v_val_tasa          ge_tas_fechas.val_tasa%type;
      v_tas_personalizada ge_cuentas.tas_personalizada%type := 'N';
      v_iva               ge_movimientos.monto%type;
      v_cod_mod_imp       ge_movimientos.cod_modulo%type;
      v_cod_mad_imp       ge_movimientos.cod_modalidad%type;
      v_cod_tra_imp       ge_movimientos.cod_transaccion%type;
      v_cod_tas_imp       ge_tasas.cod_tasa%type;
      v_val_tas_imp       ge_tas_fechas.val_tasa%type;
      v_nro_documento     ge_movimientos.nro_documento%type;
      v_tra_deb_cta       ge_movimientos.nro_documento%type;
      v_procesa           varchar2(01);
      v_secuencia         number;
      v_estado            ge_cuentas.estado%type;
      v_sal_disponible    ge_cuentas.sal_contable%type;
      v_ok                boolean;
    begin
      v_redondeo := FUG_OBT_PARDINAMICO('VAL_RED_MON_EXTRANJERA',
                                        p_cod_modulo,
                                        p_cod_modalidad,
                                        p_cod_moneda,
                                        null);
      --Obtener siguiente nro. de documento para la operacion
      select s_nro_cob_cargo.nextval into v_nro_documento from dual;

      If p_cod_transaccion is not null then
        BEGIN
          select distinct cod_tasa
            into v_cod_tasa
            from ge_transacciones t
           where t.cod_modulo = p_cod_modulo
             and t.cod_modalidad = p_cod_modalidad
             and t.cod_transaccion = p_cod_transaccion
             and t.cod_tasa is not null
             and t.rutina1 is null
             and nvl(t.afecta, 'N') = 'N'
             and fug_obt_tip_mov_contable(t.cod_modulo,
                                          t.cod_modalidad,
                                          t.cod_transaccion) = 'C';

        exception
          when no_data_found then
            g_error := 'Transacción no registrada.';
            v_ok    := false;
        end;
      end if;

      begin
        --cargar impuestos
        select det.cod_mod_hijo, det.cod_mad_hijo, det.cod_tra_hijo
          into v_cod_mod_imp, v_cod_mad_imp, v_cod_tra_imp
          from ge_transacciones_det det
         where det.cod_modulo = p_cod_modulo
           and det.cod_modalidad = p_cod_modalidad
           and det.cod_transaccion = p_cod_transaccion
           and det.cod_tra_hijo <> p_cod_transaccion
           and exists (select 0
                  from ge_transacciones b
                 where b.cod_modulo = det.cod_mod_hijo
                   and b.cod_modalidad = det.cod_mad_hijo
                   and b.cod_transaccion = det.cod_tra_hijo
                   and b.cod_tasa is not null
                   and fug_obt_tip_mov_contable(det.cod_modulo,
                                                det.cod_modalidad,
                                                det.cod_transaccion) in ('C', 'A'));
      exception
        when no_data_found then
          g_error := 'Transacción hija no registrada.';
          v_ok    := false;
      end;

      if p_nro_cuenta is not null and p_cod_transaccion is not null then
        begin
          select tas_personalizada
            into v_tas_personalizada
            from ge_cuentas
           where nro_cuenta = p_nro_cuenta;
        end;
      end if;

      pag_gen.pr_obt_val_tasa(p_cod_modulo,
                              p_cod_modalidad,
                              p_cod_oficina,
                              p_nro_cuenta,
                              p_cod_moneda,
                              p_monto,
                              nvl(v_tas_personalizada, 'N'),
                              v_cod_tasa,
                              p_cod_transaccion,
                              v_fcdehoy,
                              v_val_tasa,
                              v_fec_vigencia,
                              v_tip_valor,
                              v_tipo,
                              fug_obt_cli_principal(p_nro_cuenta));

      if v_tip_valor = 'V' then
        v_monto := nvl(v_val_tasa, 0);
      else
        v_monto := round(nvl(p_monto, 0) * nvl(v_val_tasa, 0) / 100, v_redondeo);
        --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
        v_monto := pag_gen.FU_OBT_VAL_FINAL(p_monto);
      end if;

      -- else --- Impuestos
      v_fec_vigencia := null;
      v_tip_valor    := null;
      v_tipo         := null;

      pag_gen.pr_obt_val_tasa(v_cod_mod_imp,
                              v_cod_mad_imp,
                              p_cod_oficina,
                              p_nro_cuenta,
                              p_cod_moneda,
                              0,
                              nvl(v_tas_personalizada, 'N'),
                              v_cod_tas_imp,
                              v_cod_tra_imp,
                              v_fcdehoy,
                              v_val_tas_imp,
                              v_fec_vigencia,
                              v_tip_valor,
                              v_tipo,
                              fug_obt_cli_principal(p_nro_cuenta)); ---OUT

      v_porcen := 100; --- Iva separado
      v_iva    := round(nvl(v_monto, 0) * nvl(v_val_tas_imp, 0) / v_porcen,v_redondeo);
      --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
      v_iva := pag_gen.FU_OBT_VAL_FINAL(v_iva);

      v_mto_final := v_monto + v_iva;

      --- validar saldo de la cuenta
      IF nvl(v_mto_final, 0) > 0 then
        --Verifica la Operación
        pag_cta.pr_ver_operacion(v_nro_cuenta,
                                 nvl(p_cod_transaccion, 322), --nvl(:det_deb_cuenta.cod_transaccion,503),
                                 nvl(clrec.cod_modulo, 4), -- cod_mod_padre
                                 nvl(clrec.cod_modalidad, 41), -- cod_mod_hijo
                                 'D', -- Tipo Crédito
                                 clrec.cod_moneda, -- Moneda de la Cta. de Débito(Moneda de la Oper.)
                                 v_mto_final,
                                 clrec.cod_ofi_camara, -- cod_ofi_origen
                                 clrec.cod_modulo,
                                 clrec.cod_modalidad,
                                 v_estado, -- toma el estado de la cuenta
                                 v_sal_disponible, -- sal_disponible
                                 v_procesa,
                                 503); -- procesa (s/n              -- procesa (s/n)
        if v_procesa = 'N' then
          if pag_cta.fu_obt_cod_error() in (25, 29, 31) then
            --Saldo Insuficiente
            pp_gen_mov_pendiente(v_mto_final,
                                 clrec.cod_modulo,
                                 clrec.cod_modalidad,
                                 p_cod_transaccion,
                                 clrec.cod_moneda,
                                 v_cod_tasa,
                                 v_val_tasa,
                                 p_fec_emision,
                                 p_hora,
                                 p_nro_cuenta,
                                 v_nro_documento);
          end if;
        else
        --  v_secuencia := p_secuencia + 1;
          g_hora        := pag_gen.fu_obt_sig_segundo(g_hora);
          --genera movimiento del cargo
          pp_genera_movimiento_cargo(p_cod_transaccion,v_monto,p_nro_cheque,p_fec_emision,v_nro_documento,
                                     v_val_tasa,v_cod_tasa,v_secuencia);

          --genera el movimiento por el iva
          pp_genera_movimiento_cargo(v_cod_tra_imp,v_iva,p_nro_cheque,p_fec_emision,v_nro_documento,
                                     v_val_tas_imp,v_cod_tas_imp,v_secuencia);

          --genera el movimiento de debito
          v_tra_deb_cta := 503; --- Debito
          pp_genera_movimiento_cargo(v_tra_deb_cta,v_mto_final,p_nro_cheque,p_fec_emision,v_nro_documento,
                                     null,null,v_secuencia);

         --MA-120
        /*  --Actualizar una vez más el saldo de la cuenta si se generaron los movimientos de cargos
          pp_actualizar_cuenta(v_cod_oficina,
                               v_nro_cuenta,
                               v_mto_final,
                               clrec.cod_modalidad,
                               2);*/
        end if;
      END IF;
    exception
      when others then
        null;
    end;

    procedure lp_act_est_che(p_nro_cuenta in varchar2,
                             p_nro_cheque in number,
                             p_estado     in varchar2) is
      v_poscheque number;
    BEGIN
      v_poscheque := p_nro_cheque - v_nro_che_inicial + 1;
      UPDATE cc_chequeras
         set est_cheques = substr(est_cheques, 1, v_poscheque - 1) ||
                           p_estado ||
                           substr(est_cheques,
                                  v_poscheque + 1,
                                  length(est_cheques))
       where nro_cuenta = p_nro_cuenta
         and nro_che_inicial = v_nro_che_inicial;

      -- vuelvo a no regularizado todos los cheques similares devueltos anteriormente
      begin
        update cc_che_devueltos
           set regularizado = 'N', fec_modificacion = fec_modificacion
         where nro_cuenta = p_nro_cuenta
           and nro_cheque = p_nro_cheque;
      exception
        when others then
          null;
      end;
    END;

    procedure lp_compensacion is
      v_nro_cuenta     cc_cta_bancarias.nro_cuenta%type;
      v_cod_modalidad  ge_modalidades.cod_modalidad%type;
      v_secuencia      ge_movimientos.nro_secuencia%type := 1;
      v_cod_ofi_camara cc_cta_bancarias.cod_oficina%type := 1;

    begin
      g_hora := pag_gen.fu_obt_sig_segundo(g_hora);

      prc_obt_cta_bancaria(clrec.cod_bco_receptor,
                           clrec.cod_moneda,
                           v_cod_ofi_camara,
                           v_nro_cuenta,
                           v_cod_modalidad);

      If v_nro_cuenta is not null then
        g_wk_nrsecuen := g_wk_nrsecuen + 1;
        pag_cta.pr_act_operacion(v_nro_cuenta,
                                 g_hora,
                                 'D',
                                 clrec.cod_moneda,
                                 clrec.monto,
                                 322,
                                 503,
                                 clrec.nro_cheque,
                                 NULL,
                                 fug_obt_ofi_camara(v_cod_oficina), --:variables.wk_cdofici
                                 4, --:variables.wk_cdmodul
                                 g_modali, --:variables.wk_cdmodal
                                 null,
                                 null,
                                 'COMP. DIRECTA - ' ||clrec.cod_cau_principal||'-'||fug_obt_des_causa(clrec.cod_cau_principal), --Se agrego el concepto, 12/02/2010
                                 'N',
                                 g_wk_nrsecuen,
                                 v_fcdehoy,
                                 null,
                                 null);
        if pag_cta.fu_obt_cod_error() <> 0 then
          raise_application_error(-20099,pag_cta.fu_obt_cod_error() || ' - ' ||pag_cta.fu_obt_msj_error());
        end if;
      else
        raise_application_error(-20099,'Cta. Bancaria no habilitada para el Banco :' ||clrec.cod_bco_receptor);
      End if;

    exception
      when others then
        raise_application_error(-20099, 'Error en LP_COMPENSACION');
    end lp_compensacion;

    procedure lp_pro_dev_deposito(p_nro_cheque  in number,
                                  p_monto       in number,
                                  p_nro_cuenta  in varchar2,
                                  p_fec_emision in date,
                                  p_ok          out boolean) is
    BEGIN
      --Debitar a la Cta. del depósito
      pag_cta.PR_ACT_OPERACION(g_cta_dep,
                               g_hora,
                               'D',
                               g_mon_dep,
                               p_monto,
                               322,
                               503,
                               p_nro_cheque,
                               NULL,
                               v_cod_ofi_usuario,
                               v_cod_modulo,
                               v_cod_modalidad,
                               null,
                               null,
                               null,
                               'N',
                               g_wk_nrsecuen,
                               p_fec_emision,
                               null,
                               null);
      if pag_cta.fu_obt_cod_error() <> 0 then
        g_error := pag_cta.fu_obt_cod_error() || ' - ' ||pag_cta.fu_obt_msj_error();
        p_ok    := false;
      end if;

      --Acreditar a la Cta. del cheque
      g_wk_nrsecuen := g_wk_nrsecuen + 1;
      pag_cta.PR_ACT_OPERACION(p_nro_cuenta,
                               g_hora,
                               'C',
                               v_cod_moneda,
                               p_monto,
                               322,
                               602,
                               p_nro_cheque,
                               NULL,
                               v_cod_ofi_usuario,
                               v_cod_modulo,
                               v_cod_modalidad,
                               null,
                               null,
                               null,
                               'N',
                               g_wk_nrsecuen,
                               p_fec_emision,
                               null,
                               null);
      if pag_cta.fu_obt_cod_error() <> 0 then
        g_error := pag_cta.fu_obt_cod_error() || ' - ' ||pag_cta.fu_obt_msj_error();
        p_ok    := false;
      end if;
    exception
      when others then
        g_error := ('Deposit.' || sqlerrm);
        p_ok    := false;
    end;

    procedure lp_validar_cheque(p_nro_cuenta in varchar2,
                                p_nro_cheque in number,
                                p_monto      in number,
                                p_fecha      in date,
                                p_ok         out boolean) is
      v_importe number(21, 2);

    begin
      begin
        select monto, nvl(com_directa, 'N')
          into v_importe, v_compensacion
          from cc_che_recibidos
         where fec_proceso = p_fecha
           and nro_cuenta = p_nro_cuenta
           and nro_cheque = p_nro_cheque
           and est_cheque in ('R', 'P');
        if nvl(v_importe, 0) <> nvl(p_monto, 0) then
          g_error := 'Importe del cheque no coincide con lo procesado';
          p_ok    := false;
        end if;
      exception
        when no_data_found then
          --Verificar si el cheque fue depositado
          begin
            select monto
              into v_importe
              from ge_movimientos
             where cod_tra_padre = 355
               and estado = 'N'
               and reversado = 'N'
               and fecha = p_fecha
               and nro_documento = p_nro_cheque
               and nro_cuenta = p_nro_cuenta;
            if nvl(v_importe, 0) <> nvl(p_monto, 0) then
              g_error := 'Importe del cheque no coincide con lo procesado';
              p_ok    := false;
            end if;
            --Obtener datos del deposito
            begin
              select dep.nro_documento, dep.nro_cuenta, dep.cod_moneda
                into g_nro_boleta, g_cta_dep, g_mon_dep
                from cj_movimientos det, cj_movimientos dep, ge_cuentas cta
               where det.nro_cuenta = p_nro_cuenta
                 and det.nro_documento = p_nro_cheque
                 and det.cod_tra_padre = 355
                 and det.nro_doc_referencia = dep.nro_documento
                 and dep.nro_cuenta = cta.nro_cuenta;
            exception
              when no_data_found then
                g_error := 'Al buscar datos del depósito';
                p_ok    := false;
            end;
          exception
            when no_data_found then
              begin
                select monto
                  into v_importe
                  from cc_movimientos_his
                 where cod_tra_padre = 355
                   and estado = 'N'
                   and reversado = 'N'
                   and fecha = p_fecha
                   and nro_documento = p_nro_cheque
                   and nro_cuenta = p_nro_cuenta;
                if nvl(v_importe, 0) <> nvl(p_monto, 0) then
                  g_error := 'Importe del cheque no coincide con lo procesado';
                  p_ok    := false;
                end if;
                --Obtener datos del deposito
                begin
                  select dep.nro_documento, dep.nro_cuenta, dep.cod_moneda
                    into g_nro_boleta, g_cta_dep, g_mon_dep
                    from cj_movimientos_his det,
                         cj_movimientos_his dep,
                         ge_cuentas         cta
                   where det.nro_cuenta = p_nro_cuenta
                     and det.nro_documento = p_nro_cheque
                     and det.cod_tra_padre = 355
                     and det.nro_doc_referencia = dep.nro_documento
                     and dep.nro_cuenta = cta.nro_cuenta;
                exception
                  when no_data_found then
                    g_error := 'Al buscar datos del depósito';
                    p_ok    := false;
                end;
              exception
                when no_data_found then
                  g_error := 'El Cheque no fue procesado en esta fecha';
                  p_ok    := false;
              end;
          end;
        when too_many_rows then
          g_error := 'Existen registros duplicados';
          p_ok    := false;
        when others then
          g_error := 'En vericar cheques ' || sqlerrm;
          p_ok    := false;
      end;
    end;

    procedure lp_validar_detalle(p_nrcuent  in varchar2,
                                 p_nrcheque in number,
                                 p_importe  in out number,
                                 p_ok       out boolean) is
      PROCEDURE pp_validar_cuenta(p_nrcuent in varchar2, p_ok out boolean) is
        v_tip_dev varchar2(1);
      begin
        p_ok := true;
        if g_cuenta <> nvl(p_nrcuent, 'a') then
          -- solo si hubo cambio de cta
          pag_cta.PR_OBT_CUENTA(p_nrcuent);
          v_nro_cuenta    := p_nrcuent;
          v_estado        := pag_cta.g_ctas.estado;
          v_cod_oficina   := pag_cta.g_ctas.cod_oficina;
          v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
          v_cod_modulo    := pag_cta.g_ctas.cod_modulo;
          v_cod_moneda    := pag_cta.g_ctas.cod_moneda;
          v_saldo         := pag_cta.g_ctas.sal_disponible;
        end if;

        if v_estado in ('C', 'T', 'D', 'P') or v_estado is null then
          --p_ok := false;
          if v_estado = 'C' then
            g_error   := 'Cuenta Cancelada';
            v_tip_dev := 'C';
          elsif v_estado in ('T', 'D') then
            g_error   := 'Cuenta Bloqueada';
            v_tip_dev := 'B';
          elsif v_estado = 'P' then
            g_error   := 'Cuenta Cerrada';
            v_tip_dev := 'C';
          elsif v_estado is null then
            g_error   := 'Cuenta no existe o con estado incorrecto';
            v_tip_dev := null;
          end if;
          If v_tip_dev is not null then
            begin
              g_tiperr := fug_obt_cau_devolucion('D', v_tip_dev);
            exception
              when no_data_found then
                null;
            end;
          End if;
        end if;
      exception
        when no_data_found then
          g_error         := 'Cuenta no existe';
          v_cod_modalidad := null;
          p_ok            := false;
        when others then
          if g_error is null then
            g_error := 'Al buscar cuenta.';
          end if;
          p_ok := false;
      end pp_validar_cuenta;

      PROCEDURE pp_verifica_estado_cheque(p_nro_cuenta  in varchar2,
                                          p_cod_oficina in number,
                                          p_nro_cheque  in number,
                                          p_importe     in out number,
                                          p_ok          in out boolean) IS
        v_error       varchar2(2000);
        v_cuenta      varchar2(15);
        v_estado      varchar2(1);
        v_desc_estado varchar2(100);

      BEGIN
        g_est_che := PAC_CHE.FU_OBT_EST_CHE(p_nro_cuenta,p_nro_cheque,v_error);
        --Verifica si existe el cheque de lo contrario da un mensaj.
        If v_error is not null then
          If g_ERROR is not null then
            g_ERROR := g_ERROR || ' - ' || v_error;
          else
            g_ERROR := v_error;
          End if;
          p_ok := false;
        end if;
        ---
        v_estado := pac_che.FU_CON_CAM_EST_CHE(p_nro_cuenta,
                                               p_nro_cheque,
                                               null,
                                               p_importe,
                                               v_nro_che_inicial,
                                               v_error,
                                               v_cuenta);



        if v_estado not in ('C', 'G', 'P', 'O') then
          If v_error is not null and rtrim(v_error) <> 'G' then
            g_ERROR := g_ERROR || ' - ' || 'Cheque en estado ' || g_est_che || '(' ||v_desc_estado || ')';
            p_ok    := false;
          end if;
        end if;
        If instr(v_error, 'Inexistente') <> 0 then
          If v_error is not null and rtrim(v_error) <> 'G' then
            g_ERROR := g_ERROR || ' - ' || 'Cheque en estado ' || g_est_che || '(' ||v_desc_estado || ')';
            p_ok    := false;
          end if;
        End if;
        ---
        If g_est_che = 'O' then
          begin
            g_tiperr := fug_obt_cau_devolucion('D', '0');
          exception
            when no_data_found then
              null;
          end;

          begin
            select g_error || '-' || descripcion
              into g_error
              from ge_causales
             where ge_causales.cod_causa =
                   (select cod_causa
                      from cc_che_ord_no_pagos
                     where nro_cheque = p_nro_cheque);
          exception
            when others then
               null;
          end;
        End if;

      exception
        when others then
          raise_application_error(-20004,'Error en pp_ver_est_che ' ||replace(sqlerrm, 'ORA-', ''));
      END;
      begin
        p_ok := true;
        if nvl(p_nrcheque, 0) <= 0 then
          if g_error is null then
            g_error := 'Numero de cheque incorrecto.';
          end if;
          p_ok := false;
        end if;
        pp_validar_cuenta(p_nrcuent, p_ok);
        if p_ok then
          g_ok := 'S';
        else
          g_ok := 'N';
        end if;
        g_cuenta := p_nrcuent;
        g_oficta := v_cod_oficina;
        g_modali := v_cod_modalidad;
        p_ok     := true;
        --Solo debe verificar el cheque si existe la cuenta
        If v_cod_modalidad is not null then
          pp_verifica_estado_cheque(v_nro_cuenta,
                                    v_cod_oficina,
                                    p_nrcheque,
                                    p_importe,
                                    p_ok);
        End if;
        if g_ok = 'N' then
          -- si la cuenta tuvo problemas
          p_ok := false;
        end if;
        if nvl(p_importe, 0) <= 0 then
          if g_error is null then
            g_error := 'Importe incorrecto.';
          else
            g_error := g_error || '/importe incorrecto';
          end if;
          p_ok := false;
        end if;
      end;
  BEGIN
    -- INICIO DEL PROCESO PRINCIPAL
    g_modali    := 41;
    g_cuenta    := '0';
    g_ok        := 'N';
    g_error     := null;
    g_oficta    := to_number('0');
    p_reg_pro   := 0;
    p_reg_err   := 0;
    v_secuencia := 0;
    v_estado    := 0;

    select count(*)
      into p_reg_tot
      from cc_che_devueltos_tmp c
     where usu_insercion = user
       AND COD_MONEDA = p_cod_moneda;

    if clrec_cur%isopen then
      close clrec_cur;
    end if;
    open clrec_cur;
    v_cod_ofi_usuario := fug_obt_ofi_usuario(user);
    g_hora            := to_char(sysdate, 'hh24:mi:ss');
    /* ciclo principal */
    <<proceso>>
    LOOP
      FETCH clrec_cur
        INTO clrec;
      EXIT WHEN clrec_cur%notfound;

      g_error     := null;
      g_tiperr    := null;
      v_cod_causa := null;
      v_cod_cau_sec := null;
      v_cod_causa := clrec.cod_cau_principal;
      v_cod_cau_sec := clrec.cod_cau_secundaria;
       
      v_multa     := nvl(FUG_OBT_PARCAUSALES(clrec.cod_cau_principal,'COD_TRA_MULTA'),0);

      v_lugar := 'lp_validar_cheque';
      lp_validar_cheque(clrec.nro_cuenta,
                        clrec.nro_cheque,
                        clrec.monto,
                        to_date(clrec.fecha, 'dd/mm/yyyy'),
                        ok);

      if g_error is null then
        v_lugar := 'lp_validar_detalle';
        lp_validar_detalle(clrec.nro_cuenta,
                           clrec.nro_cheque,
                           clrec.monto,
                           ok);
      End if;
      
       if clrec.estado = 'C' then
         v_cod_cau_sec := IT.FUG_OBT_PARDINAMICO('COD_CAU_CTA_CANCEL')||','||v_cod_cau_sec;
         v_cod_causa   := clrec.cod_cau_principal;
       end if;
       if g_est_che = 'O'  then
         v_cod_cau_sec := clrec.cod_cau_principal||','||v_cod_cau_sec;
         v_cod_causa   := IT.FUG_OBT_PARDINAMICO('COD_CAU_ORD_NO_PAGO');
       end if;

      if g_error is null or clrec.estado IN ('C', 'P') /*or g_error like '%Cuenta Cancelada%'*/
         or nvl(g_est_che, 'A') = 'O' then

        v_imp := nvl(v_imp, 0) + nvl(clrec.monto, 0);
        if g_wk_nrsecuen >= 800 then
          --sig segundo
          g_hora        := pag_gen.fu_obt_sig_segundo(to_char(sysdate,'hh24:mi:ss'));
          g_wk_nrsecuen := 1;
        end if;

        v_lugar := 'X1 ';

        If g_nro_boleta is not null and v_estado not in ('C', 'P') then
          -- CHEQUE NUESTRO BANCO
          v_lugar := 'X2 ';
          lp_pro_dev_deposito(clrec.nro_cheque,
                              clrec.monto,
                              clrec.nro_cuenta,
                              to_date(clrec.fecha, 'dd/mm/yyyy'),
                              ok);

        else
          --INGRESA PARA PROCESAR LOS CHEQUES DEVUELTOS
          v_lugar           := 'X3 ' || v_fcdehoy;
          v_cod_transaccion := 631;

          --CONSULTA SI ES ALTO VALOR PARA BUSCAR LA TRANSACCION CORRESPONDIENTE
          if to_date(clrec.fecha, 'dd/mm/yyyy') = v_fcdehoy and
             p_tip_importe = '1' then
            --- ALTO VALOR o SE HACE LA DEVOLUCIÓN DEL DÍA
            v_lugar := 'X4 ';
            BEGIN
              SELECT nvl(tipo, 'X')
                INTO v_tipo
                FROM ge_bancos
               WHERE ge_bancos.cod_banco = clrec.cod_bco_receptor;
            EXCEPTION
              WHEN no_data_found THEN
                v_tipo := 'X';
            END;
            if v_tipo = 'X' then
              v_cod_transaccion := 608;
            else
              v_cod_transaccion := 668;
            end if;
          end if;

          v_lugar := 'pp_genera_mov';
          v_cod_banco := clrec.cod_bco_receptor;

          If nvl(v_compensacion, 'N') = 'S' then
            ----
            pp_genera_movimiento(602,
                                 clrec.monto,
                                 clrec.nro_cheque,
                                 to_date(clrec.fecha, 'dd/mm/yyyy'),
                                 v_secuencia);
            --MA - 120
            --Para orden de no pago y cuenta cancelada no debe generar movimiento
            IF upper(nvl(g_error,'X')) not like '%CUENTA CANCELADA%' and upper(nvl(g_error,'X')) not like '%CUENTA CERRADA%' and nvl(g_est_che, 'x') <> 'O' then
               lp_compensacion;
            END IF;
          else
            pp_genera_movimiento(v_cod_transaccion,
                                 clrec.monto,
                                 clrec.nro_cheque,
                                 to_date(clrec.fecha, 'dd/mm/yyyy'),
                                 v_secuencia);
          End if;

          v_lugar := 'pp_actualizar_cuenta';
          if clrec.estado not in ('C', 'P') then
            if nvl(g_est_che, 'x') <> 'O' then
              If (nvl(g_est_che, 'x') <> 'C') then
                --Si no es cuenta certificada
                pp_actualizar_cuenta(v_cod_oficina,
                                     clrec.nro_cuenta,
                                     clrec.monto,
                                     v_cod_modalidad,
                                     1);
              else
                --Cuenta certificada
                v_lugar := 'pp_act_cuenta 44';
                pp_actualizar_cuenta(v_cod_oficina,
                                     g_cuenta_cert,
                                     clrec.monto,
                                     44,
                                     1);
              end if;
            end if;
          end if;
        end if;
        v_lugar := 'ACTUALIZAR ESTADO CHEQUE';

        --Actualizar el estado del cheque en cc_chequeras
        If nvl(g_est_che, 'x') = 'C' then
          lp_act_est_che(clrec.nro_cuenta, clrec.nro_cheque, 'C');
        elsIf nvl(g_est_che, 'x') = 'O' then
          lp_act_est_che(clrec.nro_cuenta, clrec.nro_cheque, 'O');
        else
          --ver si es cuenta gerencia
          If v_cod_modalidad = 43 then
            lp_act_est_che(clrec.nro_cuenta, clrec.nro_cheque, 'G');
          else
            lp_act_est_che(clrec.nro_cuenta, clrec.nro_cheque, 'E');
          End if;
        End if;

        v_lugar := 'ACTUALIZAR SALDO';

        if nvl(g_est_che, 'x') = 'C' then
          update cc_che_certificados
             set fec_pago = null, cod_cau_devolucion = 11 ---:devolucion.sc_cod_devolucion
           where nro_cuenta = clrec.nro_cuenta
             and nro_cheque = clrec.nro_cheque;
        end if;

        --si es cheque gerencia
        if nvl(g_est_che, 'x') = 'G' then
          update cc_che_ger_emitidos
             set fec_pago = null, cod_usu_pagador = null
           where nro_cuenta = clrec.nro_cuenta
             and nro_cheque = clrec.nro_cheque;
        end if;

        update cc_che_pagados
           set cod_cau_devolucion = v_cod_causa
         where nro_cheque = clrec.nro_cheque
           and monto = clrec.monto
           and fecha = (select max(fecha)
                          from cc_che_pagados b
                         where b.nro_cheque = clrec.nro_cheque
                           and b.monto = clrec.monto);

        If g_nro_boleta is null then
          update cc_che_recibidos
             set cod_cau_devolucion = v_cod_causa, est_cheque = 'R'
           where fec_proceso = to_date(clrec.fecha, 'dd/mm/yyyy')
             and cod_ofi_camara = FUG_OBT_OFI_CAMARA(v_cod_oficina)
             and (nro_cuenta = clrec.nro_cuenta)
             and nro_cheque = clrec.nro_cheque;

          if v_fcdehoy = to_date(clrec.fecha, 'dd/mm/yyyy') then
            v_fecha := PAG_CAL.FU_OBT_FEC_PROXIMA(4);
          else
            v_fecha := v_fcdehoy;
          end if;

          

          if nvl(v_compensacion, 'N') = 'N' then
            v_lugar := 'ACTUALIZAR SALDO DE CAMARA';
            /* actualizo los cheques rechazados en la tabla de totales */
            update cc_sal_camara
               set sis_che_dev_a_camara = nvl(sis_che_dev_a_camara, 0) +
                                          nvl(clrec.monto, 0)
             where cod_ofi_camara = FUG_OBT_OFI_CAMARA(v_cod_oficina)
               and cod_moneda = clrec.cod_moneda
               and fecha = v_fecha
               and tip_importe = nvl(p_tip_importe, 0);
            if sql%notfound then
              v_lugar := 'INSERTAR SALDO DE CAMARA';
              insert into cc_sal_camara
                (cod_ofi_camara,
                 cod_moneda,
                 fecha,
                 sis_che_dev_a_camara,
                 tip_importe)
              values
                (FUG_OBT_OFI_CAMARA(v_cod_oficina),
                 clrec.cod_moneda,
                 v_fecha,
                 clrec.monto,
                 nvl(p_tip_importe, 0));
            end if;
          end if;
        End if;
        v_lugar := 'Obtener Causal de transaccion';
        v_cargo := nvl(FUG_OBT_PARCAUSALES(v_cod_causa,'COD_TRA_CARGO'),0);

        --calcular la multa por los casos de CUENTA CANCELADA E INSUFICIENCIA DE FONDOS
        if v_multa > 0 then
          if FUC_VER_COB_MULTA(clrec.nro_cuenta, clrec.nro_cheque) = 'N' then

            v_lugar := 'prg_obt_cargos'; -- BUSCAR LA TASA PARA LA MULTA

            prg_obt_cargos(clrec.cod_ofi_camara,
                           clrec.nro_cuenta,
                           clrec.cod_moneda,
                           clrec.monto,
                           clrec.cod_modulo,
                           clrec.cod_modalidad,
                           v_multa, --multa
                           v_cod_tas_multa,
                           v_val_tas_multa,
                           p_val_multa,
                           v_cod_tra_impuesto,
                           v_cod_tas_impuesto,
                           v_val_tas_impuesto,
                           v_val_impuesto);
          end if;
        else
          p_val_multa := 0;
        end if;
        
        v_tip_dev:=null;
        v_tip_dev:= FUG_OBT_PARCAUSALES(v_cod_causa, 'TIP_DEVOLUCION');
        v_lugar := 'Ins.CC_CHE_DEVUELTOS-Nro.Cheque: '|| clrec.nro_cheque|| ' Tip.Dev:'||v_tip_dev||' Sub-Mot:'||clrec.cod_sub_motivo;
        insert into CC_CHE_DEVUELTOS
          (FECHA,
           HORA,
           COD_USUARIO,
           NRO_Cuenta,
           NRO_CHEQUE,
           COD_MONEDA,
           MONTO,
           COD_CAUSA,
           MULTA,
           SAL_MULTA,
           COD_BCO_RECEPTOR,
           NRO_CAJA,
           COD_OFI_CAMARA,
           TIPO,
           DEV_COM_DIRECTA,
           TIP_IMPORTE,
           COD_SUB_MOTIVO)
        values
          (to_date(clrec.fecha, 'dd/mm/yyyy'),
           g_hora,
           USER,
           clrec.nro_cuenta,
           clrec.nro_cheque,
           v_cod_moneda,
           clrec.monto,
           v_cod_causa,
           p_val_multa,
           p_val_multa,
           clrec.cod_bco_receptor,
           null,
           fug_obt_ofi_camara(v_cod_oficina),
           v_tip_dev,
           decode(v_cod_moneda,pag_gen.FU_OBT_MON_FUERTE,'S',v_compensacion),
           p_tip_importe,
           clrec.cod_sub_motivo);

        --CALCULAR LA MULTA
        if p_val_multa > 0 then
          v_lugar := 'prc_cob_multa';
          prc_cob_multa(clrec.nro_cuenta,clrec.nro_cheque,v_fcdehoy,g_hora,g_wk_nrsecuen);
        end if;
        --BUSCAR EL CODIGO DE TASA CORRESPONDIENTE AL CARGO, GENERAR EL MOVIMIENTO POR CARGO, Y
        --EL MOVIMIENTO POR IMPUESTO DE CARGO.
        if v_cargo > 0 then
          v_lugar := 'lp_cal_cargo_impuesto';
          lp_cal_cargo_impuesto(clrec.nro_cuenta,
                                clrec.nro_cheque,
                                v_fcdehoy,
                                g_hora,
                                v_secuencia,
                                clrec.cod_modulo,
                                clrec.cod_modalidad,
                                clrec.cod_moneda,
                                clrec.cod_ofi_camara,
                                clrec.monto,
                                v_cargo,
                                'C');
        end if;

        if v_cod_cau_sec is not null or clrec.cod_cau_secundaria is not null then
          v_lugar := 'ACTUALIZA CAUSA SECUNDARIA';
          BEGIN
            select count(*)
              into v_existe
              from ba_tab_dat_adicionales
             where tab_relacion = 'CC_CHE_DEVUELTOS'
               and referencia = clrec.nro_cuenta || ',' || clrec.nro_cheque
               and val_parametro = nvl(v_cod_cau_sec, clrec.cod_cau_secundaria);

            IF v_existe = 0 THEN
              insert into ba_tab_dat_adicionales
                (TAB_RELACION, REFERENCIA, PARAMETRO, VAL_PARAMETRO)
              values
                ('CC_CHE_DEVUELTOS',
                 clrec.nro_cuenta || ',' || clrec.nro_cheque,
                 'COD_CAU_SECUNDARIA',
                 nvl(v_cod_cau_sec,clrec.cod_cau_secundaria));
            END IF;
          end;
        end if;

        BEGIN
          SELECT 'S'
            INTO v_exi
            FROM cc_che_dev_firmantes
           WHERE nro_cuenta = clrec.nro_cuenta
             and cod_persona = fug_obt_cli_principal(clrec.nro_cuenta)
             and nro_cheque = clrec.nro_cheque;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            INSERT INTO cc_che_dev_firmantes
              (nro_cuenta, nro_cheque, cod_persona)
            VALUES
              (clrec.nro_cuenta,
               clrec.nro_cheque,
               fug_obt_cli_principal(clrec.nro_cuenta));
        END;

        p_reg_pro := p_reg_pro + 1;
      else
        g_error := g_error || '- Linea: ' || clrec.nro_linea;
        insert into cc_che_dev_errores
          (nro_cuenta, nro_cheque, msj_error, importe, cod_banco)
        values
          (clrec.nro_cuenta,
           clrec.nro_cheque,
           substr(g_error, 1, 100),
           clrec.monto,
           clrec.cod_bco_receptor);

        g_error   := null;
        g_tiperr  := null;
        v_est     := 'N';
        p_reg_err := p_reg_err + 1;
      end if;
    END LOOP proceso;

    if clrec_cur%rowcount = 0 then
      Raise_application_error(-20003,'No existen registros a ser procesados.');
    --else
     -- p_reg_tot := clrec_cur%rowcount; comentado 12/07/25
    end if;
    -- agregado 12/07/25
    select count(*)
      into p_reg_err
      from cc_che_dev_errores error
     where error.usu_insercion = USER
       AND error.tip_importe = p_tip_importe;
    --
    close clrec_cur;
    commit;
  exception
    when others then
      If sqlcode <= -20000 then
        raise;
      Else
        Raise_application_error(-20097,'Error en ' || v_lugar || ' ' || SQLERRM);
      End if;
  END;
begin
  pp_cheques_devueltos;
  prc_con_che_devueltos;
Exception
  When OTHERS then
    If sqlcode <= -20000 then
      raise;
    Else
      Raise_application_error(-20098,'Error ' || replace(sqlerrm, 'ORA-', ''));
    End if;
end prc_pro_che_devueltos;
/
