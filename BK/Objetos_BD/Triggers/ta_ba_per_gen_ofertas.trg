create or replace trigger it.ta_ba_per_gen_ofertas
  after delete
  on BA_PER_GEN_OFERTAS
  for each row
declare
  -- local variables here
begin
  BEGIN
    insert into ba_per_gen_ofertas_his(cod_registro,
                                       fec_consulta,
                                       cod_persona,
                                       mto_lim_prestable,
                                       cod_cat_crc,
                                       tot_deu_crc,
                                       mto_cuo_aproximado,
                                       faja,
                                       fec_ing_set,
                                       ant_infomercio,
                                       mto_oferta,
                                       can_cuotas,
                                       cod_moneda,
                                       rta_servicio,
                                       rta_rrnn,
                                       est_servicios,
                                       est_rrnn,
                                       error,
                                       mto_ingreso)
                               VALUES(:old.cod_registro,
                                      :old.fec_consulta,
                                      :old.cod_persona,
                                      :old.mto_lim_prestable,
                                      :old.cod_cat_crc,
                                      :old.tot_deu_crc,
                                      :old.mto_cuo_aproximado,
                                      :old.faja,
                                      :old.fec_ing_set,
                                      :old.ant_infomercio,
                                      :old.mto_oferta,
                                      :old.can_cuotas,
                                      :old.cod_moneda,
                                      :old.rta_servicio,
                                      :old.rta_rrnn,
                                      :old.est_servicios,
                                      :old.est_rrnn,
                                      :old.error,
                                      :old.mto_ingreso);
 EXCEPTION
   WHEN dup_val_on_index THEN
        null;
   WHEN OTHERS THEN
       raise_application_error(-20002,
                                'Error al insertar  ba_per_gen_ofertas_his: ' ||
                                sqlerrm || ' Cod persona: ' ||
                                :old.cod_persona);
 END;
end ta_ba_per_gen_ofertas;
/
