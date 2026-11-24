Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update ba_consultas
set    det_sql =
'SELECT b.nro_documento,
       a.val_parametro AS cel_onb,
       (SELECT g.val_parametro
          FROM ba_tab_dat_adicionales g
         WHERE g.referencia = b.cod_persona
           AND g.parametro = ''EMAIL_ONBOARDING'') mail_onb
  FROM ba_tab_dat_adicionales a, ba_personas b
 WHERE a.referencia = b.cod_persona
   AND a.parametro = ''CELULAR_ONBOARDING''
   AND ('||'&'||'P_FILTROS)',
   filtros = 'NULL'
where cod_consulta='CD_ONB_PER';

commit;   
