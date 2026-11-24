CREATE OR REPLACE PROCEDURE IT.prt_ins_cta_deb_aut_cobrar IS
  --Variables--------
  v_hora          ge_movimientos.hora%type;
  v_fcdehoy       date;
  v_fec_anterior  date;
  v_fec_proxima   date;
  v_lugar         varchar2(1000);
  v_pro_cta_nomina varchar2(1) := nvl(fug_obt_pardinamico('PRO_CTA_NOMINA'),'S');
  v_es_nocturno varchar2(1) := 'N'; -- No es Nocturno DYDMR-5283 NAF. Nov/2016
  v_cod_causa     ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('GEN_COD_CAU_INH_COBRO');

  --Carga los debitos automaticos a realizar
  procedure lp_car_deb_aut_normal;

  --Con debito Automatico Atrasados--
  procedure lp_car_deb_aut_atrasados;

  --Carga los debitos automaticos a realizar
  procedure lp_car_deb_aut_normal is
  begin
       --Deudas Normales - Por el Vencimiento de Pago--
       insert into TA_CTA_DEB_AUT_COBRAR (nro_cta_debito,nro_tarjeta,monto,nro_cuenta,fec_proceso,estado,
                                   fec_valor, hora, est_envio, dia_mora,
                                   cod_modulo, cod_modalidad, cod_oficina, cod_moneda, referencia,
                                   cod_persona, deb_automatico, mto_pag_minimo, mto_mora)
       select nro_cta_debito, nro_tarjeta,nvl(mto_pag_minimo,0),tar.nro_cuenta,
              v_fcdehoy,'I',v_fcdehoy, v_hora, 'P', cta.dia_mora,
              cta.cod_modulo, cta.cod_modalidad, cta.cod_oficina, cta.cod_moneda, '01_PRO_NORMAL',
              tar.cod_persona, nvl(cta.deb_automatico,'N'), cta.mto_pag_minimo, cta.mto_mora
         from ta_tarjetas  tar, ge_cta_clientes cli, ta_cta_tarjetas cta
        where tar.nro_cuenta = cli.nro_cuenta
          and cli.cod_persona = tar.cod_persona
          -- and vigente = 'S' - 05/09/2013
          and cta.nro_cuenta = tar.nro_cuenta
          and relacion = 'P'
          and cta.estado <> 'C'
          and not EXISTS
         (SELECT DISTINCT ('S')
                  FROM GE_PER_INHIBIDAS A, GE_CAUSALES B
                 WHERE A.COD_CAUSA = B.COD_CAUSA
                   AND A.ESTADO = 'I'
                   AND A.COD_PERSONA = CLI.COD_PERSONA
                   AND INSTR(v_cod_causa,
                             a.COD_CAUSA) > 0
                UNION ALL
                SELECT 'S'
                  FROM GE_CUENTAS A, GE_CTA_CLIENTES B, GE_PER_INHIBIDAS C
                 WHERE A.NRO_CUENTA = B.NRO_CUENTA
                   AND B.COD_PERSONA = C.COD_PERSONA
                   and b.nro_cuenta = cli.nro_cuenta
                   and c.estado = 'I'
                   and b.relacion <> 'P'
                   and INSTR(v_cod_causa,
                             C.COD_CAUSA) > 0
                   AND ROWNUM = 1)
          and it.fut_obt_procesadora(cta.nro_cuenta) = fug_obt_pardinamico('COD_PRO_BANCARD')
          and v_fcdehoy >= fec_vct_ult_cierre
          and nvl(deb_automatico,'N') = 'S'
          --and nvl(sal_pag_minimo, 0) > 0
          and nvl(mto_pag_minimo, 0) > 0
          /*RI: 15/12/2010: para que evalue si procesar o no cuentas de nomina */
          and (not exists (Select 1 from cc_cta_corrientes c
                           where c.nro_cuenta = cta.nro_cta_debito and c.cod_ente is not null
                             and v_pro_cta_nomina = 'N')
           or v_pro_cta_nomina = 'S')
          and (not exists(Select 1 from ah_cta_vistas c
                           where c.nro_cuenta = cta.nro_cta_debito and c.cod_ente is not null
                             and v_pro_cta_nomina = 'N')
           or v_pro_cta_nomina = 'S')
           and tar.nro_tarjeta = (select max(ta.nro_tarjeta) from ta_tarjetas ta
                                   where ta.nro_cuenta=tar.nro_cuenta
                                     and ta.cod_persona=tar.cod_persona
                                     and ta.cod_estado=tar.cod_estado)
           /* DYDMR-279. CB. 28/03/2014. Caso Ex-Citi*/
           and tar.cod_estado = (select min(ta.cod_estado) from ta_tarjetas ta
                                   where ta.nro_cuenta=tar.nro_cuenta
                                     and ta.cod_persona=tar.cod_persona)
           --No debe estar insertado anteriormente--
           and not exists (select 1
                             from TA_CTA_DEB_AUT_COBRAR z
                            where z.nro_cuenta = cta.nro_cuenta);

       --Deudas Morosas--
       insert into TA_CTA_DEB_AUT_COBRAR (nro_cta_debito, nro_tarjeta, monto,nro_cuenta,fec_proceso,estado,
                                   fec_valor, est_envio, dia_mora,
                                   cod_modulo, cod_modalidad, cod_oficina, cod_moneda, referencia,
                                   cod_persona, deb_automatico, mto_pag_minimo, mto_mora)
       select nro_cta_debito, nro_tarjeta,nvl(mto_mora,0),tar.nro_cuenta,v_fcdehoy,'I',v_fcdehoy, 'P',
              cta.dia_mora, cta.cod_modulo, cta.cod_modalidad, cta.cod_oficina, cta.cod_moneda, '02_PRO_MOROSO',
              tar.cod_persona, nvl(cta.deb_automatico,'N'), cta.mto_pag_minimo, cta.mto_mora
         from ta_tarjetas  tar,
              ge_cta_clientes cli,
              ta_cta_tarjetas cta
        where tar.nro_cuenta = cli.nro_cuenta
          and cli.cod_persona = tar.cod_persona
          --and vigente = 'S'
          and cta.nro_cuenta = tar.nro_cuenta
          and relacion = 'P'
          and nvl(deb_automatico,'N') = 'S'
          and it.fut_obt_procesadora(cta.nro_cuenta) = fug_obt_pardinamico('COD_PRO_BANCARD')
          and fec_vct_ult_cierre != v_fcdehoy
          and nvl(dia_mora,0) > 0
          and nvl(mto_mora, 0) > 0
          and cta.estado <> 'C' -- Jul/2017 DYDMR-6990 No debe evaluar cuentas Canceladas
          and not EXISTS
         (SELECT DISTINCT ('S')
                  FROM GE_PER_INHIBIDAS A, GE_CAUSALES B
                 WHERE A.COD_CAUSA = B.COD_CAUSA
                   AND A.ESTADO = 'I'
                   AND A.COD_PERSONA = CLI.COD_PERSONA
                   AND INSTR(v_cod_causa,
                             a.COD_CAUSA) > 0
                UNION ALL
                SELECT 'S'
                  FROM GE_CUENTAS A, GE_CTA_CLIENTES B, GE_PER_INHIBIDAS C
                 WHERE A.NRO_CUENTA = B.NRO_CUENTA
                   AND B.COD_PERSONA = C.COD_PERSONA
                   and b.nro_cuenta = cli.nro_cuenta
                   and c.estado = 'I'
                   and b.relacion <> 'P'
                   and INSTR(v_cod_causa,
                             C.COD_CAUSA) > 0
                   AND ROWNUM = 1)
          /*RI: 15/12/2010: para que evalue si procesar o no cuentas de nomina */
          and (not exists (Select 1 from cc_cta_corrientes c
                           where c.nro_cuenta = cta.nro_cta_debito and c.cod_ente is not null
                             and v_pro_cta_nomina = 'N')
           or v_pro_cta_nomina = 'S')
          and (not exists(Select 1 from ah_cta_vistas c
                           where c.nro_cuenta = cta.nro_cta_debito and c.cod_ente is not null
                             and v_pro_cta_nomina = 'N')
           or v_pro_cta_nomina = 'S')
           /* CB y NAN: 05/09/2013: se elimina el filtro Vigente = 'S'
              se envia la TC con max nro_tarjeta SPI 2370 */
          and tar.nro_tarjeta = (select max(ta.nro_tarjeta) from ta_tarjetas ta
                                   where ta.nro_cuenta=tar.nro_cuenta
                                     and ta.cod_persona=tar.cod_persona
                                     and ta.cod_estado=tar.cod_estado)
           /* DYDMR-279. CB. 28/03/2014. Caso Ex-Citi*/
           and tar.cod_estado = (select min(ta.cod_estado) from ta_tarjetas ta
                                   where ta.nro_cuenta=tar.nro_cuenta
                                     and ta.cod_persona=tar.cod_persona)
           --No debe estar insertado anteriormente--
           and not exists (select 1
                             from TA_CTA_DEB_AUT_COBRAR z
                            where z.nro_cuenta = cta.nro_cuenta)
           --Condiciones de pro_debitos--
           and not exists (select 1
                             from ge_par_dinamicos x
                            where x.parametro = 'TAR_COB_AUT_MAD_EXCLUIDA'
                              and x.cod_modulo = cta.cod_modulo
                              and x.cod_modalidad = cta.cod_modalidad
                              and nvl(x.val_parametro,'N') = 'S')
           and not exists (select 1
                             from ge_cta_dat_adicionales da
                            where da.nro_cuenta = cta.nro_cuenta
                              and da.parametro = 'EXC_CTA_COB_AUTOMATICO'
                              and nvl(da.val_parametro, 'N') = 'S');

  end;

  --Sin debitos automaticos a realizar atrasados con dias de mora--
  procedure lp_car_deb_aut_atrasados is
    v_dia_ATR_DEB_AUT number(6);
  begin
       v_dia_atr_deb_aut := fug_obt_pardinamico('TAR_ATR_DEB_AUT_CUENTAS_REL');
       --Morosos--
       insert into TA_CTA_DEB_AUT_COBRAR(nro_cta_debito, nro_tarjeta, monto,nro_cuenta,
                                  fec_proceso,estado, fec_valor, est_envio, dia_mora, observacion,
                                  cod_modulo, cod_modalidad, cod_oficina, cod_moneda, referencia,
                                  cod_persona, deb_automatico, mto_pag_minimo, mto_mora)
       select distinct nro_cta_debito, nro_tarjeta,nvl(mto_mora,0),tar.nro_cuenta,
                       v_fcdehoy,'I',v_fcdehoy, 'P', cta.dia_mora, 'Cuenta Morosa prt_deb_automatico ATR',
                       cta.cod_modulo, cta.cod_modalidad, cta.cod_oficina, cta.cod_moneda, '03_PRO_ATRASADO',
                       tar.cod_persona, nvl(cta.deb_automatico,'N'), cta.mto_pag_minimo, cta.mto_mora
         from ge_cta_clientes cli, ta_cta_tarjetas cta, ta_tarjetas  tar, ge_cta_clientes gd
        where cli.nro_cuenta = cta.nro_cuenta
         and cli.cod_persona = tar.cod_persona
         --and vigente = 'S'
         and cta.nro_cuenta = tar.nro_cuenta
         and cli.relacion = 'P'
         and nvl(deb_automatico,'N') <> 'S'
         and it.fut_obt_procesadora(cta.nro_cuenta) = fug_obt_pardinamico('COD_PRO_BANCARD')
         and cta.fec_vct_ult_cierre != v_fcdehoy
         and cli.cod_persona = gd.cod_persona
         and gd.relacion in('P','O')
         and gd.cod_modalidad in(31,41)
         and nvl(dia_mora,0) > 0
         and nvl(mto_mora, 0) > 0
         and cta.estado <> 'C' -- Jul/2017 DYDMR-6990 No debe evaluar cuentas Canceladas
         and not EXISTS
         (SELECT DISTINCT ('S')
                  FROM GE_PER_INHIBIDAS A, GE_CAUSALES B
                 WHERE A.COD_CAUSA = B.COD_CAUSA
                   AND A.ESTADO = 'I'
                   AND A.COD_PERSONA = CLI.COD_PERSONA
                   AND INSTR(v_cod_causa,
                             a.COD_CAUSA) > 0
                UNION ALL
                SELECT 'S'
                  FROM GE_CUENTAS A, GE_CTA_CLIENTES B, GE_PER_INHIBIDAS C
                 WHERE A.NRO_CUENTA = B.NRO_CUENTA
                   AND B.COD_PERSONA = C.COD_PERSONA
                   and b.nro_cuenta = cli.nro_cuenta
                   and c.estado = 'I'
                   and b.relacion <> 'P'
                   and INSTR(v_cod_causa,
                             C.COD_CAUSA) > 0
                   AND ROWNUM = 1)
          /*RI: 15/12/2010: para que evalue si procesar o no cuentas de nomina */
          and (not exists (Select 1 from cc_cta_corrientes c
                           where c.nro_cuenta = cta.nro_cta_debito and c.cod_ente is not null
                             and v_pro_cta_nomina = 'N')
           or v_pro_cta_nomina = 'S')
          and (not exists(Select 1 from ah_cta_vistas c
                           where c.nro_cuenta = cta.nro_cta_debito and c.cod_ente is not null
                             and v_pro_cta_nomina = 'N')
           or v_pro_cta_nomina = 'S')
           /* CB y NAN: 05/09/2013: se elimina el filtro Vigente = 'S'
              se envia la TC con max nro_tarjeta SPI 2370 */
          and tar.nro_tarjeta = (select max(ta.nro_tarjeta) from ta_tarjetas ta
                                   where ta.nro_cuenta=tar.nro_cuenta
                                     and ta.cod_persona=tar.cod_persona
                                     and ta.cod_estado=tar.cod_estado)
           /* DYDMR-279. CB. 28/03/2014. Caso Ex-Citi*/
           and tar.cod_estado = (select min(ta.cod_estado) from ta_tarjetas ta
                                   where ta.nro_cuenta=tar.nro_cuenta
                                     and ta.cod_persona=tar.cod_persona)
           --Condiciones de pro_debitos--
           and not exists (select 1
                             from ge_par_dinamicos x
                            where x.parametro = 'TAR_COB_AUT_MAD_EXCLUIDA'
                              and x.cod_modulo = cta.cod_modulo
                              and x.cod_modalidad = cta.cod_modalidad
                              and nvl(x.val_parametro,'N') = 'S')
           and nvl(cta.dia_mora,0) >= nvl(v_dia_atr_deb_aut,0)
           and not exists (select 1
                             from ge_cta_dat_adicionales da
                            where da.nro_cuenta = cta.nro_cuenta
                              and da.parametro = 'EXC_CTA_COB_AUTOMATICO'
                              and nvl(da.val_parametro, 'N') = 'S')
           --No debe estar insertado anteriormente--
           and not exists (select 1
                             from TA_CTA_DEB_AUT_COBRAR z
                            where z.nro_cuenta = cta.nro_cuenta);

  end;

  --Actualizar Registros de Pagos del Dia--
  procedure lp_act_reg_pag_del_dia is
    cursor c_reg_pag_del_dia is
       select a.nro_cuenta, sum(nvl(a.monto,0)) mto_pagado
         from ta_cobros a
        where a.estado in ('C','P')
          and a.fec_proceso between v_fec_anterior and v_fec_proxima
        group by a.nro_cuenta;
  begin
    for cta in c_reg_pag_del_dia loop
        update TA_CTA_DEB_AUT_COBRAR x
           set x.estado      = decode(sign(x.monto-cta.mto_pagado),0,'P',-1,'P','F'),
               x.fec_proceso = v_fcdehoy,
               x.fec_valor = v_fcdehoy,
               x.can_pagos = nvl(x.can_pagos,0) + 1,
               x.mto_cobrado = cta.mto_pagado
         where x.nro_cuenta = cta.nro_cuenta;
       end loop;
  end;

  --Insertar cuentas relacionadas de detalle--
  procedure lp_ins_cta_rel_detalle is
    v_cod_mon_local ba_monedas.cod_moneda%type;
  begin
    v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;

    insert into ta_cta_deb_aut_detalle
    (nro_cuenta, nro_cta_debito, cod_persona, relacion,
     cod_moneda, sal_total, cod_modulo, cod_modalidad, fec_proceso)
     SELECT W.NRO_CUENTA,
       A.NRO_CUENTA NRO_CTA_DEBITO,
           A.COD_PERSONA,
           A.RELACION,
           D.cod_moneda,
           DECODE(A.COD_MODULO,
                  3,
                  (B.SAL_TOTAL - (B.SAL_BLOQUEADO + B.SAL_RETENIDO)),
                  4,
                  (C.SAL_TOTAL - (C.SAL_RETENIDO + C.SAL_BLOQUEADO))) SAL_TOTAL,
           A.COD_MODULO,
           A.COD_MODALIDAD, v_fcdehoy
      FROM GE_CTA_CLIENTES   A, AH_CTA_VISTAS     B, CC_CTA_CORRIENTES C,
           GE_CUENTAS        D, BA_PERSONAS       P, TA_CTA_DEB_AUT_COBRAR w
     WHERE (a.Relacion = 'P' OR
           ((a.relacion = 'O' AND P.TIPO = 'F' AND
           pag_gen.FU_ES_PER_FISICA(FUG_OBT_CLI_PRINCIPAL(A.NRO_CUENTA)) = 'S') or
           (a.relacion = 'O' AND P.TIPO = 'J' AND
           pag_gen.FU_ES_PER_FISICA(FUG_OBT_CLI_PRINCIPAL(A.NRO_CUENTA)) = 'N')))
       --La moneda de la cuenta recuperada igual a la moneda de la cuenta debito.
       and nvl(c.cod_moneda, b.cod_moneda) = d.cod_moneda
       and d.cod_moneda = v_cod_mon_local
       AND A.NRO_CUENTA = B.NRO_CUENTA(+)
       AND A.NRO_CUENTA = C.NRO_CUENTA(+)
       AND A.NRO_CUENTA = D.NRO_CUENTA
       AND A.COD_MODALIDAD IN (31, 41)
       AND A.COD_PERSONA = P.COD_PERSONA
       AND d.cod_sub_modalidad <> 6
       AND D.ESTADO not IN ('A', 'C', 'T', 'D', 'X')
       and w.cod_persona = A.COD_PERSONA
       and nvl(w.nro_cta_debito,'-999') <> A.NRO_CUENTA
     ORDER BY 6 DESC;

     --Elimina las cuentas que no tienen cuentas para debito--
     delete from TA_CTA_DEB_AUT_COBRAR t
      where t.nro_cta_debito is null
        and not exists (select 1
                          from TA_CTA_DEB_AUT_DETALLE x
                         where x.nro_cuenta = t.nro_cuenta);
  end;

