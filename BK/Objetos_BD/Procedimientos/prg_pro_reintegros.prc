create or replace procedure it.prg_pro_reintegros is
  v_fec_actual date := pag_cal.fu_obt_fec_actual(3);
  v_fec_valor  date := trunc(sysdate);
    v_hora varchar2(8) := to_char(sysdate,'hh24:mi:ss');
  v_nro_secuencia ge_movimientos.nro_secuencia%TYPE := 0;
  v_cod_tra_padre ge_transacciones.cod_transaccion%type;
  v_horario       VARCHAR2(1) := 'D';
  v_est_modulo    ba_modulos.estado%TYPE;
  v_val_reintegro varchar2(1) := 'N';
  v_reversar      varchar2(1) := 'N';
  v_mto_reintegro number;
  v_ult_nro_doc   number;
  v_ult_identificador number;
  v_redondeo      number := 0;
  v_pri_dia_mes   date;
  v_ult_dia_mes   date;
  v_cod_error     varchar2(100);
  v_men_error     varchar2(200);
  v_hor_rev        ge_movimientos.hora%type;
  v_usu_movimiento ge_movimientos.cod_usuario%type;
  v_cod_mod_padre  ge_movimientos.cod_mod_padre%type;
  v_cod_mad_padre  ge_movimientos.cod_mad_padre%type;
  v_nro_doc_reverso cj_log_glo_pro.nro_documento%type;
  v_identificador   ta_bus_transacciones.identificador%type;
  v_nro_documento   cj_log_glo_pro.nro_documento%type;
  v_nro_documento3  ge_movimientos.nro_documento3%type;
  v_por_reintegro   ge_com_adheridos.por_reintegro%type;
  v_es_nocturno    varchar2(1) := 'N';
  v_error          varchar2(200);
  v_nro_cuenta     ge_cuentas.nro_cuenta%type;
  v_cod_moneda     ba_monedas.cod_moneda%type;
  v_mto_compra     number;
  v_cod_cli_comercio ge_com_adheridos.cod_cli_comercio%type;
  v_nom_comercio     ge_com_adheridos.nom_comercio%type;
  v_cod_comercio     ge_com_adheridos.cod_comercio%type;
  v_cod_suc_comercio ge_com_adheridos.cod_suc_comercio%type;
  v_cod_promocion    ge_com_adheridos.cod_promocion%type;
  v_fec_reversion    ge_movimientos.fecha%type;
  v_nro_cta_rev      ge_movimientos.nro_cuenta%type;
  v_tot_compra       number;
  v_compra           number;
  v_mto_com_reintegro ge_mov_reintegros.mto_com_reintegro%type;
  --
  v_nvo_estado       ah_cta_vistas.estado%type;
  v_sal_disponible   number;
  v_procesa          varchar2(1);
  v_cod_transaccion  ge_movimientos.cod_transaccion%type;
  v_cod_modulo       ge_transacciones.cod_modulo%type := 3;
  v_cod_modalidad    ge_transacciones.cod_modalidad%type := 31;
  v_moneda           ba_monedas.cod_moneda%type;
  --
  cursor c_dattd is
  select a.nro_documento, a.nro_cta_debito, d.cod_persona,
         c.mon_maximo, c.fec_inicio, c.fec_fin, c.por_reintegro,
         a.mto_total, ltrim(a.cod_comercio,'0') cod_comercio,
         c.cod_promocion, a.fec_sistema, c.cod_cli_comercio,
         c.nom_comercio, c.cod_suc_comercio, nvl(c.top_compra,0) top_compra,
         nvl(c.top_com_tc,0) top_com_tc
    from cv_log_glo_pro a,
         ge_com_adheridos c,
         ge_cta_clientes d
   where a.respuesta = 'approved'
     and (c.cod_comercio = ltrim(a.cod_comercio,'0') or c.cod_switch = ltrim(a.cod_comercio,'0'))
     and d.nro_cuenta = a.nro_cta_debito
     and d.relacion = 'P'
     and nvl(c.tipo,'D') in ('D', 'A')
     and a.fec_sistema between c.fec_inicio and c.fec_fin
     and v_fec_valor between c.fec_inicio and c.fec_fin
     and a.mto_total >= nvl(c.mto_minimo,0)
     and ((v_ult_nro_doc is null and a.fec_sistema between c.fec_inicio and c.fec_fin)
      or (v_ult_nro_doc is not null and a.nro_documento > v_ult_nro_doc))
     and not exists (select 1 from cv_log_glo_pro b
                      where b.nro_tra_cancelado = a.nro_transaccion
                        and b.respuesta = a.RESPUESTA
                        and b.pedido = 'cancel')
     and not exists (select 1 from ge_movimientos e
                      where e.cod_tra_padre = v_cod_tra_padre
                        and e.reversado = 'N'
                        and e.nro_documento3 = a.nro_documento)

  order by a.fec_sistema, a.HORA;
  cursor c_datqr is
  select c.cod_persona, a.customer_account_number, a.commerce_code, a.commerce_name, a.branch_code,
         a.branch_description, b.fec_inicio, b.fec_fin, b.mon_maximo,
         a.transaction_amount, b.por_reintegro, a.ticket_number, a.identificador,
         a.Provide_Service_Code, b.cod_promocion, a.transaction_date,
         b.nom_comercio, b.cod_comercio, nvl(b.top_compra,0) top_compra,
         nvl(b.top_com_tc,0) top_com_tc
    from ta_bus_transacciones a, ge_com_adheridos b, ge_cta_clientes c
   where a.Provide_Service_Code in ('TDQR','STQR')
     and a.response_code = '00'
     and a.transaction_date between b.fec_inicio and b.fec_fin
     and v_fec_valor between b.fec_inicio and b.fec_fin
     and b.cod_cli_comercio = a.commerce_code
     and b.cod_suc_comercio = a.branch_code
     and c.nro_cuenta = a.customer_account_number
     and c.relacion = 'P'
     and nvl(b.tipo,'D') in ('D', 'A')
     and a.transaction_amount >= nvl(b.mto_minimo,0)
     and not exists (select 1 from ta_bus_transacciones c
                      where c.ticket_number = a.ticket_number
                        and c.transaction_amount = (a.transaction_amount * -1))
     and not exists (select 1 from ge_movimientos e
                      where e.nro_documento3 = a.ticket_number
                        and (a.transaction_amount * -1) = e.monto
                        and a.transaccion != 'R')
     and not exists (select 1 from ge_movimientos d
                      where d.cod_tra_padre = v_cod_tra_padre
                        and d.reversado = 'N'
                        and d.nro_documento3 = a.ticket_number)
     and ((v_ult_identificador is null and a.transaction_date between b.fec_inicio and b.fec_fin)
      or (v_ult_identificador is not null and a.identificador > v_ult_identificador))
  order by a.identificador;
  cursor c_tdcancel is
  select * from cv_log_glo_pro a
  where a.PEDIDO = 'cancel'
    and a.respuesta = 'approved'
    and exists (select 1 from ge_mov_reintegros d
                 where d.nro_cuenta = a.NRO_CTA_DEBITO
                   and d.cod_tra_padre = v_cod_tra_padre
                   and d.nro_documento3 = a.NRO_DOCUMENTO)
    and exists (select 1 from cv_log_glo_pro b, ge_com_adheridos c
                 where b.fec_sistema between c.fec_inicio and c.fec_fin
                   and v_fec_valor between c.fec_inicio and c.fec_fin
                   and b.NRO_TRANSACCION = a.NRO_TRA_CANCELADO
                   and b.RESPUESTA = a.RESPUESTA
                   and ((c.cod_comercio = ltrim(b.cod_comercio,'0')) or (c.cod_switch = ltrim(b.cod_comercio,'0')))
                   );
  cursor c_qrcancel is
  select * from ta_bus_transacciones a
   where a.Provide_Service_Code in ('TDQR','STQR')
     and a.response_code = '00'
     and a.transaction_amount < 0
     and exists (select 1 from ge_mov_reintegros d
                      where d.FECHA = a.transaction_date
                        and d.NRO_CUENTA = a.customer_account_number
                        and d.NRO_DOCUMENTO3 = a.ticket_number
                        and d.REVERSADO = 'N'
                        and d.COD_TRA_PADRE = v_cod_tra_padre)
     and not exists (select 1 from ge_movimientos d
                      where d.FECHA = a.transaction_date
                        and d.NRO_CUENTA = a.customer_account_number
                        and d.NRO_DOCUMENTO3 = a.ticket_number
                        and d.REVERSADO = 'S'
                        and d.COD_TRA_PADRE = v_cod_tra_padre)
     and exists (select 1 from ta_bus_transacciones b, ge_com_adheridos c
                  where b.provide_service_code = a.provide_service_code
                    and b.transaction_date between c.fec_inicio and c.fec_fin
                    and v_fec_valor between c.fec_inicio and c.fec_fin
                    and (b.transaction_amount * -1) = a.transaction_amount
                    and b.commerce_code = c.cod_cli_comercio
                    and b.branch_code = c.cod_suc_comercio
                    and b.ticket_number = a.ticket_number);
  function fu_obt_tot_compra(p_cod_persona varchar2, p_cod_promocion varchar2, p_cod_transaccion number default null) return number is
    v_tot_compra number;
    v_cod_promo  ge_mov_reintegros.cod_promocion%type;
  begin
    begin
      select a.cod_promocion, sum(a.mto_compra) tot_compra 
        into v_cod_promo, v_tot_compra
        from ge_mov_reintegros a, 
             ge_cta_clientes b
       where a.cod_promocion = p_cod_promocion
         and b.nro_cuenta = a.nro_cuenta
         and a.cod_tra_padre = nvl(p_cod_transaccion, a.cod_tra_padre)
         and b.relacion = 'P'
         and a.reversado = 'N'
         and b.cod_persona = p_cod_persona
       group by a.cod_promocion;
       return v_tot_compra;
    exception
      when no_data_found then
        return 0;
    end;
  end;
  function fu_obt_tot_reintegro(p_cod_persona in varchar2, p_cod_promocion varchar2) return number is
    v_tot_reintegros number;
    v_tot_rei_his    number;
    v_ind_top_mes ge_com_adheridos.top_mes%type;
    v_fec_ini date;
    v_fec_fin date;
    v_fec_ini_promo date;
  begin
    v_tot_reintegros := 0;
    begin
      select distinct a.top_mes
        into v_ind_top_mes
        from ge_com_adheridos a
       where a.cod_promocion = p_cod_promocion;
    exception
      when no_data_found then
        v_ind_top_mes := 'N';
      when others then
        v_ind_top_mes := 'N';
    end;
    if nvl(v_ind_top_mes,'N') = 'S' then
      v_fec_ini := trunc(v_fec_valor,'mm');
      v_fec_fin := last_day(v_fec_valor);
    else
      v_fec_ini := v_pri_dia_mes;
      v_fec_fin := v_ult_dia_mes;
    end if;
    if v_fec_ini is null or v_fec_fin is null then
      begin
        select a.fec_inicio, a.fec_fin
          into v_fec_ini, v_fec_fin
          from ge_com_adheridos a
         where a.cod_promocion = p_cod_promocion
           and rownum = 1;
      exception
        when others then
          v_fec_ini := trunc(v_fec_valor,'mm');
          v_fec_fin := last_day(v_fec_valor);
      end;
    end if;
    begin
      select a.fec_inicio
        into v_fec_ini_promo
        from ge_com_adheridos a
       where a.cod_promocion = p_cod_promocion
         and rownum = 1;
    exception
        when others then
          v_fec_ini_promo := v_fec_actual;
    end;
    begin
      if v_fec_ini_promo < to_date('01/02/2023','dd/mm/yyyy') then
        select sum(a.monto) tot_reintegro
          into v_tot_rei_his
          from ah_movimientos_his a, ge_cta_clientes b
         where a.fec_valor between v_fec_ini and v_fec_fin
           and a.referencia is null
           and a.nro_documento in (select c.cod_cli_comercio
                                     from ge_com_adheridos c
                                    where c.cod_promocion = p_cod_promocion)
           and a.reversado = 'N'
           and a.cod_tra_padre in (fug_obt_pardinamico('COD_TRA_REI_TARJETAS'),fug_obt_pardinamico('COD_TRA_REINTEGRO'))
           and b.nro_cuenta = a.NRO_CUENTA
           and b.relacion = 'P'
           and b.cod_persona = p_cod_persona;
        select sum(a.monto) tot_reintegro
          into v_tot_reintegros
          from ge_movimientos a, ge_cta_clientes b
         where a.fec_valor between v_fec_ini and v_fec_fin
           and a.referencia is null
           and a.nro_documento in (select c.cod_cli_comercio
                                     from ge_com_adheridos c
                                    where c.cod_promocion = p_cod_promocion)
           and a.reversado = 'N'
           and a.cod_tra_padre in (fug_obt_pardinamico('COD_TRA_REI_TARJETAS'),fug_obt_pardinamico('COD_TRA_REINTEGRO'))
           and b.nro_cuenta = a.NRO_CUENTA
           and b.relacion = 'P'
           and b.cod_persona = p_cod_persona;
       else
         select sum(a.monto) tot_reintegro
          into v_tot_rei_his
          from ah_movimientos_his a, ge_cta_clientes b
         where a.fec_valor between v_fec_ini and v_fec_fin
           and a.referencia is null
           and a.nro_documento in (select c.cod_cli_comercio
                                     from ge_com_adheridos c
                                    where c.cod_promocion = p_cod_promocion)
           and a.reversado = 'N'
           and a.cod_tra_padre = v_cod_tra_padre
           and b.nro_cuenta = a.NRO_CUENTA
           and b.relacion = 'P'
           and b.cod_persona = p_cod_persona;
        select sum(a.monto) tot_reintegro
          into v_tot_reintegros
          from ge_movimientos a, ge_cta_clientes b
         where a.fec_valor between v_fec_ini and v_fec_fin
           and a.referencia is null
           and a.nro_documento in (select c.cod_cli_comercio
                                     from ge_com_adheridos c
                                    where c.cod_promocion = p_cod_promocion)
           and a.reversado = 'N'
           and a.cod_tra_padre = v_cod_tra_padre
           and b.nro_cuenta = a.NRO_CUENTA
           and b.relacion = 'P'
           and b.cod_persona = p_cod_persona;
       end if;
       v_tot_reintegros := nvl(v_tot_reintegros,0) + nvl(v_tot_rei_his,0);
    exception
      when no_data_found then
        v_tot_reintegros := 0;
      when others then
        v_tot_reintegros := 0;
    end;
    return nvl(v_tot_reintegros,0);
  end;
  procedure pr_ins_mov_reintegros(p_reversado in varchar2 default 'N') is
  begin
    if nvl(p_reversado,'N') = 'N' then
      insert into ge_mov_reintegros
      (fecha, hora, cod_usuario, nro_secuencia, fec_valor, mto_reintegro, nro_cuenta,
       cod_moneda, mto_compra, reversado, cod_tra_padre, cod_cli_comercio, nom_comercio,
       cod_comercio, cod_suc_comercio, cod_promocion, nro_documento3, mto_com_reintegro)
      values(v_fec_actual, v_hora, user, v_nro_secuencia, v_fec_valor, v_mto_reintegro, v_nro_cuenta,
             v_cod_moneda, v_mto_compra, nvl(p_reversado,'N'), v_cod_tra_padre, v_cod_cli_comercio, v_nom_comercio,
             v_cod_comercio, v_cod_suc_comercio, v_cod_promocion, v_nro_documento3, v_mto_com_reintegro);
    else
      update ge_mov_reintegros a
         set a.reversado = p_reversado
       where a.fecha = v_fec_reversion
         and a.hora = v_hor_rev
         and a.cod_usuario = v_usu_movimiento
         and a.nro_cuenta = v_nro_cta_rev
         and a.cod_tra_padre = v_cod_tra_padre;
    end if;
  exception
    when others then
      null;
  end;
  procedure pr_log_reintegros(p_tipo varchar2,
                              p_nro_operacion number,
                              p_cod_cli_comercio varchar2,
                              p_cod_suc_comercio varchar2,
                              p_cod_comercio varchar2,
                              p_mto_reintegro number,
                              p_reintegro varchar2,
                              p_cod_error varchar2,
                              p_msj_error varchar2,
                              p_nro_cuenta varchar2) is
  pragma autonomous_transaction;
  begin
    insert into ge_log_reintegros(fecha,
                                  hora,
                                  tipo,
                                  nro_operacion,
                                  cod_cli_comercio,
                                  cod_suc_comercio,
                                  cod_comercio,
                                  mto_reintegro,
                                  reintegro,
                                  cod_error,
                                  msj_error,
                                  nro_cuenta)
     values(v_fec_actual, v_hora, p_tipo, p_nro_operacion, p_cod_cli_comercio, p_cod_suc_comercio,
            p_cod_comercio, p_mto_reintegro, p_reintegro, p_cod_error, p_msj_error,p_nro_cuenta);
     commit;
  end;
