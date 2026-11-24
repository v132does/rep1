declare
  v_existe varchar2(1);
begin
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  begin
    select 'S'
      into v_existe
      from ge_par_entes c
     where parametro = 'NRO_CTA_ESCRIBANIA'
       and cod_ente = 6;
  exception
    when others then
      v_existe := 'N';
  end;
  
  if v_existe = 'S' then
    update ge_par_entes
       set val_parametro = '263008021'
     where parametro = 'NRO_CTA_ESCRIBANIA'
       and cod_ente = 6;
    commit;
  else
  
    insert into ge_par_entes
      (cod_ente,
       parametro,
       val_parametro,
       usu_insercion,
       fec_insercion,
       usu_modificacion,
       fec_modificacion)
    values
      (6, 'NRO_CTA_ESCRIBANIA', '263008021', user, sysdate, user, sysdate);
    commit;
  end if;
end;
