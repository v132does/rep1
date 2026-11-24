create or replace procedure it.prt_rei_tarjetas is
  v_fec_actual date := pag_cal.fu_obt_fec_actual(3);
  v_ult_fec_habil date := pag_cal.fu_obt_fec_anterior(3);
    v_fec_valor  date := trunc(sysdate);
  v_hora varchar2(8) := to_char(sysdate,'hh24:mi:ss');
  v_nro_secuencia ge_movimientos.nro_secuencia%TYPE := 0;
  v_cod_tra_padre ge_transacciones.cod_transaccion%type;
  v_horario       VARCHAR2(1) := 'D';
  v_est_modulo    ba_modulos.estado%TYPE;
  v_val_reintegro varchar2(1) := 'N';
  v_mto_reintegro number;
  v_tot_reintegro number;
  v_redondeo      number := 0;
  v_pri_dia_mes   date;
  v_ult_dia_mes   date;
  v_cod_error     varchar2(100);
  v_men_error     varchar2(200);
  v_por_reintegro   ge_com_adheridos.por_reintegro%type;
  v_es_nocturno    varchar2(1) := 'N';
  v_nro_cuenta     ge_cta_clientes.nro_cuenta%type;
  --
  v_nro_cta_tarjeta ge_cuentas.nro_cuenta%type;
  v_cod_moneda      ba_monedas.cod_moneda%type;
  v_mto_compra      number;
  v_cod_cli_comercio ge_com_adheridos.cod_cli_comercio%type;
  v_nom_comercio     ge_com_adheridos.nom_comercio%type;
  v_cod_comercio     ge_com_adheridos.cod_comercio%type;
  v_cod_suc_comercio ge_com_adheridos.cod_suc_comercio%type;
  v_cod_promocion    ge_com_adheridos.cod_promocion%type;
  v_tot_compra       number;
  v_compra           number;
  v_mto_com_reintegro ge_mov_reintegros.mto_com_reintegro%type;
  v_nro_documento3   ge_movimientos.nro_documento3%type;
  v_top_compra       number;

  cursor c_compras is
    select a.*, c.cod_persona, b.fec_inicio, b.fec_fin, b.por_rei_tc, b.top_mes,
           b.cod_promocion, nvl(b.mto_max_tc,b.mon_maximo) mon_maximo, b.cod_cli_comercio,
           b.cod_comercio cod_com_adherido, b.cod_suc_comercio, b.nom_comercio nom_com_adherido,
           nvl(b.top_compra,0) top_compra, nvl(b.top_com_tc,0) top_com_tc
      from ah_con_dia_det a, ge_com_adheridos b, ge_cta_clientes c
     where a.tip_producto = 38
       and a.procesado = 'S'
       and nvl(b.tipo,'D') in ('T', 'A')
       and nvl(b.por_rei_tc,0) > 0
       and a.imp_mon_original >= nvl(b.mto_minimo,0)
       and (b.cod_comercio = ltrim(a.cod_comercio,'0') or b.cod_switch = ltrim(a.cod_comercio,'0'))
       and a.fec_operacion between b.fec_inicio and b.fec_fin
       and a.fec_proceso >= v_ult_fec_habil
       and c.nro_cuenta = a.nro_cuenta
       and c.relacion = 'P'
       and not exists (select 1 from ge_cla_operaciones s
                        where s.dia_atraso >= fug_obt_pardinamico('CAN_DIA_HAB_REINTEGRO')
                          and s.cod_persona = c.cod_persona)
       and not exists (select 1 from ah_movimientos_his e
                        where e.fecha >= a.fec_operacion
                          and e.cod_tra_padre = v_cod_tra_padre
                          and e.reversado = 'N'
                          and e.nro_documento3 = a.nro_comprobante)
       and not exists (select 1 from ge_movimientos e
                        where e.cod_tra_padre = v_cod_tra_padre
                          and e.reversado = 'N'
                          and e.nro_documento3 = a.nro_comprobante)
      order by a.fec_operacion, a.nro_comprobante;

  procedure pr_ins_mov_reintegros(p_reversado in varchar2 default 'N') is
  begin
    insert into ge_mov_reintegros
    (fecha, hora, cod_usuario, nro_secuencia, fec_valor, mto_reintegro, nro_cuenta,
     cod_moneda, mto_compra, reversado, cod_tra_padre, cod_cli_comercio, nom_comercio,
     cod_comercio, cod_suc_comercio, cod_promocion, mto_com_reintegro, nro_documento3, nro_cta_tarjeta)
    values(v_fec_actual, v_hora, user, v_nro_secuencia, v_fec_valor, v_mto_reintegro, v_nro_cuenta,
           v_cod_moneda, v_mto_compra, nvl(p_reversado,'N'), v_cod_tra_padre, v_cod_cli_comercio, v_nom_comercio,
           v_cod_comercio, v_cod_suc_comercio, v_cod_promocion, v_mto_com_reintegro, v_nro_documento3, v_nro_cta_tarjeta);
  end;
  
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
  function fu_obt_tot_reintegro(p_cod_persona in varchar2,
                                p_cod_promocion varchar2,
                                p_fec_operacion date) return number is
    v_tot_reintegros number := 0;
    v_mto_rei_mes_actual number := 0;
    v_ind_top_mes ge_com_adheridos.top_mes%type;
    v_fec_ini date;
    v_fec_fin date;
    v_fec_ini_promo date;
  begin
    v_tot_reintegros := 0;
    v_mto_rei_mes_actual := 0;
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
      v_fec_ini := trunc(p_fec_operacion,'mm');
      v_fec_fin := last_day(p_fec_operacion);
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
          v_fec_ini := trunc(v_fec_actual,'mm');
          v_fec_fin := last_day(v_fec_actual);
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
        into v_tot_reintegros
        from gv_movimientos a, ge_cta_clientes b
       where a.fec_valor between v_fec_ini and v_fec_fin
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
            into v_tot_reintegros
            from gv_movimientos a, ge_cta_clientes b
           where a.fec_valor between v_fec_ini and v_fec_fin
             and a.nro_documento in (select c.cod_cli_comercio
                                       from ge_com_adheridos c
                                      where c.cod_promocion = p_cod_promocion)
             and a.reversado = 'N'
             and a.cod_tra_padre = v_cod_tra_padre
             and b.nro_cuenta = a.NRO_CUENTA
             and b.relacion = 'P'
             and b.cod_persona = p_cod_persona;
       end if;
    exception
      when no_data_found then
        v_tot_reintegros := 0;
      when others then
        v_tot_reintegros := 0;
    end;
    begin
      if v_fec_ini_promo < to_date('01/02/2023','dd/mm/yyyy') then
      select sum(a.monto) tot_reintegro
        into v_mto_rei_mes_actual
        from gv_movimientos a, ge_cta_clientes b
       where a.fec_valor between trunc(v_fec_actual,'mm') and last_day(v_fec_actual)
         and nvl(a.referencia,'x') = to_char(p_fec_operacion,'MMYYYY')
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
        into v_mto_rei_mes_actual
        from gv_movimientos a, ge_cta_clientes b
       where a.fec_valor between trunc(v_fec_actual,'mm') and last_day(v_fec_actual)
         and nvl(a.referencia,'x') = to_char(p_fec_operacion,'MMYYYY')
         and a.nro_documento in (select c.cod_cli_comercio
                                   from ge_com_adheridos c
                                  where c.cod_promocion = p_cod_promocion)
         and a.reversado = 'N'
         and a.cod_tra_padre = v_cod_tra_padre
         and b.nro_cuenta = a.NRO_CUENTA
         and b.relacion = 'P'
         and b.cod_persona = p_cod_persona;
      end if;
       
    end;
    return nvl(v_tot_reintegros,0) + nvl(v_mto_rei_mes_actual,0);
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
  v_cod_tra_padre       := fug_obt_pardinamico('COD_TRA_REI_TARJETAS');
  v_horario             := 'D';
  v_est_modulo          := pae_cnf.fu_obt_est_modulo(3);
  if v_est_modulo != 2 then
    v_horario := 'N';
    v_es_nocturno := 'S';
  else
    v_horario := 'D';
    v_es_nocturno :='N';
  end if;
  pag_cta.g_horario := v_horario;
  for tc in c_compras loop
    v_nro_secuencia := 0;
    v_pri_dia_mes   := tc.fec_inicio;
    v_ult_dia_mes   := tc.fec_fin;
    --v_tot_reintegro := fu_obt_tot_reintegro(tc.cod_persona, tc.cod_promocion, tc.fec_operacion);
    if nvl(tc.top_com_tc,0) > 0 then
      v_tot_compra    := fu_obt_tot_compra(tc.cod_persona, tc.cod_promocion, v_cod_tra_padre);
      v_top_compra    := tc.top_com_tc;
    else
      v_tot_compra    := fu_obt_tot_compra(tc.cod_persona, tc.cod_promocion);
      v_top_compra    := tc.top_compra;
    end if;
    v_nro_cuenta    := null;
    begin
      select max(cli.nro_cuenta)
        into v_nro_cuenta
        from ge_cta_clientes cli, ah_cta_vistas a, ge_cta_dat_adicionales b
       where cli.cod_persona = tc.cod_persona
         and cli.relacion = 'P'
         and a.nro_cuenta = cli.nro_cuenta
         and a.estado in ('N','A','B','S','D','I')
         and a.cod_moneda = pag_gen.fu_obt_mon_local
         and b.nro_cuenta = a.nro_cuenta
         and b.parametro = 'ONB_CTA_FONDEADA';
    exception
      when no_data_found then
        v_nro_cuenta := null;
      when others then
        v_nro_cuenta := null;
    end;
    if v_nro_cuenta is null then
      begin
        select max(cli.nro_cuenta)
          into v_nro_cuenta
          from ge_cta_clientes cli, ah_cta_vistas a
         where cli.cod_persona = tc.cod_persona
           and cli.relacion = 'P'
           and a.nro_cuenta = cli.nro_cuenta
           and a.estado in ('N','A','B','S','D','I')
           and a.cod_moneda = pag_gen.fu_obt_mon_local;
      exception
        when others then
          v_nro_cuenta := null;
      end;
    end if;
    if v_nro_cuenta is not null then
      pag_cta.pr_obt_cuenta(v_nro_cuenta);
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',pag_cta.g_ctas.cod_modulo,pag_cta.g_ctas.cod_modalidad,pag_cta.g_ctas.cod_moneda);
      v_por_reintegro := fug_obt_por_reintegro(tc.cod_promocion, tc.cod_persona, tc.por_rei_tc);
      if v_por_reintegro is null then
        v_por_reintegro := tc.por_rei_tc;
      end if;
      if nvl(v_tot_compra,0) < v_top_compra then
        if nvl(v_tot_compra,0) + tc.imp_mon_original > v_top_compra then
          v_compra := v_top_compra - nvl(v_tot_compra,0);
        else
          v_compra := tc.imp_mon_original;
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
    else
      v_val_reintegro := 'N';
      v_cod_error := '01';
      v_men_error := 'Persona '||tc.cod_persona||' Sin cuenta de modalidad 3.';
      pr_log_reintegros('TC',tc.nro_comprobante,null,null,tc.cod_comercio,
                        v_mto_reintegro,v_val_reintegro,v_cod_error,v_men_error,tc.nro_cuenta);
    end if;
    -- credito de reintegro
    if nvl(v_val_reintegro,'N') = 'S' then
      v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_nocturno);
      if to_char(tc.fec_operacion,'MM') <> to_char(v_fec_actual,'MM') then
        pag_cta.pr_set_referencia(to_char(tc.fec_operacion,'MMYYYY'));
      else
        pag_cta.pr_set_referencia(null);
      end if;
      pag_cta.pr_set_nro_documento3(tc.nro_comprobante);
      v_nro_cta_tarjeta  := tc.nro_cuenta;
      v_cod_moneda       := pag_cta.g_ctas.cod_moneda;
      v_mto_compra       := tc.imp_mon_original;
      v_mto_com_reintegro := v_compra;
      v_cod_cli_comercio := tc.cod_cli_comercio;
      v_nom_comercio     := tc.nom_com_adherido;
      v_cod_comercio     := tc.cod_com_adherido;
      v_cod_suc_comercio := tc.cod_suc_comercio;
      v_cod_promocion    := tc.cod_promocion;
      v_nro_documento3   := tc.nro_comprobante;
      pag_cta.pr_act_operacion(v_nro_cuenta,
                               v_hora,
                               'C',
                               pag_cta.g_ctas.cod_moneda,
                               v_mto_reintegro,
                               v_cod_tra_padre,
                               v_cod_tra_padre,
                               tc.cod_cli_comercio,
                               null,
                               pag_cta.g_ctas.cod_oficina,
                               pag_cta.g_ctas.cod_modulo,
                               pag_cta.g_ctas.cod_modalidad,
                               null,
                               null,
                               'REINTEGRO PAGO TC',
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
      pr_log_reintegros('TC',tc.nro_comprobante,null,null,tc.cod_comercio,
                        v_mto_reintegro,v_val_reintegro,v_cod_error,v_men_error,v_nro_cuenta);
    end if;
    commit;
  end loop;
end;
/

