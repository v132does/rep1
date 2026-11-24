Begin 
  dbms_session.set_identifier('FSOP-63106');
  pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
end; 
/
insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_CAUSAL', 'TIP_CAUSA', 'g', 'I-Inhibición', 'F', 1, 'V', 'S', 'N', null);

commit;
