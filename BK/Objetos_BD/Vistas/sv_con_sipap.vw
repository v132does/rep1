create or replace view it.sv_con_sipap as
select /*+parallel(8)*/ "MT_CAMPOS","FECHA","MONEDA","TIPO","IMPORTE","REFERENCIA_BCP","TIPO_MT","REFERENCIA","REF_CONSOLIDADA","PLATAFORMA","ESTADO","NRO_REF_REV_RECIBIDA","NRO_REF_REV_ENVIADA","SAL_INI","SAL_FIN" from (
select t.MT_Campos MT_Campos,
       t.Fecha Fecha,
       t.moneda Moneda,
       t.Tipo Tipo,
       t.Importe Importe,
       t.Referencia_BCP Referencia_BCP,
       t.Tipo_MT Tipo_MT,
       to_number(t.Referencia) Referencia,
       t.Ref_Consolidada Ref_Consolidada,
       t.Plataforma Plataforma,
       t.Estado Estado,
       t.Nro_Ref_Rev_Recibida Nro_Ref_Rev_Recibida,
       t.Nro_Ref_Rev_Enviada Nro_Ref_Rev_Enviada,
       t.sal_inicial Sal_ini,
       t.sal_final sal_fin
from IT.SB_EXT_MT940 t);
