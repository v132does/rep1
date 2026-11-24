create or replace force view it.gv_emision_claves as
select d.clave cod_persona, p.nom_completo nom_completo, p.tipo tipo_persona, it.fuy_obt_nom_usuario(c.cod_usu_oficial) agente,
       c.cod_oficina ofi_cliente, o.descripcion desc_oficina, d.fec_sistema fecha, d.usuario, u.nombre nom_usu_impresion/*,
       d.detalle, it.fue_obt_novedad(d.tip_novedad, d.detalle) detalle_nov*/
  from it.ge_auditorias d, it.ba_personas p, it.ge_clientes c, it.ba_oficinas o, it.ba_usuarios u
 where d.tabla = 'GE_CLIENTES'
   and d.detalle like '%~CLAVE:<i::f><i:%' /*que no tenia clave y luego ya tuvo*/
   and trim(d.clave) = p.cod_persona
   and trim(d.clave) = c.cod_persona
   and c.cod_oficina = o.cod_oficina
   and d.usuario = u.cod_usuario(+);

