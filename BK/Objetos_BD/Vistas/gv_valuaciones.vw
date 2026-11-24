create or replace force view it.gv_valuaciones as
select nro_cuenta,
nvl(tot_val_capital,0)+
nvl(tot_val_interes,0)+
nvl(tot_val_int_ade,0)+
nvl(tot_val_devengado,0)+
nvl(tot_val_garantia,0)+
nvl(tot_val_prevision,0)+
nvl(tot_val_suspenso,0)+
nvl(tot_val_int_devengar,0) sal_valuacion
from pr_valuaciones
union all
select nro_cuenta, tot_valuacion from cc_valuaciones
union all
select nro_cuenta,
nvl(tot_val_saldo,0)+
nvl(tot_val_garantia,0)+
nvl(tot_val_prevision,0) from ov_valuaciones;

