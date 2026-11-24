create or replace force view it.sv_inf_planinfo as
select substr(cb.cod_rub_bcp,1,2)||'0'||substr(cb.cod_rub_bcp,4,2)||substr(cb.cod_rub_bcp,6,3)||'0'||substr(cb.cod_rub_bcp,10,2) cod_rubro,
       sum((case when a.cla_moneda = '6900' and a.cod_rubro not in ('10000000000','14000000000','16000000000') then a.importe
                 when a.cla_moneda = '6200' and a.cod_rubro like ('1__7%') then a.importe
                 when a.cla_moneda = '6900' and a.cod_rubro = '10000000000' then
                      a.importe + (select nvl(sum(sb.importe),0) from sb_bcp_sum sb where sb.cod_rubro like ('1__700%') and sb.cla_moneda = '6200')
                 when a.cla_moneda = '6900' and a.cod_rubro = '14000000000' then
                      a.importe + (select nvl(sum(sb.importe),0) from sb_bcp_sum sb where sb.cod_rubro like ('14_700%') and sb.cla_moneda = '6200')
                 when a.cla_moneda = '6900' and a.cod_rubro = '16000000000' then
                      a.importe + (select nvl(sum(sb.importe),0) from sb_bcp_sum sb where sb.cod_rubro like ('16_700%') and sb.cla_moneda = '6200')
                 else 0 end)) guaranies,
       sum((case when a.cla_moneda = '6100' then a.importe else 0 end)) dolares,
       sum((case when a.cla_moneda = '6200' and a.cod_rubro like ('1__7%') then 0
								 when a.cla_moneda = '6200' and a.cod_rubro not in ('10000000000','14000000000','16000000000') then a.importe
                 when a.cla_moneda = '6200' and a.cod_rubro = '10000000000' then
                      a.importe - (select nvl(sum(sb.importe),0) from sb_bcp_sum sb where sb.cod_rubro like ('1__700%') and sb.cla_moneda = '6200')
                 when a.cla_moneda = '6200' and a.cod_rubro = '14000000000' then
                      a.importe - (select nvl(sum(sb.importe),0) from sb_bcp_sum sb where sb.cod_rubro like ('14_700%') and sb.cla_moneda = '6200')
                 when a.cla_moneda = '6200' and a.cod_rubro = '16000000000' then
                      a.importe - (select nvl(sum(sb.importe),0) from sb_bcp_sum sb where sb.cod_rubro like ('16_700%') and sb.cla_moneda = '6200')
                 else 0 end)) Equivalente
 from sb_bcp_sum a, cb_rub_bcp cb
  where a.cod_rubro = cb.cod_rub_bcp
    and a.cla_moneda in ('6900','6100','6200')
group by substr(cb.cod_rub_bcp,1,2)||'0'||substr(cb.cod_rub_bcp,4,2)||substr(cb.cod_rub_bcp,6,3)||'0'||substr(cb.cod_rub_bcp,10,2)
order by 1;

