create or replace force view it.gv_inf_ing_sal_ant_mediana as
Select
nro_inf_credito,1 orden,nvl(sal_ene_ano_anterior,0)sal_ano_anterior
from ge_inf_ingresos
Union
Select
nro_inf_credito,2 , nvl(sal_feb_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,3 ,  nvl(sal_mar_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,4 ,   nvl(sal_abr_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,5 ,    nvl(sal_may_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,6 ,     nvl(sal_jun_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,7 ,nvl(sal_jul_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,8 , nvl(sal_ago_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,9 ,  nvl(sal_set_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,10 ,   nvl(sal_oct_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,11 ,    nvl(sal_nov_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,12 ,    nvl(sal_dic_ano_anterior,0)
from ge_inf_ingresos;

