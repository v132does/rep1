begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
end;
/
update ge_par_dinamicos s
set s.val_parametro='N'
where s.parametro='TAR_ACT_TRI_AUDITORIA';
commit;
