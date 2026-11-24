-- Modalidades producto 138 / 139 / 140
-- Referencia: mod 127 REPO INTERBANCARIO RECIBIDO (tipo y prod. contable desde ambiente destino)
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

insert into it.ge_modalidades (cod_modulo, cod_modalidad, descripcion, cod_gru_cruzamiento, sigla, cod_pro_contable, tipo)
select 10, n.cod_modalidad, n.descripcion, b.cod_gru_cruzamiento, b.sigla, b.cod_pro_contable, b.tipo
  from (select 138 cod_modalidad, 'FLI RECIBIDO' descripcion from dual
        union all select 139, 'REPO OVERNIGHT RECIBIDO' from dual
        union all select 140, 'REPO TRIPARTITO RECIBIDO' from dual) n
 cross join it.ge_modalidades b
 where b.cod_modulo = 10
   and b.cod_modalidad = 127
   and not exists (
         select 1 from it.ge_modalidades x
          where x.cod_modulo = 10 and x.cod_modalidad = n.cod_modalidad);

commit;
/
