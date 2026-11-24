create or replace force view it.gv_ent_financieras as
select to_number(p.val_parametro) cod_banco, e.descripcion 
       from ge_par_entes p, ge_entes e
      where p.parametro = 'COD_ENT_FINANCIERA'
        and p.cod_ente = e.cod_ente
        and p.val_parametro is not null
        and e.tipo = 'FI'
      union all
     select b.cod_banco cod_banco, b.descripcion
       from ge_bancos b
      where b.estado = 'A'
        and b.ubicacion = 'L'
      order by 1;

