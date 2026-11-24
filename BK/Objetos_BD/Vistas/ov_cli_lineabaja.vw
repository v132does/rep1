create or replace force view it.ov_cli_lineabaja as
select distinct b.cod_persona
  from ba_telefonos b
 where b.observacion is null
   and b.area is not null
   and not exists (select distinct a.cod_persona
                     from ba_telefonos a
                    where a.cod_persona = b.cod_persona
                      and a.observacion is null
                      and trim(a.area) not like '%096%'
                      and trim(a.area) not like '%097%'
                      and trim(a.area) not like '%098%'
                      and trim(a.area) not like '%099%'
                      and trim(a.area) not in ('961','971','981','991')
                   );

