CREATE OR REPLACE PACKAGE BODY IT.PAS_PLA IS
  /*se corre despues del inicio contable del primer dia de mes habil.*/
  /*se toma como fecha de proceso el ultimo dia habil del mes anterior*/
  /*se generan los archivos ES, ER, EN, EX, ET de planinfo*/
  /*los datos del analisis de liquidez se arman en el PAS_BCP*/
  v_fec_actual     date := pag_cal.fu_obt_fec_actual(2);
  v_fec_proceso    date := last_day(pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_actual,
                                                               null));
  v_cod_mon_local  ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_cod_mon_fuerte ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_fuerte;
  /*genera los datos de moneda ext. arbitrada en usd*/
  PROCEDURE PR_GEN_6100(p_sector_desde in varchar2,
                        p_sector_hasta in varchar2) is
  BEGIN
    /* Selecciona ctas m/e arbitradas a USD para reporte de moneda 6100 del MES ACTUAL,*/
    insert into sb_bcp
      select cod_rub_bcp, /*cod_moneda*/
             '6100',
             sum(nvl(sal_ini_mes_mon_fuerte, 0))
        from cb_sal_oficinas a, cb_rub_bcp b, cb_rubros c
       where cod_rub_bcp =
             substr(a.cod_rubro, 1, 8) || substr(a.cod_rubro, 3, 1) ||
             substr(a.cod_rubro, 9, 2)
         and substr(cod_rub_bcp, 1, 1) between p_sector_desde and
             p_sector_hasta
         and cod_oficina between 0 and 999
         and a.cod_rubro = c.cod_rubro
            --and ano = to_number(to_char(v_fec_proceso,'YYYY'))
            --and mes = to_number(to_char(v_fec_proceso,'MM'))
         and c.imputable = 'S'
         and cod_moneda <> v_cod_mon_local
       group by cod_rub_bcp, cod_moneda
      having sum(nvl(sal_ini_mes_mon_fuerte, 0)) <> 0
       order by cod_rub_bcp;
    --
    /*   update sb_bcp -- se hace en el insert
      set cla_moneda = '6100'
    where substr(cod_rubro,1,1) between p_SECTOR_DESDE and p_SECTOR_HASTA
      and substr(cla_moneda,1,1) <> '6';*/
  END;
  /*genera los datos de moneda extranjera*/
  PROCEDURE PR_GEN_6200(SECTOR_DESDE IN VARCHAR2, SECTOR_HASTA IN VARCHAR2) IS
  BEGIN
    /* Selecciona ctas m/e para reporte de moneda 6200 */
    insert into sb_bcp
      select cod_rub_bcp, /*cod_moneda*/
             '6200',
             sum(nvl(sal_mon_loc_ant, 0) + nvl(deb_mon_local, 0) -
                 nvl(cre_mon_local, 0))
        from cb_sal_oficinas_his a, cb_rub_bcp b, cb_rubros c
       where cod_rub_bcp =
             substr(a.cod_rubro, 1, 8) || substr(a.cod_rubro, 3, 1) ||
             substr(a.cod_rubro, 9, 2)
         and substr(cod_rub_bcp, 1, 1) between sector_desde and
             sector_hasta
         and cod_oficina between 0 and 999
         and a.cod_rubro = c.cod_rubro
         and ano = to_number(to_char(v_fec_proceso, 'YYYY'))
         and mes = to_number(to_char(v_fec_proceso, 'MM'))
         and c.imputable = 'S'
         and (substr(c.cod_rubro, 14, 2) = '98' --trae moneda local
             or COD_MONEDA <> v_cod_mon_local)
       group by cod_rub_bcp, cod_moneda
      having sum(nvl(sal_mon_loc_ant, 0) + nvl(deb_mon_local, 0) - nvl(cre_mon_local, 0)) <> 0
       order by cod_rub_bcp;
    --
    /*   update sb_bcp
          set cla_moneda = '6200'
        where substr(cod_rubro,1,1) between SECTOR_DESDE and SECTOR_HASTA
          and substr(cla_moneda,1,1) <> '6';
    */
  END;
  /*genera los datos en moneda local*/
  PROCEDURE PR_GEN_6900(SECTOR_DESDE IN VARCHAR2, SECTOR_HASTA IN VARCHAR2) IS
  BEGIN
    /* Selecciona ctas GS para reporte de moneda 6900 */
    insert into sb_bcp
      select cod_rub_bcp, /*cod_moneda*/
             '6900',
             sum(nvl(sal_mon_loc_ant, 0) + nvl(deb_mon_local, 0) -
                 nvl(cre_mon_local, 0))
        from cb_sal_oficinas_his a, cb_rub_bcp b, cb_rubros c
       where cod_rub_bcp =
             substr(a.cod_rubro, 1, 8) || substr(a.cod_rubro, 3, 1) ||
             substr(a.cod_rubro, 9, 2)
         and substr(cod_rub_bcp, 1, 1) between sector_desde and
             sector_hasta
         and cod_oficina between 0 and 999
         and a.cod_rubro = c.cod_rubro
         and ano = to_number(to_char(v_fec_proceso, 'YYYY'))
         and mes = to_number(to_char(v_fec_proceso, 'MM'))
         and c.imputable = 'S'
         and substr(c.cod_rubro, 14, 2) = '99'
         and c.cod_rubro not in ('310604220100099', '310604180100099')
         and cod_moneda = v_cod_mon_local
       group by cod_rub_bcp, cod_moneda
      having sum(nvl(sal_mon_loc_ant, 0) + nvl(deb_mon_local, 0) - nvl(cre_mon_local, 0)) <> 0
       order by cod_rub_bcp;
    --
    /*  update sb_bcp
         set cla_moneda = '6900'
       where substr(cod_rubro,1,1) between SECTOR_DESDE and SECTOR_HASTA
         and cla_moneda = v_cod_mon_local;
    */
  END;
  /*genera promedio en moneda local (6900)*/
  PROCEDURE PR_GEN_6400(SECTOR_DESDE IN VARCHAR2, SECTOR_HASTA IN VARCHAR2) IS
  BEGIN
    /* Promedio de ctas GS para reporte de moneda 6400 */
    insert into sb_bcp
      select cod_rub_bcp, /*c.cod_moneda*/
             '6400',
             round(sum(nvl(tot_acu_mon_local, 0) /
                       nvl(can_dia_acumulado, 1)))
        from cb_sal_promedios a, cb_rub_bcp b, cb_rubros c
       where cod_rub_bcp =
             substr(a.cod_rubro, 1, 8) || substr(a.cod_rubro, 3, 1) ||
             substr(a.cod_rubro, 9, 2)
         and substr(cod_rub_bcp, 1, 1) between sector_desde and
             sector_hasta
         and cod_oficina between 0 and 999
         and a.cod_rubro = c.cod_rubro
         and ano = to_number(to_char(v_fec_proceso, 'YYYY'))
         and mes = to_number(to_char(v_fec_proceso, 'MM'))
         and c.imputable = 'S'
         and c.cod_moneda = v_cod_mon_local
         and c.cod_rubro not in ('310604220100099', '310604180100099')
            -- agregado el 19/05/95 para no generar promedios de ctas sin saldo
         and exists (select 1
                from sb_bcp
               where cod_rubro = cod_rub_bcp
                 and cla_moneda in (6900))
       group by cod_rub_bcp, c.cod_moneda
      having sum(nvl(tot_acu_mon_local, 0) / nvl(can_dia_acumulado, 1)) <> 0
       order by cod_rub_bcp;
    --
    /*  update sb_bcp
         set cla_moneda = '6400'
       where substr(cod_rubro,1,1) between SECTOR_DESDE and SECTOR_HASTA
         and cla_moneda = v_cod_mon_local;
    */
  END;
  /*genera promedio moneda ext. arbitrada en usd (6100)*/
  PROCEDURE PR_GEN_6500(SECTOR_DESDE IN VARCHAR2, SECTOR_HASTA IN VARCHAR2) IS
  BEGIN
    /* Promedios de ctas m/e arbitradas a USD para reporte de moneda 6500 */
    insert into sb_bcp
      select cod_rub_bcp, /*c.cod_moneda*/
             '6500',
             sum(nvl(tot_acu_mon_fuerte, 0) / nvl(can_dia_acumulado, 1))
        from cb_sal_promedios a, cb_rub_bcp b, cb_rubros c
       where cod_rub_bcp =
             substr(a.cod_rubro, 1, 8) || substr(a.cod_rubro, 3, 1) ||
             substr(a.cod_rubro, 9, 2)
         and substr(cod_rub_bcp, 1, 1) between sector_desde and
             sector_hasta
         and cod_oficina between 0 and 999
         and a.cod_rubro = c.cod_rubro
         and ano = to_number(to_char(v_fec_proceso, 'YYYY'))
         and mes = to_number(to_char(v_fec_proceso, 'MM'))
         and c.imputable = 'S'
         and c.cod_moneda <> v_cod_mon_local
            -- Agregado el 19/05/95 para no generar promedios de ctas sin saldo
         and exists (select 1
                from sb_bcp
               where cod_rubro = cod_rub_bcp
                 and cla_moneda = 6100)
       group by cod_rub_bcp, c.cod_moneda
      having sum(nvl(tot_acu_mon_fuerte, 0)) <> 0
       order by cod_rub_bcp;
    --
    /*  update sb_bcp
         set cla_moneda = '6500'
       where substr(cod_rubro,1,1) between SECTOR_DESDE and SECTOR_HASTA
         and substr(cla_moneda,1,1) <> '6';
    */
  END;
  /*genera promedio en moneda ext. (6200)*/
  PROCEDURE PR_GEN_6600(SECTOR_DESDE IN VARCHAR2, SECTOR_HASTA IN VARCHAR2) IS
  BEGIN
    /* Promedios de ctas m/e para reporte de moneda 6600 */
    insert into sb_bcp
      select cod_rub_bcp, /*c.cod_moneda*/
             '6600',
             round(sum(nvl(tot_acu_mon_local, 0) /
                       nvl(can_dia_acumulado, 1)))
        from cb_sal_promedios a, cb_rub_bcp b, cb_rubros c
       where cod_rub_bcp =
             substr(a.cod_rubro, 1, 8) || substr(a.cod_rubro, 3, 1) ||
             substr(a.cod_rubro, 9, 2)
         and substr(cod_rub_bcp, 1, 1) between sector_desde and
             sector_hasta
         and cod_oficina between 0 and 999
         and a.cod_rubro = c.cod_rubro
         and ano = to_number(to_char(v_fec_proceso, 'YYYY'))
         and mes = to_number(to_char(v_fec_proceso, 'MM'))
         and c.imputable = 'S'
         and ((c.cod_moneda <> v_cod_mon_local) or
             (c.cod_moneda = v_cod_mon_local and
             b.cod_rub_bcp like '1__70%'))
            -- Agregado el 19/05/95 para no generar promedios de ctas sin saldo
         and exists (select 1
                from sb_bcp
               where cod_rubro = cod_rub_bcp
                 and cla_moneda in (6100, 6200))
       group by cod_rub_bcp, c.cod_moneda
      having sum(nvl(tot_acu_mon_local, 0) / nvl(can_dia_acumulado, 1)) <> 0
       order by cod_rub_bcp;
    --
    /*  update sb_bcp
         set cla_moneda = '6600'
       where substr(cod_rubro,1,1) between SECTOR_DESDE and SECTOR_HASTA
         and substr(cla_moneda,1,1) <> '6';
    */
  END;
  /*genera datos 6100 a partir de la 6200*/
  PROCEDURE PR_GEN_6100_RESULTADO(SECTOR_DESDE IN VARCHAR2,
                                  SECTOR_HASTA IN VARCHAR2) IS
    wk_cotizac number(6, 2) := 1966;
  BEGIN
    /*  Genera moneda 6100 a partir de la 6200 */
    insert into sb_bcp
      select b.cod_rub_bcp, '6100', sum(a.sal_ini_mes_mon_rubro) importe
        from cb_sal_oficinas a, cb_rub_bcp b, cb_rubros c
       where b.cod_rub_bcp =
             substr(a.cod_rubro, 1, 8) || substr(a.cod_rubro, 3, 1) ||
             substr(a.cod_rubro, 9, 2)
         and a.cod_rubro = c.cod_rubro
         and c.imputable = 'S'
         and c.cod_moneda <> 'GS'
         and b.cod_rub_bcp in
             (select cod_rubro
                from sb_bcp
               where cla_moneda = '6200'
                 and substr(cod_rubro, 1, 1) between SECTOR_DESDE and
                     SECTOR_HASTA)
       group by b.cod_rub_bcp, '6100'
       order by 1;
  END;
  /*genera datos moneda local 6900*/
  PROCEDURE PR_GEN_6900_RESULTADO(SECTOR_DESDE IN VARCHAR2,
                                  SECTOR_HASTA IN VARCHAR2) IS
  BEGIN
    /* Selecciona ctas GS para reporte de moneda 6900 */
    insert into sb_bcp
      select cod_rub_bcp, /*cod_moneda*/
             '6900',
             sum(nvl(sal_mon_loc_ant, 0) + nvl(deb_mon_local, 0) -
                 nvl(cre_mon_local, 0))
        from cb_sal_oficinas_his a, cb_rub_bcp b, cb_rubros c
       where cod_rub_bcp =
             substr(a.cod_rubro, 1, 8) || substr(a.cod_rubro, 3, 1) ||
             substr(a.cod_rubro, 9, 2)
         and substr(cod_rub_bcp, 1, 1) between sector_desde and
             sector_hasta
         and cod_oficina between 0 and 999
         and a.cod_rubro = c.cod_rubro
         and ano = to_number(to_char(v_fec_proceso, 'YYYY'))
         and mes = to_number(to_char(v_fec_proceso, 'MM'))
         and c.imputable = 'S'
         and substr(c.cod_rubro, 14, 2) = '99'
      --  and cod_moneda = v_cod_mon_local
       group by cod_rub_bcp, cod_moneda
      having sum(nvl(sal_mon_loc_ant, 0) + nvl(deb_mon_local, 0) - nvl(cre_mon_local, 0)) <> 0
       order by cod_rub_bcp;
    --
    /*  update sb_bcp
         set cla_moneda = '6900'
      where substr(cod_rubro,1,1) between SECTOR_DESDE and SECTOR_HASTA
        and substr(cla_moneda,1,1) <> '6';
    */
  END;
  /*genera datos moneda ext. 6200*/
  PROCEDURE PR_GEN_6200_RESULTADO(SECTOR_DESDE IN VARCHAR2,
                                  SECTOR_HASTA IN VARCHAR2) IS
  BEGIN
    /* Selecciona ctas m/e para reporte de moneda 6200 */
    insert into sb_bcp
      select cod_rub_bcp, /*cod_moneda*/
             '6200',
             sum(nvl(sal_mon_loc_ant, 0) + nvl(deb_mon_local, 0) -
                 nvl(cre_mon_local, 0))
        from cb_sal_oficinas_his a, cb_rub_bcp b, cb_rubros c
       where cod_rub_bcp =
             substr(a.cod_rubro, 1, 8) || substr(a.cod_rubro, 3, 1) ||
             substr(a.cod_rubro, 9, 2)
         and substr(cod_rub_bcp, 1, 1) between sector_desde and
             sector_hasta
         and cod_oficina between 0 and 999
         and a.cod_rubro = c.cod_rubro
         and ano = to_number(to_char(v_fec_proceso, 'YYYY'))
         and mes = to_number(to_char(v_fec_proceso, 'MM'))
         and c.imputable = 'S'
         and (substr(c.cod_rubro, 14, 2) = '98' --trae moneda local
             or COD_MONEDA <> v_cod_mon_local)
       group by cod_rub_bcp, cod_moneda
      having sum(nvl(sal_mon_loc_ant, 0) + nvl(deb_mon_local, 0) - nvl(cre_mon_local, 0)) <> 0
       order by cod_rub_bcp;
    --
    /*  update sb_bcp
         set cla_moneda = '6200'
       where substr(cod_rubro,1,1) between SECTOR_DESDE and SECTOR_HASTA
         and substr(cla_moneda,1,1) <> '6';
    */
  END;
  /*proceso q genera datos para el estado de resultado*/
  PROCEDURE PR_GEN_EST_RESULTADO IS
  BEGIN
    delete sb_bcp where substr(cod_rubro, 1, 1) in ('6', '7');

    pr_gen_6200_resultado('6', '7'); --me
    pr_gen_6100_resultado('6', '7'); --arbitrado en usd
    pr_gen_6900_resultado('6', '7'); --ml
    --  genera_6300('6','7');--ya no se informa

    /*  pr_gen_6500('6','7');ESTOS PROMEDIOS TAMPOCO SE INFORMAN
    pr_gen_6400('6','7');
    pr_gen_6600('6','7');*/

    --  genera_6700('6','7');--ya no se informa

  END;
  /*proceso q genera datos para el estado de situacion*/
  PROCEDURE PR_GEN_EST_SITUACION IS
    wk_ctagana     VARchar2(15);
    wk_totacti     number(16, 2);
    wk_totpasi     number(16, 2);
    wk_totpatr     number(16, 2);
    wk_utilida     number(16, 2);
    v_tot_ing      number(16, 2);
    v_tot_eg       number(16, 2);
    v_pro_ing      number(16, 2);
    v_pro_eg       number(16, 2);
    v_pro_utilidad number(16, 2);
  BEGIN
    delete sb_bcp where substr(cod_rubro, 1, 1) between '1' and '5';
    --- busca cuenta utilidad
    wk_ctagana := fug_obt_pardinamico('COD_RUB_GANANCIAS');
    wk_ctagana := substr(wk_ctagana, 1, 8) || '0' ||
                  substr(wk_ctagana, 9, 2);
    pr_gen_6100('1', '5');
    pr_gen_6200('1', '5');
    pr_gen_6900('1', '5');
    begin
      -- inserta utilidad ----------------------------------------------------
      --busca total ingresos
      select sum(nvl(sal_mon_loc_ant, 0) + nvl(deb_mon_local, 0) -
                 nvl(cre_mon_local, 0))
        into v_tot_ing
        from cb_sal_oficinas_his
       where cod_rubro like '60000%'
         and ano = to_number(to_char(v_fec_proceso, 'YYYY'))
         and mes = to_number(to_char(v_fec_proceso, 'MM'));
      --busca total egresos
      select sum(nvl(sal_mon_loc_ant, 0) + nvl(deb_mon_local, 0) -
                 nvl(cre_mon_local, 0))
        into v_tot_eg
        from cb_sal_oficinas_his
       where cod_rubro like '70000%'
         and ano = to_number(to_char(v_fec_proceso, 'YYYY'))
         and mes = to_number(to_char(v_fec_proceso, 'MM'));

      --- calcula utilidad
      wk_utilida := (v_tot_ing + v_tot_eg);
      --- inserta registro
      insert into sb_bcp values (wk_ctagana, '6900', NVL(wk_utilida, 0));

      --busca total promedio ingreso
      select sum(nvl(tot_acu_mon_local, 0) / nvl(can_dia_acumulado, 1))
        into v_pro_ing
        from cb_sal_promedios a, cb_rub_bcp b, cb_rubros c
       where cod_rub_bcp =
             substr(a.cod_rubro, 1, 8) || substr(a.cod_rubro, 3, 1) ||
             substr(a.cod_rubro, 9, 2)
            --and substr(cod_rub_bcp,1,1) between sector_desde and sector_hasta
            --and cod_oficina between 0 and 999
         and a.cod_rubro = c.cod_rubro
         and a.cod_rubro like '60000%'
         and ano = to_number(to_char(v_fec_proceso, 'YYYY'))
         and mes = to_number(to_char(v_fec_proceso, 'MM'))
         and c.imputable = 'S'
         and c.cod_moneda = v_cod_mon_local;
      -- agregado el 19/05/95 para no generar promedios de ctas sin saldo
      /*and exists (select 1
       from sb_bcp
      where cod_rubro = cod_rub_bcp
        and cla_moneda = 6900)*/

      --busca total promedio egreso
      select sum(nvl(tot_acu_mon_local, 0) / nvl(can_dia_acumulado, 1))
        into v_pro_eg
        from cb_sal_promedios a, cb_rub_bcp b, cb_rubros c
       where cod_rub_bcp =
             substr(a.cod_rubro, 1, 8) || substr(a.cod_rubro, 3, 1) ||
             substr(a.cod_rubro, 9, 2)
            --and substr(cod_rub_bcp,1,1) between sector_desde and sector_hasta
            --and cod_oficina between 0 and 999
         and a.cod_rubro = c.cod_rubro
         and a.cod_rubro like '70000%'
         and ano = to_number(to_char(v_fec_proceso, 'YYYY'))
         and mes = to_number(to_char(v_fec_proceso, 'MM'))
         and c.imputable = 'S'
         and c.cod_moneda = v_cod_mon_local;

      -------- promedio de utilidad ver como sacar ---------
      v_pro_utilidad := (v_pro_ing + v_pro_eg);
      insert into sb_bcp
      values
        (wk_ctagana, '6400', nvl(v_pro_utilidad, 0));

    exception
      when no_data_found then
        raise_application_error(-20001, 'No existe cuenta de utilidad');
      when others then
        raise_application_error(-20001, 'Ins.cuenta utilidad ' || sqlerrm);
    end;
    ------------------------------------------------------------------------
    --  genera_6300('1','5');
    pr_gen_6500('1', '5');
    pr_gen_6400('1', '5');
    pr_gen_6600('1', '5');
    --  genera_6700('1','5');

    --  inserta cuentas de orden  --
    --insert into bcp
    --select bc_cdcuent, bc_clmoned, bc_importe
    --from bcp1;
    --

  END;
  /*proceso  de sumarizacion de datos*/
  PROCEDURE PR_PRO_SUMARIZACION(SECTOR_DESDE IN VARCHAR2 DEFAULT 1, --- agregado por Teresita 21/09/2007
                                SECTOR_HASTA IN VARCHAR2 DEFAULT 9) IS
    --- agregado por Teresita 21/09/2007
    moneda   number(4);
    cuenta   varchar2(15);
    importe  number(18, 2);
    totsec   number(18, 2) := 0;
    totcap   number(18, 2) := 0;
    totpla   number(18, 2) := 0;
    totgru   number(18, 2) := 0;
    cmon     number(4);
    csec     varchar2(1);
    ccap     varchar2(1);
    cpla     varchar2(1);
    cgru     varchar2(1);
    smoneda  number(4);
    scuenta  varchar2(15);
    simporte number(18, 2);
    existe   number(1) := 0;

    cursor bcp is
      select cla_moneda, cod_rubro, importe
        from sb_bcp
       where substr(cod_rubro, 1, 1) between sector_desde and sector_hasta
       order by 1, 2;

    PROCEDURE LP_ACT_RUB_TRANSITORIOS IS
      v_cod_rubro sb_bcp_sum.cod_rubro%type;
      -- Cursores.
      cursor c_sal_transitorios is
        select a.cla_moneda, nvl(sum(a.importe), 0) importe
          from sb_bcp_sum a
         where a.cod_rubro in ('51010000000', '52010000000')
           and a.cla_moneda in ('6500', '6600')
         group by a.cla_moneda;

    BEGIN

      for reg in c_sal_transitorios loop
        update sb_bcp_sum sbs
           set sbs.importe = sbs.importe - reg.importe
         where sbs.cod_rubro = '51010000000'
           and sbs.cla_moneda = reg.cla_moneda;

        --Obtengo el rubro hijo.
        begin
          select v.cod_rubro
            into v_cod_rubro
            from (select sb.cod_rubro, sb.importe
                    from sb_bcp_sum sb
                   where sb.cod_rubro like '51010%'
                     and sb.cod_rubro != '51010000000'
                     and sb.cla_moneda = reg.cla_moneda
                   order by 2 desc) v;
        exception
          when others then
            null;
        end;

        update sb_bcp_sum sbs
           set sbs.importe = sbs.importe - reg.importe
         where sbs.cod_rubro = v_cod_rubro
           and sbs.cla_moneda = reg.cla_moneda;

      end loop;

    EXCEPTION
      WHEN OTHERS THEN
        null;
    END;

  BEGIN
    --VERIFICACION_PREVIA;
    delete sb_bcp_sum
     where substr(cod_rubro, 1, 1) between sector_desde and sector_hasta;

    if bcp%isopen then
      close bcp;
    end if;
    open bcp;
    fetch bcp
      into moneda, cuenta, importe;
    if bcp%notfound then
      raise_application_error(-20000, 'No existen registros a sumarizar');
    end if;
    cmon   := moneda;
    csec   := substr(cuenta, 1, 1);
    ccap   := substr(cuenta, 2, 1);
    cpla   := substr(cuenta, 3, 1);
    cgru   := substr(cuenta, 4, 1);
    totgru := totgru + importe;
    totpla := totpla + importe;
    totcap := totcap + importe;
    totsec := totsec + importe;
    loop
      fetch bcp
        into moneda, cuenta, importe;
      exit when bcp%notfound;
      /* Verifica corte por moneda o sector */
      if moneda <> cmon or substr(cuenta, 1, 1) <> csec then
        smoneda  := cmon;
        scuenta  := rpad(csec, 11, '0');
        simporte := totsec;

        --repetir el plazo en la posicion 9, solo para imputables
        insert into sb_bcp_sum values (scuenta, smoneda, simporte);

        /* Verifica si existe totalizador a nivel de capitulo */
        scuenta  := rpad(csec || ccap, 11, '0');
        simporte := totcap;
        begin
          select count(*)
            into existe
            from sb_bcp_sum
           where cod_rubro = scuenta
             and cla_moneda = smoneda;
          if existe = 0 then
            insert into sb_bcp_sum values (scuenta, smoneda, simporte);
          end if;
        end;
        /* Verifica si existe totalizador a nivel de plazo */
        scuenta  := rpad(csec || ccap || cpla, 11, '0');
        simporte := totpla;
        begin
          select count(*)
            into existe
            from sb_bcp_sum
           where cod_rubro = scuenta
             and cla_moneda = smoneda;
          if existe = 0 then
            insert into sb_bcp_sum values (scuenta, smoneda, simporte);
          end if;
        end;
        /* Verifica si existe totalizador a nivel de grupo */
        scuenta  := rpad(csec || ccap || cpla || cgru, 11, '0');
        simporte := totgru;
        begin
          select count(*)
            into existe
            from sb_bcp_sum
           where cod_rubro = scuenta
             and cla_moneda = smoneda;
          if existe = 0 then
            insert into sb_bcp_sum values (scuenta, smoneda, simporte);
          end if;
        end;
        cmon   := moneda;
        csec   := substr(cuenta, 1, 1);
        ccap   := substr(cuenta, 2, 1);
        cpla   := substr(cuenta, 3, 1);
        cgru   := substr(cuenta, 4, 1);
        totsec := importe;
        totcap := importe;
        totpla := importe;
        totgru := importe;
        /* Verifica corte por capitulo */
      elsif substr(cuenta, 2, 1) <> ccap then
        smoneda  := moneda;
        scuenta  := rpad(csec || ccap, 11, '0');
        simporte := totcap;
        insert into sb_bcp_sum values (scuenta, smoneda, simporte);
        /* Verifica si existe totalizador a nivel de plazo */
        scuenta  := rpad(csec || ccap || cpla, 11, '0');
        simporte := totpla;
        begin
          select count(*)
            into existe
            from sb_bcp_sum
           where cod_rubro = scuenta
             and cla_moneda = smoneda;
          if existe = 0 then
            insert into sb_bcp_sum values (scuenta, smoneda, simporte);
          end if;
        end;
        /* Verifica si existe totalizador a nivel de grupo */
        scuenta  := rpad(csec || ccap || cpla || cgru, 11, '0');
        simporte := totgru;
        begin
          select count(*)
            into existe
            from sb_bcp_sum
           where cod_rubro = scuenta
             and cla_moneda = smoneda;
          if existe = 0 then
            insert into sb_bcp_sum values (scuenta, smoneda, simporte);
          end if;
        end;
        ccap   := substr(cuenta, 2, 1);
        cpla   := substr(cuenta, 3, 1);
        cgru   := substr(cuenta, 4, 1);
        totsec := totsec + importe;
        totcap := importe;
        totpla := importe;
        totgru := importe;
        /* Verifica corte por plazo */
      elsif substr(cuenta, 3, 1) <> cpla then
        smoneda  := moneda;
        scuenta  := rpad(csec || ccap || cpla, 11, '0');
        simporte := totpla;
        insert into sb_bcp_sum values (scuenta, smoneda, simporte);
        /* Verifica si existe totalizador a nivel de grupo */
        scuenta  := rpad(csec || ccap || cpla || cgru, 11, '0');
        simporte := totgru;
        begin
          select count(*)
            into existe
            from sb_bcp_sum
           where cod_rubro = scuenta
             and cla_moneda = smoneda;
          if existe = 0 then
            insert into sb_bcp_sum values (scuenta, smoneda, simporte);
          end if;
        end;
        cpla   := substr(cuenta, 3, 1);
        cgru   := substr(cuenta, 4, 1);
        totsec := totsec + importe;
        totcap := totcap + importe;
        totpla := importe;
        totgru := importe;
        /* Verifica corte por grupo */
      elsif substr(cuenta, 4, 1) <> cgru then
        smoneda  := moneda;
        scuenta  := rpad(csec || ccap || cpla || cgru, 11, '0');
        simporte := totgru;
        insert into sb_bcp_sum values (scuenta, smoneda, simporte);
        cgru   := substr(cuenta, 4, 1);
        totsec := totsec + importe;
        totcap := totcap + importe;
        totpla := totpla + importe;
        totgru := importe;
        /* No hubo corte alguno */
      else
        totgru := totgru + importe;
        totpla := totpla + importe;
        totcap := totcap + importe;
        totsec := totsec + importe;
      end if;
    end loop;
    /* CORTE POR FIN DE ARCHIVO */
    /* Corte por moneda */
    smoneda  := cmon;
    scuenta  := rpad(csec, 11, '0');
    simporte := totsec;
    insert into sb_bcp_sum values (scuenta, smoneda, simporte);

    /* Verifica si existe totalizador a nivel de capitulo */
    scuenta  := rpad(csec || ccap, 11, '0');
    simporte := totcap;
    begin
      select count(*)
        into existe
        from sb_bcp_sum
       where cod_rubro = scuenta
         and cla_moneda = smoneda;
      if existe = 0 then
        insert into sb_bcp_sum values (scuenta, smoneda, simporte);
      end if;
    end;
    /* Verifica si existe totalizador a nivel de plazo */
    scuenta  := rpad(csec || ccap || cpla, 11, '0');
    simporte := totpla;
    begin
      select count(*)
        into existe
        from sb_bcp_sum
       where cod_rubro = scuenta
         and cla_moneda = smoneda;
      if existe = 0 then
        insert into sb_bcp_sum values (scuenta, smoneda, simporte);
      end if;
    end;
    /* Verifica si existe totalizador a nivel de grupo */
    scuenta  := rpad(csec || ccap || cpla || cgru, 11, '0');
    simporte := totgru;
    begin
      select count(*)
        into existe
        from sb_bcp_sum
       where cod_rubro = scuenta
         and cla_moneda = smoneda;
      if existe = 0 then
        insert into sb_bcp_sum values (scuenta, smoneda, simporte);
      end if;
    end;
    close bcp;
    /* Inserta en la tabla sb_bcp_sum los correspondientes registros de detalle*/
    insert into sb_bcp_sum
      select cod_rubro, cla_moneda, sum(importe)
        from sb_bcp
       where substr(cod_rubro, 1, 1) between sector_desde and sector_hasta
       group by cod_rubro, cla_moneda;
    /* Actualiza totalizadores de sectores 4 y 5 */
    update sb_bcp_sum a
       set importe =
           (select sum(importe)
              from sb_bcp_sum b
             where b.cla_moneda = a.cla_moneda
               and b.cod_rubro = '41000000000') ----/*in ('41000000000','42000000000'))
     where cod_rubro = '40000000000';

    update sb_bcp_sum a
       set importe =
           (select sum(importe)
              from sb_bcp_sum b
             where b.cla_moneda = a.cla_moneda
               and b.cod_rubro = '51000000000') ----/*in ('51000000000','52000000000'))
     where cod_rubro = '50000000000';

    /* Actualiza saldo promedio de cuentas transitorias */
    LP_ACT_RUB_TRANSITORIOS;

  END;

  /*proceso q genera datos para el archivo de riesgos*/
  PROCEDURE PR_PRO_RIESGO IS

    v_fec_vto         DATE;
    AUX               NUMBER(8) := 0;
    v_cod_entidad     sb_planinfo.cod_entidad%TYPE;
    w_tipo_entidad    sb_planinfo.tip_entidad%TYPE;
    w_clase_entidad   sb_planinfo.cla_entidad%TYPE;
    w_total_registros sb_planinfo.tot_reg_detalle%TYPE;
    wc_identificador  sb_riesgos.identificador%TYPE;
    wc_cuenta         sb_riesgos.cuenta%TYPE;
    wc_total_mn       sb_riesgos.tot_mon_local%TYPE;
    wc_total_me       sb_riesgos.tot_mon_extranjera%TYPE;
    wc_total_equiv    sb_riesgos.tot_equivalente%TYPE;
    v_nro_registro    number := 0;
    ----
    w_cdcuent   varchar2(15);
    w_acsalml   NUMBER := 0;
    w_acsalme   NUMBER := 0;
    w_ctdiast   NUMBER := 0;
    w_saldoml   NUMBER(18, 2);
    w_saldome   NUMBER(18, 2);
    w_cdctanv   varchar2(15);
    w_cdmoned   varchar2(3);
    w_vlconve   NUMBER(16, 2);
    w_resulta1  NUMBER;
    w_resulta2  NUMBER;
    SUMAI1A     NUMBER := 0;
    SUMAI1B     NUMBER := 0;
    SUMAI1C     NUMBER := 0;
    SUMAI1D     NUMBER := 0;
    SUMAI1E     NUMBER := 0;
    SUMAI1F     NUMBER := 0;
    SUMAI2A     NUMBER := 0;
    SUMAI2B     NUMBER := 0;
    SUMAI2C     NUMBER := 0;
    SUMAI2D     NUMBER := 0;
    SUMAI2E     NUMBER := 0;
    SUMAI2F     NUMBER := 0;
    SUMAI2T     NUMBER := 0;
    SUMAV1A     NUMBER := 0;
    SUMAV1B     NUMBER := 0;
    SUMAV1C     NUMBER := 0;
    SUMAV1D     NUMBER := 0;
    SUMAV1E     NUMBER := 0;
    SUMAV1F     NUMBER := 0;
    SUMAV2A     NUMBER := 0;
    SUMAV2B     NUMBER := 0;
    SUMAV2C     NUMBER := 0;
    SUMAV2D     NUMBER := 0;
    SUMAV2E     NUMBER := 0;
    SUMAV2F     NUMBER := 0;
    SUMAV2T     NUMBER := 0;
    SUMACAA     NUMBER := 0;
    SUMACAB     NUMBER := 0;
    SUMACAC     NUMBER := 0;
    SUMACAD     NUMBER := 0;
    SUMACAE     NUMBER := 0;
    SUMACAF     NUMBER := 0;
    SUMACAA_USD NUMBER := 0;
    SUMACAB_USD NUMBER := 0;
    SUMACAC_USD NUMBER := 0;
    SUMACAD_USD NUMBER := 0;
    SUMACAE_USD NUMBER := 0;
    SUMACAF_USD NUMBER := 0;
    SUMAIAA_USD NUMBER := 0;
    SUMAIAB_USD NUMBER := 0;
    SUMAIAC_USD NUMBER := 0;
    SUMAIAD_USD NUMBER := 0;
    SUMAIAE_USD NUMBER := 0;
    SUMAIAF_USD NUMBER := 0;
    SUMQCAA_USD NUMBER := 0;
    SUMQCAB_USD NUMBER := 0;
    SUMQCAC_USD NUMBER := 0;
    SUMQCAD_USD NUMBER := 0;
    SUMQCAE_USD NUMBER := 0;
    SUMQCAF_USD NUMBER := 0;
    SUMQIAA_USD NUMBER := 0;
    SUMQIAB_USD NUMBER := 0;
    SUMQIAC_USD NUMBER := 0;
    SUMQIAD_USD NUMBER := 0;
    SUMQIAE_USD NUMBER := 0;
    SUMQIAF_USD NUMBER := 0;
    SUMAIAA     NUMBER := 0;
    SUMAIAB     NUMBER := 0;
    SUMAIAC     NUMBER := 0;
    SUMAIAD     NUMBER := 0;
    SUMAIAE     NUMBER := 0;
    SUMAIAF     NUMBER := 0;
    SUMATSF     NUMBER := 0;
    SUMATNF     NUMBER := 0;
    SUMAV1A_USD NUMBER := 0;
    SUMAV1B_USD NUMBER := 0;
    SUMAV1C_USD NUMBER := 0;
    SUMAV1D_USD NUMBER := 0;
    SUMAV1E_USD NUMBER := 0;
    SUMAV1F_USD NUMBER := 0;
    SUMAV2A_USD NUMBER := 0;
    SUMAV2B_USD NUMBER := 0;
    SUMAV2C_USD NUMBER := 0;
    SUMAV2D_USD NUMBER := 0;
    SUMAV2E_USD NUMBER := 0;
    SUMAV2F_USD NUMBER := 0;
    SUMAI1A_USD NUMBER := 0;
    SUMAI1B_USD NUMBER := 0;
    SUMAI1C_USD NUMBER := 0;
    SUMAI1D_USD NUMBER := 0;
    SUMAI1E_USD NUMBER := 0;
    SUMAI1F_USD NUMBER := 0;
    SUMAI2A_USD NUMBER := 0;
    SUMAI2B_USD NUMBER := 0;
    SUMAI2C_USD NUMBER := 0;
    SUMAI2D_USD NUMBER := 0;
    SUMAI2E_USD NUMBER := 0;
    SUMAI2F_USD NUMBER := 0;
    SUMQI1A_USD NUMBER := 0;
    SUMQI1B_USD NUMBER := 0;
    SUMQC2A_USD NUMBER := 0;
    SUMQC2B_USD NUMBER := 0;
    SUMQC2C_USD NUMBER := 0;
    SUMQC2D_USD NUMBER := 0;
    SUMQC2E_USD NUMBER := 0;
    SUMQC2F_USD NUMBER := 0;
    SUMQC1A_USD NUMBER := 0;
    SUMQC1B_USD NUMBER := 0;
    SUMQC1C_USD NUMBER := 0;
    SUMQC1D_USD NUMBER := 0;
    SUMQC1E_USD NUMBER := 0;
    SUMQC1F_USD NUMBER := 0;
    SUMQI1C_USD NUMBER := 0;
    SUMQI1D_USD NUMBER := 0;
    SUMQI1E_USD NUMBER := 0;
    SUMQI1F_USD NUMBER := 0;
    SUMQI2A_USD NUMBER := 0;
    SUMQI2B_USD NUMBER := 0;
    SUMQI2C_USD NUMBER := 0;
    SUMQI2D_USD NUMBER := 0;
    SUMQI2E_USD NUMBER := 0;
    SUMQI2F_USD NUMBER := 0;
    T1_TOTAL_MN NUMBER := 0;
    T1_TOTAL_ME NUMBER := 0;
    T1_TOTAL_EQ NUMBER := 0;
    INTERESES   NUMBER(17, 2) := 0;
    v_fecha     DATE := NULL;
    DIAS        NUMBER := 0;
    CURSOR Cartera IS
      SELECT d.COD_PERSONA,
             COD_SEC_CONTABLE,
             DECODE(b.cod_modalidad, 671, 0, 670, 0, NVL(b.SAL_CAPITAL, 0)) SALDO,
             --NVL(b.SAL_INTERES,0) INTERES,
             DECODE(b.cod_modalidad,
                    671,
                    0,
                    670,
                    0,
                    NVL(b.dev_no_cobrado, 0)) interes, --modif
             nvl(p.monto, 0) prevision, --agregado
             --            NVL(TRUNC(o.cat_automatica),1) cat_riesgo,
             fup_obt_categoria(d.cat_automatica, d.cat_subjetiva) cat_riesgo,
             b.NRO_CUENTA,
             b.COD_MONEDA MONEDA,
             b.ESTADO,
             b.cod_modulo modulo,
             0 dia_mora,
             DECODE(b.cod_modalidad,
                    671,
                    0,
                    670,
                    0,
                    nvl(tot_val_capital, 0) + nvl(tot_val_devengado, 0) +
                    nvl(tot_val_garantia, 0) + nvl(tot_val_interes, 0) +
                    nvl(tot_val_int_ade, 0) + nvl(tot_val_int_devengar, 0) +
                    nvl(tot_val_prevision, 0) + nvl(tot_val_suspenso, 0)) valuacion
        FROM ge_cta_clientes e,
             GE_CLIENTES     d,
             pr_valuaciones  z,
             --            ge_cla_operaciones o,
             (select monto, nro_cuenta
                from pr_previsiones a
               where a.fecha =
                     (select max(b.fecha)
                        from pr_previsiones b
                       where a.nro_cuenta = b.nro_cuenta)) p,
             PR_CTA_PRESTAMOS b
       WHERE b.nro_cuenta = e.nro_cuenta
         and e.cod_persona = d.cod_persona
         and e.relacion = 'P'
         and b.estado not in ('N', 'I')
            --AND b.FEC_INICIO <= v_fec_actual
         AND (COD_SEC_CONTABLE = 'N' or
             (cod_sec_contable = 'F' and b.estado in ('V', 'G', 'M')))
         and b.nro_cuenta = p.nro_cuenta(+) --prevision
         and b.nro_cuenta = z.nro_cuenta(+) --valuacion
            --        and b.nro_cuenta = o.nro_cuenta
         and b.cod_modalidad not in (650, 656) --bonos y bienes
         and ((fug_obt_tip_implementacion = 2 and b.cod_modalidad <> 658) or
             fug_obt_tip_implementacion <> 2)
      union
      select cl.cod_persona,
             cl.cod_sec_contable,
             nvl(b.saldo, 0) saldo,
             0 interes,
             nvl(v.monto, 0) prevision,
             fup_obt_categoria(cl.cat_automatica, cl.cat_subjetiva) cat_riesgo,
             t.nro_cuenta,
             t.cod_moneda moneda,
             decode(t.cat_automatica,
                    '1',
                    'C',
                    '2',
                    'V',
                    '3',
                    'G',
                    '4',
                    'M',
                    'M') estado,
             t.cod_modulo modulo,
             dia_mora,
             0 valuacion
        from ta_cta_tarjetas t,
             ge_cta_clientes ct,
             ge_clientes cl,
             (select t.nro_cuenta,
                     decode(sign((nvl(t.sal_facturar, 0) +
                                 nvl(t.sal_facturado, 0) +
                                 nvl(t.sal_financiado, 0) +
                                 nvl(t.sal_cuo_pendientes, 0))),
                            1,
                            (nvl(t.sal_facturar, 0) + nvl(t.sal_facturado, 0) +
                            nvl(t.sal_financiado, 0) +
                            nvl(t.sal_cuo_pendientes, 0)),
                            0) saldo
                from ta_cta_tarjetas t
               where t.estado <> 'C') b,
             (select p.nro_cuenta, nvl(p.monto, 0) monto
                from ta_previsiones p
               where p.fecha =
                     (select max(p1.fecha)
                        from ta_previsiones p1
                       where p1.nro_cuenta = p.nro_cuenta)) v
       where t.nro_cuenta = b.nro_cuenta
         and t.nro_cuenta = v.nro_cuenta(+)
         and t.estado <> 'C'
         and t.nro_cuenta = ct.nro_cuenta
         and ct.relacion = 'P'
         and cl.cod_persona = ct.cod_persona
            ----/*        and b.saldo > 0
         AND (COD_SEC_CONTABLE = 'N' or
             (cod_sec_contable = 'F' and
             t.cat_automatica in ('2', '3', '4')))
         and ((fug_obt_tip_implementacion = 2 and t.cat_automatica <> 6) or
             fug_obt_tip_implementacion <> 2)
        UNION
      SELECT d.COD_PERSONA,
             d.COD_SEC_CONTABLE,
             NVL(b.SAL_TOTAL, 0) SALDO,
             0 interes, --modif
             nvl(p.monto, 0) prevision, --agregado
             fup_obt_categoria(d.cat_automatica, d.cat_subjetiva) cat_riesgo,
             b.NRO_CUENTA,
             b.COD_MONEDA MONEDA,
             b.ESTADO,
             b.cod_modulo modulo,
             0 dia_mora,
             nvl(tot_val_capital, 0) + nvl(tot_val_devengado, 0) +
             nvl(tot_val_garantia, 0) + nvl(tot_val_interes, 0) +
             nvl(tot_val_int_ade, 0) + nvl(tot_val_int_devengar, 0) +
             nvl(tot_val_prevision, 0) + nvl(tot_val_suspenso, 0) valuacion
        FROM ge_cta_clientes e,
             GE_CLIENTES d,
             pr_valuaciones z,
             (select monto, nro_cuenta
                from ov_previsiones a
               where a.fecha =
                     (select max(b.fecha)
                        from pr_previsiones b
                       where a.nro_cuenta = b.nro_cuenta)) p,
             OV_CTA_VENCIDAS b
       WHERE b.nro_cuenta = e.nro_cuenta
         and e.cod_persona = d.cod_persona
         and e.relacion = 'P'
         and b.estado not in ('C', 'I')
         AND (COD_SEC_CONTABLE = 'N' or
             (cod_sec_contable = 'F' and b.estado in ('V', 'G', 'M')))
         and b.nro_cuenta = p.nro_cuenta(+) --prevision
         and b.nro_cuenta = z.nro_cuenta(+);--valuacion

    CURSOR Ctacte IS
      SELECT c.COD_PERSONA CLIENTE, -- MC_CDSECTO,--
             NVL(SAL_TOTAL, 0) * -1 SALDO,
             COD_MONEDA MONEDA
        FROM CC_CTA_CORRIENTES a, GE_CLIENTES b, GE_CTA_CLIENTES c
       WHERE a.NRO_CUENTA = c.NRO_CUENTA
         AND b.COD_PERSONA = c.COD_PERSONA
         AND c.relacion = 'P'
         AND FEC_APERTURA <= v_fecha
         AND COD_SEC_CONTABLE = 'N' --<> 'F'
         AND a.estado <> 'C'
         AND SAL_TOTAL < 0
         AND c.COD_MODALIDAD = 41;
    CURSOR Comercio IS
      SELECT C.COD_PERSONA,
             nvl(COD_SEC_CONTABLE, 'NF') CDSECTO,
             NVL(SALDO, 0) SALDO,
             NVL(COD_MONEDA, v_cod_mon_local) MONEDA
        FROM CX_CTA_EXPORTACIONES E, GE_CLIENTES C, GE_CTA_CLIENTES B
       WHERE E.NRO_CUENTA = B.NRO_CUENTA
         AND B.COD_PERSONA = C.COD_PERSONA
         AND B.RELACION = 'P'
         AND C.COD_SEC_CONTABLE = 'N' --<> 'F'
         AND E.ESTADO IN ('A', 'D', 'P')
      UNION
      SELECT C.COD_PERSONA,
             nvl(COD_SEC_CONTABLE, 'NF') CDSECTO,
             NVL(SALDO, 0) SALDO,
             NVL(COD_MONEDA, v_cod_mon_local) MONEDA
        FROM CX_CTA_IMPORTACIONES I, GE_CLIENTES C, GE_CTA_CLIENTES B
       WHERE I.NRO_CUENTA = B.NRO_CUENTA
         AND B.COD_PERSONA = C.COD_PERSONA
         AND B.RELACION = 'P'
         AND C.COD_SEC_CONTABLE = 'N' --<> 'F'
         AND I.ESTADO IN ('A', 'D', 'P');
    SALDO1    NUMBER(17, 2) := 0;
    SALDO2    NUMBER(17, 2) := 0;
    SALDO3    NUMBER(17, 2) := 0;
    SALDO_NC  NUMBER(17, 2) := 0;
    SALDO_NI  NUMBER(17, 2) := 0;
    SALDO_EQC NUMBER(17, 2) := 0;
    SALDO_EQI NUMBER(17, 2) := 0;
    COTIZ     NUMBER(17, 2) := 0;
    v_tot_loc NUMBER(17, 2) := 0;
    v_tot_ext NUMBER(17, 2) := 0;
    v_tot_equ NUMBER(17, 2) := 0;
    ---PREV
    SALDO_PRV   NUMBER(17, 2) := 0;
    SALDO_EQP   NUMBER(17, 2) := 0;
    SUMAP1A     NUMBER(17, 2) := 0;
    SUMAP1B     NUMBER(17, 2) := 0;
    SUMAP1C     NUMBER(17, 2) := 0;
    SUMAP1D     NUMBER(17, 2) := 0;
    SUMAP1E     NUMBER(17, 2) := 0;
    SUMAP1F     NUMBER(17, 2) := 0;
    SUMAP2A     NUMBER(17, 2) := 0;
    SUMAP2B     NUMBER(17, 2) := 0;
    SUMAP2C     NUMBER(17, 2) := 0;
    SUMAP2D     NUMBER(17, 2) := 0;
    SUMAP2E     NUMBER(17, 2) := 0;
    SUMAP2F     NUMBER(17, 2) := 0;
    SUMAP1A_USD NUMBER(17, 2) := 0;
    SUMQP1A_USD NUMBER(17, 2) := 0;
    SUMAP1B_USD NUMBER(17, 2) := 0;
    SUMQP1B_USD NUMBER(17, 2) := 0;
    SUMAP1C_USD NUMBER(17, 2) := 0;
    SUMQP1C_USD NUMBER(17, 2) := 0;
    SUMAP1D_USD NUMBER(17, 2) := 0;
    SUMQP1D_USD NUMBER(17, 2) := 0;
    SUMAP1E_USD NUMBER(17, 2) := 0;
    SUMQP1E_USD NUMBER(17, 2) := 0;
    SUMAP1F_USD NUMBER(17, 2) := 0;
    SUMQP1F_USD NUMBER(17, 2) := 0;
    SUMAP2A_USD NUMBER(17, 2) := 0;
    SUMQP2A_USD NUMBER(17, 2) := 0;
    SUMAP2B_USD NUMBER(17, 2) := 0;
    SUMQP2B_USD NUMBER(17, 2) := 0;
    SUMAP2C_USD NUMBER(17, 2) := 0;
    SUMQP2C_USD NUMBER(17, 2) := 0;
    SUMAP2D_USD NUMBER(17, 2) := 0;
    SUMQP2D_USD NUMBER(17, 2) := 0;
    SUMAP2E_USD NUMBER(17, 2) := 0;
    SUMQP2E_USD NUMBER(17, 2) := 0;
    SUMAP2F_USD NUMBER(17, 2) := 0;
    SUMQP2F_USD NUMBER(17, 2) := 0;
    SUMAPAA     NUMBER(17, 2) := 0;
    SUMAPAB     NUMBER(17, 2) := 0;
    SUMAPAC     NUMBER(17, 2) := 0;
    SUMAPAD     NUMBER(17, 2) := 0;
    SUMAPAE     NUMBER(17, 2) := 0;
    SUMAPAF     NUMBER(17, 2) := 0;
    SUMAPAA_USD NUMBER(17, 2) := 0;
    SUMQPAA_USD NUMBER(17, 2) := 0;
    SUMAPAB_USD NUMBER(17, 2) := 0;
    SUMQPAB_USD NUMBER(17, 2) := 0;
    SUMAPAC_USD NUMBER(17, 2) := 0;
    SUMQPAC_USD NUMBER(17, 2) := 0;
    SUMAPAD_USD NUMBER(17, 2) := 0;
    SUMQPAD_USD NUMBER(17, 2) := 0;
    SUMAPAE_USD NUMBER(17, 2) := 0;
    SUMQPAE_USD NUMBER(17, 2) := 0;
    SUMAPAF_USD NUMBER(17, 2) := 0;
    SUMQPAF_USD NUMBER(17, 2) := 0;
    --VALUAC
    SALDO_VAL   NUMBER(17, 2) := 0;
    SALDO_EQL   NUMBER(17, 2) := 0;
    SUMAL1A     NUMBER(17, 2) := 0;
    SUMAL1B     NUMBER(17, 2) := 0;
    SUMAL1C     NUMBER(17, 2) := 0;
    SUMAL1D     NUMBER(17, 2) := 0;
    SUMAL1E     NUMBER(17, 2) := 0;
    SUMAL1F     NUMBER(17, 2) := 0;
    SUMAL2A     NUMBER(17, 2) := 0;
    SUMAL2B     NUMBER(17, 2) := 0;
    SUMAL2C     NUMBER(17, 2) := 0;
    SUMAL2D     NUMBER(17, 2) := 0;
    SUMAL2E     NUMBER(17, 2) := 0;
    SUMAL2F     NUMBER(17, 2) := 0;
    SUMAL1A_USD NUMBER(17, 2) := 0;
    SUMQL1A_USD NUMBER(17, 2) := 0;
    SUMAL1B_USD NUMBER(17, 2) := 0;
    SUMQL1B_USD NUMBER(17, 2) := 0;
    SUMAL1C_USD NUMBER(17, 2) := 0;
    SUMQL1C_USD NUMBER(17, 2) := 0;
    SUMAL1D_USD NUMBER(17, 2) := 0;
    SUMQL1D_USD NUMBER(17, 2) := 0;
    SUMAL1E_USD NUMBER(17, 2) := 0;
    SUMQL1E_USD NUMBER(17, 2) := 0;
    SUMAL1F_USD NUMBER(17, 2) := 0;
    SUMQL1F_USD NUMBER(17, 2) := 0;
    SUMAL2A_USD NUMBER(17, 2) := 0;
    SUMQL2A_USD NUMBER(17, 2) := 0;
    SUMAL2B_USD NUMBER(17, 2) := 0;
    SUMQL2B_USD NUMBER(17, 2) := 0;
    SUMAL2C_USD NUMBER(17, 2) := 0;
    SUMQL2C_USD NUMBER(17, 2) := 0;
    SUMAL2D_USD NUMBER(17, 2) := 0;
    SUMQL2D_USD NUMBER(17, 2) := 0;
    SUMAL2E_USD NUMBER(17, 2) := 0;
    SUMQL2E_USD NUMBER(17, 2) := 0;
    SUMAL2F_USD NUMBER(17, 2) := 0;
    SUMQL2F_USD NUMBER(17, 2) := 0;
    SUMALAA     NUMBER(17, 2) := 0;
    SUMALAB     NUMBER(17, 2) := 0;
    SUMALAC     NUMBER(17, 2) := 0;
    SUMALAD     NUMBER(17, 2) := 0;
    SUMALAE     NUMBER(17, 2) := 0;
    SUMALAF     NUMBER(17, 2) := 0;
    SUMALAA_USD NUMBER(17, 2) := 0;
    SUMQLAA_USD NUMBER(17, 2) := 0;
    SUMALAB_USD NUMBER(17, 2) := 0;
    SUMQLAB_USD NUMBER(17, 2) := 0;
    SUMALAC_USD NUMBER(17, 2) := 0;
    SUMQLAC_USD NUMBER(17, 2) := 0;
    SUMALAD_USD NUMBER(17, 2) := 0;
    SUMQLAD_USD NUMBER(17, 2) := 0;
    SUMALAE_USD NUMBER(17, 2) := 0;
    SUMQLAE_USD NUMBER(17, 2) := 0;
    SUMALAF_USD NUMBER(17, 2) := 0;
    SUMQLAF_USD NUMBER(17, 2) := 0;
    --sector n, est m
    SUMMV1A      NUMBER(17, 2) := 0;
    SUMMV1B      NUMBER(17, 2) := 0;
    SUMMV1C      NUMBER(17, 2) := 0;
    SUMMV1D      NUMBER(17, 2) := 0;
    SUMMV1E      NUMBER(17, 2) := 0;
    SUMMV1F      NUMBER(17, 2) := 0;
    SUMMV1A_USD  NUMBER(17, 2) := 0;
    SUMMQC1A_USD NUMBER(17, 2) := 0;
    SUMMV1B_USD  NUMBER(17, 2) := 0;
    SUMMQC1B_USD NUMBER(17, 2) := 0;
    SUMMV1C_USD  NUMBER(17, 2) := 0;
    SUMMQC1C_USD NUMBER(17, 2) := 0;
    SUMMV1D_USD  NUMBER(17, 2) := 0;
    SUMMQC1D_USD NUMBER(17, 2) := 0;
    SUMMV1E_USD  NUMBER(17, 2) := 0;
    SUMMQC1E_USD NUMBER(17, 2) := 0;
    SUMMV1F_USD  NUMBER(17, 2) := 0;
    SUMMQC1F_USD NUMBER(17, 2) := 0;
    --sector f
    SUMFV1A      NUMBER(17, 2) := 0;
    SUMFV1B      NUMBER(17, 2) := 0;
    SUMFV1C      NUMBER(17, 2) := 0;
    SUMFV1D      NUMBER(17, 2) := 0;
    SUMFV1E      NUMBER(17, 2) := 0;
    SUMFV1F      NUMBER(17, 2) := 0;
    SUMFV1A_USD  NUMBER(17, 2) := 0;
    SUMFQC1A_USD NUMBER(17, 2) := 0;
    SUMFV1B_USD  NUMBER(17, 2) := 0;
    SUMFQC1B_USD NUMBER(17, 2) := 0;
    SUMFV1C_USD  NUMBER(17, 2) := 0;
    SUMFQC1C_USD NUMBER(17, 2) := 0;
    SUMFV1D_USD  NUMBER(17, 2) := 0;
    SUMFQC1D_USD NUMBER(17, 2) := 0;
    SUMFV1E_USD  NUMBER(17, 2) := 0;
    SUMFQC1E_USD NUMBER(17, 2) := 0;
    SUMFV1F_USD  NUMBER(17, 2) := 0;
    SUMFQC1F_USD NUMBER(17, 2) := 0;
    ---
    ----procedimiento local de insercion
    procedure lp_ins_sb_riesgos(p_fecha        in date,
                                p_nro_registro in number,
                                p_cuenta       in varchar2,
                                p_tot_local    in number,
                                p_tot_me       in number,
                                p_tot_equiv    in number) is
      v_tip_formulario number := 5;
    begin
      INSERT INTO sb_riesgos
        (fecha,
         nro_registro,
         tip_formulario,
         identificador,
         cuenta,
         tot_mon_local,
         tot_mon_extranjera,
         tot_equivalente)
      VALUES
        (p_fecha,
         p_nro_registro,
         v_tip_formulario,
         0,
         p_cuenta,
         p_tot_local,
         p_tot_me,
         p_tot_equiv);
    exception
      when others then
        raise_application_error(-20002, 'Ins.Sb_Riesgos ' || sqlerrm);
    end;

    PROCEDURE LP_CTA_CONTABLES IS
      v_cod_grupo      cb_gru_rubros.cod_gru_rubro%type;
      v_cod_moneda     ba_monedas.cod_moneda%type;
      v_cod_mon_local  ba_monedas.cod_moneda%type;
      v_cod_mon_fuerte ba_monedas.cod_moneda%type;
      v_saldo          cb_sal_oficinas.sal_ini_mes_mon_local%type;
      v_rowid          rowid;
      ---
      V_RUBRO       VARCHAR2(15);
      V_PLAZO       NUMBER;
      V_DESCRIPCION VARCHAR2(200);
      --- Cursor de cuentas contables a insertar en el analisis de liquidez
      cursor c_liq_contable is
        select a.cod_rubro,
               abs(sum(decode(c.cod_moneda,
                              v_cod_mon_local,
                              0,
                              nvl(sal_ini_mes_mon_fuerte, 0)))) saldo_me,
               abs(sum(nvl(sal_ini_mes_mon_local, 0) -
                       nvl(sal_ini_mes_equ_local, 0))) saldo_ml,
               abs(sum(nvl(sal_ini_mes_equ_local, 0))) saldo_eq
          from cb_sal_oficinas a, cb_rubros c, cb_gru_rubros_det d
         where a.cod_rubro = c.cod_rubro
           and c.imputable = 'S'
           and d.cod_gru_rubro = v_cod_grupo
           and d.cod_rubro = a.cod_rubro
           and (substr(d.cod_rubro, 1, 2) = '14' or
               substr(d.cod_rubro, 1, 2) = '16')
           and (nvl(sal_ini_mes_mon_fuerte, 0) <> 0 or
               nvl(sal_ini_mes_equ_local, 0) <> 0 or
               nvl(sal_ini_mes_mon_local, 0) <> 0)
         group by a.cod_rubro;
    BEGIN
      -- Recuperar grupo de cuentas contables para AL
      v_cod_grupo      := fug_obt_pardinamico('GRU_RUB_LIQUIDEZ');
      v_cod_mon_local  := pag_gen.fu_obt_mon_local;
      v_cod_mon_fuerte := pag_gen.fu_obt_mon_fuerte;
      for sal in c_liq_contable loop
        --- Procesar registro
        --- Procesar registro
        if substr(sal.cod_rubro, 3, 1) in ('7', '8', '0') then
          if substr(sal.cod_rubro, 1, 2) = '14' then
            if substr(sal.cod_rubro, 4, 2) = '90' then
              v_rubro := substr(sal.cod_rubro, 1, 2) || '0' ||
                         substr(sal.cod_rubro, 4, 1) || '1' || '000000';
            else
              v_rubro := substr(sal.cod_rubro, 1, 2) || '0' ||
                         substr(sal.cod_rubro, 4, 1) || '3' || '000000';
            end if;
          end if;
          if substr(sal.cod_rubro, 1, 2) = '16' then
            if substr(sal.cod_rubro, 4, 2) = '90' then
              v_rubro := substr(sal.cod_rubro, 1, 2) || '0' ||
                         substr(sal.cod_rubro, 4, 1) || '3' || '000000';
            else
              v_rubro := substr(sal.cod_rubro, 1, 2) || '0' ||
                         substr(sal.cod_rubro, 4, 1) || '3' || '000000';
            end if;
          end if;
        else
          v_rubro := substr(sal.cod_rubro, 1, 2) || '0' ||
                     substr(sal.cod_rubro, 4, 1) ||
                     substr(sal.cod_rubro, 3, 1) || '000000';
        end if;
        begin
          select rowid
            into v_rowid
            from sb_riesgos
           where fecha = v_fecha
             and cuenta = v_rubro;
          --- Actualizar registro con saldo
          update sb_riesgos
             set tot_mon_local      = nvl(tot_mon_local, 0) +
                                      nvl(sal.saldo_ml, 0),
                 tot_mon_extranjera = nvl(tot_mon_extranjera, 0) +
                                      nvl(sal.saldo_me, 0),
                 tot_equivalente    = nvl(tot_equivalente, 0) +
                                      nvl(sal.saldo_eq, 0)
           where rowid = v_rowid;
        exception
          when no_data_found then
            --- Insertar registro
            v_nro_registro := nvl(v_nro_registro, 0) + 1;
            lp_ins_sb_riesgos(v_fecha,
                              v_nro_registro,
                              v_rubro,
                              nvl(sal.saldo_ml, 0),
                              nvl(sal.saldo_me, 0),
                              nvl(sal.saldo_eq, 0));
        end;
      end loop;
    END;

    PROCEDURE LP_PRE_GENERICAS IS
      v_cod_grupo      cb_gru_rubros.cod_gru_rubro%type;
      v_cod_moneda     ba_monedas.cod_moneda%type;
      v_cod_mon_local  ba_monedas.cod_moneda%type;
      v_cod_mon_fuerte ba_monedas.cod_moneda%type;
      v_saldo          cb_sal_oficinas.sal_ini_mes_mon_local%type;
      v_rowid          rowid;
      ---
      V_RUBRO       VARCHAR2(15);
      V_PLAZO       NUMBER;
      V_DESCRIPCION VARCHAR2(200);
      --- Cursor de cuentas de previsiones genericas a insertar
      cursor c_liq_contable is
        select a.cod_rubro,
               abs(sum(decode(nvl(sal_ini_mes_mon_rubro, 0),
                              0,
                              0,
                              nvl(sal_ini_mes_mon_rubro, 0)))) saldo_me,
               abs(sum(nvl(sal_ini_mes_mon_local, 0) -
                       nvl(sal_ini_mes_equ_local, 0))) saldo_ml,
               abs(sum(nvl(sal_ini_mes_equ_local, 0))) saldo_eq
          from cb_sal_oficinas a, cb_rubros c, cb_rub_genericas d
         where a.cod_rubro = c.cod_rubro
           and a.cod_rubro = d.cod_rub_generica
           and a.cod_oficina = d.cod_oficina
           and (nvl(sal_ini_mes_mon_fuerte, 0) <> 0 or
               nvl(sal_ini_mes_equ_local, 0) <> 0 or
               nvl(sal_ini_mes_mon_local, 0) <> 0)
         group by a.cod_rubro;

    BEGIN
      v_cod_mon_local  := pag_gen.fu_obt_mon_local;
      v_cod_mon_fuerte := pag_gen.fu_obt_mon_fuerte;
      for sal in c_liq_contable loop
        --- Procesar registro
        if substr(sal.cod_rubro, 3, 1) in ('7', '8', '0') then
          if substr(sal.cod_rubro, 1, 2) = '14' then
            if substr(sal.cod_rubro, 4, 2) = '90' then
              v_rubro := substr(sal.cod_rubro, 1, 2) || '0' ||
                         substr(sal.cod_rubro, 4, 1) || '1' || '000000';
            else
              v_rubro := substr(sal.cod_rubro, 1, 2) || '0' ||
                         substr(sal.cod_rubro, 4, 1) || '3' || '000000';
            end if;
          end if;
          if substr(sal.cod_rubro, 1, 2) = '16' then
            if substr(sal.cod_rubro, 4, 2) = '90' then
              v_rubro := substr(sal.cod_rubro, 1, 2) || '0' ||
                         substr(sal.cod_rubro, 4, 1) || '3' || '000000';
            else
              v_rubro := substr(sal.cod_rubro, 1, 2) || '0' ||
                         substr(sal.cod_rubro, 4, 1) || '3' || '000000';
            end if;
          end if;
        else
          v_rubro := substr(sal.cod_rubro, 1, 2) || '0' ||
                     substr(sal.cod_rubro, 4, 1) ||
                     substr(sal.cod_rubro, 3, 1) || '000000';
        end if;
        begin
          select rowid
            into v_rowid
            from sb_riesgos
           where fecha = v_fecha
             and cuenta = v_rubro;
          --- Actualizar registro con saldo
          update sb_riesgos
             set tot_mon_local      = nvl(tot_mon_local, 0) +
                                      nvl(sal.saldo_ml, 0),
                 tot_mon_extranjera = nvl(tot_mon_extranjera, 0) +
                                      nvl(sal.saldo_me, 0),
                 tot_equivalente    = nvl(tot_equivalente, 0) +
                                      nvl(sal.saldo_eq, 0)
           where rowid = v_rowid;
        exception
          when no_data_found then
            --- Insertar registro
            v_nro_registro := nvl(v_nro_registro, 0) + 1;
            lp_ins_sb_riesgos(v_fecha,
                              v_nro_registro,
                              v_rubro,
                              nvl(sal.saldo_ml, 0),
                              nvl(sal.saldo_me, 0),
                              nvl(sal.saldo_eq, 0));
        end;
      end loop;
    END;

    PROCEDURE LP_ACT_SAL_EQUIVALENTES IS

      -- Variables.
      v_cotizacion  ge_cotizaciones.val_conversion%type;
      v_redondeo    number := 0;
      v_fec_sistema date := pag_cal.fu_obt_fec_actual(11);
      -- Cursores.
      cursor c_sal_equivalentes is
        select sr.cuenta,
               round(sr.tot_mon_extranjera * v_cotizacion, v_redondeo) mto_equivalente,
               sr.rowid
          from sb_riesgos sr
         where sr.fecha = v_fec_proceso
           and sr.tot_mon_extranjera != 0;

    BEGIN
      --
      v_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_mon_fuerte,
                                                v_fec_sistema);
      v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                          null,
                                          null,
                                          v_cod_mon_local);
      update sb_riesgos sr set sr.tot_equivalente = 0;
      --

      for reg in c_sal_equivalentes loop
        update sb_riesgos sb
           set sb.tot_equivalente = reg.mto_equivalente
         where sb.rowid = reg.rowid;
      end loop;

    EXCEPTION
      WHEN OTHERS THEN
        null;
    END;

    /*inicio proceso*/
  BEGIN
    v_nro_registro := 0;

    pag_cal.PR_OBT_DAT_CALENDAR(2);
    v_fecha := last_day(v_fec_proceso); --pag_cal.G_ULT_DIA_MES_HABIL;
    --debe tener el ultimo dia del mes anterior,ya q se corre luego del inicio del 1er dia hab del mes
    --no debe ser habil ya q es por el calculo de mora (no dif entre hab o no)

    --recupera entidad
    select cod_entidad --clase y tipo entidad
      into v_cod_entidad
      from ge_par_generales;

    DELETE FROM sb_riesgos;
    DELETE FROM sb_planinfo where nom_archivo = 'RIESGO_TAS';

    FOR CA IN CARTERA LOOP
      SALDO_NC  := 0;
      SALDO_NI  := 0;
      SALDO_PRV := 0;
      SALDO_EQC := 0;
      SALDO_EQI := 0;
      SALDO_EQP := 0;
      if ca.modulo = 6 then
        begin
          SELECT MAX(FEC_VENCIMIENTO)
            INTO v_fec_vto
            FROM PR_CUOTAS
           WHERE NRO_CUENTA = CA.NRO_CUENTA
             AND ESTADO <> 'N';
        exception
          when others then
            v_fec_vto := v_fecha;
        end;
      end if;

      IF CA.MONEDA = v_cod_mon_fuerte THEN
        SALDO_NC  := NVL(CA.SALDO, 0);
        SALDO_NI  := NVL(CA.INTERES, 0);
        SALDO_PRV := NVL(CA.PREVISION, 0);
        SALDO_VAL := pag_gen.FU_CON_MON_A_MONEDA(v_cod_mon_local,
                                                 v_cod_mon_fuerte,
                                                 NVL(CA.VALUACION, 0));
        --valuacion esta en gs.
      ELSE
        --moneda extranjera no USD
        IF CA.MONEDA <> v_cod_mon_local THEN
          --convierte a USD
          SALDO_NC  := pag_gen.FU_CON_MON_A_MONEDA(ca.moneda,
                                                   v_cod_mon_fuerte,
                                                   NVL(CA.SALDO, 0));
          SALDO_NI  := pag_gen.FU_CON_MON_A_MONEDA(ca.moneda,
                                                   v_cod_mon_fuerte,
                                                   NVL(CA.INTERES, 0));
          SALDO_PRV := pag_gen.FU_CON_MON_A_MONEDA(ca.moneda,
                                                   v_cod_mon_fuerte,
                                                   NVL(CA.PREVISION, 0));
          SALDO_VAL := pag_gen.FU_CON_MON_A_MONEDA(v_cod_mon_local,
                                                   v_cod_mon_fuerte,
                                                   NVL(CA.VALUACION, 0));
          --valuacion ya esta en gs.
        END IF;
      END IF;
      --equivalente
      IF CA.MONEDA <> v_cod_mon_local THEN
        --convierte mon. extranj a local
        SALDO_EQC := round(pag_gen.fu_con_mon_a_moneda(ca.moneda,
                                                       v_cod_mon_local,
                                                       SALDO_NC)); -- * :SCR_COTIZ_USD;
        SALDO_EQI := round(pag_gen.fu_con_mon_a_moneda(ca.moneda,
                                                       v_cod_mon_local,
                                                       SALDO_NI)); -- * :SCR_COTIZ_USD;
        SALDO_EQP := round(pag_gen.fu_con_mon_a_moneda(ca.moneda,
                                                       v_cod_mon_local,
                                                       SALDO_PRV)); -- * :SCR_COTIZ_USD;
        SALDO_EQL := NVL(CA.VALUACION, 0); --round(pag_gen.fu_con_mon_a_moneda(ca.moneda, v_cod_mon_local, SALDO_VAL));-- * :SCR_COTIZ_USD;
      END IF;
      IF CA.ESTADO NOT IN ('C', 'A') THEN
        --CON ATRASO
        if ca.modulo = 6 then
          AUX := v_fecha - v_FEC_vto;
        else
          AUX := nvl(CA.dia_mora, 0);
        end if;
        --- Preguntar por sector para Vencido, Gestion, Moroso
        --       IF AUX <= 180 THEN
        IF CA.CAT_RIESGO = '1' THEN
          IF CA.MONEDA = v_cod_mon_local THEN
            if ca.cod_sec_contable = 'N' and ca.estado in ('V', 'G') then
              --- Va en la 16010
              SUMAV1A := NVL(SUMAV1A, 0) + NVL(CA.SALDO, 0);
            elsif ca.cod_sec_contable = 'N' and ca.estado = 'M' then
              --- Va en la 16030, solo capital
              SUMMV1A := NVL(SUMMV1A, 0) + NVL(CA.SALDO, 0);
            else
              --- Sector Financiero -- Va en la 16050, solo capital
              SUMFV1A := NVL(SUMFV1A, 0) + NVL(CA.SALDO, 0);
            end if;
            SUMAI1A := NVL(SUMAI1A, 0) + NVL(CA.INTERES, 0);
            SUMAP1A := NVL(SUMAP1A, 0) + NVL(CA.PREVISION, 0);
            SUMAL1A := NVL(SUMAL1A, 0) + NVL(CA.VALUACION, 0);
          ELSE
            if ca.cod_sec_contable = 'N' and ca.estado in ('V', 'G') then
              SUMAV1A_USD := NVL(SUMAV1A_USD, 0) + NVL(SALDO_NC, 0);
              SUMQC1A_USD := NVL(SUMQC1A_USD, 0) + NVL(SALDO_EQC, 0);
            elsif ca.cod_sec_contable = 'N' and ca.estado = 'M' then
              --- Va en la 16030
              SUMMV1A_USD  := NVL(SUMMV1A_USD, 0) + NVL(SALDO_NC, 0);
              SUMMQC1A_USD := NVL(SUMMQC1A_USD, 0) + NVL(SALDO_EQC, 0);
            else
              --- Sector Financiero -- Va en la 16050
              SUMFV1A_USD  := NVL(SUMFV1A_USD, 0) + NVL(SALDO_NC, 0);
              SUMFQC1A_USD := NVL(SUMFQC1A_USD, 0) + NVL(SALDO_EQC, 0);
            end if;
            SUMAI1A_USD := NVL(SUMAI1A_USD, 0) + NVL(SALDO_NI, 0);
            SUMQI1A_USD := NVL(SUMQI1A_USD, 0) + NVL(SALDO_EQI, 0);
            SUMAP1A_USD := NVL(SUMAP1A_USD, 0) + NVL(SALDO_PRV, 0);
            SUMQP1A_USD := NVL(SUMQP1A_USD, 0) + NVL(SALDO_EQP, 0);
            SUMAL1A_USD := NVL(SUMAL1A_USD, 0) + NVL(SALDO_VAL, 0);
            SUMQL1A_USD := NVL(SUMQL1A_USD, 0) + NVL(SALDO_EQL, 0);
          END IF;
        ELSIF CA.CAT_RIESGO = '2' THEN
          IF CA.MONEDA = v_cod_mon_local THEN
            if ca.cod_sec_contable = 'N' and ca.estado in ('V', 'G') then
              SUMAV1B := NVL(SUMAV1B, 0) + NVL(CA.SALDO, 0);
            elsif ca.cod_sec_contable = 'N' and ca.estado = 'M' then
              --- Va en la 16030, solo capital
              SUMMV1B := NVL(SUMMV1B, 0) + NVL(CA.SALDO, 0);
            else
              --- Sector Financiero -- Va en la 16050, solo capital
              SUMFV1B := NVL(SUMFV1B, 0) + NVL(CA.SALDO, 0);
            end if;
            SUMAI1B := NVL(SUMAI1B, 0) + NVL(CA.INTERES, 0);
            SUMAP1B := NVL(SUMAP1B, 0) + NVL(CA.PREVISION, 0);
            SUMAL1B := NVL(SUMAL1B, 0) + NVL(CA.VALUACION, 0);
          ELSE
            if ca.cod_sec_contable = 'N' and ca.estado in ('V', 'G') then
              SUMAV1B_USD := NVL(SUMAV1B_USD, 0) + NVL(SALDO_NC, 0);
              SUMQC1B_USD := NVL(SUMQC1B_USD, 0) + NVL(SALDO_EQC, 0);
            elsif ca.cod_sec_contable = 'N' and ca.estado = 'M' then
              --- Va en la 16030
              SUMMV1B_USD  := NVL(SUMMV1B_USD, 0) + NVL(SALDO_NC, 0);
              SUMMQC1B_USD := NVL(SUMMQC1B_USD, 0) + NVL(SALDO_EQC, 0);
            else
              --- Sector Financiero -- Va en la 16050
              SUMFV1B_USD  := NVL(SUMFV1B_USD, 0) + NVL(SALDO_NC, 0);
              SUMFQC1B_USD := NVL(SUMFQC1B_USD, 0) + NVL(SALDO_EQC, 0);
            end if;
            SUMAI1B_USD := NVL(SUMAI1B_USD, 0) + NVL(SALDO_NI, 0);
            SUMQI1B_USD := NVL(SUMQI1B_USD, 0) + NVL(SALDO_EQI, 0);
            SUMQP1B_USD := NVL(SUMQP1B_USD, 0) + NVL(SALDO_EQP, 0);
            SUMAP1B_USD := NVL(SUMAP1B_USD, 0) + NVL(SALDO_PRV, 0);
            SUMAL1B_USD := NVL(SUMAL1B_USD, 0) + NVL(SALDO_VAL, 0);
            SUMQL1B_USD := NVL(SUMQL1B_USD, 0) + NVL(SALDO_EQL, 0);
          END IF;
        ELSIF CA.CAT_RIESGO = '3' THEN
          IF CA.MONEDA = v_cod_mon_local THEN
            if ca.cod_sec_contable = 'N' and ca.estado in ('V', 'G') then
              SUMAV1C := NVL(SUMAV1C, 0) + NVL(CA.SALDO, 0);
            elsif ca.cod_sec_contable = 'N' and ca.estado = 'M' then
              --- Va en la 16030, solo capital
              SUMMV1C := NVL(SUMMV1C, 0) + NVL(CA.SALDO, 0);
            else
              --- Sector Financiero -- Va en la 16050, solo capital
              SUMFV1C := NVL(SUMFV1C, 0) + NVL(CA.SALDO, 0);
            end if;
            if ca.cod_sec_contable = 'N' and ca.estado = 'M' then
              --- ICL 05/09/07 porque deja en negativo la prevision
              SUMAI1D := NVL(SUMAI1D, 0) + NVL(CA.INTERES, 0);
              SUMAP1D := NVL(SUMAP1D, 0) + NVL(CA.PREVISION, 0);
              SUMAL1D := NVL(SUMAL1D, 0) + NVL(CA.VALUACION, 0);
            else
              SUMAI1C := NVL(SUMAI1C, 0) + NVL(CA.INTERES, 0);
              SUMAP1C := NVL(SUMAP1C, 0) + NVL(CA.PREVISION, 0);
              SUMAL1C := NVL(SUMAL1C, 0) + NVL(CA.VALUACION, 0);
            end if;
          ELSE
            if ca.cod_sec_contable = 'N' and ca.estado in ('V', 'G') then
              SUMAV1C_USD := NVL(SUMAV1C_USD, 0) + NVL(SALDO_NC, 0);
              SUMQC1C_USD := NVL(SUMQC1C_USD, 0) + NVL(SALDO_EQC, 0);
            elsif ca.cod_sec_contable = 'N' and ca.estado = 'M' then
              --- Va en la 16030
              SUMMV1C_USD  := NVL(SUMMV1C_USD, 0) + NVL(SALDO_NC, 0);
              SUMMQC1C_USD := NVL(SUMMQC1C_USD, 0) + NVL(SALDO_EQC, 0);
            else
              --- Sector Financiero -- Va en la 16050
              SUMFV1C_USD  := NVL(SUMFV1C_USD, 0) + NVL(SALDO_NC, 0);
              SUMFQC1C_USD := NVL(SUMFQC1C_USD, 0) + NVL(SALDO_EQC, 0);
            end if;
            if ca.cod_sec_contable = 'N' and ca.estado = 'M' then
              --- ICL 05/09/07 porque deja en negativo la prevision
              SUMAI1D_USD := NVL(SUMAI1D_USD, 0) + NVL(SALDO_NI, 0);
              SUMQI1D_USD := NVL(SUMQI1D_USD, 0) + NVL(SALDO_EQI, 0);
              SUMAP1D_USD := NVL(SUMAP1D_USD, 0) + NVL(SALDO_PRV, 0);
              SUMQP1D_USD := NVL(SUMQP1D_USD, 0) + NVL(SALDO_EQP, 0);
              SUMAL1D_USD := NVL(SUMAL1D_USD, 0) + NVL(SALDO_VAL, 0);
              SUMQL1D_USD := NVL(SUMQL1D_USD, 0) + NVL(SALDO_EQL, 0);
            else
              SUMAI1C_USD := NVL(SUMAI1C_USD, 0) + NVL(SALDO_NI, 0);
              SUMQI1C_USD := NVL(SUMQI1C_USD, 0) + NVL(SALDO_EQI, 0);
              SUMAP1C_USD := NVL(SUMAP1C_USD, 0) + NVL(SALDO_PRV, 0);
              SUMQP1C_USD := NVL(SUMQP1C_USD, 0) + NVL(SALDO_EQP, 0);
              SUMAL1C_USD := NVL(SUMAL1C_USD, 0) + NVL(SALDO_VAL, 0);
              SUMQL1C_USD := NVL(SUMQL1C_USD, 0) + NVL(SALDO_EQL, 0);
            end if;
          END IF;
        ELSIF CA.CAT_RIESGO = '4' THEN
          IF CA.MONEDA = v_cod_mon_local THEN
            if ca.cod_sec_contable = 'N' and ca.estado in ('V', 'G') then
              SUMAV1D := NVL(SUMAV1D, 0) + NVL(CA.SALDO, 0);
            elsif ca.cod_sec_contable = 'N' and ca.estado = 'M' then
              --- Va en la 16030, solo capital
              SUMMV1D := NVL(SUMMV1D, 0) + NVL(CA.SALDO, 0);
            else
              --- Sector Financiero -- Va en la 16050, solo capital
              SUMFV1D := NVL(SUMFV1D, 0) + NVL(CA.SALDO, 0);
            end if;
            SUMAI1D := NVL(SUMAI1D, 0) + NVL(CA.INTERES, 0);
            SUMAP1D := NVL(SUMAP1D, 0) + NVL(CA.PREVISION, 0);
            SUMAL1D := NVL(SUMAL1D, 0) + NVL(CA.VALUACION, 0);
          ELSE
            if ca.cod_sec_contable = 'N' and ca.estado in ('V', 'G') then
              SUMAV1D_USD := NVL(SUMAV1D_USD, 0) + NVL(SALDO_NC, 0);
              SUMQC1D_USD := NVL(SUMQC1D_USD, 0) + NVL(SALDO_EQC, 0);
            elsif ca.cod_sec_contable = 'N' and ca.estado = 'M' then
              --- Va en la 16030
              SUMMV1D_USD  := NVL(SUMMV1D_USD, 0) + NVL(SALDO_NC, 0);
              SUMMQC1D_USD := NVL(SUMMQC1D_USD, 0) + NVL(SALDO_EQC, 0);
            else
              --- Sector Financiero -- Va en la 16050
              SUMFV1D_USD  := NVL(SUMFV1D_USD, 0) + NVL(SALDO_NC, 0);
              SUMFQC1D_USD := NVL(SUMFQC1D_USD, 0) + NVL(SALDO_EQC, 0);
            end if;
            SUMAI1D_USD := NVL(SUMAI1D_USD, 0) + NVL(SALDO_NI, 0);
            SUMQI1D_USD := NVL(SUMQI1D_USD, 0) + NVL(SALDO_EQI, 0);
            SUMAP1D_USD := NVL(SUMAP1D_USD, 0) + NVL(SALDO_PRV, 0);
            SUMQP1D_USD := NVL(SUMQP1D_USD, 0) + NVL(SALDO_EQP, 0);
            SUMAL1D_USD := NVL(SUMAL1D_USD, 0) + NVL(SALDO_VAL, 0);
            SUMQL1D_USD := NVL(SUMQL1D_USD, 0) + NVL(SALDO_EQL, 0);
          END IF;
        ELSIF CA.CAT_RIESGO = '5' THEN
          IF CA.MONEDA = v_cod_mon_local THEN
            if ca.cod_sec_contable = 'N' and ca.estado in ('V', 'G') then
              SUMAV1E := NVL(SUMAV1E, 0) + NVL(CA.SALDO, 0);
            elsif ca.cod_sec_contable = 'N' and ca.estado = 'M' then
              --- Va en la 16030, solo capital
              SUMMV1E := NVL(SUMMV1E, 0) + NVL(CA.SALDO, 0);
            else
              --- Sector Financiero -- Va en la 16050, solo capital
              SUMFV1E := NVL(SUMFV1E, 0) + NVL(CA.SALDO, 0);
            end if;
            SUMAI1E := NVL(SUMAI1E, 0) + NVL(CA.INTERES, 0);
            SUMAP1E := NVL(SUMAP1E, 0) + NVL(CA.PREVISION, 0);
            SUMAL1E := NVL(SUMAL1E, 0) + NVL(CA.VALUACION, 0);
          ELSE
            if ca.cod_sec_contable = 'N' and ca.estado in ('V', 'G') then
              SUMAV1E_USD := NVL(SUMAV1E_USD, 0) + NVL(SALDO_NC, 0);
              SUMQC1E_USD := NVL(SUMQC1E_USD, 0) + NVL(SALDO_EQC, 0);
            elsif ca.cod_sec_contable = 'N' and ca.estado = 'M' then
              --- Va en la 16030
              SUMMV1E_USD  := NVL(SUMMV1E_USD, 0) + NVL(SALDO_NC, 0);
              SUMMQC1E_USD := NVL(SUMMQC1E_USD, 0) + NVL(SALDO_EQC, 0);
            else
              --- Sector Financiero -- Va en la 16050
              SUMFV1E_USD  := NVL(SUMFV1E_USD, 0) + NVL(SALDO_NC, 0);
              SUMFQC1E_USD := NVL(SUMFQC1E_USD, 0) + NVL(SALDO_EQC, 0);
            end if;
            SUMAI1E_USD := NVL(SUMAI1E_USD, 0) + NVL(SALDO_NI, 0);
            SUMQI1E_USD := NVL(SUMQI1E_USD, 0) + NVL(SALDO_EQI, 0);
            SUMAP1E_USD := NVL(SUMAP1E_USD, 0) + NVL(SALDO_PRV, 0);
            SUMQP1E_USD := NVL(SUMQP1E_USD, 0) + NVL(SALDO_EQP, 0);
            SUMAL1E_USD := NVL(SUMAL1E_USD, 0) + NVL(SALDO_VAL, 0);
            SUMQL1E_USD := NVL(SUMQL1E_USD, 0) + NVL(SALDO_EQL, 0);
          END IF;
        ELSE
          IF CA.MONEDA = v_cod_mon_local THEN
            if ca.cod_sec_contable = 'N' and ca.estado in ('V', 'G') then
              SUMAV1F := NVL(SUMAV1F, 0) + NVL(CA.SALDO, 0);
            elsif ca.cod_sec_contable = 'N' and ca.estado = 'M' then
              --- Va en la 16030, solo capital
              SUMMV1F := NVL(SUMMV1F, 0) + NVL(CA.SALDO, 0);
            else
              --- Sector Financiero -- Va en la 16050, solo capital
              SUMFV1F := NVL(SUMFV1F, 0) + NVL(CA.SALDO, 0);
            end if;
            SUMAI1F := NVL(SUMAI1F, 0) + NVL(CA.INTERES, 0);
            SUMAP1F := NVL(SUMAP1F, 0) + NVL(CA.PREVISION, 0);
            SUMAL1F := NVL(SUMAL1F, 0) + NVL(CA.VALUACION, 0);
          ELSE
            if ca.cod_sec_contable = 'N' and ca.estado in ('V', 'G') then
              SUMAV1F_USD := NVL(SUMAV1F_USD, 0) + NVL(SALDO_NC, 0);
              SUMQC1F_USD := NVL(SUMQC1F_USD, 0) + NVL(SALDO_EQC, 0);
            elsif ca.cod_sec_contable = 'N' and ca.estado = 'M' then
              --- Va en la 16030
              SUMMV1F_USD  := NVL(SUMMV1F_USD, 0) + NVL(SALDO_NC, 0);
              SUMMQC1F_USD := NVL(SUMMQC1F_USD, 0) + NVL(SALDO_EQC, 0);
            else
              --- Sector Financiero -- Va en la 16050
              SUMFV1F_USD  := NVL(SUMFV1F_USD, 0) + NVL(SALDO_NC, 0);
              SUMFQC1F_USD := NVL(SUMFQC1F_USD, 0) + NVL(SALDO_EQC, 0);
            end if;
            SUMAI1F_USD := NVL(SUMAI1F_USD, 0) + NVL(SALDO_NI, 0);
            SUMQI1F_USD := NVL(SUMQI1F_USD, 0) + NVL(SALDO_EQI, 0);
            SUMAP1F_USD := NVL(SUMAP1F_USD, 0) + NVL(SALDO_PRV, 0);
            SUMQP1F_USD := NVL(SUMQP1F_USD, 0) + NVL(SALDO_EQP, 0);
            SUMAL1F_USD := NVL(SUMAL1F_USD, 0) + NVL(SALDO_VAL, 0);
            SUMQL1F_USD := NVL(SUMQL1F_USD, 0) + NVL(SALDO_EQL, 0);
          END IF;
        END IF;
      ELSE
        --14010       -- CARTERA --VIGENTE,
        IF CA.CAT_RIESGO = '1' THEN
          IF CA.MONEDA = v_cod_mon_local THEN
            SUMACAA := NVL(SUMACAA, 0) + NVL(CA.SALDO, 0);
            SUMAIAA := NVL(SUMAIAA, 0) + NVL(CA.INTERES, 0);
            SUMAPAA := NVL(SUMAPAA, 0) + NVL(CA.PREVISION, 0);
            SUMALAA := NVL(SUMALAA, 0) + NVL(CA.VALUACION, 0);
          ELSE
            SUMACAA_USD := NVL(SUMACAA_USD, 0) + NVL(SALDO_NC, 0);
            SUMAIAA_USD := NVL(SUMAIAA_USD, 0) + NVL(SALDO_NI, 0);
            SUMQCAA_USD := NVL(SUMQCAA_USD, 0) + NVL(SALDO_EQC, 0);
            SUMQIAA_USD := NVL(SUMQIAA_USD, 0) + NVL(SALDO_EQI, 0);
            SUMAPAA_USD := NVL(SUMAPAA_USD, 0) + NVL(SALDO_PRV, 0);
            SUMQPAA_USD := NVL(SUMQPAA_USD, 0) + NVL(SALDO_EQP, 0);
            SUMALAA_USD := NVL(SUMALAA_USD, 0) + NVL(SALDO_VAL, 0);
            SUMQLAA_USD := NVL(SUMQLAA_USD, 0) + NVL(SALDO_EQL, 0);
          END IF;
        ELSIF CA.CAT_RIESGO = '2' THEN
          IF CA.MONEDA = v_cod_mon_local THEN
            SUMACAB := NVL(SUMACAB, 0) + NVL(CA.SALDO, 0);
            SUMAIAB := NVL(SUMAIAB, 0) + NVL(CA.INTERES, 0);
            SUMAPAB := NVL(SUMAPAB, 0) + NVL(CA.PREVISION, 0);
            SUMALAB := NVL(SUMALAB, 0) + NVL(CA.VALUACION, 0);
          ELSE
            SUMACAB_USD := NVL(SUMACAB_USD, 0) + NVL(SALDO_NC, 0);
            SUMAIAB_USD := NVL(SUMAIAB_USD, 0) + NVL(SALDO_NI, 0);
            SUMQCAB_USD := NVL(SUMQCAB_USD, 0) + NVL(SALDO_EQC, 0);
            SUMQIAB_USD := NVL(SUMQIAB_USD, 0) + NVL(SALDO_EQI, 0);
            SUMAPAB_USD := NVL(SUMAPAB_USD, 0) + NVL(SALDO_PRV, 0);
            SUMQPAB_USD := NVL(SUMQPAB_USD, 0) + NVL(SALDO_EQP, 0);
            SUMALAB_USD := NVL(SUMALAB_USD, 0) + NVL(SALDO_VAL, 0);
            SUMQLAB_USD := NVL(SUMQLAB_USD, 0) + NVL(SALDO_EQL, 0);
          END IF;
        ELSIF CA.CAT_RIESGO = '3' THEN
          IF CA.MONEDA = v_cod_mon_local THEN
            SUMACAC := NVL(SUMACAC, 0) + NVL(CA.SALDO, 0);
            SUMAIAC := NVL(SUMAIAC, 0) + NVL(CA.INTERES, 0);
            SUMAPAC := NVL(SUMAPAC, 0) + NVL(CA.PREVISION, 0);
            SUMALAC := NVL(SUMALAC, 0) + NVL(CA.VALUACION, 0);
          ELSE
            SUMACAC_USD := NVL(SUMACAC_USD, 0) + NVL(SALDO_NC, 0);
            SUMAIAC_USD := NVL(SUMAIAC_USD, 0) + NVL(SALDO_NI, 0);
            SUMQCAC_USD := NVL(SUMQCAC_USD, 0) + NVL(SALDO_EQC, 0);
            SUMQIAC_USD := NVL(SUMQIAC_USD, 0) + NVL(SALDO_EQI, 0);
            SUMAPAC_USD := NVL(SUMAPAC_USD, 0) + NVL(SALDO_PRV, 0);
            SUMQPAC_USD := NVL(SUMQPAC_USD, 0) + NVL(SALDO_EQP, 0);
            SUMALAC_USD := NVL(SUMALAC_USD, 0) + NVL(SALDO_VAL, 0);
            SUMQLAC_USD := NVL(SUMQLAC_USD, 0) + NVL(SALDO_EQL, 0);
          END IF;
        ELSIF CA.CAT_RIESGO = '4' THEN
          IF CA.MONEDA = v_cod_mon_local THEN
            SUMACAD := NVL(SUMACAD, 0) + NVL(CA.SALDO, 0);
            SUMAIAD := NVL(SUMAIAD, 0) + NVL(CA.INTERES, 0);
            SUMAPAD := NVL(SUMAPAD, 0) + NVL(CA.PREVISION, 0);
            SUMALAD := NVL(SUMALAD, 0) + NVL(CA.VALUACION, 0);
          ELSE
            SUMACAD_USD := NVL(SUMACAD_USD, 0) + NVL(SALDO_NC, 0);
            SUMAIAD_USD := NVL(SUMAIAD_USD, 0) + NVL(SALDO_NI, 0);
            SUMQCAD_USD := NVL(SUMQCAD_USD, 0) + NVL(SALDO_EQC, 0);
            SUMQIAD_USD := NVL(SUMQIAD_USD, 0) + NVL(SALDO_EQI, 0);
            SUMAPAD_USD := NVL(SUMAPAD_USD, 0) + NVL(SALDO_PRV, 0);
            SUMQPAD_USD := NVL(SUMQPAD_USD, 0) + NVL(SALDO_EQP, 0);
            SUMALAD_USD := NVL(SUMALAD_USD, 0) + NVL(SALDO_VAL, 0);
            SUMQLAD_USD := NVL(SUMQLAD_USD, 0) + NVL(SALDO_EQL, 0);
          END IF;
        ELSIF CA.CAT_RIESGO = '5' THEN
          IF CA.MONEDA = v_cod_mon_local THEN
            SUMACAE := NVL(SUMACAE, 0) + NVL(CA.SALDO, 0);
            SUMAIAE := NVL(SUMAIAE, 0) + NVL(CA.INTERES, 0);
            SUMAPAE := NVL(SUMAPAE, 0) + NVL(CA.PREVISION, 0);
            SUMALAE := NVL(SUMALAE, 0) + NVL(CA.VALUACION, 0);
          ELSE
            SUMACAE_USD := NVL(SUMACAE_USD, 0) + NVL(SALDO_NC, 0);
            SUMAIAE_USD := NVL(SUMAIAE_USD, 0) + NVL(SALDO_NI, 0);
            SUMQCAE_USD := NVL(SUMQCAE_USD, 0) + NVL(SALDO_EQC, 0);
            SUMQIAE_USD := NVL(SUMQIAE_USD, 0) + NVL(SALDO_EQI, 0);
            SUMAPAE_USD := NVL(SUMAPAE_USD, 0) + NVL(SALDO_PRV, 0);
            SUMQPAE_USD := NVL(SUMQPAE_USD, 0) + NVL(SALDO_EQP, 0);
            SUMALAE_USD := NVL(SUMALAE_USD, 0) + NVL(SALDO_VAL, 0);
            SUMQLAE_USD := NVL(SUMQLAE_USD, 0) + NVL(SALDO_EQL, 0);
          END IF;
        ELSE
          IF CA.MONEDA = v_cod_mon_local THEN
            SUMACAF := NVL(SUMACAF, 0) + NVL(CA.SALDO, 0);
            SUMAIAF := NVL(SUMAIAF, 0) + NVL(CA.INTERES, 0);
            SUMAPAF := NVL(SUMAPAF, 0) + NVL(CA.PREVISION, 0);
            SUMALAF := NVL(SUMALAF, 0) + NVL(CA.VALUACION, 0);
          ELSE
            SUMACAF_USD := NVL(SUMACAF_USD, 0) + NVL(SALDO_NC, 0);
            SUMAIAF_USD := NVL(SUMAIAF_USD, 0) + NVL(SALDO_NI, 0);
            SUMQCAF_USD := NVL(SUMQCAF_USD, 0) + NVL(SALDO_EQC, 0);
            SUMQIAF_USD := NVL(SUMQIAF_USD, 0) + NVL(SALDO_EQI, 0);
            SUMAPAF_USD := NVL(SUMAPAF_USD, 0) + NVL(SALDO_PRV, 0);
            SUMQPAF_USD := NVL(SUMQPAF_USD, 0) + NVL(SALDO_EQP, 0);
            SUMALAF_USD := NVL(SUMALAF_USD, 0) + NVL(SALDO_VAL, 0);
            SUMQLAF_USD := NVL(SUMQLAF_USD, 0) + NVL(SALDO_EQL, 0);
          END IF;
        END IF;
      END IF;
    END LOOP;

    --\* LEO EL CURSOR PARA LOS REGISTROS DE CTA.CTE. (SOBREG.
    FOR CC IN CTACTE LOOP
      SALDO_NC  := 0;
      SALDO_NI  := 0;
      SALDO_EQC := 0;
      SALDO_EQI := 0;
      IF CC.MONEDA = v_cod_mon_fuerte THEN
        SALDO_NC := NVL(CC.SALDO, 0);
      ELSE
        IF CC.MONEDA <> v_cod_mon_local THEN
          --LEE_COTIZACION(CC.MONEDA,COTIZ);
          SALDO_NC := pag_gen.fu_con_mon_a_moneda(cc.moneda,
                                                  v_cod_mon_fuerte,
                                                  NVL(CC.SALDO, 0)); -- * COTIZ/:SCR_COTIZ_USD;
        END IF;
      END IF;
      IF CC.MONEDA <> v_cod_mon_local THEN
        SALDO_EQC := round(pag_gen.fu_con_mon_a_moneda(cc.moneda,
                                                       v_cod_mon_local,
                                                       SALDO_NC)); -- * :SCR_COTIZ_USD;
      END IF;
      -- Ver si cta.cte.se categorizara por cliente
      -- por el momento se suma como capital a cartera vig.
      --SELECT GREATEST(CAT_RIESGO, GC_RESULTA)
      --INTO CATEGORIA
      --FROM GE_CLIENTES
      --WHERE GC_CDCLIEN = CC.CLIENTE AND ROWNUM = 1;
      -- Cta.Cte. se suma todo a Cartera Vigente
      IF CC.MONEDA = v_cod_mon_local THEN
        SUMACAA := NVL(SUMACAA, 0) + NVL(CC.SALDO, 0);
      ELSE
        SUMACAA_USD := NVL(SUMACAA_USD, 0) + NVL(SALDO_NC, 0);
        SUMQCAA_USD := NVL(SUMQCAA_USD, 0) + NVL(SALDO_EQC, 0);
      END IF;
    END LOOP;

    --\* LEO EL CURSOR PARA LOS REGISTROS DE COM.EXTERIOR
    FOR CE IN COMERCIO LOOP
      SALDO_NC  := 0;
      SALDO_NI  := 0;
      SALDO_EQC := 0;
      SALDO_EQI := 0;
      IF CE.MONEDA = v_cod_mon_fuerte THEN
        SALDO_NC := NVL(CE.SALDO, 0);
      ELSE
        IF CE.MONEDA <> v_cod_mon_local THEN
          --LEE_COTIZACION(CE.MONEDA,COTIZ);
          SALDO_NC := pag_gen.fu_con_mon_a_moneda(ce.moneda,
                                                  v_cod_mon_fuerte,
                                                  NVL(CE.SALDO, 0)); -- * COTIZ/:SCR_COTIZ_USD;
        END IF;
      END IF;
      IF CE.MONEDA <> v_cod_mon_local THEN
        SALDO_EQC := round(pag_gen.fu_con_mon_a_moneda(ce.moneda,
                                                       v_cod_mon_local,
                                                       SALDO_NC)); -- * :SCR_COTIZ_USD;
      END IF;
      -- Ver si comercio   categorizara por cliente
      -- por el momento se suma como capital a cartera vig.
      -- Comercio se suma todo a Cartera Vigente
      IF CE.MONEDA = v_cod_mon_local THEN
        SUMACAA := NVL(SUMACAA, 0) + NVL(CE.SALDO, 0);
      ELSE
        SUMACAA_USD := NVL(SUMACAA_USD, 0) + NVL(SALDO_NC, 0);
        SUMQCAA_USD := NVL(SUMQCAA_USD, 0) + NVL(SALDO_EQC, 0);
      END IF;
    END LOOP;

    --\* INSERTO EL REGISTRO DE CRED.VIGENTES 140100000000 '1'
    --no insertar monto cero
    if nvl(SUMACAA, 0) > 0 or nvl(SUMACAA_USD, 0) > 0 or
       nvl(SUMQCAA_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14011000000',
                        SUMACAA,
                        SUMACAA_USD,
                        SUMQCAA_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES 140800000000 '1'
    if nvl(SUMAIAA, 0) > 0 or nvl(SUMAIAA_USD, 0) > 0 or
       nvl(SUMQIAA_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14081000000',
                        SUMAIAA,
                        SUMAIAA_USD,
                        SUMQIAA_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES PREVISION 140900000000 '1'
    if nvl(SUMAPAA, 0) > 0 or nvl(SUMAPAA_USD, 0) > 0 or
       nvl(SUMQPAA_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14091000000',
                        SUMAPAA,
                        SUMAPAA_USD,
                        SUMQPAA_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES VALUACION 140700000000 '1'
    if nvl(SUMALAA, 0) > 0 or nvl(SUMALAA_USD, 0) > 0 or
       nvl(SUMQLAA_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14071000000',
                        SUMALAA,
                        0,
                        SUMQLAA_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES 140100000000 '2'
    if nvl(SUMACAB, 0) > 0 or nvl(SUMACAB, 0) > 0 or
       nvl(SUMQCAB_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14012000000',
                        SUMACAB,
                        SUMACAB_USD,
                        SUMQCAB_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES 140800000000 '2'
    if nvl(SUMAIAB, 0) > 0 or nvl(SUMAIAB_USD, 0) > 0 or
       nvl(SUMQIAB_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14082000000',
                        SUMAIAB,
                        SUMAIAB_USD,
                        SUMQIAB_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES PREVISION 140900000000 '2'
    if nvl(SUMAPAB, 0) > 0 or nvl(SUMAPAB_USD, 0) > 0 or
       nvl(SUMQPAB_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14092000000',
                        SUMAPAB,
                        SUMAPAB_USD,
                        SUMQPAB_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES VALUACION 140700000000 '2'
    if nvl(SUMALAB, 0) > 0 or nvl(SUMALAB_USD, 0) > 0 or
       nvl(SUMQLAB_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14072000000',
                        SUMALAB,
                        0,
                        SUMQLAB_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES 140100000000 '3'
    if nvl(SUMACAC, 0) > 0 or nvl(SUMACAC_USD, 0) > 0 or
       nvl(SUMQCAC_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14013000000',
                        SUMACAC,
                        SUMACAC_USD,
                        SUMQCAC_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES 140800000000 '3'
    if nvl(SUMAIAC, 0) > 0 or nvl(SUMAIAC_USD, 0) > 0 or
       nvl(SUMQIAC_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14083000000',
                        SUMAIAC,
                        SUMAIAC_USD,
                        SUMQIAC_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES PREVISION 140900000000 '3'
    if nvl(SUMAPAC, 0) > 0 or nvl(SUMAPAC_USD, 0) > 0 or
       nvl(SUMQPAC_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14093000000',
                        SUMAPAC,
                        SUMAPAC_USD,
                        SUMQPAC_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES VALUACION 140700000000 '3'
    if nvl(SUMALAC, 0) > 0 or nvl(SUMALAC_USD, 0) > 0 or
       nvl(SUMQLAC_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14073000000',
                        SUMALAC,
                        0,
                        SUMQLAC_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES 140100000000 '4'
    if nvl(SUMACAD, 0) > 0 or nvl(SUMACAD_USD, 0) > 0 or
       nvl(SUMQCAD_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14014000000',
                        SUMACAD,
                        SUMACAD_USD,
                        SUMQCAD_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES 140800000000 '4'
    if nvl(SUMAIAD, 0) > 0 or nvl(SUMAIAD_USD, 0) > 0 or
       nvl(SUMQIAD_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14084000000',
                        SUMAIAD,
                        SUMAIAD_USD,
                        SUMQIAD_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES PREVISION 140900000000 '4'
    if nvl(SUMAPAD, 0) > 0 or nvl(SUMAPAD_USD, 0) > 0 or
       nvl(SUMQPAD_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14094000000',
                        SUMAPAD,
                        SUMAPAD_USD,
                        SUMQPAD_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES VALUACION 140700000000 '4'
    if nvl(SUMALAD, 0) > 0 or nvl(SUMALAD_USD, 0) > 0 or
       nvl(SUMQLAD_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14074000000',
                        SUMALAD,
                        0,
                        SUMQLAD_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES 140100000000 '5'
    if nvl(SUMACAE, 0) > 0 or nvl(SUMACAE_USD, 0) > 0 or
       nvl(SUMQCAE_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14015000000',
                        SUMACAE,
                        SUMACAE_USD,
                        SUMQCAE_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES 140800000000 '5'
    if nvl(SUMAIAE, 0) > 0 or nvl(SUMAIAE_USD, 0) > 0 or
       nvl(SUMQIAE_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14085000000',
                        SUMAIAE,
                        SUMAIAE_USD,
                        SUMQIAE_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES PREVISION 140900000000 '5'
    if nvl(SUMAPAE, 0) > 0 or nvl(SUMAPAE_USD, 0) > 0 or
       nvl(SUMQPAE_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14095000000',
                        SUMAPAE,
                        SUMAPAE_USD,
                        SUMQPAE_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES VALUACION 140700000000 '5'
    if nvl(SUMALAE, 0) > 0 or nvl(SUMALAE_USD, 0) > 0 or
       nvl(SUMQLAE_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14075000000',
                        SUMALAE,
                        0,
                        SUMQLAE_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES 140100000000 '6'
    if nvl(SUMACAF, 0) > 0 or nvl(SUMACAF_USD, 0) > 0 or
       nvl(SUMQCAF_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14016000000',
                        SUMACAF,
                        SUMACAF_USD,
                        SUMQCAF_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES 140800000000 '6'
    if nvl(SUMAIAF, 0) > 0 or nvl(SUMAIAF_USD, 0) > 0 or
       nvl(SUMQIAF_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14086000000',
                        SUMAIAF,
                        SUMAIAF_USD,
                        SUMQIAF_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES PREVISION 140900000000 '6'
    if nvl(SUMAPAF, 0) > 0 or nvl(SUMAPAF_USD, 0) > 0 or
       nvl(SUMQPAF_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14096000000',
                        SUMAPAF,
                        SUMAPAF_USD,
                        SUMQPAF_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VIGENTES VALUACION 140700000000 '6'
    if nvl(SUMALAF, 0) > 0 or nvl(SUMALAF_USD, 0) > 0 or
       nvl(SUMQLAF_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '14076000000',
                        SUMALAF,
                        0,
                        SUMQLAF_USD);
    end if;

    -------------------------------------------------------------------------
    /*  AJUSTES INICIALES DE DEFINICION
     1) NO PUEDE HABER 16011 SE PASA 16012, NO PUEDE HABER 16031,16032,16033 SE PASA A 16034
     2) NO PUEDE HABER 16081 SE PASA 16082, NO PUEDE HABER 16091 SE PASA A 16092
     3) NO PUEDE HABER 16071 SE PASA 16072.
    */
    -------------------------------------------------------------------------
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160100000000 '1' -- Sector N, Estado: Vencido, Gestion
    if nvl(SUMAV1A, 0) > 0 or nvl(SUMAV1A_USD, 0) > 0 or
       nvl(SUMQC1A_USD, 0) > 0 then
      ---16011000000 a 16012 (se suma en la otra)
      --v_nro_registro := nvl(v_nro_registro,0) + 1;
      --lp_ins_sb_riesgos(v_fecha, v_nro_registro, '16011000000',
      --                  SUMAV1A, SUMAV1A_USD, SUMQC1A_USD);
      null;
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160300000000 '1' -- Sector N, Estados: Moroso
    if nvl(SUMMV1A, 0) > 0 or nvl(SUMMV1A_USD, 0) > 0 or
       nvl(SUMMQC1A_USD, 0) > 0 then
      --      v_nro_registro := nvl(v_nro_registro,0) + 1;
      --      lp_ins_sb_riesgos(v_fecha, v_nro_registro, '16031000000',
      --                        SUMMV1A, SUMMV1A_USD, SUMMQC1A_USD);
      null; --suma en 16034
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160500000000 '1' -- Sector F
    if nvl(SUMFV1A, 0) > 0 or nvl(SUMFV1A_USD, 0) > 0 or
       nvl(SUMFQC1A_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16051000000',
                        SUMFV1A,
                        SUMFV1A_USD,
                        SUMFQC1A_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160800000000 '1'
    if nvl(SUMAI1A, 0) > 0 or nvl(SUMAI1A_USD, 0) > 0 or
       nvl(SUMQI1A_USD, 0) > 0 then
      --      v_nro_registro := nvl(v_nro_registro,0) + 1;
      --      lp_ins_sb_riesgos(v_fecha, v_nro_registro, '16081000000',
      --                        SUMAI1A, SUMAI1A_USD, SUMQI1A_USD);
      null; --suma en la 16082
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS PREVISION 160900000000 '1'
    if nvl(SUMAP1A, 0) > 0 or nvl(SUMAP1A_USD, 0) > 0 or
       nvl(SUMQP1A_USD, 0) > 0 then
      --      v_nro_registro := nvl(v_nro_registro,0) + 1;
      --      lp_ins_sb_riesgos(v_fecha, v_nro_registro, '16091000000',
      --                        SUMAP1A, SUMAP1A_USD, SUMQP1A_USD);
      null; --- suma en 16092
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS VALUACION 160700000000 '1'
    if nvl(SUMAL1A, 0) > 0 or nvl(SUMAL1A_USD, 0) > 0 or
       nvl(SUMQL1A_USD, 0) > 0 then
      --      v_nro_registro := nvl(v_nro_registro,0) + 1;
      --      lp_ins_sb_riesgos(v_fecha, v_nro_registro, '16071000000',
      --                        SUMAL1A, 0, SUMQL1A_USD);
      null; --- suma en 16072
    end if;
    if nvl(SUMAV1B, 0) > 0 or nvl(SUMAV1B_USD, 0) > 0 or
       nvl(SUMQC1B_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16012000000',
                        SUMAV1A + SUMAV1B,
                        SUMAV1A_USD + SUMAV1B_USD,
                        SUMQC1A_USD + SUMQC1B_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160300000000 '2' -- Sector N, Estados: Moroso
    if nvl(SUMMV1B, 0) > 0 or nvl(SUMMV1B_USD, 0) > 0 or
       nvl(SUMMQC1B_USD, 0) > 0 then
      --      v_nro_registro := nvl(v_nro_registro,0) + 1;
      --      lp_ins_sb_riesgos(v_fecha, v_nro_registro, '16032000000',
      --                        SUMMV1B, SUMMV1B_USD, SUMMQC1B_USD);
      null; --- pasa a 16034
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160500000000 '2' -- Sector F
    if nvl(SUMFV1B, 0) > 0 or nvl(SUMFV1B_USD, 0) > 0 or
       nvl(SUMFQC1B_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16052000000',
                        SUMFV1B,
                        SUMFV1B_USD,
                        SUMFQC1B_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160100000000 '2'
    if nvl(SUMAI1B, 0) > 0 or nvl(SUMAI1B_USD, 0) > 0 or
       nvl(SUMQI1B_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16082000000',
                        SUMAI1A + SUMAI1B,
                        SUMAI1A_USD + SUMAI1B_USD,
                        SUMQI1A_USD + SUMQI1B_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS PREVISION 160900000000 '2'
    if nvl(SUMAP1B, 0) > 0 or nvl(SUMAP1B_USD, 0) > 0 or
       nvl(SUMQP1B_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16092000000',
                        SUMAP1B + SUMAP1A,
                        SUMAP1B_USD + SUMAP1A_USD,
                        SUMQP1B_USD + SUMQP1A_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS VALUACION 160700000000 '2'
    if nvl(SUMAL1B, 0) > 0 or nvl(SUMAL1B_USD, 0) > 0 or
       nvl(SUMQL1B_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16072000000',
                        SUMAL1B + SUMAL1A,
                        0,
                        SUMQL1B_USD + SUMQL1A_USD); -- Incluye la 16071
    end if;

    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160100000000 '3'
    if nvl(SUMAV1C, 0) > 0 or nvl(SUMAV1C_USD, 0) > 0 or
       nvl(SUMQC1C_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16013000000',
                        SUMAV1C,
                        SUMAV1C_USD,
                        SUMQC1C_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160300000000 '3' -- Sector N, Estados: Moroso
    if nvl(SUMMV1C, 0) > 0 or nvl(SUMMV1C_USD, 0) > 0 or
       nvl(SUMMQC1C_USD, 0) > 0 then
      --      v_nro_registro := nvl(v_nro_registro,0) + 1;
      --      lp_ins_sb_riesgos(v_fecha, v_nro_registro, '16033000000',
      --                        SUMMV1C, SUMMV1C_USD, SUMMQC1C_USD);
      null; -- suma 16034
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160500000000 '3' -- Sector F
    if nvl(SUMFV1C, 0) > 0 or nvl(SUMFV1C_USD, 0) > 0 or
       nvl(SUMFQC1C_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16053000000',
                        SUMFV1C,
                        SUMFV1C_USD,
                        SUMFQC1C_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160800000000 '3'
    if nvl(SUMAI1C, 0) > 0 or nvl(SUMAI1C_USD, 0) > 0 or
       nvl(SUMQI1C_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16083000000',
                        SUMAI1C,
                        SUMAI1C_USD,
                        SUMQI1C_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS PREVISION 160900000000 '3'
    if nvl(SUMAP1C, 0) > 0 or nvl(SUMAP1C_USD, 0) > 0 or
       nvl(SUMQP1C_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16093000000',
                        SUMAP1C,
                        SUMAP1C_USD,
                        SUMQP1C_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS VALUACION 160700000000 '3'
    if nvl(SUMAL1C, 0) > 0 or nvl(SUMAL1C_USD, 0) > 0 or
       nvl(SUMQL1C_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16073000000',
                        SUMAL1C,
                        0,
                        SUMQL1C_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160100000000 '4'
    if nvl(SUMAV1D, 0) > 0 or nvl(SUMAV1D_USD, 0) > 0 or
       nvl(SUMQC1D_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16014000000',
                        SUMAV1D,
                        SUMAV1D_USD,
                        SUMQC1D_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160300000000 '4' -- Sector N, Estados: Moroso
    if nvl(SUMMV1D, 0) > 0 or nvl(SUMMV1D_USD, 0) > 0 or
       nvl(SUMMQC1D_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16034000000',
                        SUMMV1D + SUMMV1A + SUMMV1B + SUMMV1C,
                        SUMMV1D_USD + SUMMV1A_USD + SUMMV1B_USD +
                        SUMMV1C_USD,
                        SUMMQC1D_USD + SUMMQC1A_USD + SUMMQC1B_USD +
                        SUMMQC1C_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160500000000 '4' -- Sector F
    if nvl(SUMFV1D, 0) > 0 or nvl(SUMFV1D_USD, 0) > 0 or
       nvl(SUMFQC1D_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16054000000',
                        SUMFV1D,
                        SUMFV1D_USD,
                        SUMFQC1D_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160100000000 '4'
    if nvl(SUMAI1D, 0) > 0 or nvl(SUMAI1D_USD, 0) > 0 or
       nvl(SUMQI1D_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16084000000',
                        SUMAI1D,
                        SUMAI1D_USD,
                        SUMQI1D_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS PREVISION 160900000000 '4'
    if nvl(SUMAP1D, 0) > 0 or nvl(SUMAP1D_USD, 0) > 0 or
       nvl(SUMQP1D_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16094000000',
                        SUMAP1D,
                        SUMAP1D_USD,
                        SUMQP1D_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS VALUACION 160700000000 '4'
    if nvl(SUMAL1D, 0) > 0 or nvl(SUMAL1D_USD, 0) > 0 or
       nvl(SUMQL1D_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16074000000',
                        SUMAL1D,
                        0,
                        SUMQL1D_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160100000000 '5'
    if nvl(SUMAV1E, 0) > 0 or nvl(SUMAV1E_USD, 0) > 0 or
       nvl(SUMQC1E_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16015000000',
                        SUMAV1E,
                        SUMAV1E_USD,
                        SUMQC1E_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160300000000 '5' -- Sector N, Estados: Moroso
    if nvl(SUMMV1E, 0) > 0 or nvl(SUMMV1E_USD, 0) > 0 or
       nvl(SUMMQC1E_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16035000000',
                        SUMMV1E,
                        SUMMV1E_USD,
                        SUMMQC1E_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160500000000 '5' -- Sector F
    if nvl(SUMFV1E, 0) > 0 or nvl(SUMFV1E_USD, 0) > 0 or
       nvl(SUMFQC1E_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16055000000',
                        SUMFV1E,
                        SUMFV1E_USD,
                        SUMFQC1E_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160100000000 '5'
    if nvl(SUMAI1E, 0) > 0 or nvl(SUMAI1E_USD, 0) > 0 or
       nvl(SUMQI1E_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16085000000',
                        SUMAI1E,
                        SUMAI1E_USD,
                        SUMQI1E_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS PREVISION 160900000000 '5'
    if nvl(SUMAP1E, 0) > 0 or nvl(SUMAP1E_USD, 0) > 0 or
       nvl(SUMQP1E_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16095000000',
                        SUMAP1E,
                        SUMAP1E_USD,
                        SUMQP1E_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS VALUACION 160700000000 '5'
    if nvl(SUMAL1E, 0) > 0 or nvl(SUMAL1E_USD, 0) > 0 or
       nvl(SUMQL1E_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16075000000',
                        SUMAL1E,
                        0,
                        SUMQL1E_USD);
    end if;

    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160100000000 '6'
    if nvl(SUMAV1F, 0) > 0 or nvl(SUMAV1F_USD, 0) > 0 or
       nvl(SUMQC1F_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16016000000',
                        SUMAV1F,
                        SUMAV1F_USD,
                        SUMQC1F_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160300000000 '6' -- Sector N, Estados: Moroso
    if nvl(SUMMV1F, 0) > 0 or nvl(SUMMV1F_USD, 0) > 0 or
       nvl(SUMMQC1F_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16036000000',
                        SUMMV1F,
                        SUMMV1F_USD,
                        SUMMQC1F_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160600000000 '6' -- Sector F
    if nvl(SUMFV1F, 0) > 0 or nvl(SUMFV1F_USD, 0) > 0 or
       nvl(SUMFQC1F_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16066000000',
                        SUMFV1F,
                        SUMFV1F_USD,
                        SUMFQC1F_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS 160100000000 '6'
    if nvl(SUMAI1F, 0) > 0 or nvl(SUMAI1F_USD, 0) > 0 or
       nvl(SUMQI1F_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16086000000',
                        SUMAI1F,
                        SUMAI1F_USD,
                        SUMQI1F_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS PREVISION 160900000000 '6'
    if nvl(SUMAP1F, 0) > 0 or nvl(SUMAP1F_USD, 0) > 0 or
       nvl(SUMQP1F_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16096000000',
                        SUMAP1F,
                        SUMAP1F_USD,
                        SUMQP1F_USD);
    end if;
    --\* INSERTO EL REGISTRO DE CRED.VENCIDOS VALUACION 160700000000 '6'
    if nvl(SUMAL1F, 0) > 0 or nvl(SUMAL1F_USD, 0) > 0 or
       nvl(SUMQL1F_USD, 0) > 0 then
      v_nro_registro := nvl(v_nro_registro, 0) + 1;
      lp_ins_sb_riesgos(v_fecha,
                        v_nro_registro,
                        '16076000000',
                        SUMAL1F,
                        0,
                        SUMQL1F_USD);
    end if;
    --- Incluir cuentas contables que no se encuentran en cartera
    LP_CTA_CONTABLES;
    --Incluir previsiones genericas
    LP_PRE_GENERICAS;
    -- Actualizar el importe equivalente de las cuentas.
    LP_ACT_SAL_EQUIVALENTES;

    -- ve la cantidad de registros del detalle --
    ---------------------------------------------------------------
    SELECT COUNT(*) INTO w_total_registros FROM sb_riesgos;
    -- inserta un registro --
    INSERT INTO sb_planinfo
      (NOM_ARCHIVO,
       FECHA,
       COD_ENTIDAD,
       TIP_ENTIDAD,
       CLA_ENTIDAD,
       NRO_REG_A,
       TOT_REG_DETALLE)
    VALUES
      ('RIESGO_TAS',
       v_fecha,
       v_COD_ENTIDAD,
       '04',
       '02',
       0,
       W_TOTAL_REGISTROS);

  END;

  /* Genera archivos ASCII a partir de tablas de planinfo */
  PROCEDURE PR_GEN_ASCII IS
    --- Variables del proceso
    v_cod_entidad varchar2(8); --ge_par_generales.cod_entidad%type;
    v_sql         varchar2(4000);
  BEGIN
    if v_fec_proceso is null then
      v_fec_proceso := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_actual, null);
    end if;

    --recupera entidad
    select cod_entidad --||'0402' --clase y tipo entidad
      into v_cod_entidad
      from ge_par_generales;

    -- estado de situacion, cabecera
    v_sql := 'SELECT ''ESTADO_SIT''||' ||
             TO_CHAR(v_fec_proceso, 'YYYYMMDD') || v_cod_entidad || '0205' --tipo y clase entidad
             || '0' || '|| LPAD(a.cantidad,6,0) ' ||
             ' from dual,(SELECT COUNT(*) cantidad FROM SB_BCP_sum WHERE substr(cod_rubro,1,1) in (''1'',''2'',''3'',''4'',''5'')) a ';

    prg_gen_archivo_txt('ES-' || v_cod_entidad || '.DAT', v_sql, 'N');

    -- estado de situacion, detalle
    v_sql := 'SELECT linea||lpad(rownum,6,''0'') ' ||
             ' from ( select ''010''||'
            --||' b.cod_rubro', replicar el plazo en la 9na posicion
             ||
             'substr(b.cod_rubro,1,8)||substr(b.cod_rubro,3,1)||substr(b.cod_rubro,10,2)' ||
             '||b.cla_moneda||lpad((round(abs(importe),2)*100),17,0) linea ' ||
             ' from sb_bcp_SUM b ' ||
             ' WHERE substr(b.cod_rubro,1,1) in (''1'',''2'',''3'',''4'',''5'') ' ||
             ' order by cod_rubro, cla_moneda)';

    prg_gen_archivo_txt('ES-' || v_cod_entidad || '.DAT',
                        v_sql,
                        'N',
                        NULL,
                        'S');

    -- estado de resultado, cabecera
    v_sql := 'SELECT ''ESTADO_RES''||' ||
             TO_CHAR(v_fec_proceso, 'YYYYMMDD') || v_cod_entidad || '0205' --tipo y clase entidad
             || '0' || '|| LPAD(a.cantidad,6,0) ' ||
             ' from dual,(SELECT COUNT(*) cantidad FROM SB_BCP_sum WHERE substr(cod_rubro,1,1) in (''6'',''7'')) a ';

    prg_gen_archivo_txt('ER-' || v_cod_entidad || '.DAT', v_sql, 'N');

    -- estado de resultado, detalle
    v_sql := 'SELECT linea||lpad(rownum,6,''0'') ' ||
             ' from ( select ''020''||'
            --||' b.cod_rubro', replicar el plazo en la 9na posicion
             ||
             'substr(b.cod_rubro,1,8)||substr(b.cod_rubro,3,1)||substr(b.cod_rubro,10,2)' ||
             '||b.cla_moneda||lpad((round(abs(importe),2)*100),17,0) linea ' ||
             ' from sb_bcp_sum b ' --estaba sb_bcp
             || ' WHERE substr(b.cod_rubro,1,1) in (''6'',''7'') ' ||
             ' order by cod_rubro, cla_moneda)';

    prg_gen_archivo_txt('ER-' || v_cod_entidad || '.DAT',
                        v_sql,
                        'N',
                        NULL,
                        'S');

    --analisis de liquidez
    -- local, cabecera
    v_sql := 'SELECT ''ANALIS_NAC''||' ||
             TO_CHAR(v_fec_proceso, 'YYYYMMDD') || v_cod_entidad || '0205' --tipo y clase entidad
             || '0' || '|| LPAD(a.cantidad,6,0) '
            --           ||'|| a.cantidad '
             || ' from dual,(SELECT COUNT(*) cantidad FROM sb_liquidez ' ||
             ' WHERE fecha = ' || ' to_date( ''' ||
             to_char(v_fec_proceso, 'dd/mm/yyyy') || ''' ,''dd/mm/yyyy'') ' ||
             ' and cod_moneda = ''' || v_cod_mon_local || ''') a ';

    prg_gen_archivo_txt('EN-' || v_cod_entidad || '.DAT', v_sql, 'N');

    -- local, detalle
    v_sql := 'SELECT linea||lpad(rownum,6,''0'') ' ||
             ' from ( select ''030''||substr(b.cuenta,1,11)||lpad(nvl(PLZ_VISTA,0)*100,17,0)|| ' ||
             ' lpad(round(nvl(MEN_30_DIAS,0),2)*100,17,0) || ' ||
             ' lpad(round(nvl(MEN_90_DIAS,0),2)*100,17,0) || ' ||
             ' lpad(round(nvl(MEN_180_DIAS,0),2)*100,17,0)|| ' ||
             ' lpad(round(nvl(MEN_1_ANO,0),2)*100,17,0)   || ' ||
             ' lpad(round(nvl(MEN_3_ANOS,0),2)*100,17,0)  || ' ||
             ' lpad(round(nvl(MAY_3_ANOS,0),2)*100,17,0)  || ' ||
             ' lpad(round(nvl(PLZ_VISTA,0) + nvl(MEN_30_DIAS,0)  + ' ||
             ' nvl(MEN_90_DIAS,0) + nvl(MEN_180_DIAS,0) + ' ||
             ' nvl(MEN_1_ANO,0)   + nvl(MEN_3_ANOS,0)   + ' ||
             ' nvl(MAY_3_ANOS,0),2)*100,17,0) linea ' ||
             ' from sb_liquidez b ' || ' WHERE fecha = ' || ' to_date(''' ||
             to_char(v_fec_proceso, 'dd/mm/yyyy') || ''',''dd/mm/yyyy'') ' ||
             ' and cod_moneda = ''' || v_cod_mon_local ||
             ''' order by b.cuenta) a ';

    prg_gen_archivo_txt('EN-' || v_cod_entidad || '.DAT',
                        v_sql,
                        'N',
                        NULL,
                        'S');

    -- extranjera, cabecera
    v_sql := 'SELECT ''ANALIS_EXT''||' ||
             TO_CHAR(v_fec_proceso, 'YYYYMMDD') || v_cod_entidad || '0205' --tipo y clase entidad
             || '0' || '|| LPAD(a.cantidad,6,0) '
            --            ||'|| a.cantidad '
             || ' from dual,(SELECT COUNT(*) cantidad FROM sb_liquidez ' ||
             ' WHERE fecha = ' || ' to_date(''' ||
             to_char(v_fec_proceso, 'dd/mm/yyyy') || ''',''dd/mm/yyyy'') ' ||
             ' and cod_moneda = ''' || v_cod_mon_fuerte || ''') a ';

    prg_gen_archivo_txt('EX-' || v_cod_entidad || '.DAT', v_sql, 'N');

    --extranjera, detalle
    v_sql := 'SELECT linea||lpad(rownum,6,''0'') ' ||
             ' from ( select ''040''||substr(b.cuenta,1,11)||lpad(round(nvl(PLZ_VISTA,0),2)*100,17,0)|| ' ||
             ' lpad(round(nvl(MEN_30_DIAS,0),2)*100,17,0) || ' ||
             ' lpad(round(nvl(MEN_90_DIAS,0),2)*100,17,0) || ' ||
             ' lpad(round(nvl(MEN_180_DIAS,0),2)*100,17,0)|| ' ||
             ' lpad(round(nvl(MEN_1_ANO,0),2)*100,17,0)   || ' ||
             ' lpad(round(nvl(MEN_3_ANOS,0),2)*100,17,0)  || ' ||
             ' lpad(round(nvl(MAY_3_ANOS,0),2)*100,17,0)  || ' ||
             ' lpad(round(nvl(PLZ_VISTA,0) + nvl(MEN_30_DIAS,0)  + ' ||
             ' nvl(MEN_90_DIAS,0) + nvl(MEN_180_DIAS,0) + ' ||
             ' nvl(MEN_1_ANO,0)   + nvl(MEN_3_ANOS,0)   + ' ||
             ' nvl(MAY_3_ANOS,0),2)*100,17,0) linea ' ||
             ' from sb_liquidez b ' || ' WHERE fecha = ' || ' to_date(''' ||
             to_char(v_fec_proceso, 'dd/mm/yyyy') || ''',''dd/mm/yyyy'') ' ||
             ' and cod_moneda = ''' || v_cod_mon_fuerte ||
             ''' order by b.cuenta) a ';

    prg_gen_archivo_txt('EX-' || v_cod_entidad || '.DAT',
                        v_sql,
                        'N',
                        NULL,
                        'S');

    --riesgo, cabecera
    v_sql := 'SELECT ''RIESGO_TAS''||' ||
             TO_CHAR(v_fec_proceso, 'YYYYMMDD') || v_cod_entidad || '0205' --tipo y clase entidad
             || '0' || '|| LPAD(a.cantidad,6,0) ' ||
             ' from dual,(SELECT COUNT(*) cantidad FROM sv_RIESGOS) a ';

    prg_gen_archivo_txt('ET-' || v_cod_entidad || '.DAT', v_sql, 'N');

    --riesgo, detalle
    v_sql := 'SELECT linea||lpad(rownum,6,''0'') ' ||
             ' from ( select lpad(tip_formulario,2,''0'')||identificador||b.cuenta|| ' ||
             ' lpad(tot_mon_local*100,17,0)||lpad(round(tot_mon_extranjera,2)*100,17,0)|| ' ||
             ' lpad(tot_equivalente*100,17,0) linea ' ||
             ' from sv_riesgos b ' || ' order by cuenta)';

    prg_gen_archivo_txt('ET-' || v_cod_entidad || '.DAT',
                        v_sql,
                        'N',
                        NULL,
                        'S');

  EXCEPTION
    when no_data_found then
      raise_application_error(-20003, 'No existen Parametros de Entidad');
    when others THEN
      raise_application_error(-20003, 'Gen.Ascii ' || sqlerrm);
  END;

  /*recupera saldo*/
  /*FUNCTION BUSCA_SALDO
  (p_cod_rubro  IN varchar2,
   p_cla_moneda IN varchar2)
   RETURN NUMBER IS
  V_SALDO  NUMBER;
  Begin
    \******************************************************\
    \* LEO CB_SAL_CONSOLIDADOS1 PARA SABER EL SALDO DE BCPSUM         *\
    \******************************************************\
     select nvl(bc_importe,0)
       into v_saldo
       from sb_bcp_sum
      where cod_rubro = p_cod_rubro
        and bc_clmoned = p_cla_moneda;
     return v_saldo;
  exception
     when no_data_found then
          raise_application_error('No existe suma cta '||p_cod_rubro;
     when others then
          raise_application_error(-20000,'Recup.Saldo Cta '||p_cod_rubro);
  End;*/
  /*
  PROCEDURE PR_PRO_LIQUIDEZ
  IS
  BEGIN
     --leer datos de sb_liquidez

  END;*/
  /*proceso principal de genearacion de arhivos de planinfo*/
  PROCEDURE PR_PRO_PLANINFO IS
    --v_fec_proceso date;
  BEGIN
    --recupera ultimo dia habil del mes anterior, ya q se corre al inicio del dia del mes sgte
    --y los saldos se generan los dias habiles
    if v_fec_proceso is null or to_char(v_fec_proceso, 'MM') = '12' then
      v_fec_proceso := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_actual, null);
    end if;

    --genera est. resultado
    pr_gen_est_resultado;
    --genera est. situacion
    PR_GEN_EST_SITUACION;
    --sumariza los datos
    PR_PRO_SUMARIZACION('1', '9');
    --genera tablas de riesgo
    PR_PRO_RIESGO;
    --genera archivos ascii
    PR_GEN_ASCII;
  exception
    when others then
      if sqlcode <= -20000 then
        raise;
      else
        raise_application_error(-20000, 'Gen.Planinfo ' || sqlerrm);
      end if;
  END;
  /*proceso para generar el archivo ID, informe diario de rubros*/
  PROCEDURE PR_PRO_ARCHIVO_ID IS
    v_cod_entidad    sb_planinfo.cod_entidad%TYPE;
    w_tipo_entidad   sb_planinfo.tip_entidad%TYPE;
    w_clase_entidad  sb_planinfo.cla_entidad%TYPE;
    v_tot_reg        sb_planinfo.tot_reg_detalle%TYPE;
    wc_identificador sb_riesgos.identificador%TYPE;
    v_cuenta         sb_riesgos.cuenta%TYPE;
    v_tot_loc        sb_riesgos.tot_mon_local%TYPE;
    v_tot_equiv      sb_riesgos.tot_equivalente%TYPE;
    v_nro_registro   number := 0;
    v_gru_rubro      number;
    v_sal_equiv      sb_riesgos.tot_equivalente%TYPE;
    v_sql            varchar2(4000);
    cursor saldos is
      select a.cod_rubro,
             cod_moneda,
             nvl(deb_mon_local, 0) - nvl(cre_mon_local, 0) sal_mon_local,
             nvl(deb_mon_rubro, 0) - nvl(cre_mon_rubro, 0) sal_mon_rubro
        from cb_sal_consolidados a, cb_rubros b
       where a.cod_rubro in
             (select cod_rubro
                from cb_gru_rubros_det
               where cod_gru_rubro = v_gru_rubro)
         and a.ano = to_number(to_char(v_fec_proceso, 'YYYY'))
         and a.mes = to_number(to_char(v_fec_proceso, 'MM'))
         and a.cod_rubro = b.cod_rubro;

  BEGIN
    --elimina las tablas
    delete sb_planinfo
     where nom_archivo = 'INF_DIARIA'
       and fecha = v_fec_actual;
    delete sb_archivo_id where fecha = v_fec_actual;
    --obtener el grupo de rubros a informar
    v_gru_rubro := fug_obt_pardinamico('GRU_INF_DIARIO');
    --recorrer saldos para insertar el detalle
    for reg in saldos loop
      v_nro_registro := v_nro_registro + 1;
      if reg.sal_mon_rubro is not null then
        if reg.cod_moneda = v_cod_mon_fuerte then
          v_sal_equiv := reg.sal_mon_rubro;
        else
          v_sal_equiv := pag_gen.FU_CON_MON_A_MONEDA(reg.cod_moneda,
                                                     v_cod_mon_fuerte,
                                                     reg.sal_mon_rubro);
        end if;
        v_sal_equiv := pag_gen.FU_CON_MON_A_MONEDA(v_cod_mon_fuerte,
                                                   v_cod_mon_local,
                                                   v_sal_equiv);
      end if;
      INSERT INTO sb_archivo_id
        (fecha,
         nro_registro,
         tip_formulario,
         identificador,
         cuenta,
         tot_mon_local,
         tot_equivalente)
      VALUES
        (v_fec_actual,
         v_nro_registro,
         '09',
         0,
         reg.cod_rubro,
         reg.sal_mon_local,
         v_sal_equiv);
    end loop;
    --calcular los encajes

    --para la cabecera
    select cod_entidad into v_cod_entidad from ge_par_generales;

    -- ve la cantidad de registros del detalle --
    SELECT COUNT(*)
      INTO v_tot_reg
      FROM sb_archivo_id
     where fecha = v_fec_actual;
    -- inserta un registro --
    INSERT INTO sb_planinfo
      (NOM_ARCHIVO,
       FECHA,
       COD_ENTIDAD,
       TIP_ENTIDAD,
       CLA_ENTIDAD,
       NRO_REG_A,
       TOT_REG_DETALLE)
    VALUES
      ('INF_DIARIA', v_fec_actual, v_COD_ENTIDAD, '04', '02', 0, v_TOT_REG);

    -- genera ASCII
    -- cabecera
    v_sql := 'SELECT ''INF_DIARIA''||' ||
             TO_CHAR(v_fec_proceso, 'YYYYMMDD') || v_cod_entidad ||
             '|| tip_entidad || cla_entidad' || '|| TOT_reg_detalle ' ||
             'from sb_planinfo ' || 'where nom_archivo = ''INF_DIARIA''' ||
             'and to_date(fecha,''dd/mm/yyyy'') = to_date(''' ||
             v_fec_actual || ''' ,''dd/mm/yyyy'') ';
    --||'|| a.cantidad '
    --||' from dual,(SELECT COUNT(*) cantidad FROM SB_RIESGOS) a ';

    prg_gen_archivo_txt('ID-' || v_cod_entidad || '.DAT', v_sql, 'N');

    -- detalle
    v_sql := 'SELECT linea||lpad(rownum,6,''0'') ' ||
             ' from ( select lpad(tip_formulario,2,''0'')||identificador||substr(b.cuenta,1,10)|| ' ||
             ' lpad(abs(tot_mon_local),17,0)||lpad(abs(tot_equivalente),17,0) linea ' ||
             ' from sb_archivo_id b ' || ' order by cuenta)';

    prg_gen_archivo_txt('ID-' || v_cod_entidad || '.DAT',
                        v_sql,
                        'N',
                        NULL,
                        'S');

  exception
    when others then
      raise_application_error(-20000, 'Gen.Archivo ID ' || sqlerrm);
  END;
  /*Proceso que realiza los ajustes de saldo segun balance en el informe de planinfo, a pedido del Banco.*/
  PROCEDURE pr_aju_cta_contables IS
    v_cod_grupo       cb_gru_rubros.cod_gru_rubro%TYPE;
    v_cod_moneda      ba_monedas.cod_moneda%TYPE;
    v_cod_mon_local   ba_monedas.cod_moneda%TYPE;
    v_cod_mon_fuerte  ba_monedas.cod_moneda%TYPE;
    v_saldo           cb_sal_oficinas.sal_ini_mes_mon_local%TYPE;
    v_rowid           ROWID;
    v_mon_local       sb_riesgos.tot_mon_local%TYPE;
    v_mon_extranjera  sb_riesgos.tot_mon_extranjera%TYPE;
    v_mon_equivalente sb_riesgos.tot_equivalente%TYPE;
    v_nro_registro    NUMBER;
    ---
    v_rubro       VARCHAR2(15);
    v_plazo       NUMBER;
    v_descripcion VARCHAR2(200);
    --- Cursor de cuentas contables a insertar en el analisis de liquidez
    CURSOR c_liq_contable IS
      SELECT a.cod_rubro,
             abs(SUM(decode(nvl(sal_ini_mes_mon_rubro, 0),
                            0,
                            0,
                            nvl(sal_ini_mes_mon_rubro, 0)))) saldo_me,
             abs(SUM(nvl(sal_ini_mes_mon_local, 0) -
                     nvl(sal_ini_mes_equ_local, 0))) saldo_ml,
             abs(SUM(nvl(sal_ini_mes_equ_local, 0))) saldo_eq
        FROM cb_sal_oficinas a, cb_rubros c, cb_gru_rubros_det d
       WHERE a.cod_rubro = c.cod_rubro
         AND d.cod_gru_rubro = v_cod_grupo
         AND d.cod_rubro = a.cod_rubro
         AND (substr(d.cod_rubro, 1, 2) = '14' OR
             substr(d.cod_rubro, 1, 2) = '16')
         AND (nvl(sal_ini_mes_mon_fuerte, 0) <> 0 OR
             nvl(sal_ini_mes_equ_local, 0) <> 0 OR
             nvl(sal_ini_mes_mon_local, 0) <> 0)
       GROUP BY a.cod_rubro;

    PROCEDURE lp_ins_sb_riesgos(p_fecha        IN DATE,
                                p_nro_registro IN NUMBER,
                                p_cuenta       IN VARCHAR2,
                                p_tot_local    IN NUMBER,
                                p_tot_me       IN NUMBER,
                                p_tot_equiv    IN NUMBER) IS
      v_tip_formulario NUMBER := 5;
    BEGIN
      INSERT INTO sb_riesgos
        (fecha,
         nro_registro,
         tip_formulario,
         identificador,
         cuenta,
         tot_mon_local,
         tot_mon_extranjera,
         tot_equivalente)
      VALUES
        (p_fecha,
         p_nro_registro,
         v_tip_formulario,
         0,
         p_cuenta,
         p_tot_local,
         p_tot_me,
         p_tot_equiv);
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20002, 'Ins.Sb_Riesgos ' || SQLERRM);
    END;

  BEGIN
    -- Recuperar grupo de cuentas contables para AL
    v_cod_grupo      := fug_obt_pardinamico('AJU_RUB_PLANINFO');
    v_cod_mon_local  := pag_gen.fu_obt_mon_local;
    v_cod_mon_fuerte := pag_gen.fu_obt_mon_fuerte;
    FOR sal IN c_liq_contable LOOP
      --- Procesar registro
      IF substr(sal.cod_rubro, 1, 2) = '14' THEN
        IF substr(sal.cod_rubro, 4, 1) != '7' THEN
          v_rubro := substr(sal.cod_rubro, 1, 2) || '0' ||
                     substr(sal.cod_rubro, 4, 1) || '1' || '000000';
        ELSE
          v_rubro := substr(sal.cod_rubro, 1, 2) || '0' ||
                     substr(sal.cod_rubro, 4, 1) || '3' || '000000';
        END IF;
      ELSIF substr(sal.cod_rubro, 1, 2) = '16' THEN
        IF substr(sal.cod_rubro, 4, 1) != '7' THEN
          v_rubro := substr(sal.cod_rubro, 1, 2) || '0' ||
                     substr(sal.cod_rubro, 4, 1) || '2' || '000000';
        ELSE
          v_rubro := substr(sal.cod_rubro, 1, 2) || '0' ||
                     substr(sal.cod_rubro, 4, 1) || '3' || '000000';
        END IF;
      END IF;

      --Obtengo el importe total del rubro
      SELECT SUM(tot_mon_local),
             SUM(tot_mon_extranjera),
             SUM(tot_equivalente)
        INTO v_mon_local, v_mon_extranjera, v_mon_equivalente
        FROM sb_riesgos
       WHERE fecha = v_fec_proceso
         AND cuenta LIKE (substr(v_rubro, 1, 4) || '%');
      BEGIN
        SELECT ROWID
          INTO v_rowid
          FROM sb_riesgos
         WHERE fecha = v_fec_proceso
           AND cuenta = v_rubro;
        --- Actualizar registro con saldo
        UPDATE sb_riesgos
           SET tot_mon_local = (CASE
                                 WHEN nvl(v_mon_local, 0) >
                                      nvl(sal.saldo_ml, 0) THEN
                                  nvl(tot_mon_local, 0) -
                                  (nvl(v_mon_local, 0) - nvl(sal.saldo_ml, 0))
                                 WHEN nvl(v_mon_local, 0) <=
                                      nvl(sal.saldo_ml, 0) THEN
                                  nvl(tot_mon_local, 0) +
                                  (nvl(sal.saldo_ml, 0) - nvl(v_mon_local, 0))
                               END),
               tot_mon_extranjera = (CASE
                                      WHEN nvl(v_mon_extranjera, 0) >
                                           nvl(sal.saldo_me, 0) THEN
                                       nvl(tot_mon_extranjera, 0) -
                                       (nvl(v_mon_extranjera, 0) -
                                        nvl(sal.saldo_me, 0))
                                      WHEN nvl(v_mon_extranjera, 0) <=
                                           nvl(sal.saldo_me, 0) THEN
                                       nvl(tot_mon_extranjera, 0) +
                                       (nvl(sal.saldo_me, 0) -
                                        nvl(v_mon_extranjera, 0))
                                    END),
               tot_equivalente = (CASE
                                   WHEN nvl(v_mon_equivalente, 0) >
                                        nvl(sal.saldo_eq, 0) THEN
                                    nvl(tot_equivalente, 0) -
                                    (nvl(v_mon_equivalente, 0) -
                                     nvl(sal.saldo_eq, 0))
                                   WHEN nvl(v_mon_equivalente, 0) <=
                                        nvl(sal.saldo_eq, 0) THEN
                                    nvl(tot_equivalente, 0) +
                                    (nvl(sal.saldo_eq, 0) -
                                     nvl(v_mon_equivalente, 0))
                                 END)
         WHERE ROWID = v_rowid;

      EXCEPTION
        WHEN no_data_found THEN
          --- Insertar registro
          SELECT MAX(sr.nro_registro)
            INTO v_nro_registro
            FROM sb_riesgos sr
           WHERE sr.fecha = v_fec_proceso;
          v_nro_registro := nvl(v_nro_registro, 0) + 1;
          lp_ins_sb_riesgos(v_fec_proceso,
                            v_nro_registro,
                            v_rubro,
                            (CASE WHEN
                             nvl(v_mon_local, 0) > nvl(sal.saldo_ml, 0)
                             THEN(nvl(v_mon_local, 0) - nvl(sal.saldo_ml, 0)) WHEN
                             nvl(v_mon_local, 0) <= nvl(sal.saldo_ml, 0)
                             THEN(nvl(sal.saldo_ml, 0) - nvl(v_mon_local, 0)) END),
                            (CASE WHEN
                             nvl(v_mon_extranjera, 0) > nvl(sal.saldo_me, 0)
                             THEN(nvl(v_mon_extranjera, 0) -
                                  nvl(sal.saldo_me, 0)) WHEN
                             nvl(v_mon_extranjera, 0) <=
                             nvl(sal.saldo_me, 0)
                             THEN(nvl(sal.saldo_me, 0) -
                                  nvl(v_mon_extranjera, 0)) END),
                            (CASE WHEN nvl(v_mon_equivalente, 0) >
                             nvl(sal.saldo_eq, 0)
                             THEN(nvl(v_mon_equivalente, 0) -
                                  nvl(sal.saldo_eq, 0)) WHEN
                             nvl(v_mon_equivalente, 0) <=
                             nvl(sal.saldo_eq, 0)
                             THEN(nvl(sal.saldo_eq, 0) -
                                  nvl(v_mon_equivalente, 0)) END));
      END;
    END LOOP;

  END;
  /*Proceso que realiza la validación del informe de planinfo.*/
  PROCEDURE pr_val_planinfo IS
    -- Local variables here
    v_monto     NUMBER;
    v_montocomp NUMBER;
    v_cuenta    VARCHAR2(15);
    v_modulo    ge_modalidades.cod_modulo%TYPE := 11; -- SUPERINTENDENCIA DE BANCOS
    v_fecha     DATE := pag_cal.fu_obt_fec_actual(v_modulo); --  to_date('31/08/2007','dd/mm/yyyy');
    v_sentencia VARCHAR2(150) := 'TRUNCATE TABLE sb_log_planinfo';
    v_error     VARCHAR2(1000);

    --Registrar en el Log de Planinfo
    PROCEDURE lp_reg_operacion(p_tipo IN LONG, p_mensaje IN LONG) IS
    BEGIN
      INSERT INTO sb_log_planinfo
        (tipo, mensaje)
      VALUES
        (p_tipo, p_mensaje);
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000, SQLERRM);
    END;
  BEGIN
    -------------------------------------------------------------------------------------------
    /*Primero truncamos la tabla de log para poder insertar los resultados de las validaciones*/
    -------------------------------------------------------------------------------------------
    sql_util.ejecute_dml(v_sentencia, v_error);
    /*********************************************/
    /************** ES y ER **********************/
    /*********************************************/
    -- activo - pasivo = patrimonio neto
    BEGIN
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro IN ('10000000000', '20000000000')
         AND a.cla_moneda IN (6200, 6900);
    EXCEPTION
      WHEN no_data_found THEN
        v_monto := 0;
    END;

    BEGIN
      SELECT nvl(a.importe, 0)
        INTO v_montocomp
        FROM sb_bcp_sum a
       WHERE a.cod_rubro = '30000000000'
         AND a.cla_moneda = 6900;
    EXCEPTION
      WHEN no_data_found THEN
        v_montocomp := 0;
    END;

    IF v_monto <> (v_montocomp) * (-1) THEN
      lp_reg_operacion('ES/ER',
                       'Activo-Pasivo <> Patrimonio / ' || v_monto ||
                       ' <> ' || v_montocomp);
    END IF;

    -- Sucursales y agencias no debe tener saldo
    BEGIN
      SELECT a.importe
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro = '15010257004'
         AND rownum < 2;

      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         'Sucursales y Agencias tiene saldo / ' || v_monto);
      ELSE
        lp_reg_operacion('ES/ER',
                         'No debe existir registro de Sucursales y Agencias');
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;
    -- la cta no debe aparecer
    BEGIN
      SELECT a.importe
        INTO v_monto
        FROM sb_bcp a
       WHERE a.cod_rubro = '15010257004'
         AND rownum < 2;

      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         'Sucursales y Agencias tiene registro con cero.');
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;

    -- Verificar 50000 51000 52000 ------------------------------
    BEGIN
      -- 51010 52010 / 6100
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro IN ('51010000000', '52010000000')
         AND a.cla_moneda = 6100;

      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         '51010 y 52010 tienen saldos distintos.6100,Dif=' ||
                         v_monto);
      END IF;
    END;

    BEGIN
      -- 51010 52010 / 6200
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro IN ('51010000000', '52010000000')
         AND a.cla_moneda = 6200;

      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         '51010 y 52010 tienen saldos distintos.6200,Dif=' ||
                         v_monto);
      END IF;
    END;
    BEGIN
      -- 51010 52010 / 6400
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro IN ('51010000000', '52010000000')
         AND a.cla_moneda = 6400;

      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         '51010 y 52010 tienen saldos distintos.6400,Dif=' ||
                         v_monto);
      END IF;
    END;
    BEGIN
      -- 51010 52010 / 6500
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro IN ('51010000000', '52010000000')
         AND a.cla_moneda = 6500;

      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         '51010 y 52010 tienen saldos distintos.6500,Dif=' ||
                         v_monto);
      END IF;
    END;
    BEGIN
      -- 51010 52010 / 6600
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro IN ('51010000000', '52010000000')
         AND a.cla_moneda = 6600;

      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         '51010 y 52010 tienen saldos distintos.6600,Dif=' ||
                         v_monto);
      END IF;
    END;
    BEGIN
      -- 51010 52010 / 6900
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro IN ('51010000000', '52010000000')
         AND a.cla_moneda = 6900;

      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         '51010 y 52010 tienen saldos distintos.6900,Dif=' ||
                         v_monto);
      END IF;
    END;
    ------------
    BEGIN
      -- 51040 52040 / 6100
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro IN ('51040000000', '52040000000')
         AND a.cla_moneda = 6100;

      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         '51040 y 52040 tienen saldos distintos.6100,Dif=' ||
                         v_monto);
      END IF;
    END;
    BEGIN
      -- 51040 52040 / 6200
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro IN ('51040000000', '52040000000')
         AND a.cla_moneda = 6200;

      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         '51040 y 52040 tienen saldos distintos.6200,Dif=' ||
                         v_monto);
      END IF;
    END;
    BEGIN
      -- 51010 52010 / 6400
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro IN ('51040000000', '52040000000')
         AND a.cla_moneda = 6400;

      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         '51040 y 52040 tienen saldos distintos.6400,Dif=' ||
                         v_monto);
      END IF;
    END;
    BEGIN
      -- 51010 52010 / 6500
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro IN ('51040000000', '52040000000')
         AND a.cla_moneda = 6500;

      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         '51040 y 52040 tienen saldos distintos.6500,Dif=' ||
                         v_monto);
      END IF;
    END;
    BEGIN
      -- 51010 52010 / 6600
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro IN ('51040000000', '52040000000')
         AND a.cla_moneda = 6600;

      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         '51040 y 52040 tienen saldos distintos.6600,Dif=' ||
                         v_monto);
      END IF;
    END;
    BEGIN
      -- 51010 52010 / 6900
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro IN ('51040000000', '52040000000')
         AND a.cla_moneda = 6900;

      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         '51040 y 52040 tienen saldos distintos.6900,Dif=' ||
                         v_monto);
      END IF;
    END;

    BEGIN
      -- 50000 51000 / 6100
      SELECT (nvl(a.importe, 0)), nvl(b.importe, 0)
        INTO v_monto, v_montocomp
        FROM sb_bcp_sum a, sb_bcp_sum b
       WHERE a.cod_rubro = '50000000000'
         AND b.cod_rubro = '51000000000'
         AND a.cla_moneda = 6100
         AND b.cla_moneda = 6100;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ES/ER',
                         '50000 y 51000 tienen saldos distintos.6100,Dif=' ||
                         v_monto);
      END IF;
    END;
    BEGIN
      -- 50000 51000 / 6200
      SELECT (nvl(a.importe, 0)), nvl(b.importe, 0)
        INTO v_monto, v_montocomp
        FROM sb_bcp_sum a, sb_bcp_sum b
       WHERE a.cod_rubro = '50000000000'
         AND b.cod_rubro = '51000000000'
         AND a.cla_moneda = 6200
         AND b.cla_moneda = 6200;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ES/ER',
                         '50000 y 51000 tienen saldos distintos.6200,Dif=' ||
                         v_monto);
      END IF;
    END;
    BEGIN
      -- 51010 52010 / 6400
      SELECT (nvl(a.importe, 0)), nvl(b.importe, 0)
        INTO v_monto, v_montocomp
        FROM sb_bcp_sum a, sb_bcp_sum b
       WHERE a.cod_rubro = '50000000000'
         AND b.cod_rubro = '51000000000'
         AND a.cla_moneda = 6400
         AND b.cla_moneda = 6400;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ES/ER',
                         '50000 y 51000 tienen saldos distintos.6400,Dif=' ||
                         v_monto);
      END IF;
    END;
    BEGIN
      -- 51010 52010 / 6500
      SELECT (nvl(a.importe, 0)), nvl(b.importe, 0)
        INTO v_monto, v_montocomp
        FROM sb_bcp_sum a, sb_bcp_sum b
       WHERE a.cod_rubro = '50000000000'
         AND b.cod_rubro = '51000000000'
         AND a.cla_moneda = 6500
         AND b.cla_moneda = 6500;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ES/ER',
                         '50000 y 51000 tienen saldos distintos.6500,Dif=' ||
                         v_monto);
      END IF;
    END;
    BEGIN
      -- 51010 52010 / 6600
      SELECT (nvl(a.importe, 0)), nvl(b.importe, 0)
        INTO v_monto, v_montocomp
        FROM sb_bcp_sum a, sb_bcp_sum b
       WHERE a.cod_rubro = '50000000000'
         AND b.cod_rubro = '51000000000'
         AND a.cla_moneda = 6600
         AND b.cla_moneda = 6600;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ES/ER',
                         '50000 y 51000 tienen saldos distintos.6600,Dif=' ||
                         v_monto);
      END IF;
    END;
    BEGIN
      -- 51010 52010 / 6900
      SELECT (nvl(a.importe, 0)), nvl(b.importe, 0)
        INTO v_monto, v_montocomp
        FROM sb_bcp_sum a, sb_bcp_sum b
       WHERE a.cod_rubro = '50000000000'
         AND b.cod_rubro = '51000000000'
         AND a.cla_moneda = 6900
         AND b.cla_moneda = 6900;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ES/ER',
                         '50000 y 51000 tienen saldos distintos.6900,Dif=' ||
                         v_monto);
      END IF;
    END;
    -----------------------------------------------
    -- Verificar moneda correcta de valuacion
    BEGIN
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro LIKE '14_70000000'
         AND a.cla_moneda = 6900;
      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         'Existe saldo de valuacion en 6900 / 14070 / ' ||
                         v_monto);
      END IF;
    END;
    BEGIN
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro LIKE '16070000000'
         AND a.cla_moneda = 6900;
      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         'Existe saldo de valuacion en 6900 / 16070 / ' ||
                         v_monto);
      END IF;
    END;
    -----------------------------------------------
    -- Verificar cuentas que no deben tener saldo en equivalente
    BEGIN
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro = '73010771018'
         AND a.cla_moneda IN (6100, 6200);
      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         'Existe saldo en 6100,6200 / 73010771018 / ' ||
                         v_monto);
      END IF;
    END;
    BEGIN
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro = '73010763004'
         AND a.cla_moneda IN (6100, 6200);
      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         'Existe saldo en 6100,6200 / 73010763004 / ' ||
                         v_monto);
      END IF;
    END;
    --------------------------
    -- Ganancias - Perdidas = Utilidades del ejercicio
    BEGIN
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro NOT IN ('31060000000', '31060418001')
         AND a.cod_rubro LIKE '31_60%'
         AND a.cla_moneda IN (6100, 6200, 6900);
      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         'Existe cta. que no se informa en 31060 / ' ||
                         v_monto);
      END IF;
    END;
    BEGIN
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro IN ('60000000000', '70000000000')
         AND a.cla_moneda IN (6200, 6900);

      SELECT (nvl(a.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum a
       WHERE a.cod_rubro = '31060000000'
         AND a.cla_moneda IN (6200, 6900);

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ES/ER',
                         'Ganancias - Perdidas <> Utilidades. Dif=' ||
                         v_monto);
      END IF;
    END;

    /*********************************************/
    /************** EN y EX **********************/
    /*********************************************/

    -- validar que totales coincidan con el ES
    -- GS
    -- 11000
    BEGIN
      BEGIN
        SELECT nvl(a.plz_vista, 0) + nvl(a.men_30_dias, 0) +
               nvl(a.men_90_dias, 0) + nvl(a.men_180_dias, 0) +
               nvl(a.men_1_ano, 0) + nvl(a.men_3_anos, 0) +
               nvl(a.may_3_anos, 0)
          INTO v_monto
          FROM sb_liquidez a
         WHERE a.fecha = v_fecha
           AND a.cod_moneda = 'GS'
           AND a.cuenta = '110000000000000';
      EXCEPTION
        WHEN no_data_found THEN
          v_monto := 0;
      END;

      BEGIN
        SELECT b.importe
          INTO v_montocomp
          FROM sb_bcp_sum b
         WHERE b.cod_rubro = '11000000000'
           AND b.cla_moneda = 6900;
        --- agregado por teresita
      EXCEPTION
        WHEN no_data_found THEN
          v_montocomp := 0;
      END;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('EN/EX',
                         'EN 11000 Dif=' || (v_monto - v_montocomp) || ';' ||
                         v_monto || ';' || v_montocomp);
      END IF;
    END;
    -- 12000
    BEGIN
      BEGIN
        SELECT nvl(a.plz_vista, 0) + nvl(a.men_30_dias, 0) +
               nvl(a.men_90_dias, 0) + nvl(a.men_180_dias, 0) +
               nvl(a.men_1_ano, 0) + nvl(a.men_3_anos, 0) +
               nvl(a.may_3_anos, 0)
          INTO v_monto
          FROM sb_liquidez a
         WHERE a.fecha = v_fecha
           AND a.cod_moneda = 'GS'
           AND a.cuenta = '120000000000000';
      EXCEPTION
        WHEN no_data_found THEN
          v_monto := 0;
      END;

      BEGIN
        SELECT b.importe
          INTO v_montocomp
          FROM sb_bcp_sum b
         WHERE b.cod_rubro = '12000000000'
           AND b.cla_moneda = 6900;
      EXCEPTION
        WHEN no_data_found THEN
          v_montocomp := 0;
      END;
      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('EN/EX',
                         'EN 12000 Dif=' || (v_monto - v_montocomp));
      END IF;
    END;
    -- 13000
    BEGIN
      BEGIN
        SELECT nvl(a.plz_vista, 0) + nvl(a.men_30_dias, 0) +
               nvl(a.men_90_dias, 0) + nvl(a.men_180_dias, 0) +
               nvl(a.men_1_ano, 0) + nvl(a.men_3_anos, 0) +
               nvl(a.may_3_anos, 0)
          INTO v_monto
          FROM sb_liquidez a
         WHERE a.fecha = v_fecha
           AND a.cod_moneda = 'GS'
           AND a.cuenta = '130000000000000';
      EXCEPTION
        WHEN no_data_found THEN
          v_monto := 0;
      END;

      BEGIN
        SELECT b.importe
          INTO v_montocomp
          FROM sb_bcp_sum b
         WHERE b.cod_rubro = '13000000000'
           AND b.cla_moneda = 6900;
      EXCEPTION
        WHEN no_data_found THEN
          v_montocomp := 0;
      END;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('EN/EX',
                         'EN 13000 Dif=' || (v_monto - v_montocomp));
      END IF;
    END;
    -- 14000
    BEGIN
      BEGIN
        SELECT nvl(a.plz_vista, 0) + nvl(a.men_30_dias, 0) +
               nvl(a.men_90_dias, 0) + nvl(a.men_180_dias, 0) +
               nvl(a.men_1_ano, 0) + nvl(a.men_3_anos, 0) +
               nvl(a.may_3_anos, 0)
          INTO v_monto
          FROM sb_liquidez a
         WHERE a.fecha = v_fecha
           AND a.cod_moneda = 'GS'
           AND a.cuenta = '140000000000000';
      EXCEPTION
        WHEN no_data_found THEN
          v_monto := 0;
      END;
      BEGIN
        SELECT b.importe + (SELECT nvl(SUM(b.importe), 0)
                              FROM sb_bcp_sum b
                             WHERE b.cod_rubro LIKE '14_70000000'
                               AND b.cla_moneda = 6200)
          INTO v_montocomp
          FROM sb_bcp_sum b
         WHERE b.cod_rubro = '14000000000'
           AND b.cla_moneda = 6900;
      EXCEPTION
        WHEN no_data_found THEN
          v_montocomp := 0;
      END;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('EN/EX',
                         'EN 14000 ' || v_monto || '/' || v_montocomp);
      END IF;
    END;
    -- 21000
    BEGIN
      BEGIN
        SELECT nvl(a.plz_vista, 0) + nvl(a.men_30_dias, 0) +
               nvl(a.men_90_dias, 0) + nvl(a.men_180_dias, 0) +
               nvl(a.men_1_ano, 0) + nvl(a.men_3_anos, 0) +
               nvl(a.may_3_anos, 0)
          INTO v_monto
          FROM sb_liquidez a
         WHERE a.fecha = v_fecha
           AND a.cod_moneda = 'GS'
           AND a.cuenta = '210000000000000';
      EXCEPTION
        WHEN no_data_found THEN
          v_monto := 0;
      END;

      BEGIN
        SELECT b.importe * (-1)
          INTO v_montocomp
          FROM sb_bcp_sum b
         WHERE b.cod_rubro = '21000000000'
           AND b.cla_moneda = 6900;
      EXCEPTION
        WHEN no_data_found THEN
          v_montocomp := 0;
      END;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('EN/EX',
                         'EN 21000 Dif=' || (v_monto - v_montocomp));
      END IF;
    END;
    -- 22000
    BEGIN
      BEGIN
        SELECT nvl(a.plz_vista, 0) + nvl(a.men_30_dias, 0) +
               nvl(a.men_90_dias, 0) + nvl(a.men_180_dias, 0) +
               nvl(a.men_1_ano, 0) + nvl(a.men_3_anos, 0) +
               nvl(a.may_3_anos, 0)
          INTO v_monto
          FROM sb_liquidez a
         WHERE a.fecha = v_fecha
           AND a.cod_moneda = 'GS'
           AND a.cuenta = '220000000000000';
      EXCEPTION
        WHEN no_data_found THEN
          v_monto := 0;
      END;

      BEGIN
        SELECT b.importe * (-1)
          INTO v_montocomp
          FROM sb_bcp_sum b
         WHERE b.cod_rubro = '22000000000'
           AND b.cla_moneda = 6900;
      EXCEPTION
        WHEN no_data_found THEN
          v_montocomp := 0;
      END;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('EN/EX',
                         'EN 22000 Dif=' || (v_monto - v_montocomp));
      END IF;
    END;
    -- USD
    -- 11000
    BEGIN
      BEGIN
        SELECT nvl(a.plz_vista, 0) + nvl(a.men_30_dias, 0) +
               nvl(a.men_90_dias, 0) + nvl(a.men_180_dias, 0) +
               nvl(a.men_1_ano, 0) + nvl(a.men_3_anos, 0) +
               nvl(a.may_3_anos, 0)
          INTO v_monto
          FROM sb_liquidez a
         WHERE a.fecha = v_fecha
           AND a.cod_moneda = 'USD'
           AND a.cuenta = '110000000000000';
      EXCEPTION
        WHEN no_data_found THEN
          v_monto := 0;
      END;

      BEGIN
        SELECT b.importe
          INTO v_montocomp
          FROM sb_bcp_sum b
         WHERE b.cod_rubro = '11000000000'
           AND b.cla_moneda = 6100;
      EXCEPTION
        WHEN no_data_found THEN
          v_montocomp := 0;
      END;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('EN/EX',
                         'EX 11000 Dif=' || (v_monto - v_montocomp));
      END IF;
    END;
    -- 12000
    BEGIN
      BEGIN
        SELECT nvl(a.plz_vista, 0) + nvl(a.men_30_dias, 0) +
               nvl(a.men_90_dias, 0) + nvl(a.men_180_dias, 0) +
               nvl(a.men_1_ano, 0) + nvl(a.men_3_anos, 0) +
               nvl(a.may_3_anos, 0)
          INTO v_monto
          FROM sb_liquidez a
         WHERE a.fecha = v_fecha
           AND a.cod_moneda = 'USD'
           AND a.cuenta = '120000000000000';
      EXCEPTION
        WHEN no_data_found THEN
          v_monto := 0;
      END;

      BEGIN
        SELECT b.importe
          INTO v_montocomp
          FROM sb_bcp_sum b
         WHERE b.cod_rubro = '12000000000'
           AND b.cla_moneda = 6100;
      EXCEPTION
        WHEN no_data_found THEN
          v_montocomp := 0;
      END;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('EN/EX',
                         'EX 12000 Dif=' || (v_monto - v_montocomp));
      END IF;
    END;
    -- 13000
    BEGIN
      BEGIN
        SELECT nvl(a.plz_vista, 0) + nvl(a.men_30_dias, 0) +
               nvl(a.men_90_dias, 0) + nvl(a.men_180_dias, 0) +
               nvl(a.men_1_ano, 0) + nvl(a.men_3_anos, 0) +
               nvl(a.may_3_anos, 0)
          INTO v_monto
          FROM sb_liquidez a
         WHERE a.fecha = v_fecha
           AND a.cod_moneda = 'USD'
           AND a.cuenta = '130000000000000';
      EXCEPTION
        WHEN no_data_found THEN
          v_monto := 0;
      END;

      BEGIN
        SELECT b.importe
          INTO v_montocomp
          FROM sb_bcp_sum b
         WHERE b.cod_rubro = '13000000000'
           AND b.cla_moneda = 6100;
      EXCEPTION
        WHEN no_data_found THEN
          v_montocomp := 0;
      END;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('EN/EX',
                         'EX 13000 Dif=' || (v_monto - v_montocomp));
      END IF;
    END;
    -- 14000
    BEGIN
      BEGIN
        SELECT nvl(a.plz_vista, 0) + nvl(a.men_30_dias, 0) +
               nvl(a.men_90_dias, 0) + nvl(a.men_180_dias, 0) +
               nvl(a.men_1_ano, 0) + nvl(a.men_3_anos, 0) +
               nvl(a.may_3_anos, 0)
          INTO v_monto
          FROM sb_liquidez a
         WHERE a.fecha = v_fecha
           AND a.cod_moneda = 'USD'
           AND a.cuenta = '140000000000000';
      EXCEPTION
        WHEN no_data_found THEN
          v_monto := 0;
      END;

      BEGIN
        SELECT b.importe
          INTO v_montocomp
          FROM sb_bcp_sum b
         WHERE b.cod_rubro = '14000000000'
           AND b.cla_moneda = 6100;
      EXCEPTION
        WHEN no_data_found THEN
          v_montocomp := 0;
      END;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('EN/EX',
                         'EX 14000 Dif=' || (v_monto - v_montocomp));
      END IF;
    END;
    -- 21000
    BEGIN
      BEGIN
        SELECT nvl(a.plz_vista, 0) + nvl(a.men_30_dias, 0) +
               nvl(a.men_90_dias, 0) + nvl(a.men_180_dias, 0) +
               nvl(a.men_1_ano, 0) + nvl(a.men_3_anos, 0) +
               nvl(a.may_3_anos, 0)
          INTO v_monto
          FROM sb_liquidez a
         WHERE a.fecha = v_fecha
           AND a.cod_moneda = 'USD'
           AND a.cuenta = '210000000000000';
      EXCEPTION
        WHEN no_data_found THEN
          v_monto := 0;
      END;

      BEGIN
        SELECT b.importe * (-1)
          INTO v_montocomp
          FROM sb_bcp_sum b
         WHERE b.cod_rubro = '21000000000'
           AND b.cla_moneda = 6100;
      EXCEPTION
        WHEN no_data_found THEN
          v_montocomp := 0;
      END;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('EN/EX',
                         'EX 21000 Dif=' || (v_monto - v_montocomp));
      END IF;
    END;
    -- 22000
    BEGIN
      BEGIN
        SELECT nvl(a.plz_vista, 0) + nvl(a.men_30_dias, 0) +
               nvl(a.men_90_dias, 0) + nvl(a.men_180_dias, 0) +
               nvl(a.men_1_ano, 0) + nvl(a.men_3_anos, 0) +
               nvl(a.may_3_anos, 0)
          INTO v_monto
          FROM sb_liquidez a
         WHERE a.fecha = v_fecha
           AND a.cod_moneda = 'USD'
           AND a.cuenta = '220000000000000';
      EXCEPTION
        WHEN no_data_found THEN
          v_monto := 0;
      END;

      BEGIN
        SELECT b.importe * (-1)
          INTO v_montocomp
          FROM sb_bcp_sum b
         WHERE b.cod_rubro = '22000000000'
           AND b.cla_moneda = 6100;
      EXCEPTION
        WHEN no_data_found THEN
          v_montocomp := 0;
      END;
      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('EN/EX',
                         'EX 22000 Dif=' || (v_monto - v_montocomp));
      END IF;
    END;

    /*********************************************/
    /**************   ET    **********************/
    /*********************************************/

    -- controlar por totales por item (capital, interes, valuacion, previsiones)
    -- 14000
    -- capital moneda local
    BEGIN
      SELECT r.tot_mon_local
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '14010000000';

      SELECT SUM(nvl(b.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '14_10000000'
         AND b.cla_moneda = 6900;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET', '14010 GS Dif=' || (v_monto - v_montocomp));
      END IF;
    END;
    -- interes moneda local
    BEGIN
      SELECT r.tot_mon_local
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '14080000000';

      SELECT SUM(nvl(b.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '14_80000000'
         AND b.cla_moneda = 6900;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET', '14080 GS Dif=' || (v_monto - v_montocomp));
      END IF;
    END;
    -- prevision moneda local
    BEGIN
      SELECT r.tot_mon_local
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '14090000000';

      SELECT SUM(nvl(b.importe, 0)) * (-1)
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '14_90000000'
         AND b.cla_moneda = 6900;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET', '14090 GS Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '14090 EQUIV (Aviso) No existe saldo');
    END;
    -- capital moneda extranjera
    BEGIN
      SELECT r.tot_mon_extranjera
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '14010000000';

      SELECT SUM(nvl(b.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '14_10000000'
         AND b.cla_moneda = 6100;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET', '14010 USD Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '14010 USD (Aviso) No existe saldo');
    END;
    -- interes moneda extranjera
    BEGIN
      SELECT r.tot_mon_extranjera
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '14080000000';

      SELECT SUM(nvl(b.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '14_80000000'
         AND b.cla_moneda = 6100;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET', '14080 USD Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '14080 USD (Aviso) No existe saldo');
    END;
    -- prevision moneda extranjera
    BEGIN
      SELECT r.tot_mon_extranjera
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '14090000000';

      SELECT SUM(nvl(b.importe, 0)) * (-1)
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '14_90000000'
         AND b.cla_moneda = 6100;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET', '14090 USD Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '14090 USD (Aviso) No existe saldo');
    END;
    -- capital moneda equivalente
    BEGIN
      SELECT r.tot_equivalente
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '14010000000';

      SELECT SUM(nvl(b.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '14_10000000'
         AND b.cla_moneda = 6200;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET',
                         '14010 Equiv. Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '14010 Equiv.(Aviso) No existe saldo');
    END;
    -- interes moneda equivalente
    BEGIN
      SELECT r.tot_equivalente
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '14080000000';

      SELECT SUM(nvl(b.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '14_80000000'
         AND b.cla_moneda = 6200;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET',
                         '14080 Equiv. Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '14080 Equiv. (Aviso) No existe saldo');
    END;
    -- valuacion moneda equivalente
    BEGIN
      SELECT r.tot_equivalente
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '14070000000';

      SELECT SUM(nvl(b.importe, 0)) * (-1)
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '14_70000000'
         AND b.cla_moneda = 6200;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET',
                         '14070 Equiv. Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '14070 Equiv. (Aviso) No existe saldo');
    END;
    -- prevision moneda equivalente
    BEGIN
      SELECT r.tot_equivalente
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '14090000000';

      SELECT SUM(nvl(b.importe, 0)) * (-1)
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '14_90000000'
         AND b.cla_moneda = 6200;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET',
                         '14090 Equiv. Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '14090 Equiv. (Aviso) No existe saldo');
    END;
    -- 16000
    -- capital moneda local
    BEGIN
      --16010
      SELECT r.tot_mon_local
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '16010000000';

      SELECT SUM(nvl(b.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '16_10000000'
         AND b.cla_moneda = 6900;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET', '16010 GS Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '16010 GS (Aviso) No existe saldo');
    END;
    BEGIN
      --16030
      SELECT r.tot_mon_local
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '16030000000';

      SELECT SUM(nvl(b.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '16_30000000'
         AND b.cla_moneda = 6900;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET', '16030 GS Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '16030 GS (Aviso) No existe saldo');
    END;
    BEGIN
      SELECT r.tot_mon_local
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '16050000000';

      SELECT SUM(nvl(b.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '16_50000000'
         AND b.cla_moneda = 6900;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET', '16050 GS Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '16050 GS (Aviso) No existe saldo');
    END;
    -- interes moneda local
    BEGIN
      SELECT r.tot_mon_local
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '16080000000';

      SELECT SUM(nvl(b.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '16_80000000'
         AND b.cla_moneda = 6900;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET', '16080 GS Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '16080 GS (Aviso) No existe saldo');
    END;
    -- prevision moneda local
    BEGIN
      SELECT r.tot_mon_local
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '16090000000';

      SELECT SUM(nvl(b.importe, 0)) * (-1)
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '16_90000000'
         AND b.cla_moneda = 6900;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET', '16090 GS Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '16090 GS (Aviso) No existe saldo');
    END;
    -- capital moneda extranjera
    BEGIN
      --16010
      SELECT r.tot_mon_extranjera
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '16010000000';

      SELECT SUM(nvl(b.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '16_10000000'
         AND b.cla_moneda = 6100;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET', '16010 USD Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '16010 USD (Aviso) No existe saldo');
    END;
    BEGIN
      --16030
      SELECT r.tot_mon_extranjera
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '16030000000';

      SELECT SUM(nvl(b.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '16_30000000'
         AND b.cla_moneda = 6100;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET', '16030 USD Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '16030 USD (Aviso) No existe saldo');
    END;
    BEGIN
      --16050
      SELECT r.tot_mon_extranjera
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '16050000000';

      SELECT SUM(nvl(b.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '16_50000000'
         AND b.cla_moneda = 6100;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET', '16050 USD Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '16050 USD (Aviso) No existe saldo');
    END;

    -- interes moneda extranjera
    BEGIN
      SELECT r.tot_mon_extranjera
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '16080000000';

      SELECT SUM(nvl(b.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '16_80000000'
         AND b.cla_moneda = 6100;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET', '16080 USD Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '16080 USD (Aviso) No existe saldo');
    END;
    -- prevision moneda extranjera
    BEGIN
      SELECT r.tot_mon_extranjera
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '16090000000';

      SELECT SUM(nvl(b.importe, 0)) * (-1)
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '16_90000000'
         AND b.cla_moneda = 6100;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET', '16090 USD Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '16090 USD (Aviso) No existe saldo');
    END;
    -- capital moneda equivalente
    BEGIN
      --16010
      SELECT r.tot_equivalente
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '16010000000';

      SELECT SUM(nvl(b.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '16_10000000'
         AND b.cla_moneda = 6200;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET',
                         '16010 Equiv. Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '16010 Equiv.(Aviso) No existe saldo');
    END;
    BEGIN
      --16030
      SELECT r.tot_equivalente
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '16030000000';

      SELECT SUM(nvl(b.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '16_30000000'
         AND b.cla_moneda = 6200;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET',
                         '16030 Equiv. Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '16030 Equiv. (Aviso) No existe saldo');
    END;
    BEGIN
      --16050
      SELECT r.tot_equivalente
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '16050000000';

      SELECT SUM(nvl(b.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '16_50000000'
         AND b.cla_moneda = 6200;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET',
                         '16050 Equiv. Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '16050 Equiv. (Aviso) No existe saldo');
    END;

    -- interes moneda equivalente
    BEGIN
      SELECT r.tot_equivalente
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '16080000000';

      SELECT SUM(nvl(b.importe, 0))
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '16_80000000'
         AND b.cla_moneda = 6200;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET',
                         '16080 Equiv. Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '16080 Equiv. (Aviso) No existe saldo');
    END;
    -- valuacion moneda equivalente
    BEGIN
      BEGIN
        SELECT r.tot_equivalente
          INTO v_monto
          FROM sv_riesgos r
         WHERE r.cuenta = '16070000000';
      EXCEPTION
        WHEN no_data_found THEN
          v_monto := 0;
      END;

      BEGIN
        SELECT SUM(nvl(b.importe, 0)) * (-1)
          INTO v_montocomp
          FROM sb_bcp_sum b
         WHERE b.cod_rubro LIKE '16_70000000'
           AND b.cla_moneda = 6200;
      EXCEPTION
        WHEN no_data_found THEN
          v_montocomp := 0;
      END;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET',
                         '16070 Equiv. Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '16070 Equiv. (Aviso) No existe saldo');
    END;
    -- prevision moneda equivalente
    BEGIN
      SELECT r.tot_equivalente
        INTO v_monto
        FROM sv_riesgos r
       WHERE r.cuenta = '16090000000';

      SELECT SUM(nvl(b.importe, 0)) * (-1)
        INTO v_montocomp
        FROM sb_bcp_sum b
       WHERE b.cod_rubro LIKE '16_90000000'
         AND b.cla_moneda = 6200;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET',
                         '16090 Equiv. Dif=' || (v_monto - v_montocomp));
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        lp_reg_operacion('ET', '16090 Equiv. (Aviso) No existe saldo');
    END;

    -- controlar que no haya saldos negativos en el ET
    BEGIN
      SELECT cuenta
        INTO v_monto
        FROM (SELECT substr(cuenta, 1, 3) || '00000000' cuenta,
                     (SUM((decode(substr(cuenta, 4, 1), '9', -1, '7', -1, 1) *
                          tot_mon_local))) tot_mon_local,
                     (SUM((decode(substr(cuenta, 4, 1), '9', -1, '7', -1, 1) *
                          tot_mon_extranjera))) tot_mon_extranjera,
                     (SUM((decode(substr(cuenta, 4, 1), '9', -1, '7', -1, 1) *
                          tot_equivalente))) tot_equivalente
                FROM sb_riesgos
               WHERE instr(substr(cuenta, 4, 2), '0') = 0
               GROUP BY substr(cuenta, 1, 3)
              UNION
              SELECT substr(cuenta, 1, 4) || '0000000' cuenta,
                     (SUM((decode(substr(cuenta, 4, 1), '9', -1, '7', -1, 1) *
                          tot_mon_local))) tot_mon_local,
                     (SUM((decode(substr(cuenta, 4, 1), '9', -1, '7', -1, 1) *
                          tot_mon_extranjera))) tot_mon_extranjera,
                     (SUM((decode(substr(cuenta, 4, 1), '9', -1, '7', -1, 1) *
                          tot_equivalente))) tot_equivalente
                FROM sb_riesgos
               WHERE instr(substr(cuenta, 4, 2), '0') = 0
               GROUP BY substr(cuenta, 1, 4)
              UNION
              SELECT substr(cuenta, 1, 3) || '0' || substr(cuenta, 5, 1) ||
                     '000000' cuenta,
                     (SUM((decode(substr(cuenta, 4, 1), '9', -1, '7', -1, 1) *
                          tot_mon_local))) tot_mon_local,
                     (SUM((decode(substr(cuenta, 4, 1), '9', -1, '7', -1, 1) *
                          tot_mon_extranjera))) tot_mon_extranjera,
                     (SUM((decode(substr(cuenta, 4, 1), '9', -1, '7', -1, 1) *
                          tot_equivalente))) tot_equivalente
                FROM sb_riesgos
               WHERE instr(substr(cuenta, 4, 2), '0') = 0
               GROUP BY substr(cuenta, 1, 3) || '0' || substr(cuenta, 5, 1)
              UNION
              SELECT cuenta,
                     tot_mon_local,
                     tot_mon_extranjera,
                     tot_equivalente
                FROM sb_riesgos
               WHERE instr(substr(cuenta, 4, 2), '0') = 0
               ORDER BY cuenta DESC)
       WHERE cuenta LIKE '1_00_000000'
         AND cuenta NOT LIKE '1_000000000'
         AND (tot_mon_local < 0 OR tot_mon_extranjera < 0 OR
             tot_equivalente < 0)
         AND rownum < 2;

      lp_reg_operacion('ET', 'Existen saldos negativos ET cta ' || v_monto);
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;
    -- que todas las monedas extranjeras tengan su equivalente
    BEGIN
      SELECT r.cuenta
        INTO v_cuenta
        FROM sv_riesgos r
       WHERE r.tot_mon_extranjera > 0
         AND r.tot_equivalente = 0;

      IF v_monto <> v_montocomp THEN
        lp_reg_operacion('ET', v_cuenta || ' falta monto equivalente');
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;
    -- cotizaciones en el ET
    BEGIN
      SELECT a.cuenta,
             round((a.tot_equivalente /
                   decode(a.tot_mon_extranjera, 0, 1, a.tot_mon_extranjera)),
                   2)
        INTO v_cuenta, v_montocomp
        FROM sb_riesgos a, ge_calendarios c
       WHERE c.cod_modulo = 11
         AND a.tot_mon_extranjera <> 0
         AND abs(round(a.tot_equivalente / a.tot_mon_extranjera, 2) -
                 (pag_gen.fu_obt_cotizacion(pag_gen.fu_obt_mon_fuerte,
                                            c.fec_actual))) > 0.09;

      IF v_montocomp <> 0 THEN
        lp_reg_operacion('ET',
                         v_cuenta || ' diferencia en la cotizacion ' ||
                         v_montocomp);
        --dbms_output.put_line('ET-'||v_cuenta||' diferencia en la cotizacion '||v_montocomp);
      END IF;

    EXCEPTION
      WHEN too_many_rows THEN
        lp_reg_operacion('ET', 'Existen diferencia en cotizaciones.');
      WHEN no_data_found THEN
        NULL;
    END;

    -- Verificar suma
    BEGIN
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro LIKE '14_80000000'
         AND a.cla_moneda = 6900
         AND a.importe < 0;
      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         'Existe 14_8000000 con saldo negativo 6900');
      END IF;
    END;
    -- Verificar suma
    BEGIN
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro LIKE '14_80000000'
         AND a.cla_moneda = 6100
         AND a.importe < 0;
      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         'Existe 14_8000000 con saldo negativo 6100');
      END IF;
    END;
    -- Verificar suma
    BEGIN
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro LIKE '22_80000000'
         AND a.cla_moneda = 6900
         AND a.importe > 0;
      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         'Existe 22_8000000 con saldo positivo 6900');
      END IF;
    END;
    BEGIN
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro LIKE '22_80000000'
         AND a.cla_moneda = 6100
         AND a.importe > 0;
      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         'Existe 22_8000000 con saldo positivo 6100');
      END IF;
    END;
    BEGIN
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro LIKE '16_80000000'
         AND a.cla_moneda = 6900
         AND a.importe < 0;
      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         'Existe 16_8000000 con saldo negativo 6900');
      END IF;
    END;
    BEGIN
      SELECT SUM(nvl(a.importe, 0))
        INTO v_monto
        FROM sb_bcp_sum a
       WHERE a.cod_rubro LIKE '16_80000000'
         AND a.cla_moneda = 6100
         AND a.importe < 0;
      IF v_monto <> 0 THEN
        lp_reg_operacion('ES/ER',
                         'Existe 16_8000000 con saldo negativo 6100');
      END IF;
    END;
    -----------------------------------------------
  END;

END PAS_PLA;
/

