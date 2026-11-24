create or replace force view it.lv_env_transferencias as
select substr(ban.cod_swift,1,6)||';'||substr(nro_ref_externa,1,16)||';'||to_char(fec_valor,'ddmmyyyy')||';'||
       substr(nro_doc_beneficiario,1,20)||';'||substr(tra.estado,1,4)||';'||substr(tel_beneficiario,1,15)||';'||
       replace(replace(replace(trim(to_char(monto,'9,999,999,999.00')),'.','#'),',','.'),'#',',')||';' registro,
       fec_cam_estado fecha,
       'TRA_RESUELTAS' archivo,
        tra.cod_banco cod_banco
  from lc_transferencias tra,
       ge_bancos ban
 where tra.estado in ('OK','AN','DE')
   and ban.cod_banco = fug_obt_cod_banco
   and cod_modalidad = 75
union
select substr(ban.cod_swift,1,6)||';'||substr(nro_ref_externa,1,16)||';'||
       substr(tra.estado,1,4)||';'||substr(tel_beneficiario,1,15)||';'||
       replace(replace(replace(trim(to_char(monto,'9,999,999,999.00')),'.','#'),',','.'),'#',',')||';' registro,
       null fecha,
       'TRA_PENDIENTES' archivo,
        tra.cod_banco cod_banco
from lc_transferencias tra,
     ge_bancos ban
where tra.estado not in ('OK','AN','DE','PE')
  and ban.cod_banco = fug_obt_cod_banco
  and cod_modalidad = 75;

