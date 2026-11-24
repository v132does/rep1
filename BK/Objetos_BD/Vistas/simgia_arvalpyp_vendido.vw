create or replace force view it.simgia_arvalpyp_vendido as
Select sum(mdev.mto_dev_acumulado) sum_devengado, mdev.nro_cuenta, to_char(min(mdev.fec_inicio),'yyyymmdd') fec_inicio,
to_char(max(mdev.fec_ult_devengado),'yyyymmdd') fec_ult_devengado
FROM md_cta_documentos mdoc, md_devengados mdev
WHERE mdoc.nro_cuenta= mdev.nro_cuenta
and mdoc.cod_modalidad in (101, 102, 103 ,105, 125)
AND mdev.estado in ('C','V')
and mdoc.estado= 'R'
group by mdev.nro_cuenta;

