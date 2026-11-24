BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END;
/

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('PRE_PLA_20_ANHOS',7300);


insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('PRE_REQ_FUSION', 'S');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('FEC_INI_DIF', '30/06/2024');

commit; 
