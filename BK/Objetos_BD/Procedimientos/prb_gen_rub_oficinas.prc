create or replace procedure it.PRB_GEN_RUB_OFICINAS
 (p_cod_oficina number default null,
  p_cod_rubro varchar2 default null)
 is
   --- Genera la tabla de rubros por oficinas en base al plan de cuentas
begin
   insert into cb_rub_oficinas
    (cod_rubro, cod_oficina)
    select pc.cod_rubro, su.cod_oficina
      from cb_rubros pc, ba_oficinas su
     where not exists (select 1 from cb_rub_oficinas ro
                        where ro.cod_oficina = su.cod_oficina
                          and ro.cod_rubro = pc.cod_rubro)
       and su.cod_oficina = nvl(p_cod_oficina,su.cod_oficina)
       and pc.cod_rubro = nvl(p_cod_rubro,pc.cod_rubro);
end PRB_GEN_RUB_OFICINAS;
/

