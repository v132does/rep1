create or replace force view it.lv_ope_cam_minorista as
select T.FECHA, t.nro_registro,
       TO_CHAR(T.FEC_REGISTRO,'YYYYMMDD')||';'||TO_CHAR(T.FECHA,'YYYYMMDD')||';'||
       T.TIP_DOCUMENTO||';'||T.NRO_DOCUMENTO||';'||T.NOM_CLIENTE||';'||
       TO_CHAR(T.FEC_VEN_FORWARD,'YYYYMMDD')||';'||
       T.MERCADO||';'||T.CIUDAD||';'||T.TIP_OPERACION||';'||T.TIP_CANJE||';'||
       T.COM_MONEDA||';'||
       TRIM(TO_CHAR(T.COM_MONTO,'9999999999999999990.99'))||';'||
       TRIM(TO_CHAR(T.COM_PRECIO,'9999999999999999990.99'))||';'||
       TRIM(TO_CHAR(T.COM_MTO_USD,'9999999999999999990.99'))||';'||
       T.VTA_MONEDA||';'||
       TRIM(TO_CHAR(T.VTA_MONTO,'9999999999999999990.99'))||';'||
       TRIM(TO_CHAR(T.VTA_PRECIO,'9999999999999999990.99'))||';'||
       TRIM(TO_CHAR(T.VTA_MTO_USD,'9999999999999999990.99'))||';' LINEA
from LC_OPE_CAM_MIN_BCP_DET t
where t.env_bcp = 'S'
order by t.fecha, t.nro_registro;

