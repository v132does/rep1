begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
update ge_snp_cta_entes
set principal='S'
where cod_ente = 22 and nro_cta_bancaria='SAMH1001PYG';

update ge_snp_cta_entes
set principal='N'
where cod_ente = 22 and nro_cta_bancaria='MH1001PYG';
commit;
