create or replace force view it.simgia_arvalpyp_modif3 as
select mdoc.cod_oficina RVSUC,
null RVCUENTA,null RVCTAIAD,null RVCTARES,
mdoc.nro_documento RVNRODOC,
0 RVNCUOTA,
to_char(mdoc.fec_inicio,'yyyymmdd') RVFCHREG,
to_char(mdoc.fec_vencimiento,'yyyymmdd') RVFCHVTO,
NULL RVPLAZO ,
decode(mdoc.cod_moneda,'GS','00','USD','05','EUR','17') RVMONEDA,
 mdoc.val_presente RVALACT,/*es capital*/
mdoc.val_tasa RVTASA,
 '0' RVFINIDV, 0 RVALDEV, '0' RVFULTDV,
decode(mdoc.cod_modalidad,101,1,102,2,103,4,105,9,125,4) RVTIPO,
substr(mdoc.denominacion,1,25) RVDESCRI,
decode(mdoc.estado,'R','V',null) RVESTADO,
to_char(trunc(mdoc.fec_insercion),'yymmdd') RVFCHPRO,
mdoc.cod_persona RVRIESGO
FROM md_cta_documentos mdoc
where mdoc.cod_modalidad in (101, 102, 103 ,105, 125)
and ((mdoc.fec_ini_repo is null and mdoc.fec_ven_repo is null)
  or (mdoc.fec_ini_repo is not null and mdoc.fec_ven_repo is not null))

UNION
--INTERES PARA ORIGINAL
--si el estado en MD_CTA_DOCUMENTOS es 'C', solo tiene q haber un registro en MD_DEVENGADOS con estado 'C'
select mdoc.cod_oficina RVSUC,
null RVCUENTA,null RVCTAIAD,null RVCTARES,
mdoc.nro_documento RVNRODOC,
1 RVNCUOTA,
to_char(mdoc.fec_inicio,'yyyymmdd') RVFCHREG,
to_char(mdoc.fec_vencimiento,'yyyymmdd') RVFCHVTO,
NULL RVPLAZO,
decode(mdoc.cod_moneda,'GS','00','USD','05','EUR','17') RVMONEDA,
mdoc.mto_interes RVALACT,
mdoc.val_tasa RVTASA,
to_char(mdev.fec_inicio,'yyyymmdd') RVFINIDV, --poner la fecha mas antigua*/
mdev.mto_dev_acumulado RVALDEV, --modificar!!
to_char(mdev.fec_ult_devengado,'yyyymmdd') RVFULTDV, --poner la fecha mas nueva
decode(mdoc.cod_modalidad,101,1,102,2,103,4,105,9,125,4) RVTIPO,
substr(mdoc.denominacion,1,25) RVDESCRI,
null RVESTADO,
to_char(trunc(mdoc.fec_insercion),'yymmdd') RVFCHPRO,
mdoc.cod_persona RVRIESGO
FROM md_cta_documentos mdoc, md_devengados mdev
WHERE mdoc.nro_cuenta= mdev.nro_cuenta
and mdoc.cod_modalidad in (101, 102, 103 ,105, 125) and mdoc.estado ='C'

UNION
---si el estado en MD_CTA_DOCUMENTOS es 'R', sumar los registros en MD_DEVENGADOS que tengan estado 'C' y 'V'
select mdoc.cod_oficina RVSUC,
null RVCUENTA,null RVCTAIAD,null RVCTARES,
mdoc.nro_documento RVNRODOC,
1 RVNCUOTA,
to_char(mdoc.fec_inicio,'yyyymmdd') RVFCHREG,
to_char(mdoc.fec_vencimiento,'yyyymmdd') RVFCHVTO,
NULL RVPLAZO,
decode(mdoc.cod_moneda,'GS','00','USD','05','EUR','17') RVMONEDA,
mdoc.mto_interes RVALACT,
mdoc.val_tasa RVTASA,
to_char(mdev.fec_inicio,'yyyymmdd') RVFINIDV, --poner la fecha mas antigua*/
sum(mdev.mto_dev_acumulado) RVALDEV, --modificar!!
to_char(mdev.fec_ult_devengado,'yyyymmdd') RVFULTDV, --poner la fecha mas nueva
decode(mdoc.cod_modalidad,101,1,102,2,103,4,105,9,125,4) RVTIPO,
substr(mdoc.denominacion,1,25) RVDESCRI,
null RVESTADO,
to_char(trunc(mdoc.fec_insercion),'yymmdd') RVFCHPRO,
mdoc.cod_persona RVRIESGO
FROM md_cta_documentos mdoc, md_devengados mdev
WHERE mdoc.nro_cuenta= mdev.nro_cuenta
and mdoc.cod_modalidad in (101, 102, 103 ,105, 125)
and mdoc.estado= 'R' and mdev.estado in ('C','V')
GROUP BY mdoc.cod_oficina,mdoc.cod_modulo,mdoc.cod_modalidad,mdoc.cod_moneda,mdoc.cod_persona,mdoc.fec_vencimiento,
mdoc.fec_inicio,mdoc.estado,mdoc.nro_documento,mdoc.mto_interes,mdoc.val_tasa,mdev.fec_inicio,
mdev.fec_ult_devengado,mdoc.denominacion,mdoc.fec_insercion

