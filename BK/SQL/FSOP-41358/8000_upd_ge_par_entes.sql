begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end; 
/

update ge_par_entes d
set d.val_parametro = 'UENOBANK_MORAWS_27155'
where d.cod_ente = 9000
and parametro = 'USR_INFORMCONF'
;


update ge_par_entes d
set d.val_parametro = fug_enc_clave ('M3*pQ7-d')
where d.cod_ente = 9000
and parametro = 'USR_PAS_INFORMCONF'
;


commit;

