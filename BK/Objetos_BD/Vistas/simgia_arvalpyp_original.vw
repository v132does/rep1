create or replace force view it.simgia_arvalpyp_original as
Select mdev.nro_cuenta, mdev.mto_dev_acumulado , mdev.fec_inicio, mdev.fec_ult_devengado
FROM md_cta_documentos mdoc, md_devengados mdev
WHERE mdoc.nro_cuenta= mdev.nro_cuenta
and mdoc.cod_modalidad in (101, 102, 103 ,105, 125)
and mdoc.estado= 'C'
group by mdev.nro_cuenta,mdev.mto_dev_acumulado , mdev.fec_inicio, mdev.fec_ult_devengado;

