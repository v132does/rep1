begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
end;
/
update ge_par_dinamicos s 
set s.val_parametro= replace(s.val_parametro,'http://172.20.20.204:4101/ms-credit-cards/','https://kongcloud-private.ind-prod-sae1.ueno.com.py/creditcards/v1/')
where s.val_parametro like ('%ms-credit-cards%');

update ge_par_dinamicos s 
set s.val_parametro= replace(s.val_parametro,'http://172.20.20.204:4100/alfa.ms.transactionals-products/','https://kongcloud-private.ind-prod-sae1.ueno.com.py/prepaycards/v1/')
where s.val_parametro like ('%alfa.ms.transactionals-products%');
commit;
