create or replace procedure it.prg_gen_ext_bancarios is
v_msj               varchar2(500);
v_fec_ini           date;
v_fec_fin           date;
v_fec_extracto      date;
v_fec               date;
v_fec_cie_ant       date;

  procedure lp_tru_tab_temporales is
   begin
     v_msj := null;
     sql_util.ejecute_dml('TRUNCATE TABLE ge_ext_ban_saldos_tmp', v_msj);
     if v_msj is not null then
         RAISE_APPLICATION_ERROR(-20001, v_msj);
     end if;
     v_msj := null;
     sql_util.ejecute_dml('TRUNCATE TABLE ge_ext_ban_movimientos_tmp', v_msj);
     if v_msj is not null then
        RAISE_APPLICATION_ERROR(-20001, v_msj);
     end if;
     v_msj := null;
     sql_util.ejecute_dml('TRUNCATE TABLE ge_ext_ban_entidades_tmp', v_msj);
     if v_msj is not null then
        RAISE_APPLICATION_ERROR(-20001, v_msj);
     end if;
  end lp_tru_tab_temporales;
---
procedure lp_ins_entidades_tmp is

begin
insert into ge_ext_ban_entidades_tmp
 select distinct c.cod_persona, p.nom_completo, cc.nro_cuenta, cc.cod_ente, cc.cod_banco
   from ge_cta_clientes c, ba_personas p, cc_cta_bancarias cc
  where c.cod_persona = p.cod_persona
    and cc.nro_cuenta = c.nro_cuenta
    and cc.cod_modalidad in (442, 42, 49)
    and exists (select 1
                 from ge_procesos_par p
                where p.cod_proceso = 201
                  and p.cod_campo = 'COD_BANCO'
                  and SUBSTR(P.VAL_DEFECTO, 1, instr(P.VAL_DEFECTO, '-') - 1) = cc.cod_banco);

insert into ge_ext_ban_entidades_tmp
 select distinct c.cod_persona, p.nom_completo, cc.nro_cuenta, cc.cod_ente, cc.cod_banco
   from ge_cta_clientes c, ba_personas p, cc_cta_bancarias cc
  where c.cod_persona = p.cod_persona
    and cc.nro_cuenta = c.nro_cuenta
    and cc.cod_modalidad in (442, 42, 49)
    and  exists (select 1
                   from ge_procesos_par p
                  where p.cod_proceso = 201
                    and p.cod_campo = 'GL_ENTE'
                    and SUBSTR(P.VAL_DEFECTO,1,instr(P.VAL_DEFECTO, '-') - 1) = cc.cod_ente);



end;

procedure lp_ins_mov_cta_bancarias_tmp is

