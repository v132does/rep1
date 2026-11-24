create or replace force view it.gv_inf_ing_fac_ant_mediana as
Select
nro_inf_credito,1 orden,nvl(fac_ene_ano_anterior,0)fac_ano_anterior
from ge_inf_ingresos
Union
Select
nro_inf_credito,2 , nvl(fac_feb_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,3 ,  nvl(fac_mar_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,4 ,   nvl(fac_abr_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,5 ,    nvl(fac_may_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,6 ,     nvl(fac_jun_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,7 ,nvl(fac_jul_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,8 , nvl(fac_ago_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,9 ,  nvl(fac_set_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,10 ,   nvl(fac_oct_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,11 ,    nvl(fac_nov_ano_anterior,0)
from ge_inf_ingresos
Union
Select
nro_inf_credito,12 ,    nvl(fac_dic_ano_anterior,0)
from ge_inf_ingresos;

