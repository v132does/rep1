create or replace procedure it.PRG_GEN_POS_CLIENTES IS

  --Variables--
  v_fec_actual          date;
  v_can_dia_vto         number;
  v_saldo_gs            number;
  v_vto_dias            number;
  v_ren_tas_dias        number;
  v_tar_dia_mora        number;
  v_mon_dep_ext         number;
  v_venc_comex          number;
  v_venc_gtias          number;
  v_venc_lin_cred       number;
  v_cump_dias           number;
  v_cod_reporte         varchar2(10);
  v_cda_dias            number;
  v_des_rep_pos_cliente ba_cod_referencias.significado%type;

  --Cursores--
  Cursor c_pos_cli_01_lin_sobregiros is --Sobregiros
    select x.cod_usu_oficial,
           z.nombre oficial,
           y.cod_persona,
           y.nom_completo,
           k.nro_cuenta,
           k.cod_moneda,
           nvl(k.sal_total, 0) - nvl(k.sal_retenido, 0) saldo,
           m.can_dias,
           m.can_dia_sobregiro,
           pp.monto mto_lin_permanente,
           pp.fec_vencimiento fec_vto_lin_permanente,
           pp.nro_secuencia nro_lin_sob_permanente,
           tt.monto mto_lin_temporal,
           tt.fec_vencimiento fec_vto_lin_temporal,
           tt.nro_secuencia nro_lin_sob_temporal
      from ge_clientes x,
           ba_personas y,
           ba_usuarios z,
           cc_cta_corrientes k,
           ge_cta_clientes n,
           cc_sobregiros_res m,
           (select xx.cod_persona,
                   xx.cod_moneda,
                   xx.monto,
                   xx.tipo,
                   xx.fec_vencimiento,
                   xx.nro_secuencia
              from cc_lin_sobregiros xx
             where xx.estado = 'A'
               and xx.tipo = 'P'
               and xx.cod_persona is not null) pp,
           (select xx.cod_persona,
                   xx.cod_moneda,
                   xx.monto,
                   xx.tipo,
                   xx.fec_vencimiento,
                   xx.nro_secuencia
              from cc_lin_sobregiros xx
             where xx.estado = 'A'
               and xx.tipo = 'T'
               and xx.cod_persona is not null) tt
     where /*x.cod_usu_oficial = 'PY00114'
       and*/ y.cod_persona = x.cod_persona
       and z.cod_usuario = x.cod_usu_oficial
       and n.nro_cuenta = k.nro_cuenta
       and n.relacion = 'P'
       and n.cod_persona = y.cod_persona
       and nvl(k.sal_total, 0) - nvl(k.sal_retenido, 0) < 0
       and m.nro_cuenta(+) = k.nro_cuenta
       and y.cod_persona = pp.cod_persona(+)
       and y.cod_persona = tt.cod_persona(+);
  ---
  cursor c_pos_cli_02_pres_a_vencer is -- Colocaciones (prestamos) a vencer
    select x.cod_usu_oficial,
           z.nombre oficial,
           y.cod_persona,
           y.nom_completo,
           fue_obt_tel_principa(y.cod_persona) telefono,
           k.nro_cuenta,
           q.descripcion tipo,
           k.fec_vencimiento fec_ven_ope,
           u.estado || '-' || u.descripcion estado,
           k.cod_moneda mon,
           p.nro_cuota || '/' || k.can_cuotas cuota,
           p.fec_vencimiento fec_ven_cuo,
           case
             when p.fec_vencimiento < v_fec_actual then
              v_fec_actual - p.fec_vencimiento
             else
              0
           end dia_mora,
           p.sal_capital sal_cap_cuo,
           k.sal_capital sal_cap_ope
      from ge_clientes      x,
           ba_personas      y,
           ba_usuarios      z,
           pr_cta_prestamos k,
           ge_cta_clientes  n,
           pr_cuotas        p,
           ge_modalidades   q,
           ge_est_cuentas   u
     where/* x.cod_usu_oficial = 'PY00114'
       and*/ y.cod_persona = x.cod_persona
       and z.cod_usuario = x.cod_usu_oficial
       and n.nro_cuenta = k.nro_cuenta
       and n.relacion = 'P'
       and n.cod_persona = y.cod_persona
       and k.estado <> 'N'
       and p.nro_cuenta = k.nro_cuenta
       and p.nro_cuota > 0
       and p.estado <> 'N'
       and (((p.fec_vencimiento - v_fec_actual) < 0) or
           ((p.fec_vencimiento - v_fec_actual) <= v_can_dia_vto))
       and q.cod_modulo = k.cod_modulo
       and q.cod_modalidad = k.cod_modalidad
       and u.cod_modulo = k.cod_modulo
       and u.cod_modalidad = k.cod_modalidad
       and u.estado = k.estado
       and k.estado <> 'I' --Se excluye incobrables--
     order by 15 desc;
  ---
  cursor c_pos_cli_03_pas_superior is -- Pasivas superiores a 200000000
    select x.cod_usu_oficial,
           z.nombre oficial,
           y.cod_persona,
           y.nom_completo,
           fue_obt_tel_principa(y.cod_persona) telefono,
           k.nro_cuenta,
           q.descripcion tipo,
           k.cod_moneda mon,
           nvl(k.sal_total, 0) - nvl(k.sal_retenido, 0) saldo,
           fub_con_mon_a_moneda(k.cod_moneda,
                                'GS',
                                nvl(k.sal_total, 0) - nvl(k.sal_retenido, 0)) sal_gs
      from ge_clientes     x,
           ba_personas     y,
           ba_usuarios     z,
           ah_cta_vistas   k,
           ge_cta_clientes n,
           ge_modalidades  q
     where /*x.cod_usu_oficial = 'PY00114'
       and*/ y.cod_persona = x.cod_persona
       and z.cod_usuario = x.cod_usu_oficial
       and n.nro_cuenta = k.nro_cuenta
       and n.relacion = 'P'
       and n.cod_persona = y.cod_persona
       and k.estado <> 'C'
       and q.cod_modulo = k.cod_modulo
       and q.cod_modalidad = k.cod_modalidad
       and fub_con_mon_a_moneda(k.cod_moneda,
                                'GS',
                                nvl(k.sal_total, 0) - nvl(k.sal_retenido, 0)) >
           v_saldo_gs
    union
    select x.cod_usu_oficial,
           z.nombre oficial,
           y.cod_persona,
           y.nom_completo,
           fue_obt_tel_principa(y.cod_persona) telefono,
           k.nro_cuenta,
           q.descripcion tipo,
           k.cod_moneda mon,
           nvl(k.sal_total, 0) - nvl(k.sal_retenido, 0) saldo,
           fub_con_mon_a_moneda(k.cod_moneda,
                                'GS',
                                nvl(k.sal_total, 0) - nvl(k.sal_retenido, 0)) sal_gs
      from ge_clientes       x,
           ba_personas       y,
           ba_usuarios       z,
           cc_cta_corrientes k,
           ge_cta_clientes   n,
           ge_modalidades    q
     where/* x.cod_usu_oficial = 'PY00114'
       and*/ y.cod_persona = x.cod_persona
       and z.cod_usuario = x.cod_usu_oficial
       and n.nro_cuenta = k.nro_cuenta
       and n.relacion = 'P'
       and n.cod_persona = y.cod_persona
       and k.estado <> 'C'
       and q.cod_modulo = k.cod_modulo
       and q.cod_modalidad = k.cod_modalidad
       and fub_con_mon_a_moneda(k.cod_moneda,
                                'GS',
                                nvl(k.sal_total, 0) - nvl(k.sal_retenido, 0)) >
           v_saldo_gs;

  ----
  cursor c_pos_cli_04_exc_al_tarifario is -- exc_al_tarifario
    select k.cod_usu_oficial,
           x.cod_persona,
           null nro_cuenta,
           z.nom_completo,
           y.descripcion,
           y.tip_valor,
           y.tipo,
           x.fec_vigencia,
           x.fec_vencimiento,
           x.val_Tasa,
           to_char(x.val_extension) || '%' val_extension
      from ge_tas_fechas x, ge_tasas y, ba_personas z, ge_clientes k
     where x.cod_persona is not null
       and y.cod_tasa = x.cod_tasa
       and z.cod_persona = x.cod_persona
       and k.cod_persona = x.cod_persona
     /*  and k.cod_usu_oficial = 'PY00615'*/
       and x.fec_vencimiento between v_fec_actual and
           (v_fec_actual + v_vto_dias)
    UNION
    select k.cod_usu_oficial,
           null cod_persona,
           x.nro_cuenta,
           z.nom_completo,
           y.descripcion,
           y.tip_valor,
           y.tipo,
           x.fec_vigencia,
           x.fec_vencimiento,
           x.val_tasa,
           to_char(x.val_extension) || '%' val_extension

      from ge_tas_fechas x, ge_tasas y, ba_personas z, ge_clientes K
     where nro_cuenta is not null

       and y.cod_tasa = x.cod_tasa
       and z.cod_persona = x.cod_persona
       and k.cod_persona = x.cod_persona

       /*and k.cod_usu_oficial = 'PY00408'*/;

  -- pre_ren_tas_interes

  cursor c_pos_cli_05_pre_ren_tas_int is
    select x.cod_usu_oficial,
           z.nombre oficial,
           y.cod_persona,
           y.nom_completo,
           fue_obt_tel_principa(y.cod_persona) telefono,
           k.nro_cuenta,
           q.descripcion tipo,
           k.fec_vencimiento fec_ven_ope,
           u.estado || '-' || u.descripcion estado,
           k.cod_moneda mon,
           k.can_cuo_pagadas || ' / ' || k.can_cuotas cuo_pag,
           k.sal_capital sal_cap_ope,
           k.fec_ren_tas_orig,
           to_char(k.val_tasa) || '%' tas_actual
      from ge_clientes      x,
           ba_personas      y,
           ba_usuarios      z,
           pr_cta_prestamos k,
           ge_cta_clientes  n,
           ge_modalidades   q,
           ge_est_cuentas   u
     where y.cod_persona = x.cod_persona
       and z.cod_usuario = x.cod_usu_oficial
       and n.nro_cuenta = k.nro_cuenta
       and n.relacion = 'P'
       and n.cod_persona = y.cod_persona
       and k.estado <> 'N'
       and (((k.fec_ren_tas_orig - v_fec_actual) < 0) or
           ((k.fec_ren_tas_orig - v_fec_actual) <= v_ren_tas_dias))
       and k.fec_ren_tas_orig is not null
       and q.cod_modulo = k.cod_modulo
       and q.cod_modalidad = k.cod_modalidad
       and u.cod_modulo = k.cod_modulo
       and u.cod_modalidad = k.cod_modalidad
       and u.estado = k.estado
       and k.estado <> 'I' --Se excluye incobrables--
     order by k.fec_ren_tas_orig;
  --
  cursor c_pos_cli_06_cda_a_vencer is -- cda a vencer

    select x.cod_usu_oficial,
           z.nombre oficial,
           y.cod_persona,
           y.nom_completo,
           fue_obt_tel_principa(y.cod_persona) telefono,
           k.nro_cuenta,
           q.descripcion tipo,
           k.fec_vencimiento,
           k.estado || '-' || m.descripcion estado,
           k.cod_moneda mon,
           k.capital,
           nvl(xx_mto_int_ven, 0) sal_cup,
           decode(k.est_certificado, 'V', k.capital, 0) sal_cap,
           k.sal_bloqueado --DYDMR-3870 Se agrega el saldo bloqueado para identificar cuentas que corresponden a garantias.
      from ge_clientes x,
           ba_personas y,
           ba_usuarios z,
           ah_cta_certificados k,
           ge_cta_clientes n,
           ge_modalidades q,
           ge_est_cuentas m,
           (select xx.nro_cuenta xx_nro_cuenta,
                   sum(nvl(xx.mto_interes, 0)) xx_mto_int_ven
              from ah_cupones xx
             where xx.estado = 'V'
             group by xx.nro_cuenta)

     where y.cod_persona = x.cod_persona
       and z.cod_usuario = x.cod_usu_oficial
       and n.nro_cuenta = k.nro_cuenta
       and n.relacion = 'P'
       and n.cod_persona = y.cod_persona
       and k.estado not in ('A', 'C', 'T', 'X')
       and q.cod_modulo = k.cod_modulo
       and q.cod_modalidad = k.cod_modalidad
       and k.fec_vencimiento <=  (v_fec_actual + v_cda_dias) --to_date('15/03/2014', 'dd/mm/yyyy')
       and m.cod_modulo = k.cod_modulo
       and m.cod_modalidad = k.cod_modalidad
       and m.estado = k.estado
       and xx_nro_cuenta(+) = k.nro_cuenta
       --and nvl(k.sal_bloqueado, 0) = 0 DYDMR-3870 Se elimina la condición para visualizar cuentas asociadas a garantias
     order by k.fec_vencimiento;
  --
  cursor c_pos_cli_07_tar_vencidas is -- tarjetas vencidas
    select x.cod_usu_oficial,
           z.nombre oficial,
           y.cod_persona,
           y.nom_completo,
           fue_obt_tel_principa(y.cod_persona) telefono,
           k.nro_cuenta,
           q.descripcion tipo,
           k.dia_mora,
           k.cod_moneda mon,
           k.lin_credito,
           k.sal_procesadora saldo
      from ge_clientes     x,
           ba_personas     y,
           ba_usuarios     z,
           ta_cta_tarjetas k,
           ge_cta_clientes n,
           ge_modalidades  q
     where y.cod_persona = x.cod_persona
       and z.cod_usuario = x.cod_usu_oficial
       and n.nro_cuenta = k.nro_cuenta
       and n.relacion = 'P'
       and n.cod_persona = y.cod_persona
       and k.estado <> 'C'
       and q.cod_modulo = k.cod_modulo
       and q.cod_modalidad = k.cod_modalidad
       and k.dia_mora >= v_tar_dia_mora;
  --
  cursor c_pos_cli_08_mov_depo_ext is -- mov depo ext mayor a 200.000.000
    select x.cod_usu_oficial,
           z.nombre oficial,
           y.cod_persona,
           y.nom_completo,
           fue_obt_tel_principa(y.cod_persona) telefono,
           k.nro_cuenta,
           q.descripcion tipo,
           k.cod_tra_padre,
           k.cod_tra_padre || '-' || t1.descripcion des_tra_padre,
           k.cod_transaccion,
           k.cod_transaccion || '-' || t2.descripcion des_transaccion,
           k.nro_documento,
           k.cod_moneda mon,
           k.monto
      from ge_clientes      x,
           ba_personas      y,
           ba_usuarios      z,
           ge_movimientos   k,
           ge_cta_clientes  n,
           ge_modalidades   q,
           ge_transacciones t1,
           ge_transacciones t2
     where /*x.cod_usu_oficial = 'PY00513'
       and*/ y.cod_persona = x.cod_persona
       and z.cod_usuario = x.cod_usu_oficial
       and n.nro_cuenta = k.nro_cuenta
       and n.relacion = 'P'
       and n.cod_persona = y.cod_persona
       and k.estado <> 'C'
       and q.cod_modulo = k.cod_modulo
       and q.cod_modalidad = k.cod_modalidad
       and k.reversado = 'N'
       and fub_con_mon_a_moneda(k.cod_moneda, 'GS', K.MONTO, null, k.fecha) >
           v_mon_dep_ext
       and k.fecha = v_fec_actual
       and k.cod_mod_padre = t1.cod_modulo
       and k.cod_mad_padre = t1.cod_modalidad
       and k.cod_tra_padre = t1.cod_transaccion
       and k.cod_modulo = t2.cod_modulo
       and k.cod_modalidad = t2.cod_modalidad
       and k.cod_transaccion = t2.cod_transaccion
       and FUP_EXI_GRU_TRANSAC(801, k.cod_tra_padre, 4, 41) = 'N'
       AND FUP_EXI_GRU_TRANSAC(801, k.cod_tra_padre, 6, 60) = 'N';

  --k.cod_tra_padre not in (310, 902, 942, 912, 358);
  --
  cursor c_pos_cli_09_venc_comex is -- VENC COMEX
    select cli.cod_usu_oficial,
           pe.nombre oficial,
           decode(o.estado, 'N', 'Pendiente', 'P', 'Pagado', 'Otro') Estado,
           c.cod_persona Persona,
           p.nom_completo Nombre,
           o.fec_vencimiento Vto,
           o.nro_cuenta Cuenta,
           e.cod_moneda Moneda,
           o.saldo,
           e.cod_oficina Oficina,
           e.cod_modalidad ,
           mo.descripcion des_modalidad
      from cx_cuotas       o,
           ge_cuentas      e,
           ge_cta_clientes c,
           ba_personas     p,
           ge_clientes     cli,
           ba_usuarios     pe,
           ge_modalidades  mo
     where o.nro_cuenta = c.nro_cuenta
       and o.nro_cuenta = e.nro_cuenta
       and c.relacion = 'P'
       and nvl(o.saldo, 0) > 0
       and c.cod_persona = p.cod_persona
       and ((o.fec_vencimiento < v_fec_actual) or
           (o.fec_vencimiento <= v_fec_actual + v_venc_comex))
       and cli.cod_persona = c.cod_persona
       and pe.cod_usuario = cli.cod_usu_oficial
       and mo.cod_modulo = e.cod_modulo
       and mo.cod_modalidad = e.cod_modalidad
     order by 2, 4;
  --
  cursor c_pos_cli_10_venc_gar_prest is --vencimiento garantias prestamos
    select cli.cod_usu_oficial,
           u.nombre oficial,
           a.cod_persona,
           a.nro_garantia,
           a.cod_garantia || '-' || ti.descripcion tip_gar,
           a.estado || '-' ||
           fue_obt_des_refcodes('EST_GARANTIA', A.ESTADO) EST_GAR,
           a.fec_vencimiento,
           a.cod_moneda,
           a.valor,
           a.mto_aplicado
      from pr_garantias a, pr_gar_tipos ti, ge_clientes cli, ba_usuarios u
     where ((a.fec_vencimiento < v_fec_actual) or
           (a.fec_vencimiento <= v_fec_actual + v_venc_gtias))
       and a.estado = 'V'
       and cli.cod_persona = a.cod_persona
       and u.cod_usuario = cli.cod_usu_oficial
       and ti.cod_garantia = a.cod_garantia;
  --
  cursor c_pos_cli_11_venc_lin_credito is -- vencimiento linea credito
    select cli.cod_usu_oficial,
           u.nombre oficial,
           a.nro_linea,
           a.cod_persona,
           b.nom_completo,
           a.fec_otorgamiento,
           a.fec_vencimiento,
           decode(upper(FUE_OBT_DES_REFCODES('NIV_APROBACION', a.niv_aprobacion)),'REFERENCIA  NO REGISTRADA EN EL SISTEMA',null,FUE_OBT_DES_REFCODES('NIV_APROBACION', a.niv_aprobacion)) niv_apro,
           a.cod_moneda,
           a.monto
      from pr_lineas a, ba_personas b, ge_clientes cli, ba_usuarios u
     where b.cod_persona = a.cod_persona
       and a.estado = 'A'
       and a.fec_vencimiento <= (v_fec_actual + v_venc_lin_cred)
       and cli.cod_persona = a.cod_persona
       and u.cod_usuario = cli.cod_usu_oficial;

  --
  cursor c_pos_cli_12_cum_clientes is -- cumpleaños de clientes
    select cli.cod_usu_oficial,
           u.nombre oficial,
           a.cod_persona,
           a.nom_completo,
           b.fec_nacimiento
      from ba_personas a, ge_clientes cli, ba_usuarios u, ba_per_fisicas b
     where a.cod_persona = cli.cod_persona
       and u.cod_usuario = cli.cod_usu_oficial
       and b.cod_persona = a.cod_persona
       and to_number(to_char(b.fec_nacimiento, 'mmdd')) between
           to_number(to_char(v_fec_actual, 'mmdd')) and
           to_number(to_char(v_fec_actual, 'mmdd')) + v_cump_dias;

