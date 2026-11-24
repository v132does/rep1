create or replace procedure it.PRB_ACT_SAL_UTILIDAD is
v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(2);
v_mes number := to_char(v_fec_actual,'MM');
v_ano number := to_char(v_fec_actual,'YYYY');
v_mto_debito  number(18,2);
v_mto_credito number(18,2);
v_tip_movimiento varchar2(1);
cursor c_oficinas is
   select cod_oficina, 
          nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0) saldo
     from cb_sal_oficinas a
    where a.cod_rubro in ('310604180100199','310604220100199')
      and nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0) <> 0;
begin
for ofi in c_oficinas loop
    --Cerar los saldos de las cuentas--
    if nvl(ofi.saldo,0) < 0 then
       --Debe cerar las ganancias--
       v_tip_movimiento:= 'D';
       v_mto_debito := abs(ofi.saldo);
       v_mto_credito := 0;
       update cb_sal_oficinas x
          set x.sal_mon_loc_ant = nvl(x.sal_mon_loc_ant,0) + 
                                  nvl(v_mto_debito,0) -
                                  nvl(v_mto_credito,0)
       where cod_oficina = ofi.cod_oficina
         and cod_rubro in ('310604180000000','310604180100000','310604180100199')
         and ano = v_ano
         and mes = v_mes;
    else
       --Debe cerar las perdidas--
       v_tip_movimiento := 'C';
       v_mto_debito := 0;
       v_mto_credito := abs(ofi.saldo);
       update cb_sal_oficinas x
          set x.sal_mon_loc_ant = nvl(x.sal_mon_loc_ant,0) + 
                                  nvl(v_mto_debito,0) -
                                  nvl(v_mto_credito,0)
       where cod_oficina = ofi.cod_oficina
         and cod_rubro in ('310604220000000','310604220100000','310604220100199')
         and ano = v_ano
         and mes = v_mes;
    end if;
    --Actualizar las cuentas padres--
    update cb_sal_oficinas x
          set deb_mon_local = nvl(x.deb_mon_local,0) + nvl(v_mto_debito,0),
              cre_mon_local = nvl(x.cre_mon_local,0) + nvl(v_mto_credito,0)
       where cod_oficina = ofi.cod_oficina
         and cod_rubro in ('300000000000000','310000000000000','310600000000000')
         and ano = v_ano
         and mes = v_mes;
end loop;
exception
  when others then
       raise_application_error(-20000,'Error en PRB_ACT_SAL_UTILIDAD'||sqlerrm);
end;
/

