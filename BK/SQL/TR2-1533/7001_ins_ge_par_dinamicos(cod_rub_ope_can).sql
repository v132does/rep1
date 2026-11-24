begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; End; 
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MONEDA)
values ('COD_RUB_OPE_CAN', '240402600224599', 'GS');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MONEDA)
values ('COD_RUB_OPE_CAN', '240402600223401', 'USD');
commit;
