create or replace procedure it.PRB_PRO_BAL_DIARIO is

  WW_COTIZ NUMBER(14,2);
  WW_SAL6  NUMBER(18,2);
  WW_SAL7  NUMBER(18,2);
  WW_DEBI  NUMBER(18,2);
  WW_CRED  NUMBER(18,2);
  WW_DIFE  NUMBER(18,2);
  WW_UTIL  NUMBER(18,2);
  v_fec_actual date;
  ww_sal_act number(18,2);

BEGIN
  /*delete cb_bal_diario
   where fecha = (select ca_fcdehoy from fgcalen
                        where ca_cdmodul = 2);*/
  v_fec_actual := pag_cal.fu_obt_fec_actual(2);

  delete cb_bal_diario_tmp;
  delete from cb_bal_diario where fecha = v_fec_actual;
  -------------------------------------
  -- obtiene la cotizacion del DOLAR --
  -------------------------------------
  ww_cotiz := pag_gen.fu_obt_cotizacion(pag_gen.fu_obt_mon_fuerte,v_fec_actual);
  ---------------------
  -- inserta cuentas --
  ---------------------
  insert into cb_bal_diario(cod_rubro, fecha)
  select substr(cb_rubros.cod_rubro,1,10), v_fec_actual
    from CB_SAL_CONSOLIDADOS, cb_rubros
   where CB_SAL_CONSOLIDADOS.cod_rubro(+) = cb_rubros.cod_rubro
     and imputable = 'N'
     and substr(cb_rubros.cod_rubro,11,5) = '00000'
   group by substr(cb_rubros.cod_rubro,1,10),v_fec_actual;
  -------------------------------------------------------
  -- inserta cuentas en auxiliar cuentas no imputables --
  -------------------------------------------------------
  insert into cb_bal_diario_tmp(cod_rubro, sal_anterior, deb_hoy,cre_hoy)
  select substr(cb_rubros.cod_rubro,1,10),
         sum(nvl(SAL_MON_LOC_ANT,0)),
         sum(nvl(DEB_MON_LOCAL,0)),
         sum(nvl(CRE_MON_LOCAL,0))
    from CB_SAL_CONSOLIDADOS, cb_rubros
   where CB_SAL_CONSOLIDADOS.cod_rubro(+) = cb_rubros.cod_rubro
     and imputable = 'N'
     and substr(cb_rubros.cod_rubro,11,5) = '00000'
   group by substr(cb_rubros.cod_rubro,1,10);
  --------------------------------------
  -- actualiza cuentas no imputables  --
  --------------------------------------
  update cb_bal_diario a
     set(sal_anterior, deb_hoy, cre_hoy) = (select sal_anterior, deb_hoy, cre_hoy
                                              from cb_bal_diario_tmp b
                                              where b.cod_rubro = a.cod_rubro)
   where exists (select 1
                   from cb_bal_diario_tmp c
                  where c.cod_rubro = a.cod_rubro)
     and fecha = v_fec_actual;

  delete cb_bal_diario_tmp;
  -----------------------------------------------------------------
  -- inserta cuentas en auxiliar cuentas imputables moneda local --
  -----------------------------------------------------------------
  insert into cb_bal_diario_tmp(cod_rubro, sal_anterior, deb_hoy,cre_hoy, SAL_MON_LOCAL)
  select substr(cb_rubros.cod_rubro,1,10),
         sum(nvl(SAL_MON_LOC_ANT,0)),
         sum(nvl(DEB_MON_LOCAL,0)),
         sum(nvl(CRE_MON_LOCAL,0)),
         sum(nvl(SAL_MON_LOC_ANT,0)+nvl(DEB_MON_LOCAL,0)-nvl(CRE_MON_LOCAL,0))
    from CB_SAL_CONSOLIDADOS, cb_rubros
   where CB_SAL_CONSOLIDADOS.cod_rubro(+) = cb_rubros.cod_rubro
     and imputable = 'S'
     and cod_moneda  = pag_gen.fu_obt_mon_local
   group by substr(cb_rubros.cod_rubro,1,10);
  ------------------------------------------------
  -- actualiza cuentas imputables moneda local  --
  ------------------------------------------------
  update cb_bal_diario a
     set SAL_MON_LOCAL = (select SAL_MON_LOCAL
                            from cb_bal_diario_tmp b
                           where b.cod_rubro = a.cod_rubro)
   where exists (select 1
                  from cb_bal_diario_tmp c
                 where c.cod_rubro = a.cod_rubro)
     and fecha = v_fec_actual;

  delete cb_bal_diario_tmp;
  ----------------------------------------------------------------------
  -- inserta cuentas en auxiliar cuentas imputables moneda extranjera --
  ----------------------------------------------------------------------
  insert into cb_bal_diario_tmp(cod_rubro, sal_anterior, deb_hoy,cre_hoy,
                                SAL_MON_LOCAL)
  select substr(cb_rubros.cod_rubro,1,10),
         sum(nvl(SAL_MON_LOC_ANT,0)),
         sum(nvl(DEB_MON_LOCAL,0)),
         sum(nvl(CRE_MON_LOCAL,0)),
         sum(nvl(SAL_MON_LOC_ANT,0)+nvl(DEB_MON_LOCAL,0)-nvl(CRE_MON_LOCAL,0))
    from CB_SAL_CONSOLIDADOS, cb_rubros
   where CB_SAL_CONSOLIDADOS.cod_rubro(+) = cb_rubros.cod_rubro
     and imputable = 'S'
     and cod_moneda <> pag_gen.fu_obt_mon_local
   group by substr(cb_rubros.cod_rubro,1,10);
  ----------------------------------------------------
  -- actualiza cuentas imputables moneda extranjera --
  ----------------------------------------------------
  update cb_bal_diario a
     set SAL_MON_ME = (select  SAL_MON_LOCAL
                         from cb_bal_diario_tmp b
                        where b.cod_rubro = a.cod_rubro)
   where exists (select 1 from cb_bal_diario_tmp c
                  where c.cod_rubro = a.cod_rubro)
     and fecha = v_fec_actual;
  delete cb_bal_diario_tmp;
  ---------------------------------------------
  -- actualiza cuentas con equivalencias USD --
  ---------------------------------------------
  update cb_bal_diario
     set sal_equivalente = nvl(SAL_MON_ME,0) / nvl(ww_cotiz,0)
   where nvl(SAL_MON_ME,0) <> 0
     and fecha = v_fec_actual;
  ---------------------------------------
  -- elimina cuentas padres duplicadas --
  ---------------------------------------
  delete cb_bal_diario
   where substr(cod_rubro,3,8) in (10000000,20000000,30000000,40000000,
                                    50000000,60000000,70000000,80000000)
     and fecha = v_fec_actual;
  ------------------------------------------------
  -- GENERA REGISTRO DE RESULTADO DEL EJERCICIO --
  ------------------------------------------------
  -- saldo de la cuenta 6000000000
  select sal_anterior into ww_sal6
    from cb_bal_diario
   where cod_rubro = 6000000000
     and fecha = v_fec_actual;

  -- saldo de la cuenta 7000000000
  select sal_anterior into ww_sal7
    from cb_bal_diario
   where cod_rubro = 7000000000
     and fecha = v_fec_actual;
  -- movimiento debito de hoy de la cuenta 6000000000 y 7000000000
  select sum(nvl(DEB_MON_LOCAL,0)) into ww_debi
    from CB_SAL_CONSOLIDADOS, cb_rubros
   where cb_rubros.cod_rubro = CB_SAL_CONSOLIDADOS.cod_rubro(+)
     and imputable = 'S'
     and substr(cb_rubros.cod_rubro,1,1) in ('6','7');
  -- movimiento credito de hoy de la cuenta 6000000000 y 7000000000
  select sum(nvl(CRE_MON_LOCAL,0)) into ww_cred
    from CB_SAL_CONSOLIDADOS, cb_rubros
   where cb_rubros.cod_rubro = CB_SAL_CONSOLIDADOS.cod_rubro(+)
     and imputable = 'S'
     and substr(cb_rubros.cod_rubro,1,1) in ('6','7');
  -- halla la diferencia entre ambos movimientos debitos y creditos
  select abs(nvl(ww_debi,0)-nvl(ww_cred,0))
    into ww_dife
    from dual;
 ww_sal_act := nvl(ww_sal6,0) + nvl(ww_sal7,0)+nvl(ww_debi,0)-nvl(ww_cred,0);
 if ww_sal_act < 0 then
    -- ganancia
      -- actualiza con la diferencia entre ambos saldos
      update cb_bal_diario set sal_anterior = nvl(ww_sal6,0) + nvl(ww_sal7,0)
       where cod_rubro in (3106000000,3106041800,3106041801)
         and fecha = v_fec_actual;
      -- verifica si la diferencia es positiva o negativa
      if nvl(ww_debi,0) > nvl(ww_cred,0) then
         -- actualiza el debito con la diferencia
         update cb_bal_diario set deb_hoy = nvl(ww_dife,0)
         where cod_rubro in (3106000000,3106041800,3106041801)
           and fecha = v_fec_actual;
      else
         -- actualiza el credito con la diferencia
         update cb_bal_diario set cre_hoy = nvl(ww_dife,0)
         where cod_rubro in (3106000000,3106041800,3106041801)
           and fecha = v_fec_actual;
      end if;
      -- calcula el saldo actual para utilidad del ejercicio
      update cb_bal_diario
         set SAL_MON_LOCAL=ww_sal_act
       where cod_rubro in (3106000000,3106041800,3106041801)
         and fecha=v_fec_actual;
      -- actualiza el saldo total para la utilidad del ejercicio
      update cb_bal_diario
         set SAL_TOTAL=nvl(SAL_MON_LOCAL,0)
       where cod_rubro in (3106000000,3106041800,3106041801)
         and fecha=v_fec_actual;
  else
     -- perdida
           -- actualiza con la diferencia entre ambos saldos
      update cb_bal_diario set sal_anterior = nvl(ww_sal6,0) + nvl(ww_sal7,0)
       where cod_rubro in (3106000000,3106042200,3106042201)
         and fecha = v_fec_actual;
      -- verifica si la diferencia es positiva o negativa
      if nvl(ww_debi,0) > nvl(ww_cred,0) then
         -- actualiza el debito con la diferencia
         update cb_bal_diario set deb_hoy = nvl(ww_dife,0)
         where cod_rubro in (3106000000,3106042200,3106042201)
           and fecha = v_fec_actual;
      else
         -- actualiza el credito con la diferencia
         update cb_bal_diario set cre_hoy = nvl(ww_dife,0)
         where cod_rubro in (3106000000,3106042200,3106042201)
           and fecha = v_fec_actual;
      end if;
      -- calcula el saldo actual para utilidad del ejercicio
      update cb_bal_diario
         set SAL_MON_LOCAL=ww_sal_act
       where cod_rubro in (3106000000,3106042200,3106042201)
         and fecha=v_fec_actual;
      -- actualiza el saldo total para la utilidad del ejercicio
      update cb_bal_diario
         set SAL_TOTAL=nvl(SAL_MON_LOCAL,0)
       where cod_rubro in (3106000000,3106042200,3106042201)
         and fecha=v_fec_actual;
  end if;
  ----------------------------------------
  -- PROCESO PARA SUMAR PATRIMONIO NETO --
  ----------------------------------------
  select sal_anterior, deb_hoy, cre_hoy
    into ww_util, ww_debi, ww_cred
    from cb_bal_diario
   where cod_rubro = 3106000000
     and fecha = v_fec_actual;
  update cb_bal_diario
     set sal_anterior = nvl(sal_anterior,0) + nvl(ww_util,0),
         deb_hoy = nvl(deb_hoy,0) + nvl(ww_debi,0),
         cre_hoy = nvl(cre_hoy,0) + nvl(ww_cred,0)
   where cod_rubro in (3000000000,3100000000)
     and fecha = v_fec_actual;
  update cb_bal_diario
     set SAL_MON_LOCAL=nvl(sal_anterior,0)+nvl(deb_hoy,0)-nvl(cre_hoy,0)
   where cod_rubro in (3000000000,3100000000)
     and fecha= v_fec_actual;
  update cb_bal_diario
     set SAL_TOTAL=nvl(SAL_MON_LOCAL,0)
   where cod_rubro in (3000000000,3100000000)
     and fecha=v_fec_actual;
  ----------------------------------------------
  -- SUMARIZA HACIA ARRIBIA MONEDA EXTRANJERA --
  ----------------------------------------------
  delete cb_bal_diario_tmp;
  insert into cb_bal_diario_tmp (cod_rubro, SAL_MON_ME)
  select substr(cod_rubro,1,8)||'00', sum(SAL_MON_ME)
    from cb_bal_diario
   where fecha = v_fec_actual
   group by substr(cod_rubro,1,8);
  delete cb_bal_diario_tmp
   where SAL_MON_ME is null;
  update cb_bal_diario a
     set SAL_MON_ME = (select SAL_MON_ME
                         from cb_bal_diario_tmp b
                        where b.cod_rubro = a.cod_rubro)
   where exists (select 1 from cb_bal_diario_tmp c
                  where c.cod_rubro = a.cod_rubro)
     and fecha = v_fec_actual;
  --
  delete cb_bal_diario_tmp;
  insert into cb_bal_diario_tmp (cod_rubro, SAL_MON_ME)
  select substr(cod_rubro,1,4)||'000000', sum(SAL_MON_ME)
    from cb_bal_diario
   where substr(cod_rubro,9,2) = '00'
     and fecha = v_fec_actual
   group by substr(cod_rubro,1,4);
  delete cb_bal_diario_tmp where SAL_MON_ME is null;
  update cb_bal_diario a
     set SAL_MON_ME = (select SAL_MON_ME
                         from cb_bal_diario_tmp b
                        where b.cod_rubro = a.cod_rubro)
   where exists (select 1 from cb_bal_diario_tmp c
                  where c.cod_rubro = a.cod_rubro)
     and fecha = v_fec_actual;
  --
  delete cb_bal_diario_tmp;
  insert into cb_bal_diario_tmp (cod_rubro, SAL_MON_ME)
  select substr(cod_rubro,1,2)||'00000000', sum(SAL_MON_ME)
    from cb_bal_diario
   where substr(cod_rubro,5,6) = '000000'
     and fecha = v_fec_actual
   group by substr(cod_rubro,1,2);
  delete cb_bal_diario_tmp where SAL_MON_ME is null;
  update cb_bal_diario a
     set SAL_MON_ME = (select SAL_MON_ME
                         from cb_bal_diario_tmp b
                        where b.cod_rubro = a.cod_rubro)
   where exists (select 1 from cb_bal_diario_tmp c
                  where c.cod_rubro = a.cod_rubro)
     and fecha = v_fec_actual;
  --
  delete cb_bal_diario_tmp;
  insert into cb_bal_diario_tmp (cod_rubro, SAL_MON_ME)
  select substr(cod_rubro,1,1)||'000000000', sum(SAL_MON_ME)
    from cb_bal_diario
   where substr(cod_rubro,4,7) = '0000000'
     and fecha = v_fec_actual
   group by substr(cod_rubro,1,1);
  delete cb_bal_diario_tmp where SAL_MON_ME is null;
  update cb_bal_diario a
     set SAL_MON_ME = (select SAL_MON_ME
                         from cb_bal_diario_tmp b
                        where b.cod_rubro = a.cod_rubro)
   where exists (select 1 from cb_bal_diario_tmp c
                  where c.cod_rubro = a.cod_rubro)
     and fecha = v_fec_actual;
  ---------------------------------------------
  -- actualiza cuentas con equivalencias USD --
  ---------------------------------------------
  update cb_bal_diario
     set sal_equivalente = nvl(SAL_MON_ME,0) / nvl(ww_cotiz,0)
   where nvl(SAL_MON_ME,0) <> 0
     and fecha = v_fec_actual;
  -----------------------------------------
  -- SUMARIZA HACIA ARRIBIA MONEDA LOCAL --
  -----------------------------------------
  delete cb_bal_diario_tmp;
  insert into cb_bal_diario_tmp (cod_rubro, SAL_MON_LOCAL)
  select substr(cod_rubro,1,8)||'00', sum(SAL_MON_LOCAL)
    from cb_bal_diario
   where fecha = v_fec_actual
   group by substr(cod_rubro,1,8);
  delete cb_bal_diario_tmp where SAL_MON_LOCAL is null;
  update cb_bal_diario a
     set SAL_MON_LOCAL = (select SAL_MON_LOCAL
                         from cb_bal_diario_tmp b
                        where b.cod_rubro = a.cod_rubro)
   where exists (select 1 from cb_bal_diario_tmp c
                  where c.cod_rubro = a.cod_rubro)
     and fecha = v_fec_actual;
  --
  delete cb_bal_diario_tmp;
  insert into cb_bal_diario_tmp (cod_rubro, SAL_MON_LOCAL)
  select substr(cod_rubro,1,4)||'000000', sum(SAL_MON_LOCAL)
    from cb_bal_diario
   where substr(cod_rubro,9,2) = '00'
     and fecha = v_fec_actual
   group by substr(cod_rubro,1,4);
  delete cb_bal_diario_tmp where SAL_MON_LOCAL is null;
  update cb_bal_diario a
     set SAL_MON_LOCAL = (select SAL_MON_LOCAL
                         from cb_bal_diario_tmp b
                        where b.cod_rubro = a.cod_rubro)
   where exists (select 1 from cb_bal_diario_tmp c
                  where c.cod_rubro = a.cod_rubro)
     and fecha = v_fec_actual;
  --
  delete cb_bal_diario_tmp;
  insert into cb_bal_diario_tmp (cod_rubro, SAL_MON_LOCAL)
  select substr(cod_rubro,1,2)||'00000000', sum(SAL_MON_LOCAL)
    from cb_bal_diario
   where substr(cod_rubro,5,6) = '000000'
     and fecha = v_fec_actual
   group by substr(cod_rubro,1,2);
  delete cb_bal_diario_tmp where SAL_MON_LOCAL is null;
  update cb_bal_diario a
     set SAL_MON_LOCAL = (select SAL_MON_LOCAL
                         from cb_bal_diario_tmp b
                        where b.cod_rubro = a.cod_rubro)
   where exists (select 1 from cb_bal_diario_tmp c
                  where c.cod_rubro = a.cod_rubro)
     and fecha = v_fec_actual;
  --
  delete cb_bal_diario_tmp;
  insert into cb_bal_diario_tmp (cod_rubro, SAL_MON_LOCAL)
  select substr(cod_rubro,1,1)||'000000000', sum(SAL_MON_LOCAL)
    from cb_bal_diario
   where substr(cod_rubro,4,7) = '0000000'
     and fecha = v_fec_actual
   group by substr(cod_rubro,1,1);
  delete cb_bal_diario_tmp where SAL_MON_LOCAL is null;
  update cb_bal_diario a
     set SAL_MON_LOCAL = (select SAL_MON_LOCAL
                         from cb_bal_diario_tmp b
                        where b.cod_rubro = a.cod_rubro)
   where exists (select 1 from cb_bal_diario_tmp c
                  where c.cod_rubro = a.cod_rubro)
     and fecha = v_fec_actual;
  -------------------------------------
  -- actualiza cuentas de patrimonio --
  -------------------------------------
  update cb_bal_diario a
     set SAL_MON_LOCAL = sal_anterior + deb_hoy - cre_hoy
   where substr(cod_rubro,1,1) = '3'
     and fecha = v_fec_actual;

end;
/

