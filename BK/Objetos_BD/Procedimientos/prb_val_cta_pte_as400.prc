create or replace procedure it.prb_val_cta_pte_AS400 is
--- Realizado por ICL - 20091230 (BBVA)
--- Permite verificar si las cuentas puentes cierran entre si a pedido de Hector B.
   cursor c_asientos is
   select * 
     from tm_as_cuadres t
    where t.tip_movimiento=1
    order by t.fec_as;
   --- Variables
   v_nro_asi_hab number(10);
   v_nro_lin_hab cb_asi_automaticos_det.nro_linea%type;
   v_cod_ofi_hab cb_asi_automaticos_det.cod_oficina%type;
   v_ref_mov_hab cb_asi_automaticos_det.ref_movimiento%type;
   v_fec_haber   cb_asi_automaticos_det.fecha%type;
   v_mto_haber   cb_asi_automaticos_det.mto_mon_local%type;
   v_cod_rub_ext_hab tm_rub_cuadres.cod_rub_ext_hab%type;
begin
   delete tm_rub_cuadres;
   for reg in c_asientos loop
      --- Recuperar creditos
      v_nro_asi_hab := null;
      v_nro_lin_hab := null;
      v_cod_ofi_hab := null;
      v_ref_mov_hab := null;
      v_fec_haber   := null;
      v_mto_haber   := null;
      v_cod_rub_ext_hab := null;
      begin
         select to_date(e.fec_as,'YMMDD'), nro_asiento, null, e.cod_oficina, null, e.monto, e.cod_rub_externo
           into v_fec_haber, v_nro_asi_hab, v_nro_lin_hab, v_cod_ofi_hab, v_ref_mov_hab,v_mto_haber, v_cod_rub_ext_hab
           from tm_as_cuadres e
          where (e.cod_rub_externo = reg.cod_rub_externo or e.cod_rub_externo <> reg.cod_rub_externo)
            and e.tip_movimiento=2
            and e.monto=reg.monto
            --and e.fec_as = reg.fec_as
            and rownum=1
          order by e.fec_as;
      exception
         when no_data_found then
            null;
      end;
      insert into tm_rub_cuadres(cod_rubro, cod_rub_externo, 
         fec_asi_deb, nro_asi_deb, nro_lin_deb, mto_debe, ref_mov_deb, cod_ofi_deb,
         fec_asi_hab, nro_asi_hab, nro_lin_hab, mto_haber, ref_mov_hab, cod_ofi_hab, cod_rub_ext_hab)
      values(null, reg.cod_rub_externo, 
         to_date(reg.fec_as,'YMMDD'), reg.nro_asiento, null, reg.monto, null, reg.cod_oficina,
         v_fec_haber, v_nro_asi_hab, v_nro_lin_hab, v_mto_haber, v_ref_mov_hab, v_cod_ofi_hab, v_cod_rub_ext_hab);
   end loop;
   --- insertar los creditos que no fueron cuadrados
   insert into tm_rub_cuadres(cod_rubro, cod_rub_externo, fec_asi_hab,
      nro_asi_hab, nro_lin_hab, mto_haber, ref_mov_hab, cod_ofi_hab, cod_rub_ext_hab)
   select null, d.cod_rub_externo, to_date(d.fec_as,'YMMDD'),
      d.nro_asiento, null, d.monto, null, d.cod_oficina, d.cod_rub_externo
     from tm_as_cuadres d
    where d.tip_movimiento=2
      and not exists(select 1 from tm_rub_cuadres r
                      where r.cod_rub_externo = d.cod_rub_externo
                        and to_date(d.fec_as,'YMMDD')=r.fec_asi_hab
                        and d.nro_asiento = r.nro_asi_hab);
end;
/

