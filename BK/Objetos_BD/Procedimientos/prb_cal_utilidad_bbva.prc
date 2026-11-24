CREATE OR REPLACE PROCEDURE IT.PRB_CAL_UTILIDAD_BBVA is
ww_sal7 number;
ww_sal6 number;
ww_debi number;
ww_cred number;
ww_dife number;
ww_deb_hoy number;
ww_cre_hoy number;
ww_sal_act number;
ww_util number;
v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(2);
v_mes number := to_char(v_fec_actual,'MM');
v_ano number := to_char(v_fec_actual,'YYYY');
cursor  ofi is
   select distinct cod_oficina
     from cb_sal_oficinas;
begin
  -- Eliminar tabla auxiliar de utilidades por si existe reproceso.
  delete CB_MAY_UTILIDADES u
   where u.fecha=v_fec_actual;
  for o in ofi loop
    ww_sal7 := 0;
    ww_sal6 := 0;
    ww_debi := 0;
    ww_cred := 0;
    -- cargo los rubros de utilidad por si no existan
    insert into cb_sal_oficinas
               (cod_oficina, cod_rubro, ano, mes)
        select o.cod_oficina, b.cod_rubro, v_ano, v_mes
          from cb_rubros b
         where cod_rubro in ('310604180000000','310604180100000','310604180100199',
                             '310604220000000','310604220100000','310604220100199',
                             '310600000000000','310000000000000','300000000000000')
           and not exists (select 0 from cb_sal_oficinas a
                            where a.cod_rubro = b.cod_rubro
                              and a.mes = v_mes
                              and a.ano = v_ano
                              and a.cod_oficina = o.cod_oficina);
    -- saldo de la cuenta GANANCIAS
    begin
    select sum(nvl(sal_mon_loc_ant,0))
      into ww_sal6
      from cb_sal_oficinas
     where cod_rubro = '600000000000000'
       and mes = v_mes and ano = v_ano
       and cod_oficina = o.cod_oficina;
    -- saldo de la cuenta PERDIDAS
    select sum(nvl(sal_mon_loc_ant,0))
      into ww_sal7
      from cb_sal_oficinas
     where cod_rubro = '700000000000000'
       and mes = v_mes and ano = v_ano
       and cod_oficina = o.cod_oficina;
    exception
       when others then
        raise_application_error(-20000,'Error al buscar la Ganancia o Perdida de la Oficina '||o.cod_oficina|| ' Mes '||v_mes||'/'||v_ano);
    end;
    -- movimiento debito de hoy de la cuenta 6000000000 y 7000000000
    select sum(nvl(DEB_MON_LOCAL,0))
      into ww_debi
      from CB_SAL_oficinas, cb_rubros
     where cb_rubros.cod_rubro = cb_sal_oficinas.cod_rubro
       and imputable = 'S'
       and cod_oficina = o.cod_oficina
       and substr(cb_rubros.cod_rubro,1,1) in ('6','7');
    -- movimiento credito de hoy de la cuenta 6000000000 y 7000000000
    select sum(nvl(CRE_MON_LOCAL,0))
      into ww_cred
      from CB_SAL_OFICINAS, cb_rubros
     where cb_rubros.cod_rubro = CB_SAL_OFICINAS.cod_rubro
       and imputable = 'S'
       and cod_oficina = o.cod_oficina
       and substr(cb_rubros.cod_rubro,1,1) in ('6','7');
    -- halla la diferencia entre ambos movimientos debitos y creditos
    ww_dife :=  abs(nvl(ww_debi,0)-nvl(ww_cred,0));
    -- calculo el saldo actual
    ww_sal_act := nvl(ww_sal6,0) + nvl(ww_sal7,0)+nvl(ww_debi,0)-nvl(ww_cred,0);
    -- calculo el debito y credito de hoy
    if nvl(ww_debi,0) > nvl(ww_cred,0) then
       ww_deb_hoy := nvl(ww_dife,0);
       ww_cre_hoy := 0;
    else
       ww_cre_hoy := nvl(ww_dife,0);
       ww_deb_hoy :=0;
    end if;
    -- si es ganancia
    if ww_sal_act < 0 then
    -- Modificado por Ingrid Larráin : 29/07/2011, porque el BBVA expone siempre GANANCIA.
        -- actualiza con la diferencia entre ambos saldos
        update cb_sal_oficinas
           set /*sal_mon_loc_ant = nvl(ww_sal6,0) + nvl(ww_sal7,0),
               */deb_mon_local   = ww_deb_hoy,
               cre_mon_local   = ww_cre_hoy
         where cod_rubro in ('310604180000000','310604180100000','310604180100199')
           and mes = v_mes and ano = v_ano
           and cod_oficina = o.cod_oficina;
        -- cero los datos de las perdidas
        update cb_sal_oficinas
           set /*sal_mon_loc_ant = 0,
               */deb_mon_local   = 0,
               cre_mon_local   = 0
         where cod_rubro in ('310604220000000','310604220100000','310604220100199')
           and mes = v_mes and ano = v_ano
           and cod_oficina = o.cod_oficina;
    else
        -- perdida
        -- actualiza con la diferencia entre ambos saldos
        update cb_sal_oficinas
           set /*sal_mon_loc_ant = nvl(ww_sal6,0) + nvl(ww_sal7,0),
--           set sal_mon_loc_ant = nvl(ww_sal6,0) + nvl(ww_sal7,0), --ANTES
               */deb_mon_local   = ww_deb_hoy,
               cre_mon_local   = ww_cre_hoy
         where cod_rubro in ('310604180000000','310604180100000','310604180100199')
---         where cod_rubro in ('310604220000000','310604220100000','310604220100199') --ANTES
           and mes = v_mes and ano = v_ano
           and cod_oficina = o.cod_oficina;
        -- actualiza en cero las ganancias
        update cb_sal_oficinas
           set /*sal_mon_loc_ant = 0,
               */deb_mon_local   = 0,
               cre_mon_local   = 0
         where cod_rubro in ('310604220000000','310604220100000','310604220100199')
--         where cod_rubro in ('310604180000000','310604180100000','310604180100199') --ANTES
           and mes = v_mes and ano = v_ano
           and cod_oficina = o.cod_oficina;
    end if;
    -- actualizo el padre comun
    update cb_sal_oficinas
           set deb_mon_local   = ww_deb_hoy,
               cre_mon_local   = ww_cre_hoy
         where cod_rubro = '310600000000000'
           and mes = v_mes and ano = v_ano
           and cod_oficina = o.cod_oficina;
    ----------------------------------------
    -- sumarizacion de patrimonio
    ----------------------------------------
    update cb_sal_oficinas
       set deb_mon_local = nvl(deb_mon_local,0) + nvl(ww_deb_hoy,0),
           cre_mon_local = nvl(cre_mon_local,0) + nvl(ww_cre_hoy,0)
     where cod_rubro in ('300000000000000','310000000000000')
       and mes = v_mes and ano = v_ano
       and cod_oficina = o.cod_oficina;
     --- Insertar tabla del Mayor de Ganancias y Pérdidas
     insert into CB_MAY_UTILIDADES(cod_oficina, cod_rubro, fecha, 
                 deb_mon_local, cre_mon_local, deb_mon_rubro, cre_mon_rubro)
     values (o.cod_oficina, '310604180100199', v_fec_actual,
             nvl(ww_deb_hoy,0),  nvl(ww_cre_hoy,0), 0 /*ww_sal6*/, 0 /*ww_sal7*/);
  end loop;
end;
/

