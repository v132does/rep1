create or replace force view it.simgia_arvalpyp as
select
-- capital del original
'capital original' tipo,
mdoc.estado estado,
mdoc.cod_sit_contable sit_contable,
nvl(mdoc.cod_oficina, 0) RVSUC,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           case
                                                           when mdoc.cod_sit_contable=10000001 then 805
                                                           when mdoc.cod_sit_contable<>10000001 then 711
                                                           end, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)), 0) RVCUENTA,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           case
                                                           when mdoc.cod_sit_contable=10000001 then 805
                                                           when mdoc.cod_sit_contable<>10000001 then 711
                                                           end, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable) rb_rvcuenta,
'0' RVCTAIAD,
'0' rb_rvctaiad,
/*nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           901,                                                            mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)), 0) '0'*/ mdoc.nro_cuenta RVCTARES,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           901, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable) rb_rvctares,
/*nvl(PAI_INT.FU_SIM_NORM_CADENA(case
when length(mdoc.nro_documento)>15 then substr(mdoc.nro_documento,-15,15)
else mdoc.nro_documento
end,15), '') RVNRODOC,*/
'co' || to_char(rownum) RVNRODOC, --modificado 20100513 con aprovacion de VP
0 RVNCUOTA,
nvl(to_char(mdoc.fec_inicio,'yyyymmdd'), 0) RVFCHREG,
nvl(to_char(mdoc.fec_vencimiento,'yyyymmdd'), 0) RVFCHVTO,
nvl(mdoc.fec_vencimiento-mdoc.fec_inicio, 0) RVPLAZO, --modif anama 08-09
decode(mdoc.cod_moneda,'GS','00','USD','05','EUR','17') RVMONEDA,
/*RVALNOMI irrelevante,*/
nvl(mdoc.val_presente, 0) RVALACT,/*es capital*/
nvl(mdoc.val_tasa, 0) RVTASA,
'0' RVFINIDV,
0 RVALDEV,
'0' RVFULTDV,
decode(mdoc.cod_modalidad,101,1,102,2,105,4,125,9,129,1,132,2,123,4,0) RVTIPO, mdoc.cod_modalidad,
nvl(PAI_INT.FU_SIM_NORM_CADENA(mdoc.denominacion,25),'') RVDESCRI,
decode(mdoc.estado,'R','V','') RVESTADO,
nvl(to_char(trunc(mdoc.fec_inicio),'yymmdd'),0) RVFCHPRO, --modif anama 08-09
nvl(mdoc.cod_persona,0) RVRIESGO,
0 RVALNOMI,
mdoc.cod_modalidad RVCTACAN,
mdoc.nro_cuenta
FROM md_cta_documentos mdoc
where mdoc.cod_modalidad in (101,102,105,125,129,132,123)
and (mdoc.estado in ('R') or (mdoc.estado like 'C' and mdoc.fec_ven_repo is null))

union

--capital vendido
select 'capital vendido' tipo,
mdoc.estado estado,
mdoc.cod_sit_contable sit_contable,
nvl(mdoc.cod_oficina, 0) RVSUC,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           811, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)), 0) RVCUENTA,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           811, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable),
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           811, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)), 0) RVCTAIAD,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           811, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable),
/*nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           901,
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)), 0) '0'*/ mdoc.nro_cuenta RVCTARES,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           901, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable),

/*nvl(PAI_INT.FU_SIM_NORM_CADENA(case
when length(mdoc.nro_documento)>15 then substr(mdoc.nro_documento,-15,15)
else mdoc.nro_documento
end,15), '') RVNRODOC,*/
'cv' || to_char(rownum) RVNRODOC, --modificado 20100513 con aprovacion de VP
0 RVNCUOTA,
nvl(to_char(mdoc.fec_inicio,'yyyymmdd'),0) RVFCHREG,
nvl(to_char(mdoc.fec_vencimiento,'yyyymmdd'),0) RVFCHVTO,
nvl(mdoc.fec_vencimiento-mdoc.fec_inicio,0) RVPLAZO, --modif anama 08-09
decode(mdoc.cod_moneda,'GS','00','USD','05','EUR','17') RVMONEDA,
/*RVALNOMI irrelevante,*/
nvl(mdoc.val_presente,0) RVALACT,/*es capital*/
nvl(mdoc.val_tasa,0) RVTASA,
'0' RVFINIDV,
0 RVALDEV,
'0' RVFULTDV,
decode(mdoc.cod_modalidad,129,11,132,16,123,15,0) RVTIPO, mdoc.cod_modalidad,
nvl(PAI_INT.FU_SIM_NORM_CADENA(mdoc.denominacion,25),'') RVDESCRI,
decode(mdoc.estado,'R','V','') RVESTADO,
nvl(to_char(trunc(mdoc.fec_inicio),'yymmdd'),0) RVFCHPRO, --modif anama 08-09
nvl(mdoc.cod_persona,0) RVRIESGO,
0 RVALNOMI,
mdoc.cod_modalidad RVCTACAN,
mdoc.nro_cuenta
FROM md_cta_documentos mdoc
where mdoc.cod_modalidad in (129,132,123)
and mdoc.estado in ('E')

