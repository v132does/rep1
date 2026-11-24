create or replace force view it.smg_val_cus_as400 as
select t.cod_val_custodia resguar_it,  substr(t.observacion,1,10) resguar_as, substr(t.observacion,22,222) cliente_as, c.cod_persona, p.nom_completo,
substr(t.observacion,1,200) observacion,  t.mto_total
from ge_val_custodias t
left join ge_val_cus_titulares c on c.cod_val_custodia = t.cod_val_custodia and c.relacion = 'P'
left join ba_personas p on p.cod_persona=c.cod_persona;

