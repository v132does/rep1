BEGIN pre_ini_aplicacion; END; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('PRE_FAC_PRI_APL_SEGUROS', 'FACTOR PRIMA APLICADA A SEGUROS', 'GE_PAR_DINAMICOS', null, 'Parámetro creado para el factor prima para todos los calculos de seguros que cobramos en el desembolso.
valor:= 6', null, null, 'N', null);

commit;