union



-- interes original estado 'R' sumar dev estado C y R

select 'interes original est R' tipo,
mdoc.estado estado,
mdoc.cod_sit_contable sit_contable,
nvl(mdoc.cod_oficina,0) RVSUC,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           719, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)),0) RVCUENTA,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           719, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable),
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           719, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)),0) RVCTAIAD,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           719, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable),
/*nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           901,
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)),0)*/mdoc.nro_cuenta RVCTARES,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           901, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable),
/*nvl(PAI_INT.FU_SIM_NORM_CADENA(case
when length(mdoc.nro_documento)>15 then substr(mdoc.nro_documento,-15,15)
else mdoc.nro_documento
end,15),'') RVNRODOC,*/
'io' || to_char(rownum) RVNRODOC, --modificado 20100513 con aprovacion de VP
1 RVNCUOTA,
nvl(to_char(mdoc.fec_inicio,'yyyymmdd'),0) RVFCHREG,
nvl(to_char(mdoc.fec_vencimiento,'yyyymmdd'),0) RVFCHVTO,
nvl(mdoc.fec_vencimiento-mdoc.fec_inicio,0) RVPLAZO, --modif anama 08-09
decode(mdoc.cod_moneda,'GS','00','USD','05','EUR','17') RVMONEDA,
/*RVALNOMI irrelevante,*/
nvl(mdoc.mto_interes,0) RVALACT,/*es interes*/
nvl(mdoc.val_tasa,0) RVTASA,
nvl(nvl((select to_char(mdev.fec_inicio,'yyyymmdd') from md_devengados mdev where mdoc.nro_cuenta = mdev.nro_cuenta and mdev.estado in ('C','R') and rownum = 1),to_char(mdoc.fec_inicio,'yyyymmdd')),0) RVFINIDV, --poner la fecha mas antigua
/*nvl((select sum(mdev.mto_dev_acumulado) from md_devengados mdev where mdoc.nro_cuenta = mdev.nro_cuenta and mdev.estado in ('C','R')),0) RVALDEV, cambiado el 20091014 recom. de Ingrid*/
nvl(mdoc.dev_acumulado,0) RVALDEV,
nvl((select to_char(mdev.fec_ult_devengado,'yyyymmdd') from md_devengados mdev where mdoc.nro_cuenta = mdev.nro_cuenta and mdev.estado in ('C','R') and rownum = 1),'0') RVFULTDV, --poner la fecha mas nueva
decode(mdoc.cod_modalidad,101,1,102,2,105,4,125,9,129,1,132,2,123,4,0) RVTIPO, mdoc.cod_modalidad,
nvl(PAI_INT.FU_SIM_NORM_CADENA(mdoc.denominacion,25),'') RVDESCRI,
'' RVESTADO,
nvl(to_char(trunc(mdoc.fec_inicio),'yymmdd'),0) RVFCHPRO, --modif anama 08-09
nvl(mdoc.cod_persona,0) RVRIESGO,
0 RVALNOMI,
mdoc.cod_modalidad RVCTACAN,
mdoc.nro_cuenta
FROM md_cta_documentos mdoc
where mdoc.cod_modalidad in (101,102,105,125,129,132,123)
and mdoc.estado= 'R'




union



-- interes original estado 'C' dev 'C'

select 'interes original est C dev C' tipo,
mdoc.estado estado,
mdoc.cod_sit_contable sit_contable,
nvl(mdoc.cod_oficina,0) RVSUC,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           case
                                                           when mdoc.cod_sit_contable=10000001 then 813
                                                           when mdoc.cod_sit_contable<>10000001 then 719
                                                           end, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)),0) RVCUENTA,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           case
                                                           when mdoc.cod_sit_contable=10000001 then 813
                                                           when mdoc.cod_sit_contable<>10000001 then 719
                                                           end, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable),
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           case
                                                           when mdoc.cod_sit_contable=10000001 then 813
                                                           when mdoc.cod_sit_contable<>10000001 then 719
                                                           end, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)),0) RVCTAIAD,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           case
                                                           when mdoc.cod_sit_contable=10000001 then 813
                                                           when mdoc.cod_sit_contable<>10000001 then 719
                                                           end, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable),
