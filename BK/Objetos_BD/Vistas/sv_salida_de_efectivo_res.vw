create or replace view it.sv_salida_de_efectivo_res as
select s.fecha, s.deposito,
       CASE
            WHEN s.tipo = 'F' THEN 3
            WHEN s.tipo = 'J' AND s.saldo_total < 1449524000 THEN 4
            WHEN s.tipo = 'J' AND s.saldo_total >= 1449524000 THEN 5
            ELSE 8
        END AS categoria,
        6 grupo,
        round(sum(s.sal_vista_gs * (case when nvl(s.saldo_total,0) <> 0 then (cast(least(s.saldo_total, 217428600) as number) / s.saldo_total) else 0 end))) sal_vista_gs,
        round(sum(s.sal_vista_ext * (case when nvl(s.saldo_total,0) <> 0 then (cast(least(s.saldo_total, 217428600) as number) / s.saldo_total) else 0 end))) sal_vista_ext,
        round(sum(s.sal_plazo_gs * (case when nvl(s.saldo_total,0) <> 0 then (cast(least(s.saldo_total, 217428600) as number) / s.saldo_total) else 0 end))) sal_plazo_gs,
        round(sum(s.sal_plazo_ext * (case when nvl(s.saldo_total,0) <> 0 then (cast(least(s.saldo_total, 217428600) as number) / s.saldo_total) else 0 end))) sal_plazo_ext,
        sum(s.sal_res_gs) sal_res_gs,
        sum(s.sal_res_ext) sal_res_ext
from IT.SB_LCR_LIQ_INV_TMP s
group by s.fecha, s.deposito, CASE WHEN s.tipo = 'F' THEN 3 WHEN s.tipo = 'J' AND s.saldo_total < 1449524000 THEN 4 WHEN s.tipo = 'J' AND s.saldo_total >= 1449524000 THEN 5 ELSE 8 END
union all
select s.fecha, s.deposito,
       CASE
            WHEN s.tipo = 'F' THEN 3
            WHEN s.tipo = 'J' AND s.saldo_total < 1449524000 THEN 4
            WHEN s.tipo = 'J' AND s.saldo_total >= 1449524000 THEN 5
            ELSE 8
        END AS categoria,
        7 grupo,
        round(sum(s.sal_vista_gs * (1- (case when nvl(s.saldo_total,0) <> 0 then (cast(least(s.saldo_total, 217428600) as number) / s.saldo_total) else 0 end)))) sal_vista_gs,
        round(sum(s.sal_vista_ext * (1- (case when nvl(s.saldo_total,0) <> 0 then (cast(least(s.saldo_total, 217428600) as number) / s.saldo_total) else 0 end)))) sal_vista_ext,
        round(sum(s.sal_plazo_gs * (1- (case when nvl(s.saldo_total,0) <> 0 then (cast(least(s.saldo_total, 217428600) as number) / s.saldo_total) else 0 end)))) sal_plazo_gs,
        round(sum(s.sal_plazo_ext * (1- (case when nvl(s.saldo_total,0) <> 0 then (cast(least(s.saldo_total, 217428600) as number) / s.saldo_total) else 0 end)))) sal_plazo_ext,
        0 sal_res_gs,
        0 sal_res_ext
from IT.SB_LCR_LIQ_INV_TMP s
where s.saldo_total > 217428600
group by s.fecha, s.deposito, CASE WHEN s.tipo = 'F' THEN 3 WHEN s.tipo = 'J' AND s.saldo_total < 1449524000 THEN 4 WHEN s.tipo = 'J' AND s.saldo_total >= 1449524000 THEN 5 ELSE 8 END;
