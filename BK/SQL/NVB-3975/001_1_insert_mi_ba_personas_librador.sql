-- Created on 2/6/2021 by EVER.AYALA 
declare
  i integer;
  CURSOR c_ba_per IS
      select p.*
      from ba_personas@uenodesg p 
      where not exists (select 1 
                          from it.ba_personas w
                        where w.nro_documento = p.nro_documento)
        and exists (select 1 
                      from it.pr_chq_libradores l
                     where l.nro_documento = p.nro_documento);
  v_cant number;
begin
  v_cant := 0;
  --
  delete from it.mi_ba_personas_librador;
  --
  FOR pj IN c_ba_per LOOP
    v_cant := v_cant + 1;
    BEGIN
      insert into it.mi_ba_personas_librador
        (cod_persona,
         nom_completo,
         tipo,
         cod_usu_promotor,
         cod_tip_documento,
         nro_documento,
         cod_pais,
         dir_correo,
         cod_actividad,
         tot_ingresos,
         ing_presuntos,
         egr_presuntos,
         est_verificacion,
         cod_usu_verificador,
         nom_per_informo,
         obs_verificacion,
         fec_verificacion,
         tip_relacion,
         fec_vto_documento,
         tip_iva,
         tas_personalizada,
         recibe_sms,
         cod_pai_documento,
         cod_rub_primario,
         cod_rub_secundario,
         cod_rub_terciario,
         cod_ciu_origen)
      values
        (pj.cod_persona,
         pj.nom_completo,
         pj.tipo,
         pj.cod_usu_promotor,
         pj.cod_tip_documento,
         pj.nro_documento,
         pj.cod_pais,
         pj.dir_correo,
         pj.cod_actividad,
         pj.tot_ingresos,
         pj.ing_presuntos,
         pj.egr_presuntos,
         pj.est_verificacion,
         pj.cod_usu_verificador,
         pj.nom_per_informo,
         pj.obs_verificacion,
         pj.fec_verificacion,
         pj.tip_relacion,
         pj.fec_vto_documento,
         pj.tip_iva,
         pj.tas_personalizada,
         pj.recibe_sms,
         pj.cod_pai_documento,
         pj.cod_rub_primario,
         pj.cod_rub_secundario,
         pj.cod_rub_terciario,
         pj.cod_ciu_origen);

    EXCEPTION
      WHEN OTHERS THEN
        dbms_output.put_line('ERROR; ' || v_cant || ' DOCUMENTO ' ||
                             PJ.cod_persona);
    END;
  END LOOP;
  commit;
exception
  when others then
    dbms_output.put_line(SQLERRM);
end;
