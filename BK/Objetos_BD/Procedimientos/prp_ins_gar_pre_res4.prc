create or replace procedure it.prp_ins_gar_pre_res4(p_nro_cta_ori in varchar2,
                                                 p_nro_cta_des in varchar2,
                                                 p_mto_capital in number) is
  --Proceso que genera las garantias de prestamos Resol4--
  --Toma como base las garantias de cta origen--

  --Variables--
  v_tot_aplicado number(18,2);
  v_reg_aux      varchar2(100);
  v_diferencia   number(18,2);

  --Cursores--                                            p_mto_capital in number) is
  cursor c_gar_detalles is
  select x.*, z.tot_aplicado, decode(z.tot_aplicado,0,0,x.mto_aplicado/z.tot_aplicado),
         decode(z.tot_aplicado,0,0,round((x.mto_aplicado/z.tot_aplicado)*p_mto_capital,
         decode(h.cod_moneda,'GS',0,2))) mto_apl_new,
         nvl(mto_apl_computable,0) mto_com_new
    from pr_cta_garantias x, pr_cta_prestamos h,
    (select y.nro_cuenta,
            sum(nvl(y.mto_aplicado,0)) tot_aplicado
       from pr_cta_garantias y
      group by y.nro_cuenta) z
   where x.nro_cuenta = p_nro_cta_ori
     and x.nro_cuenta = z.nro_cuenta
     and h.nro_cuenta = x.nro_cuenta;

   cursor c_gar_ajustes is
   select y.*, y.rowid registro
     from pr_cta_garantias y
    where y.nro_cuenta = p_nro_cta_des
      and nvl(y.mto_aplicado,0) > 0
    order by y.mto_aplicado;

begin
  for det in c_gar_detalles loop
      insert into pr_cta_garantias
      (nro_cuenta, nro_garantia, cod_garantia,
       mto_aplicado, mto_con_computable, mto_apl_computable,
       mto_con_nocomputable, porcentaje, cod_persona,
       mto_riesgo, ind_pagare)
      values
      (p_nro_cta_des, det.nro_garantia, det.cod_garantia,
       det.mto_apl_new, det.mto_con_computable,
       decode(det.mto_com_new,0,0,det.mto_apl_new),
       det.mto_con_nocomputable, det.porcentaje, det.cod_persona,
       det.mto_riesgo, det.ind_pagare);
  end loop;

  v_tot_aplicado := 0;
  for aju in c_gar_ajustes loop
      v_tot_aplicado := nvl(v_tot_aplicado,0) + nvl(aju.mto_aplicado,0);
      v_reg_aux := aju.registro;
  end loop;
  v_diferencia := nvl(v_tot_aplicado,0) - nvl(p_mto_capital,0);
  if nvl(v_diferencia,0) <> 0 then
     update pr_cta_garantias z
        set z.mto_aplicado = nvl(z.mto_aplicado,0) - nvl(v_diferencia,0),
            z.mto_apl_computable = decode(z.mto_apl_computable,0,0,nvl(z.mto_apl_computable,0) - nvl(v_diferencia,0))
      where rowid = v_reg_aux;
  end if;

exception
  when others then
    raise_application_error(-20000,'Error en prp_ins_gar_pre_res4: '||sqlerrm);
end;
/