begin
  --Carga de Variables--
  v_fec_actual    := pae_cnf.fu_obt_fec_actual(1);
  v_can_dia_vto   := to_number(fug_obt_pardinamico('REP_POS_CLI_CAN_DIA_VEN'));
  v_saldo_gs      := to_number(fug_obt_pardinamico('REP_POS_CLI_SALDO_GS'));
  v_vto_dias      := to_number(fug_obt_pardinamico('REP_POS_CLI_VTO_EN_DIAS'));
  v_ren_tas_dias  := to_number(fug_obt_pardinamico('REP_POS_CLI_TAS_INT_DIAS'));
  v_tar_dia_mora  := to_number(fug_obt_pardinamico('REP_POS_CLI_TAR_DIA_MORA'));
  v_mon_dep_ext   := to_number(fug_obt_pardinamico('REP_POS_CLI_DEP_EXT_MONTO'));
  v_venc_comex    := to_number(fug_obt_pardinamico('REP_POS_CLI_VTO_COMEX_DIA'));
  v_venc_gtias    := to_number(fug_obt_pardinamico('REP_POS_CLI_VTO_GTIA_DIAS'));
  v_venc_lin_cred := to_number(fug_obt_pardinamico('REP_POS_CLI_VTO_LIN_CRED'));
  v_cump_dias     := to_number(fug_obt_pardinamico('REP_POS_CLI_CUMP_PROX_DIAS'));
  v_cda_dias := to_number (fug_obt_pardinamico ('REP_POS_CLI_CDA_VTO_DIAS'));
  --Elimnar datos anteriores--
  delete from ge_pos_clientes_det a where a.fecha = v_fec_actual;

  --Procesamiento de Informacion--
  v_cod_reporte         := '1';
  v_des_rep_pos_cliente := fue_obt_des_refcodes('COD_REP_POS_CLIENTE',
                                                v_cod_reporte);
  --sobregiros
  for c in c_pos_cli_01_lin_sobregiros loop
    insert into ge_pos_clientes_det
      (fecha,
       cod_reporte,
       cod_usu_oficial,
       nom_oficial,
       cod_persona,
       nom_completo,
       nro_cuenta,
       cod_moneda,
       can_dias,
       can_dias_sobregiro,
       mto_lin_permanente,
       fec_vto_lin_permanente,
       nro_lin_sob_permanente,
       mto_lin_temporal,
       fec_vto_lin_temporal,
       nro_lin_sob_temporal,
       saldo)
    values
      (v_fec_actual,
       v_cod_reporte,
       c.cod_usu_oficial,
       c.oficial,
       c.cod_persona,
       c.nom_completo,
       c.nro_cuenta,
       c.cod_moneda,
       c.can_dias,
       c.can_dia_sobregiro,
       c.mto_lin_permanente,
       c.fec_vto_lin_permanente,
       c.nro_lin_sob_permanente,
       c.mto_lin_temporal,
       c.fec_vto_lin_temporal,
       c.nro_lin_sob_temporal,
       c.saldo);
  end loop;
  --prestamos a vencer
  v_cod_reporte := '2';
  for d in c_pos_cli_02_pres_a_vencer loop
    insert into ge_pos_clientes_det
      (fecha,
       cod_reporte,
       cod_usu_oficial,
       nom_oficial,
       cod_persona,
       nom_completo,
       nro_cuenta,
       cod_moneda,
       telefono,
       tipo,
       fec_vencimiento,
       estado,
       cuota,
       fec_ven_cuota,
       dia_mora,
       sal_cap_cuota,
       sal_cap_operacion)
    values
      (v_fec_actual,
       v_cod_reporte,
       d.cod_usu_oficial,
       d.oficial,
       d.cod_persona,
       d.nom_completo,
       d.nro_cuenta,
       d.mon,
       d.telefono,
       d.tipo,
       d.fec_ven_ope,
       d.estado,
       d.cuota,
       d.fec_ven_cuo,
       d.dia_mora,
       d.sal_cap_cuo,
       d.sal_cap_ope);
  end loop;
  --pasivas  superiores a 200.000.000
  v_cod_reporte := '3';
  for e in c_pos_cli_03_pas_superior loop
    insert into ge_pos_clientes_det
      (fecha,
       cod_reporte,
       cod_usu_oficial,
       nom_oficial,
       cod_persona,
       nom_completo,
       nro_cuenta,
       cod_moneda,
       telefono,
       tipo,
       saldo,
       sal_mon_local)
    values
      (v_fec_actual,
       v_cod_reporte,
       e.cod_usu_oficial,
       e.oficial,
       e.cod_persona,
       e.nom_completo,
       e.nro_cuenta,
       e.mon,
       e.telefono,
       e.tipo,
       e.saldo,
       e.sal_gs);
  end loop;

  --- Exc_al_tarifario
  v_cod_reporte := '4';
  for f in c_pos_cli_04_exc_al_tarifario loop
    insert into ge_pos_clientes_det
      (fecha,
       cod_reporte,
       cod_usu_oficial,
       cod_persona,
       nro_cuenta,
       nom_completo,
       descripcion,
       tip_valor,
       tipo,
       fec_vigencia,
       fec_vencimiento,
       val_tasa,
       val_extension)
    values
      (v_fec_actual,
       v_cod_reporte,
       f.cod_usu_oficial,
       f.cod_persona,
       f.nro_cuenta,
       f.nom_completo,
       f.descripcion,
       f.tip_valor,
       f.tipo,
       f.fec_vigencia,
       f.fec_vencimiento,
       f.val_tasa,
       f.val_extension);
  end loop;

  --- pre_ren_tas_interes

  v_cod_reporte := '5';
  for g in c_pos_cli_05_pre_ren_tas_int loop
    insert into ge_pos_clientes_det
      (fecha,
       cod_reporte,
       cod_usu_oficial,
       nom_oficial,
       cod_persona,
       nom_completo,
       telefono,
       nro_cuenta,
       tipo,
       fec_vencimiento,
       estado,
       cod_moneda,
       cuota,
       sal_cap_operacion,
       fec_ren_tas_orig,
       tas_actual)
    values
      (v_fec_actual,
       v_cod_reporte,
       g.cod_usu_oficial,
       g.oficial,
       g.cod_persona,
       g.nom_completo,
       g.telefono,
       g.nro_cuenta,
       g.tipo,
       g.fec_ven_ope,
       g.estado,
       g.mon,
       g.cuo_pag,
       g.sal_cap_ope,
       g.fec_ren_tas_orig,
       g.tas_Actual);
  end loop;

  --- cda a vencer
  v_cod_reporte := '6';
  for h in c_pos_cli_06_cda_a_vencer loop
    insert into ge_pos_clientes_det
      (fecha,
       cod_reporte,
       cod_usu_oficial,
       nom_oficial,
       cod_persona,
       nom_completo,
       telefono,
       nro_cuenta,
       tipo,
       fec_vencimiento,
       estado,
       cod_moneda,
       capital,
       sal_int_vencido,
       sal_cap_operacion,
       monto) --DYDMR-3870 Se utiliza el campo MONTO para insertar el saldo bloqueado
    values
      (v_fec_actual,
       v_cod_reporte,
       h.cod_usu_oficial,
       h.oficial,
       h.cod_persona,
       h.nom_completo,
       h.telefono,
       h.nro_cuenta,
       h.tipo,
       h.fec_vencimiento,
       h.estado,
       h.mon,
       h.capital,
       h.sal_cup,
       h.sal_cap, 
       h.sal_bloqueado); --DYDMR-3870 Se agrega el campo para insertar el saldo bloqueado
  end loop;
  --- Tarjetas vencidas
  v_cod_reporte := '7';
  for i in c_pos_cli_07_tar_vencidas loop
    insert into ge_pos_clientes_det
      (fecha,
       cod_reporte,
       cod_usu_oficial,
       nom_oficial,
       cod_persona,
       nom_completo,
       telefono,
       nro_cuenta,
       tipo,
       dia_mora,
       cod_moneda,
       saldo,
       lin_credito)
    values
      (v_fec_actual,
       v_cod_reporte,
       i.cod_usu_oficial,
       i.oficial,
       i.cod_persona,
       i.nom_completo,
       i.telefono,
       i.nro_cuenta,
       i.tipo,
       i.dia_mora,
       i.mon,
       i.saldo,
       i.lin_credito);
  end loop;
  --mov depo ext mayor a 200.000.000
  v_cod_reporte := '8';

  for j in c_pos_cli_08_mov_depo_ext loop
    insert into ge_pos_clientes_det
      (fecha,
       cod_reporte,
       cod_usu_oficial,
       nom_oficial,
       cod_persona,
       nom_completo,
       telefono,
       nro_cuenta,
       tipo,
       cod_tra_padre,
       des_tra_padre,
       cod_transaccion,
       des_transaccion,
       nro_documento,
       cod_moneda,
       monto)
    values
      (v_fec_actual,
       v_cod_reporte,
       j.cod_usu_oficial,
       j.oficial,
       j.cod_persona,
       j.nom_completo,
       j.telefono,
       j.nro_cuenta,
       j.tipo,
       j.cod_tra_padre,
       j.des_tra_padre,
       j.cod_transaccion,
       j.des_transaccion,
       j.nro_documento,
       j.mon,
       j.monto);
  end loop;

  --venc comex
  v_cod_reporte := '9';

  for k in c_pos_cli_09_venc_comex loop
    insert into ge_pos_clientes_det
      (fecha,
       cod_reporte,
       cod_usu_oficial,
       nom_oficial,
       estado,
       cod_persona,
       nom_completo,
       fec_vencimiento,
       nro_cuenta,
       cod_moneda,
       saldo,
       cod_oficina,
       cod_modalidad,
       des_modalidad)
    values
      (v_fec_actual,
       v_cod_reporte,
       k.cod_usu_oficial,
       k.oficial,
       k.estado,
       k.persona,
       k.nombre,
       k.vto,
       k.cuenta,
       k.moneda,
       k.saldo,
       k.oficina,
       k.cod_modalidad,
       k.des_modalidad);
  end loop;
  -- vecimiento garantias prestamos
  v_cod_reporte := '10';

  for l in c_pos_cli_10_venc_gar_prest loop
    insert into ge_pos_clientes_det
      (fecha,
       cod_reporte,
       cod_usu_oficial,
       nom_oficial,
       cod_persona,
       nro_garantia,
       tipo,
       estado,
       fec_vencimiento,
       cod_moneda,
       valor,
       mto_aplicado)
    values
      (v_fec_actual,
       v_cod_reporte,
       l.cod_usu_oficial,
       l.oficial,
       l.cod_persona,
       l.nro_garantia,
       l.tip_gar,
       l.est_gar,
       l.fec_vencimiento,
       l.cod_moneda,
       l.valor,
       l.mto_aplicado);
  end loop;

  -- vecimiento linea de credito
  v_cod_reporte := '11';

  for m in c_pos_cli_11_venc_lin_credito loop
    insert into ge_pos_clientes_det
      (fecha,
       cod_reporte,
       cod_usu_oficial,
       nom_oficial,
       nro_linea,
       cod_persona,
       nom_completo,
       Fec_otorgamiento,
       fec_vencimiento,
       niv_aprobacion,
       cod_moneda,
       monto)
    values
      (v_fec_actual,
       v_cod_reporte,
       m.cod_usu_oficial,
       m.oficial,
       m.nro_linea,
       m.cod_persona,
       m.nom_completo,
       m.fec_otorgamiento,
       m.fec_vencimiento,
       substr(m.niv_apro,1,20),
       m.cod_moneda,
       m.monto);
  end loop;

  -- Cumpleaños de Clientes
  v_cod_reporte := '12';

  for n in c_pos_cli_12_cum_clientes loop
    insert into ge_pos_clientes_det
      (fecha,
       cod_reporte,
       cod_usu_oficial,
       nom_oficial,
       cod_persona,
       nom_completo,
       fec_nacimiento)
    values
      (v_fec_actual,
       v_cod_reporte,
       n.cod_usu_oficial,
       n.oficial,
       n.cod_persona,
       n.nom_completo,
       n.fec_nacimiento);
  end loop;
  commit;

exception
  when others then
    RAISE_APPLICATION_ERROR(-20830,
                            'ERROR. en PRG_GEN_POS_CLIENTES ' || sqlerrm);

end;
/

