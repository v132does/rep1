begin
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;

  insert into ge_snp_patrocinador_cab
    (COD_BANCO, COD_SWIFT, COD_MONEDA, NRO_CTA_BANCARIA)
  values
    (43, 'BCOPPYPA', 'USD', 'BCOP1001USD');

  insert into ge_snp_patrocinador_det
    (COD_SWIFT_PADRE,
     COD_PERSONA,
     SUBPARTICIPANTE,
     COD_SWIFT_SUB,
     CTA_INTERNA_SUB,
     ESTADO)
  values
    ('BCOPPYPA',
     '317911',
     'COOP CHORTITZER USD',
     'BCOPPYPA1223',
     '0410358746',
     'S');

  commit;

end;
/
