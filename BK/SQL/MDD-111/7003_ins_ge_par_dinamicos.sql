-- SIG_NROCTA (semillas nuevas) + MD_OPE_REPO / REP_TIP_NEGOCIACIONES desde mod 127
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

insert into it.ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, cod_sub_modalidad)
select 'SIG_NROCTA', n.val_parametro, 10, n.cod_modalidad, null, null, null
  from (select 138 cod_modalidad, '13800001' val_parametro from dual
        union all select 139, '13900001' from dual
        union all select 140, '14000001' from dual) n
 where not exists (
         select 1 from it.ge_par_dinamicos x
          where x.cod_modulo = 10
            and x.cod_modalidad = n.cod_modalidad
            and x.parametro = 'SIG_NROCTA');

insert into it.ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, cod_sub_modalidad)
select p.parametro, p.val_parametro, 10, m.cod_modalidad, p.cod_oficina, p.cod_moneda, p.cod_sub_modalidad
  from (select 138 cod_modalidad from dual
        union all select 139 from dual
        union all select 140 from dual) m
 cross join it.ge_par_dinamicos p
 where p.cod_modulo = 10
   and p.cod_modalidad = 127
   and p.parametro in ('MD_OPE_REPO', 'REP_TIP_NEGOCIACIONES')
   and not exists (
         select 1 from it.ge_par_dinamicos x
          where x.cod_modulo = 10
            and x.cod_modalidad = m.cod_modalidad
            and x.parametro = p.parametro);

commit;
/
