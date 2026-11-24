create or replace force view it.ov_rcyo as
select distinct a.cod_persona, a.nro_cuenta,
         case a.relacion
           when 'P' then 'T01'
           when 'Y' then 'T02'
           when 'O' then 'T02'
           when 'G' then 'A01'
           when 'C' then 'A01'
           when 'A' then 'A01'
           when 'D' then 'A01'
         end relacion,
         a.cod_modulo, a.cod_modalidad, a.cod_oficina
    from ge_cta_clientes a,
         ov_asignaciones b
   where a.nro_cuenta = b.nro_cuenta
     and a.relacion = 'P'
     and ((a.cod_modulo in (15,5,6) or cod_modalidad =41) and (cod_modalidad <> 55 and cod_modalidad <> 58))
     and a.cod_persona != '11198'
union
select distinct a.cod_persona, a.nro_cuenta,
         case a.relacion
           when 'P' then 'T01'
           when 'Y' then 'T02'
           when 'O' then 'T02'
           when 'G' then 'A01'
           when 'C' then 'A01'
           when 'A' then 'A01'
           when 'D' then 'A01'
         end relacion,
         a.cod_modulo, a.cod_modalidad, a.cod_oficina
    from ge_cta_clientes a,
         ov_preventivas b
   where a.cod_persona = b.cod_persona
     and nvl(b.nro_cuenta,a.nro_cuenta) = a.nro_cuenta
     and a.relacion = 'P'
     and a.cod_modulo != 4
     and ((a.cod_modulo in (15,5,6) or cod_modalidad =41) and (cod_modalidad <> 55 and cod_modalidad <> 58))
     and a.cod_persona != '11198';

