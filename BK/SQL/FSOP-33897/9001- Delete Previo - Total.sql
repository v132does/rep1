begin
  
  BEGIN pre_ini_aplicacion; END;

  delete from sb_snp_mensajes s
  where s.nro_referencia in (select m.nro_referencia from ge_snp_mensajes m
  where m.fec_valor in ('01/07/2024','02/07/2024','08/07/2024')
  and m.cod_msj_swift in (940, 970))
  and s.cod_mensaje in ('MT940', 'MT970');  

  delete from ge_snp_mensajes s
  where cod_msj_swift in (940,970)
  and fec_valor in ('01/07/2024','02/07/2024','08/07/2024');

  commit;

end;
