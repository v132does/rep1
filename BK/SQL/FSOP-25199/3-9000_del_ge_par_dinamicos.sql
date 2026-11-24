BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END;
/
delete from ge_par_dinamicos b
where b.parametro='PRE_MAD_EXC_PYMES'
and   b.cod_modalidad in (634,645,642);

commit;
