create or replace force view it.simgia_bcdt001_cat as
select
b.cod_persona as numclien,
nvl(fup_obt_categoria(b.cat_automatica,b.cat_subjetiva),1) as ncalifbcp,
/*nvl(to_char(b.fec_ult_clasif,'DDMMYYYY'),*/(select to_char(a.pri_dia_mes - 1, 'DDMMYYYY') from ge_calendarios a where a.cod_modulo = 1)/*)*/ as  nfecalif
from ge_clientes b;

