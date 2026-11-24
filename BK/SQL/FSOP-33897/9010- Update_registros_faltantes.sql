BEGIN pre_ini_aplicacion; END; 

update sb_snp_mensajes s
set s.fec_insercion = TO_DATE('01/07/2024 10:00','DD/MM/YYYY HH24:MI')
where cod_mensaje = 'MT940'
and nro_referencia = 'S254938560/940'
and fec_insercion in (to_date('31/07/2024 16:21:25', 'dd/mm/yyyy hh24:mi:ss') , to_date('31/7/2024 16:22:06', 'dd/mm/yyyy hh24:mi:ss'));

update ge_snp_mensajes s
set s.fec_insercion = TO_DATE('01/07/2024 10:00','DD/MM/YYYY HH24:MI')
where nro_referencia = 'S254938560/940'
and nro_ref_externa in ('123/325', '123/361');

commit;