begin
  insert into ge_ext_ban_movimientos_tmp (cod_persona, nro_cuenta, tip_movimiento,
                                      fecha, hora, descripcion, nro_documento,
                                      debito, credito, cod_moneda, fec_extracto,
                                      cod_ente, cod_banco)
  select
         g.cod_persona,
         cc.nro_cuenta,
         c.tip_movimiento,
         m.fecha,
         m.hora,
         rtrim(nvl(c.descripcion,t.descripcion)) descripcion,
         m.nro_documento,
         decode (c.tip_movimiento, 'D', decode(cc.cod_moneda, 'GS', c.mto_mon_local, c.mto_mon_rubro), 0) debito,
         decode (c.tip_movimiento, 'C', decode(cc.cod_moneda, 'GS', c.mto_mon_local, c.mto_mon_rubro), 0) credito,
         cc.cod_moneda,
         v_fec_extracto,
         cc.cod_ente,
         cc.cod_banco
    from ge_bancos           g,
         cb_asientos_det_his c,
         cc_cta_bancarias    cc,
         cc_movimientos_his  m,
         ge_transacciones    t
   where cc.cod_banco = g.cod_banco
     and c.fecha = m.FECHA
     and c.ref_movimiento = m.NRO_DOCUMENTO4
     and cc.cod_rubro = c.cod_rubro
     and g.cod_bco_central is not null
     and g.cod_bco_central not in (fug_obt_cod_entidad, 1001)
     and m.cod_tra_padre = t.cod_transaccion(+)
     and m.cod_modulo = t.cod_modulo(+)
     and m.cod_modalidad = t.cod_modalidad(+)
     and c.fecha between v_fec_ini and v_fec_extracto
     and ((cc.cod_moneda <> 'GS' and c.mto_mon_rubro <> 0) or
         (cc.cod_moneda = 'GS' and c.mto_mon_rubro = 0))
    and cc.cod_modalidad in (442, 42)
    and exists (select 1
                from ge_ext_ban_entidades_tmp e
                where e.nro_cuenta = cc.nro_cuenta)

  UNION

  select g.cod_persona,
         cc.nro_cuenta,
         c.tip_movimiento,
         m.fecha,
         m.hora,
         rtrim(nvl(c.descripcion,t.descripcion)) descripcion,
         m.nro_documento,
         decode (c.tip_movimiento, 'D', decode(cc.cod_moneda, 'GS', c.mto_mon_local, c.mto_mon_rubro), 0) debito,
         decode (c.tip_movimiento, 'C', decode(cc.cod_moneda, 'GS', c.mto_mon_local, c.mto_mon_rubro), 0) credito,
         cc.cod_moneda,
         v_fec_extracto,
         cc.cod_ente,
         cc.cod_banco
    from ge_bancos              g,
         cb_asientos_det_his    c,
         cc_cta_bancarias       cc,
         cc_movimientos_his     m,
         ge_cta_dat_adicionales dx,
         ge_transacciones    t
   where cc.cod_banco = g.cod_banco
     and c.fecha = m.FECHA
     and c.ref_movimiento = m.NRO_DOCUMENTO4
     and c.cod_rubro = dx.val_parametro
     and dx.nro_cuenta = cc.nro_cuenta
     and dx.parametro = 'COD_RUB_SOB_CTA_BAN'
     and g.cod_bco_central is not null
     and g.cod_bco_central not in (fug_obt_cod_entidad, 1001)
     and m.cod_tra_padre = t.cod_transaccion(+)
     and m.cod_modulo = t.cod_modulo(+)
     and m.cod_modalidad = t.cod_modalidad(+)
     and c.fecha between v_fec_ini and v_fec_extracto
     and ((cc.cod_moneda <> 'GS' and c.mto_mon_rubro <> 0) or
         (cc.cod_moneda = 'GS' and c.mto_mon_rubro = 0))
    and cc.cod_modalidad in (442, 42)
    and exists (select 1
                  from ge_ext_ban_entidades_tmp e
                  where e.nro_cuenta = cc.nro_cuenta)
  UNION
  select g.cod_persona,
         cc.nro_cuenta,
         c.tip_movimiento,
         m.fecha,
         m.hora,
         rtrim(nvl(c.descripcion, t.descripcion)) descripcion,
         m.nro_documento,
         decode(c.tip_movimiento, 'D', decode(cc.cod_moneda, 'GS', c.mto_mon_local, c.mto_mon_rubro), 0) debito,
         decode(c.tip_movimiento, 'C', decode(cc.cod_moneda, 'GS', c.mto_mon_local, c.mto_mon_rubro), 0) credito,
         cc.cod_moneda,
         v_fec_extracto,
         cc.cod_ente,
         cc.cod_banco
    from ge_entes            g,
         cb_asientos_det_his c,
         cc_cta_bancarias    cc,
         cc_movimientos_his  m,
         ge_transacciones    t
   where cc.cod_ente = g.cod_ente
     and c.fecha = m.FECHA
     and c.ref_movimiento = m.NRO_DOCUMENTO4
     and cc.cod_rubro = c.cod_rubro
     and m.cod_tra_padre = t.cod_transaccion(+)
     and m.cod_modulo = t.cod_modulo(+)
     and m.cod_modalidad = t.cod_modalidad(+)
     and c.fecha between v_fec_ini and v_fec_extracto
     and ((cc.cod_moneda <> 'GS' and c.mto_mon_rubro <> 0) or
         (cc.cod_moneda = 'GS' and c.mto_mon_rubro = 0))
     and cc.cod_modalidad in (49)
     and exists (select 1
                  from ge_ext_ban_entidades_tmp e
                  where e.nro_cuenta = cc.nro_cuenta)

  UNION

  select g.cod_persona,
         cc.nro_cuenta,
         c.tip_movimiento,
         m.fecha,
         m.hora,
         rtrim(nvl(c.descripcion, t.descripcion)) descripcion,
         m.nro_documento,
         decode(c.tip_movimiento, 'D', decode(cc.cod_moneda, 'GS', c.mto_mon_local, c.mto_mon_rubro), 0) debito,
         decode(c.tip_movimiento, 'C', decode(cc.cod_moneda, 'GS', c.mto_mon_local, c.mto_mon_rubro), 0) credito,
         cc.cod_moneda,
         v_fec_extracto,
         cc.cod_ente,
         cc.cod_banco
    from ge_entes               g,
         cb_asientos_det_his    c,
         cc_cta_bancarias       cc,
         cc_movimientos_his     m,
         ge_cta_dat_adicionales dx,
         ge_transacciones       t
   where cc.cod_ente = g.cod_ente
     and c.fecha = m.FECHA
     and c.ref_movimiento = m.NRO_DOCUMENTO4
     and c.cod_rubro = dx.val_parametro
     and dx.nro_cuenta = cc.nro_cuenta
     and dx.parametro = 'COD_RUB_SOB_CTA_BAN'
     and m.cod_tra_padre = t.cod_transaccion(+)
     and m.cod_modulo = t.cod_modulo(+)
     and m.cod_modalidad = t.cod_modalidad(+)
     and c.fecha between v_fec_ini and v_fec_extracto
     and ((cc.cod_moneda <> 'GS' and c.mto_mon_rubro <> 0) or
         (cc.cod_moneda = 'GS' and c.mto_mon_rubro = 0))
     and cc.cod_modalidad in (49)
     and exists (select 1
                  from ge_ext_ban_entidades_tmp e
                  where e.nro_cuenta = cc.nro_cuenta)
  order by nro_cuenta, fecha, hora;