begin
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  v_ult_identificador := fug_obt_pardinamico('ULT_NRO_IDE_QR');
  v_ult_nro_doc       := fug_obt_pardinamico('ULT_NRO_DOC_TD');
  v_cod_tra_padre     := fug_obt_pardinamico('COD_TRA_REINTEGRO');
  v_horario           := 'D';
  v_est_modulo        := pae_cnf.fu_obt_est_modulo(3);
  if v_est_modulo != 2 then
    v_horario := 'N';
    v_es_nocturno := 'S';
  else
    v_horario := 'D';
    v_es_nocturno :='N';
  end if;
  pag_cta.g_horario := v_horario;
    -- Reintegros pagos qr
    for qr in c_datqr loop
      v_nro_secuencia := 0;
      v_pri_dia_mes   := qr.fec_inicio;
      v_ult_dia_mes   := qr.fec_fin;
      --v_tot_reintegro := fu_obt_tot_reintegro(qr.cod_persona, qr.cod_promocion);
      if nvl(qr.top_com_tc,0) > 0 then
        v_tot_compra    := fu_obt_tot_compra(qr.cod_persona, qr.cod_promocion, v_cod_tra_padre);
      else
        v_tot_compra    := fu_obt_tot_compra(qr.cod_persona, qr.cod_promocion);
      end if;
      pag_cta.pr_obt_cuenta(qr.customer_account_number);
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',pag_cta.g_ctas.cod_modulo,pag_cta.g_ctas.cod_modalidad,pag_cta.g_ctas.cod_moneda);
      v_por_reintegro := fug_obt_por_reintegro(qr.cod_promocion, qr.cod_persona, qr.por_reintegro);

      if nvl(v_tot_compra,0) < qr.top_compra then
        if v_por_reintegro is null then
          v_por_reintegro := qr.por_reintegro;
        end if;
        if nvl(v_tot_compra,0) + qr.transaction_amount > qr.top_compra then
          v_compra := qr.top_compra - nvl(v_tot_compra,0);
        else
          v_compra := qr.transaction_amount;
        end if;
        if v_por_reintegro is not null then
          v_mto_reintegro := round((v_compra * v_por_reintegro / 100),v_redondeo);
          v_val_reintegro := 'S';
        else
          v_val_reintegro := 'N';
        end if;
      else
        v_val_reintegro := 'N';
      end if;
      -- credito de reintegro
      if nvl(v_val_reintegro,'N') = 'S' then
        v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_nocturno);
        pag_cta.pr_set_nro_documento2(qr.branch_code);
        pag_cta.pr_set_nro_documento3(qr.ticket_number);
        v_nro_cuenta := qr.customer_account_number;
        v_cod_moneda := pag_cta.g_ctas.cod_moneda;
        v_mto_compra := qr.transaction_amount;
        v_mto_com_reintegro := v_compra;
        v_cod_cli_comercio := qr.commerce_code;
        v_nom_comercio     := qr.nom_comercio;
        v_cod_comercio     := qr.cod_comercio;
        v_cod_suc_comercio := qr.branch_code;
        v_cod_promocion    := qr.cod_promocion;
        v_nro_documento3   := qr.ticket_number;
        pag_cta.pr_act_operacion(qr.customer_account_number,
                                 v_hora,
                                 'C',
                                 pag_cta.g_ctas.cod_moneda,
                                 v_mto_reintegro,
                                 v_cod_tra_padre,
                                 v_cod_tra_padre,
                                 qr.commerce_code,
                                 null,
                                 pag_cta.g_ctas.cod_oficina,
                                 pag_cta.g_ctas.cod_modulo,
                                 pag_cta.g_ctas.cod_modalidad,
                                 null,
                                 null,
                                 'REINTEGRO PAGO QR',
                                 'S',
                                 v_nro_secuencia,
                                 v_fec_valor);
        if pag_cta.fu_obt_cod_error() <> 0 then
          v_cod_error := pag_cta.fu_obt_cod_error;
          v_men_error := pag_cta.fu_obt_msj_error;
          v_val_reintegro := 'N';
        else
          v_cod_error := null;
          v_men_error := null;
          pr_ins_mov_reintegros;
        end if;
      end if;
      pr_log_reintegros(qr.Provide_Service_Code,qr.ticket_number,qr.commerce_code, qr.branch_code,null,
                        v_mto_reintegro,v_val_reintegro,v_cod_error,v_men_error, qr.customer_account_number);
      -- se actualiza el nro identificador
      v_identificador := qr.identificador;
      commit;
    end loop;
    if v_identificador is not null then
      begin
        update ge_par_dinamicos a
        set a.val_parametro = v_identificador
        where a.parametro = 'ULT_NRO_IDE_QR';
        v_identificador := null;
        if sql%notfound then
          begin
            insert into ge_par_dinamicos(parametro,val_parametro)
            values('ULT_NRO_IDE_QR', v_identificador);
          end;
        end if;
      end;
    end if;
    -- Reintegros pagos td
    for td in c_dattd loop
      v_nro_secuencia := 0;
      v_pri_dia_mes   := td.fec_inicio;
      v_ult_dia_mes   := td.fec_fin;
      --v_tot_reintegro := fu_obt_tot_reintegro(td.cod_persona, td.cod_promocion);
      if nvl(td.top_com_tc,0) > 0 then
        v_tot_compra    := fu_obt_tot_compra(td.cod_persona, td.cod_promocion, v_cod_tra_padre);
      else
        v_tot_compra    := fu_obt_tot_compra(td.cod_persona, td.cod_promocion);
      end if;
      pag_cta.pr_obt_cuenta(td.nro_cta_debito);
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',pag_cta.g_ctas.cod_modulo,pag_cta.g_ctas.cod_modalidad,pag_cta.g_ctas.cod_moneda);
      v_por_reintegro := fug_obt_por_reintegro(td.cod_promocion, td.cod_persona, td.por_reintegro);
      if v_por_reintegro is null then
        v_por_reintegro := td.por_reintegro;
      end if;
      if nvl(v_tot_compra,0) < td.top_compra then
        if nvl(v_tot_compra,0) + td.mto_total > td.top_compra then
          v_compra := td.top_compra - nvl(v_tot_compra,0);
        else
          v_compra := td.mto_total;
        end if;
        if v_por_reintegro is not null then
          v_mto_reintegro := round((v_compra * v_por_reintegro / 100),v_redondeo);
          v_val_reintegro := 'S';
        else
          v_val_reintegro := 'N';
        end if;
      else
        v_val_reintegro := 'N';
      end if;
      -- credito de reintegro
      if nvl(v_val_reintegro,'N') = 'S' then
        v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_nocturno);
        pag_cta.pr_set_nro_documento2(null);
        pag_cta.pr_set_nro_documento3(td.nro_documento);
        v_nro_cuenta := td.nro_cta_debito;
        v_cod_moneda := pag_cta.g_ctas.cod_moneda;
        v_mto_compra := td.mto_total;
        v_mto_com_reintegro := v_compra;
        v_cod_cli_comercio := td.cod_cli_comercio;
        v_nom_comercio     := td.nom_comercio;
        v_cod_comercio     := td.cod_comercio;
        v_cod_suc_comercio := td.cod_suc_comercio;
        v_cod_promocion    := td.cod_promocion;
        begin
          
        pag_cta.pr_act_operacion(td.nro_cta_debito,
                                 v_hora,
                                 'C',
                                 pag_cta.g_ctas.cod_moneda,
                                 v_mto_reintegro,
                                 v_cod_tra_padre,
                                 v_cod_tra_padre,
                                 td.cod_cli_comercio,
                                 null,
                                 pag_cta.g_ctas.cod_oficina,
                                 pag_cta.g_ctas.cod_modulo,
                                 pag_cta.g_ctas.cod_modalidad,
                                 null,
                                 null,
                                 'REINTEGRO PAGO TD',
                                 'S',
                                 v_nro_secuencia,
                                 v_fec_valor);
            exception when others then 
              raise_application_error(-20000,sqlerrm||'-'||td.nro_cta_debito);
              end;
        if pag_cta.fu_obt_cod_error() <> 0 then
          v_cod_error := pag_cta.fu_obt_cod_error;
          v_men_error := pag_cta.fu_obt_msj_error;
          v_val_reintegro := 'N';
        else
          v_cod_error := null;
          v_men_error := null;
          pr_ins_mov_reintegros;
        end if;
      end if;
      pr_log_reintegros('TD',td.nro_documento,null,null,td.cod_comercio,
                        v_mto_reintegro,v_val_reintegro,v_cod_error,v_men_error,td.nro_cta_debito);
      -- se actualiza el nro identificador
      v_nro_documento := td.nro_documento;
      commit;
    end loop;
    if v_nro_documento is not null then
      begin
        update ge_par_dinamicos a
        set a.val_parametro = v_nro_documento
        where a.parametro = 'ULT_NRO_DOC_TD';
        v_nro_documento := null;
        if sql%notfound then
          begin
            insert into ge_par_dinamicos(parametro,val_parametro)
            values('ULT_NRO_DOC_TD',v_nro_documento);
          end;
        end if;
      end;
    end if;

    -- Reversiones td
    for revtd in c_tdcancel loop
      v_reversar := 'N';
      begin
        select a.nro_documento
          into v_nro_doc_reverso
          from cv_log_glo_pro a
         where a.nro_transaccion = revtd.nro_tra_cancelado;
      exception
        when no_data_found then
          v_nro_doc_reverso := null;
        when others then
          v_nro_doc_reverso := null;
      end;
      if v_nro_doc_reverso is not null then
        begin
          select a.hora, a.cod_usuario, a.cod_mod_padre, a.cod_mad_padre, 'S', a.fecha, a.nro_cuenta
            into v_hor_rev, v_usu_movimiento, v_cod_mod_padre, v_cod_mad_padre, v_reversar, v_fec_reversion,
                 v_nro_cta_rev
            from ge_movimientos a
           where a.fecha = revtd.fecha
             and a.cod_tra_padre = v_cod_tra_padre
             and a.reversado = 'N'
             and a.nro_documento3 = v_nro_doc_reverso;
        exception
          when no_data_found then
            begin
              select a.hora, a.cod_usuario, a.cod_mod_padre, a.cod_mad_padre, 'S', a.fecha, a.nro_cuenta
                into v_hor_rev, v_usu_movimiento, v_cod_mod_padre, v_cod_mad_padre, v_reversar, v_fec_reversion,
                     v_nro_cta_rev
                from ah_movimientos_his a
               where a.fecha = revtd.fecha
                 and a.cod_tra_padre = v_cod_tra_padre
                 and a.reversado = 'N'
                 and a.nro_documento3 = v_nro_doc_reverso;
            exception
              when no_data_found then
                v_hor_rev        := null;
                v_usu_movimiento := null;
                v_cod_mod_padre  := null;
                v_cod_mad_padre  := null;
                v_reversar       := 'N';
              when others then
                pr_log_reintegros('TD',revtd.nro_documento,null,null,revtd.cod_comercio,
                          -1,v_val_reintegro,v_cod_error,'Error al buscar datos his Nro.Doc: '||v_nro_doc_reverso,revtd.nro_cta_debito);
            end;
          when others then
            pr_log_reintegros('TD',revtd.nro_documento,null,null,revtd.cod_comercio,
                          -1,v_val_reintegro,v_cod_error,'Error al buscar datos Nro.Doc: '||v_nro_doc_reverso,revtd.nro_cta_debito);
        end;
      -- aqui verificar la cuenta 
       pag_cta.PR_VER_OPERACION(revtd.nro_cta_debito,
                                v_cod_tra_padre,
                                v_cod_mod_padre,
                                v_cod_mad_padre,
                                'D',
                                revtd.cod_moneda,
                                revtd.mto_total,
                                61,
                                v_cod_modulo,
                                v_cod_modalidad,
                                v_nvo_estado      ,
                                v_sal_disponible  ,
                                v_procesa         ,
                                v_cod_transaccion );
        v_reversar := v_procesa;
        if nvl(v_reversar,'N') = 'S' then
          v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_nocturno);
          begin 
            prg_rev_operacion(revtd.fecha,v_hor_rev,v_usu_movimiento,v_cod_mod_padre, v_cod_mad_padre, v_cod_tra_padre, user, v_hora, 'N', 'Rev.Reintegro');
            pr_ins_mov_reintegros('S');
          exception
            when others then
              v_error := substr(sqlerrm,1,200);
              pr_log_reintegros('TD',revtd.nro_documento,null,null,revtd.cod_comercio,
                          -1,v_val_reintegro,v_cod_error,v_error,revtd.nro_cta_debito);
              v_error := null;
          end;
         else
           pr_log_reintegros('TD',revtd.nro_documento,null,null,revtd.cod_comercio,
                             -revtd.mto_total,v_val_reintegro,v_cod_error,v_error,revtd.nro_cta_debito);        
         end if;
      end if;
      commit;
    end loop;
    -- reversiones qr
    for revqr in c_qrcancel loop
      v_reversar := 'N';
      begin
        select a.hora, a.cod_usuario, a.cod_mod_padre, a.cod_mad_padre, 'S'
          into v_hor_rev, v_usu_movimiento, v_cod_mod_padre, v_cod_mad_padre, v_reversar
          from ge_movimientos a
         where a.fecha = revqr.transaction_date
           and a.cod_tra_padre = v_cod_tra_padre
           and a.reversado = 'N'
           and a.nro_documento3 = revqr.ticket_number;
      exception
        when no_data_found then
          begin
             select a.hora, a.cod_usuario, a.cod_mod_padre, a.cod_mad_padre, 'S'
               into v_hor_rev, v_usu_movimiento, v_cod_mod_padre, v_cod_mad_padre, v_reversar
               from ah_movimientos_his a
              where a.fecha = revqr.transaction_date
                and a.cod_tra_padre = v_cod_tra_padre
                and a.reversado = 'N'
                and a.nro_documento3 = revqr.ticket_number;
          exception
            when no_data_found then
              v_hor_rev        := null;
              v_usu_movimiento := null;
              v_cod_mod_padre  := null;
              v_cod_mad_padre  := null;
              v_reversar       := 'N';
            when others then
              pr_log_reintegros(revqr.Provide_Service_Code,revqr.ticket_number,revqr.commerce_code, revqr.branch_code,null,
                        -1,v_val_reintegro,v_cod_error,'Error al buscar datos his ticket: '||revqr.ticket_number, revqr.customer_account_number);
          end;
        when others then
          pr_log_reintegros(revqr.Provide_Service_Code,revqr.ticket_number,revqr.commerce_code, revqr.branch_code,null,
                        -1,v_val_reintegro,v_cod_error,'Error al buscar datos ticket: '||revqr.ticket_number, revqr.customer_account_number);
      end;
      -- aqui verificar la cuenta
      v_moneda := revqr.currency_code;
      if revqr.currency_code = 600 then
        v_moneda := pag_gen.FU_OBT_MON_LOCAL;
      end if;
      pag_cta.PR_VER_OPERACION(revqr.customer_account_number,
                               v_cod_tra_padre,
                               v_cod_mod_padre,
                               v_cod_mad_padre,
                               'D',
                               v_moneda,
                               revqr.transaction_amount * -1,
                               61,
                               v_cod_modulo,
                               v_cod_modalidad,
                               v_nvo_estado      ,
                               v_sal_disponible  ,
                               v_procesa         ,
                               v_cod_transaccion );
     
      v_reversar := v_procesa;

      if nvl(v_reversar,'N') = 'S' then
        v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_nocturno);
        begin
          prg_rev_operacion(revqr.transaction_date,v_hor_rev,v_usu_movimiento,v_cod_mod_padre, v_cod_mad_padre, v_cod_tra_padre, user, v_hora, 'N', 'Rev.Reintegro');
          pr_ins_mov_reintegros('S');
        exception
          when others then
            v_error := substr(sqlerrm,1,200);
            pr_log_reintegros(revqr.Provide_Service_Code,revqr.ticket_number,revqr.commerce_code, revqr.branch_code,null,
                        -1,v_val_reintegro,v_cod_error,v_error, revqr.customer_account_number);
            v_error := null;
        end;
      else
        pr_log_reintegros(revqr.Provide_Service_Code,revqr.ticket_number,revqr.commerce_code, revqr.branch_code,null,
                        revqr.transaction_amount,v_val_reintegro,pag_cta.g_cod_error, pag_cta.g_msj_error, revqr.customer_account_number);
                 
      end if;
      commit;
    end loop;

end;
/
