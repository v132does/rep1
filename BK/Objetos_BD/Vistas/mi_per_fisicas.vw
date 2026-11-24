create or replace force view it.mi_per_fisicas as
select u.cod_oficina, p.cod_persona, p.cod_usu_promotor, u.nombre, p.cod_tip_documento, p.nro_documento,
     f.pri_apellido, f.seg_apellido, f.pri_nombre, f.seg_nombre, d.direccion, b.descripcion pais,
     c.descripcion ciudad, a.descripcion barrio, t.telefono
from ba_personas p, ba_per_fisicas f, ba_direcciones d, ba_telefonos t, ba_usuarios u,
     ba_barrios a, ba_ciudades c, ba_paises b
where p.cod_persona = f.cod_persona
and d.cod_persona = p.cod_persona
and t.cod_persona(+) = p.cod_persona
and p.cod_usu_promotor = u.cod_usuario(+)
and d.cod_barrio = a.cod_barrio
and d.cod_ciudad = a.cod_ciudad
and d.cod_pais = a.cod_pais
and c.cod_ciudad = a.cod_ciudad
and c.cod_pais = a.cod_pais
and b.cod_pais = a.cod_pais
and d.principal = 'S'
and (t.principal = 'S' or t.principal is null)
union all
select u.cod_oficina, p.cod_persona, p.cod_usu_promotor, u.nombre, p.cod_tip_documento, p.nro_documento,
     f.pri_apellido, f.seg_apellido, f.pri_nombre, f.seg_nombre, null, null,
     null, null,null
from ba_personas p, ba_per_fisicas f, ba_usuarios u
where p.cod_persona = f.cod_persona
and p.cod_usu_promotor = u.cod_usuario(+)
and not exists (select 1 from ba_direcciones d
                where d.cod_persona = p.cod_persona
                and d.principal = 'S');

