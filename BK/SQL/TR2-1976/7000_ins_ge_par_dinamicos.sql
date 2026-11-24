begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
end;
/
insert into GE_PARAMETROS (PARAMETRO, DESCRIPCION, OBSERVACION, MODIFICABLE, TAB_RELACION)
values ('TAR_NRO_CTA_FICTICIA', 'NRO. CTA. FICTICIA GP ARC. 2001', 'Parametro donde meteremos la cuenta ficticia para su uso en el archivo 2001', 'N', 'GE_PAR_DINAMICOS');

insert into GE_PARAMETROS (PARAMETRO, DESCRIPCION, OBSERVACION, MODIFICABLE, TAB_RELACION)
values ('TAR_VAL_ICA_ADELANTO', 'VALOR ICA ADELANTO EFE. ARC. 2001', 'Valor ICA para identificar el Adelanto de Efectivo en el archivo 2001', 'N', 'GE_PAR_DINAMICOS');

insert into GE_PAR_DINAMICOS (PARAMETRO, VAL_PARAMETRO, COD_MONEDA)
values ('TAR_NRO_CTA_FICTICIA', '01000000002', null);

insert into GE_PAR_DINAMICOS (PARAMETRO, VAL_PARAMETRO, COD_MONEDA)
values ('TAR_VAL_ICA_ADELANTO', '23265', null);

commit;