UNION
--------------------------------------------------------------------
-- PARA REPO
-- CAPITAL
select mdoc.cod_oficina RVSUC,
null RVCUENTA,null RVCTAIAD,null RVCTARES,
mdoc.nro_documento RVNRODOC,
0 RVNCUOTA,
to_char(mdoc.fec_ini_repo,'yyyymmdd') RVFCHREG,
to_char(mdoc.fec_ven_repo,'yyyymmdd') RVFCHVTO,
(mdoc.Fec_Ven_Repo - mdoc.Fec_Ini_Repo) RVPLAZO,
decode(mdoc.cod_moneda,'GS','00','USD','05','EUR','17') RVMONEDA,
mdoc.val_bas_repo RVALACT,
mdoc.val_tas_repo RVTASA,
 '0' RVFINIDV,0 RVALDEV,'0' RVFULTDV,
decode(mdoc.cod_modalidad,101,11,102,16,103,15,125,15) RVTIPO,
substr(mdoc.denominacion,1,25) RVDESCRI,
NULL RVESTADO,
to_char(trunc(mdoc.fec_ini_repo),'yymmdd') RVFCHPRO,
mdoc.cod_per_vendido RVRIESGO
FROM md_cta_documentos mdoc
where mdoc.estado like 'R' and mdoc.cod_modalidad in (101, 102, 103 ,105, 125)

UNION
--INTERES PARA EL REPO
select mdoc.cod_oficina RVSUC,
null RVCUENTA,null RVCTAIAD,null RVCTARES,
mdoc.nro_documento RVNRODOC, 1 RVNCUOTA,
to_char(mdoc.fec_ini_repo,'yyyymmdd') RVFCHREG,
to_char(mdoc.fec_ven_repo,'yyyymmdd') RVFCHVTO,
(mdoc.Fec_Ven_Repo - mdoc.Fec_Ini_Repo) RVPLAZO,
decode(mdoc.cod_moneda,'GS','00','USD','05','EUR','17') RVMONEDA,
((mdoc.fec_ven_repo - mdoc.fec_ini_repo) * mdoc.val_tas_repo *  mdoc.val_bas_repo)/365000 RVALACT,/*es interes*/
mdoc.val_tas_repo RVTASA,
to_char(mdoc.fec_ini_repo,'yyyymmdd') RVFINIDV,
mdev.mto_dev_acumulado RVALDEV,
to_char(mdev.fec_ult_devengado,'yyyymmdd') RVFULTDV,
decode(mdoc.cod_modalidad,101,11,102,16,103,15,125,15) RVTIPO,substr(mdoc.denominacion,1,25) RVDESCRI,
null RVESTADO,
to_char(trunc(mdoc.fec_ini_repo),'yymmdd') RVFCHPRO,
mdoc.cod_per_vendido RVRIESGO
FROM md_cta_documentos mdoc, md_devengados mdev
WHERE mdoc.nro_cuenta= mdev.nro_cuenta
and mdoc.estado= 'R' and mdev.estado like 'R'
and mdoc.cod_modalidad in (101, 102, 103 ,105, 125)

UNION

-- si no tiene ningun devengado tiene q ser 0
select mdoc.cod_oficina RVSUC,
null RVCUENTA,null RVCTAIAD,null RVCTARES,
mdoc.nro_documento RVNRODOC,
1 RVNCUOTA,
to_char(mdoc.fec_ini_repo,'yyyymmdd') RVFCHREG,
to_char(mdoc.fec_ven_repo,'yyyymmdd') RVFCHVTO,
(mdoc.Fec_Ven_Repo - mdoc.Fec_Ini_Repo) RVPLAZO,
decode(mdoc.cod_moneda,'GS','00','USD','05','EUR','17') RVMONEDA,
((mdoc.fec_ven_repo - mdoc.fec_ini_repo) * mdoc.val_tas_repo *  mdoc.val_bas_repo)/365000 RVALACT,
mdoc.val_tas_repo RVTASA,
to_char(mdoc.fec_ini_repo,'yyyymmdd') RVFINIDV,
0 RVALDEV,'0' RVFULTDV, --anama
decode(mdoc.cod_modalidad,101,11,102,16,103,15,125,15) RVTIPO,
substr(mdoc.denominacion,1,25) RVDESCRI,
null RVESTADO,
to_char(trunc(mdoc.fec_ini_repo),'yymmdd') RVFCHPRO,
mdoc.cod_per_vendido RVRIESGO
FROM md_cta_documentos mdoc
WHERE mdoc.nro_cuenta not in (select mdev.nro_cuenta from it.md_devengados mdev where mdev.estado like 'R') --anama
and mdoc.cod_modalidad in (101, 102, 103 ,105, 125) and mdoc.estado like 'R' --anama
;