end;

procedure lp_ins_ext_saldos_tmp is

begin
  insert into ge_ext_ban_saldos_tmp (cod_persona, nro_cuenta, denominacion, sal_actual,
                                     sal_anterior, fec_extracto, cod_ente, cod_banco)
  select g.cod_persona,
   c.nro_cuenta,
   cc.denominacion,
   c.saldo_act *-1 Saldo_Actual,
   c.saldo_ant *-1 Saldo_Anterior,
   v_fec_extracto,
   cc.cod_ente, cc.cod_banco

  from
     ge_bancos g,
     cc_cta_bancarias cc,
     (select cc.cod_banco,cc.nro_cuenta, sum((nvl(FUB_OBT_SAL_CONTABLE(CC.Cod_Rubro,v_fec_extracto,cc.cod_moneda),0) +
             nvl(FUB_OBT_SAL_CONTABLE(g.val_parametro,v_fec_extracto,cc.cod_moneda),0)))saldo_act,
             sum((nvl(FUB_OBT_SAL_CONTABLE(CC.Cod_Rubro,v_fec_cie_ant,cc.cod_moneda),0) +
             nvl(FUB_OBT_SAL_CONTABLE(g.val_parametro,v_fec_cie_ant,cc.cod_moneda),0)))saldo_ant
             from cc_cta_bancarias cc,ge_cta_dat_adicionales g
             where cc.nro_cuenta = g.nro_cuenta
               and g.parametro = 'COD_RUB_SOB_CTA_BAN'
             group by cc.cod_banco,cc.nro_cuenta)c
 where g.estado='A'
  and g.cod_bco_central is not null
  and g.cod_bco_central not in(fug_obt_cod_entidad,1001)
  and g.cod_banco=cc.cod_banco
  and g.cod_banco=c.cod_banco
  and c.cod_banco=cc.cod_banco
  and c.nro_cuenta=cc.nro_cuenta
  and cc.cod_modalidad in (442, 42)
  and exists (select 1
              from ge_ext_ban_entidades_tmp e
              where e.nro_cuenta = cc.nro_cuenta)
 union
select g.cod_persona,
   c.nro_cuenta,
   cc.denominacion,
   c.saldo_act *-1 Saldo_Actual,
   c.saldo_ant *-1 Saldo_Anterior,
   v_fec_extracto,
   cc.cod_ente, cc.cod_banco
  from
     ge_entes g,
     cc_cta_bancarias cc,
     (select cc.cod_ente,cc.nro_cuenta, sum((nvl(FUB_OBT_SAL_CONTABLE(CC.Cod_Rubro,v_fec_extracto,cc.cod_moneda),0) +
             nvl(FUB_OBT_SAL_CONTABLE(g.val_parametro,v_fec_extracto,cc.cod_moneda),0)))saldo_act,
             sum((nvl(FUB_OBT_SAL_CONTABLE(CC.Cod_Rubro,v_fec_cie_ant,cc.cod_moneda),0) +
             nvl(FUB_OBT_SAL_CONTABLE(g.val_parametro,v_fec_cie_ant,cc.cod_moneda),0)))saldo_ant
             from cc_cta_bancarias cc,ge_cta_dat_adicionales g
             where cc.nro_cuenta = g.nro_cuenta
               and g.parametro = 'COD_RUB_SOB_CTA_BAN'
                         group by cc.cod_ente,cc.nro_cuenta)c
 where g.cod_ente=cc.cod_ente
  and g.cod_ente=c.cod_ente
  and c.cod_ente=cc.cod_ente
  and c.nro_cuenta=cc.nro_cuenta
  and cc.cod_modalidad in (49)
  and exists (select 1
            from ge_ext_ban_entidades_tmp e
            where e.nro_cuenta = cc.nro_cuenta)

order by nro_cuenta;
end;


begin

   --Asignación de fechas por parámetro dinámico
   v_fec_ini := to_date(fug_obt_pardinamico('FEC_INI_BCO_PAIS'),'dd/mm/yyyy');
   v_fec_fin := to_date(fug_obt_pardinamico('FEC_FIN_BCO_PAIS'),'dd/mm/yyyy');
   v_fec_extracto := pag_cal.fu_obt_fec_habil(v_fec_fin,1,1);
   
   --Fecha Cierre Anterior   
   select pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_ini, 31, 1)
     into v_fec
     from dual;
   v_fec_cie_ant := pag_cal.fu_obt_fec_habil(v_fec,1,1);
	 ---		       


    --Borrar Datos de tablas tmp
    lp_tru_tab_temporales;

    --Insertar Datos de Extractos
    lp_ins_entidades_tmp;
    lp_ins_mov_cta_bancarias_tmp;
    lp_ins_ext_saldos_tmp;

end;
/

