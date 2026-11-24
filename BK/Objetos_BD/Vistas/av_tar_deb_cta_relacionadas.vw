create or replace force view it.av_tar_deb_cta_relacionadas as
select   lpad(nvl(fua_obt_cta_ficticia(d.nro_cuenta, d.nro_bin), pag_sue.Fu_cod_cuenta(d.nro_cuenta)),10,'0')||-- 10- CUENTA SDBIN8TDD-1 Obt Cta Ficticia
         lpad(d.adherente,2,'0')|| -- 2-NRO. ADHERENTE
         rpad(fue_obt_des_refcodes('TIP_TAR_DEBITO',D.tip_tar_debito),6,' ')|| -- 6-Codigo de Formato de Embozado
         lpad(pag_sue.Fu_cod_cuenta(c.nro_cta_relacionada),10,'0')||-- NRO. CTA. RELACIONADA
         --1|| -- TIPO DE CUENTA: AHORRO
         decode(g.cod_modulo,3,'1',4,'2')|| --Tipo de Cuenta: 1/Cuenta de Ahorros, 2/Cuenta Corriente
         decode(g.cod_moneda,pag_gen.fu_obt_mon_local,600,840)|| -- MONEDA
         0 registro,  -- 1- Tipo de acción a realizar (0=ALTA)
         d.cod_ent_procesadora,
         c.fec_envio,
         d.nro_cuenta,
         c.enviado,
         d.nro_lote,
         d.ide_reg_lote
    from ah_tar_debitos d,
         ah_tar_deb_cuentas c,
         ah_cta_vistas v,
         ge_cuentas g,
         ba_personas p
   where d.nro_cuenta = c.nro_cuenta
     and d.adherente  = c.adherente
     and d.nro_cuenta = v.nro_cuenta
     and p.cod_persona = d.cod_persona
     and g.nro_cuenta  = c.nro_cta_relacionada
     and c.fec_envio is not null
     and instr(fug_obt_pardinamico('EST_VAL_REL_CUENTA'),d.cod_est_solicitud) > 0
union all
  select lpad(nvl(fua_obt_cta_ficticia(d.nro_cuenta, d.nro_bin),pag_sue.Fu_cod_cuenta(d.nro_cuenta)),10,'0')||-- 10- CUENTA SDBIN8TDD-1 Obt Cta Ficticia
         d.adherente|| -- 2-NRO. ADHERENTE
         rpad(fue_obt_des_refcodes('TIP_TAR_DEBITO',d.tip_tar_debito),6,' ')|| -- 6-Codigo de Formato de Embozado
         lpad(pag_sue.Fu_cod_cuenta(c.nro_cta_relacionada),10,'0')||-- NRO. CTA. RELACIONADA
         --2|| -- TIPO DE CUENTA: CTA.CTE.
         decode(g.cod_modulo,3,'1',4,'2')|| --Tipo de Cuenta: 1/Cuenta de Ahorros, 2/Cuenta Corriente
         decode(g.cod_moneda,pag_gen.fu_obt_mon_local,600,840)|| -- MONEDA
         0 registro,  -- 1- Tipo de acción a realizar (0=ALTA)
         d.cod_ent_procesadora,
         c.fec_envio,
         d.nro_cuenta,
         c.enviado,
         d.nro_lote,
         d.ide_reg_lote
    from ah_tar_debitos d,
         ah_tar_deb_cuentas c,
         cc_cta_corrientes cc,
         ge_cuentas g
   where d.nro_cuenta = c.nro_cuenta
     and d.adherente  = c.adherente
     and g.nro_cuenta = c.nro_cta_relacionada
     and d.nro_cuenta = cc.nro_cuenta
     and c.fec_envio is not null
     and cc.estado IN( 'N', 'A', 'I','S')
     and instr(fug_obt_pardinamico('EST_VAL_REL_CUENTA'),d.cod_est_solicitud) > 0
;