Begin
  --Carga Variables--
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;end;
  pag_cal.PR_OBT_DAT_CALENDAR(5);
  v_fec_anterior  := pag_cal.G_FEC_ANTERIOR;
  v_fec_proxima   := pag_cal.G_FEC_PROXIMA;
  v_fcdehoy       := pag_cal.G_FEC_ACTUAL;
  v_hora          := to_char(sysdate,'HH24:MI:SS');
  v_hora          := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,v_es_nocturno); -- DYDMR-5283 NAF. Nov/2016

  --Eliminar registros anteriores--
  delete from TA_CTA_DEB_AUT_COBRAR;
  delete from TA_CTA_DEB_AUT_DETALLE;

  --Carga Tabla para control de Pagos--
  v_lugar := 'lp_car_deb_aut_normal';
  lp_car_deb_aut_normal;

  --Carga Tabla para control de Pagos Atrasados--
  v_lugar := 'lp_car_deb_aut_atrasados';
  lp_car_deb_aut_atrasados;

  --Actualizar Registros de Pagos del Dia--
  v_lugar := 'lp_act_reg_pag_del_dia';
  lp_act_reg_pag_del_dia;

  --Insertar cuentas relacionadas de detalle--
  v_lugar := 'lp_ins_cta_rel_detalle';
  lp_ins_cta_rel_detalle;

EXCEPTION
  WHEN OTHERS THEN
       raise_application_error(-20002,'Error en PRT_INS_CTA_DEB_AUT_COBRAR: '||v_lugar||' '||sqlerrm);
END;
/

