create or replace force view it.gv_ent_cidesa as
select to_number(p.val_parametro) cod_bco_central, e.descripcion,
           e.cod_ente cod_banco
      from ge_par_entes p, ge_entes e
     where p.parametro = 'COD_ENT_CIDESA'
       and p.cod_ente = e.cod_ente
       and e.tipo = 'FI'
    union all
    select cod_bco_central cod_bco_central, b.descripcion,
           b.cod_banco cod_banco
      from ge_bancos b
     where b.estado = 'A'
       and b.ubicacion = 'L'
	   order by 1;

