create or replace procedure it.prb_val_cta_puente(p_cod_rubro in cb_rubros.cod_rubro%type) is
--- Realizado por ICL - 20091230 (BBVA)
--- Permite verificar si las cuentas puentes cierran entre si a pedido de Hector B.
   cursor c_asientos is
   select d.*, r.cod_rub_externo
     from cb_asi_automaticos_det d, cb_rubros r
    where d.cod_rubro = p_cod_rubro
      and d.cod_rubro = r.cod_rubro
      and d.tip_movimiento='D'
    order by d.fecha, d.nro_asiento, d.nro_linea;
   --- Variables
   v_nro_asi_hab cb_asi_automaticos_det.nro_asiento%type;
   v_nro_lin_hab cb_asi_automaticos_det.nro_linea%type;
   v_cod_ofi_hab cb_asi_automaticos_det.cod_oficina%type;
   v_ref_mov_hab cb_asi_automaticos_det.ref_movimiento%type;
   v_fec_haber   cb_asi_automaticos_det.fecha%type;
   v_mto_haber   cb_asi_automaticos_det.mto_mon_local%type;
begin
   delete tm_rub_cuadres where cod_rubro = p_cod_rubro;
   for reg in c_asientos loop
      --- Recuperar creditos
      v_nro_asi_hab := null;
      v_nro_lin_hab := null;
      v_cod_ofi_hab := null;
      v_ref_mov_hab := null;
      v_fec_haber   := null;
      v_mto_haber   := null;
      begin
         select e.fecha, e.nro_asiento, e.nro_linea, e.cod_oficina, e.ref_movimiento, e.mto_mon_local
           into v_fec_haber, v_nro_asi_hab, v_nro_lin_hab, v_cod_ofi_hab, v_ref_mov_hab,v_mto_haber
           from cb_asi_automaticos_det e
          where e.cod_rubro = p_cod_rubro
            and e.tip_movimiento='C'
            and e.mto_mon_local=reg.mto_mon_local
            and rownum=1
          order by e.fecha, e.nro_asiento;
      exception
         when no_data_found then
            null;
      end;
      insert into tm_rub_cuadres(cod_rubro, cod_rub_externo, 
         fec_asi_deb, nro_asi_deb, nro_lin_deb, mto_debe, ref_mov_deb, cod_ofi_deb,
         fec_asi_hab, nro_asi_hab, nro_lin_hab, mto_haber, ref_mov_hab, cod_ofi_hab)
      values(reg.cod_rubro, reg.cod_rub_externo, 
         reg.fecha, reg.nro_asiento, reg.nro_linea, reg.mto_mon_local, reg.ref_movimiento, reg.cod_oficina,
         v_fec_haber, v_nro_asi_hab, v_nro_lin_hab, v_mto_haber, v_ref_mov_hab, v_cod_ofi_hab);
   end loop;
   --- insertar los creditos que no fueron cuadrados
   insert into tm_rub_cuadres(cod_rubro, cod_rub_externo, fec_asi_hab,
      nro_asi_hab, nro_lin_hab, mto_haber, ref_mov_hab, cod_ofi_hab)
   select d.cod_rubro, r.cod_rub_externo, d.fecha,
      d.nro_asiento, d.nro_linea, d.mto_mon_local, d.ref_movimiento, d.cod_oficina
     from cb_asi_automaticos_det d, cb_rubros r
    where d.cod_rubro = p_cod_rubro
      and d.cod_rubro = r.cod_rubro
      and d.tip_movimiento='C'
      and not exists(select 1 from tm_rub_cuadres r
                      where r.cod_rubro = d.cod_rubro
                        and d.nro_asiento = r.nro_asi_hab
                        and d.nro_linea = r.nro_lin_hab);
end prb_val_cta_puente;
/

