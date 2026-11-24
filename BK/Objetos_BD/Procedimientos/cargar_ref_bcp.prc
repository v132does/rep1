create or replace procedure it.cargar_ref_bcp is
/*cursor consulta is
       select decode(t.tipo_per,'F',2,1) tipo_per_dec,t.* from personas_ref_tmp t
       where not exists ( select 1 from  personas_ref  b
       where b.rf_tipo_ident = t.tipo_ident
       and b.rf_numero = t.nro_documento);*/
begin
  /*for x in consulta loop
      insert into  bcp.personas_ref
      ( personas_ref.rf_tipo_ident,
       personas_ref.rf_numero,
       personas_ref.rf_pais_swift,
       personas_ref.rf_nombre,
       personas_ref.rf_apellido,
       personas_ref.rf_tipo_per,
       personas_ref.rf_fecha_nac,    
       personas_ref.rf_ajuste_nac,
       personas_ref.rf_version,
       personas_ref.rf_fecha_ver,
       personas_ref.rf_fecha_alta,
       personas_ref.rf_fecha_baja)
      VALUES
      (x.tipo_ident,
      x.nro_documento,
      null,
      x.nombre,
      x.apellido,
      x.tipo_per_dec,
      x.fecha_nac,
      null,
      null,
      null,
      null,
      null);
  end loop;
  commit;*/
  NULL;
end cargar_ref_bcp;
/