/*nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           901,
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)),0)*/ mdoc.nro_cuenta RVCTARES,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           901, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable),
/*nvl(PAI_INT.FU_SIM_NORM_CADENA(case
when length(mdoc.nro_documento)>15 then substr(mdoc.nro_documento,-15,15)
else mdoc.nro_documento
end,15),'') RVNRODOC,*/
'ic' || to_char(rownum) RVNRODOC, --modificado 20100513 con aprovacion de VP
1 RVNCUOTA,
nvl(to_char(mdoc.fec_inicio,'yyyymmdd'),0) RVFCHREG,
nvl(to_char(mdoc.fec_vencimiento,'yyyymmdd'),0) RVFCHVTO,
nvl(mdoc.fec_vencimiento-mdoc.fec_inicio,0) RVPLAZO, --modif anama 08-09
decode(mdoc.cod_moneda,'GS','00','USD','05','EUR','17') RVMONEDA,
/*RVALNOMI irrelevante,*/
nvl(mdoc.mto_interes,0) RVALACT,/*es interes*/
nvl(mdoc.val_tasa,0) RVTASA,
nvl(nvl((select to_char(mdev.fec_inicio,'yyyymmdd') from md_devengados mdev where mdoc.nro_cuenta = mdev.nro_cuenta and mdev.estado in ('C') and rownum = 1),to_char(mdoc.fec_inicio,'yyyymmdd')),0) RVFINIDV, --poner la fecha mas antigua
/*nvl((select sum(mdev.mto_dev_acumulado) from md_devengados mdev where mdoc.nro_cuenta = mdev.nro_cuenta and mdev.estado in ('C')),0) RVALDEV,cambiado el 20091014 recom. de Ingrid*/
nvl(mdoc.dev_acumulado,0) RVALDEV,
nvl((select to_char(mdev.fec_ult_devengado,'yyyymmdd') from md_devengados mdev where mdoc.nro_cuenta = mdev.nro_cuenta and mdev.estado in ('C') and rownum = 1),'0') RVFULTDV, --poner la fecha mas nueva
decode(mdoc.cod_modalidad,101,1,102,2,105,4,125,9,129,1,132,2,123,4,0) RVTIPO, mdoc.cod_modalidad,
nvl(PAI_INT.FU_SIM_NORM_CADENA(mdoc.denominacion,25),0) RVDESCRI,
'' RVESTADO,
nvl(to_char(trunc(mdoc.fec_inicio),'yymmdd'),0) RVFCHPRO, --modif anama 08-09
nvl(mdoc.cod_persona,0) RVRIESGO,
0 RVALNOMI,
mdoc.cod_modalidad RVCTACAN, mdoc.nro_cuenta
from md_cta_documentos mdoc
where mdoc.cod_modalidad in (101,102,105,125,129,132,123)
and (mdoc.estado = 'C' and mdoc.fec_ven_repo is null)

union


--interes vendido estado 'E'

select 'interes vendido est E' tipo,
mdoc.estado estado,
mdoc.cod_sit_contable sit_contable,
nvl(mdoc.cod_oficina,0) RVSUC,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           812, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)),0) RVCUENTA,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           812, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable),
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           902, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)),0) RVCTAIAD,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           902, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable),
/*nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           901,
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)),0) */ mdoc.nro_cuenta RVCTARES,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           901, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable),
/*nvl(PAI_INT.FU_SIM_NORM_CADENA(case
when length(mdoc.nro_documento)>15 then substr(mdoc.nro_documento,-15,15)
else mdoc.nro_documento
end,15), '') RVNRODOC,*/
'iv' || to_char(rownum) RVNRODOC, --modificado 20100513 con aprovacion de VP
1 RVNCUOTA,
nvl(to_char(mdoc.fec_inicio,'yyyymmdd'),0) RVFCHREG,
nvl(to_char(mdoc.fec_vencimiento,'yyyymmdd'),0) RVFCHVTO,
nvl(mdoc.fec_vencimiento-mdoc.fec_inicio,0) RVPLAZO, --modif anama 08-09
decode(mdoc.cod_moneda,'GS','00','USD','05','EUR','17') RVMONEDA,
/*RVALNOMI irrelevante,*/
nvl(mdoc.mto_interes,0) RVALACT,/*es interes*/
nvl(mdoc.val_tasa,0) RVTASA,
nvl(nvl((select to_char(mdev.fec_inicio,'yyyymmdd') from md_devengados mdev where mdoc.nro_cuenta = mdev.nro_cuenta and mdev.estado in ('E') and rownum = 1),to_char(mdoc.fec_inicio,'yyyymmdd')),0) RVFINIDV, --poner la fecha mas antigua
/*nvl((select sum(mdev.mto_dev_acumulado) from md_devengados mdev where mdoc.nro_cuenta = mdev.nro_cuenta and mdev.estado in ('E')),0) RVALDEV, cambiado el 20091014 recom. de Ingrid*/
nvl(mdoc.dev_acumulado,0) RVALDEV,
nvl((select to_char(mdev.fec_ult_devengado,'yyyymmdd') from md_devengados mdev where mdoc.nro_cuenta = mdev.nro_cuenta and mdev.estado in ('E') and rownum = 1),'0') RVFULTDV, --poner la fecha mas nueva
decode(mdoc.cod_modalidad,129,11,132,16,123,15,0) RVTIPO, mdoc.cod_modalidad,
nvl(PAI_INT.FU_SIM_NORM_CADENA(mdoc.denominacion,25),'') RVDESCRI,
'' RVESTADO,
nvl(to_char(trunc(mdoc.fec_inicio),'yymmdd'),0) RVFCHPRO, --modif anama 08-09
nvl(mdoc.cod_persona,0) RVRIESGO,
0 RVALNOMI,
mdoc.cod_modalidad RVCTACAN, mdoc.nro_cuenta
from md_cta_documentos mdoc
where mdoc.cod_modalidad in (101,102,105,129,132,123)
and mdoc.estado = 'E'
;

