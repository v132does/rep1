Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update ba_consultas
set    det_sql =
'SELECT a.referencia,
       b.nro_documento,
       a.val_parametro AS cel_onb,
       (SELECT g.val_parametro
          FROM ba_tab_dat_adicionales g
         WHERE g.referencia = b.cod_persona
           AND g.parametro = ''EMAIL_ONBOARDING'') mail_onb
  FROM ba_tab_dat_adicionales a, ba_personas b
 WHERE a.referencia = b.cod_persona
   AND a.parametro = ''CELULAR_ONBOARDING''
   AND (&'||'P_FILTROS)',
   filtros = 'NULL'
where cod_consulta='CD_ONB_PER';

delete from ba_par_consultas where cod_consulta='CD_ONB_PER' and cod_campo='PERSONA';

insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_ONB_PER', 'NRO_DOCU', 'b', null, 'F', 1, 'V', 'S', 'N', NULL);

commit;   
