begin
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;
end;
/ 
insert into ba_consultas
  (cod_consulta,
   descripcion,
   cod_usuario,
   tipo,
   permiso,
   observacion,
   det_sql,
   filtros,
   col_cortes,
   col_sumas/*,
   parametros*/)
values
  ('CD_CHEROGA',
   'Clientes con oferta de préstamo Che Roga.',
   'IT',
   'G',
   'INFORMATICA-INFORMATICA',
   'Clientes con oferta de préstamo Che Roga.',
   'select nro_oferta,
       nro_doc_solicitante,
       cod_per_solicitante,
       fue_obt_nom_persona(cod_per_solicitante) nombre_solicitante,
       fug_val_con_uni_per(cod_per_solicitante) tiene_cu_solicitante,
       nro_doc_invitado,
       cod_per_invitado,
       fue_obt_nom_persona(cod_per_invitado) nombre_invitado,
       fug_val_con_uni_per(cod_per_invitado) tiene_cu_invitado,
       inv_acepto acepto_invitado,
       fec_oferta fecha_solicitud,
       fec_vencimiento fecha_vencimiento,
       estado estado_oferta,
       mto_total monto_total,
       nro_solicitud nro_solicitud_prestamo
  from pr_pre_che_roga
  where &' || 'P_FILTROS',
   'ROWNUM IS NOT NULL',
   null,
   null/*,
   'rownum is not null'*/);

commit;
