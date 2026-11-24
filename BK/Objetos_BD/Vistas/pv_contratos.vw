create or replace force view it.pv_contratos as
select g.nom_completo Nom_titular,
g.nro_documento Nro_doc_titular,
a.nro_solicitud,a.cod_moneda Cod_moneda,
nvl(a.tot_prestamo,0) Tot_prestamo,
fue_obt_denominacion(a.tot_prestamo) des_monto,
a.dia_plazo dia_plazo,a.descripcion descripcion,
fup_obt_des_garantia(a.nro_solicitud) garantia,
b.val_tasa val_tasa,
c.c_direccion dir_persona,c.c_ciudad per_ciudad,
e.descripcion ofi_ciudad,
fug_des_fecha(nvl(a.fec_inicio,sysdate)) des_fecha,
decode(f.cod_per_vinculo,null,' ',f.nom_completo) nom_conyuge,
decode(f.cod_per_vinculo,null,' ',f.nro_documento) nro_doc_conyuge
from pr_solicitudes a,pr_sol_tasas b,
     (select z.cod_persona c_cod_persona, z.direccion||decode(numero,null,'',' '||numero) c_direccion,
      y.descripcion c_ciudad
      from ba_direcciones z,ba_ciudades y
      where z.cod_pais = y.cod_pais
      and z.cod_ciudad = y.cod_ciudad
      and z.principal = 'S') c,
     ba_oficinas d,ba_ciudades e,(select x.cod_persona cod_persona,
                                         x.cod_per_vinculo cod_per_vinculo,
                                         w.nom_completo nom_completo,
                                         w.nro_documento nro_documento
                                  from ba_vinculos x,
                                       ba_personas w
                                  where x.cod_per_vinculo = w.cod_persona
                                    and x.tipo = 'E') f,-- Datos del Conyuge
     ba_personas g -- Datos del Titular
where a.cod_persona = c.c_cod_persona(+)
  and a.cod_persona = f.cod_persona(+)
  and a.cod_persona = g.cod_persona
  and a.nro_solicitud = b.nro_solicitud
  and a.fec_inicio = b.fec_vigencia
  and a.cod_oficina = d.cod_oficina
  and d.cod_pais = e.cod_pais
  and d.cod_ciudad = e.cod_ciudad
;

