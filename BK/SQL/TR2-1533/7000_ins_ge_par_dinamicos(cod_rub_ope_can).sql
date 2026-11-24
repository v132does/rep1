begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; End; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION)
values ('COD_RUB_OPE_CAN', 'RUBRO CONTABLE PARA OP. CANCELADAS', 'GE_PAR_DINAMICOS', 'Son los rubros contables (Gs/Usd) utilizados en devoluciones de operaciones de cuentas canceladas');
commit;
