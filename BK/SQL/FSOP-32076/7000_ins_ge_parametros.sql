BEGIN pre_ini_aplicacion; END; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('IND_NO_MOS_CTA_APP', 'INDICADOR NO MUESTRA CTA. PRESTAMO', 'GE_CTA_DEF_ADICIONALES', 'COD_BAN_LOCALES', 'Indicador de que no muestre la cuenta de prestamos en la app.
S= No muestra Cta. prestamos en la app
N= Muestra Cta. prestamos en la app', null, null, 'N', null);

commit;