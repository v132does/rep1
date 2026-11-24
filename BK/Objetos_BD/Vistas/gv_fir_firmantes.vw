create or replace view it.gv_fir_firmantes as
select a.nro_cuenta nro_cuenta, a.cod_persona, nom_completo nombre, nro_documento documento,
       decode(c.est_firma, null,'NO ESCANEADA','R','RECHAZADA','A','APROBADA','E','NO APROBADA') estado
  from ba_per_firmas c,ba_personas b, ge_cta_clientes a
 where b.cod_persona = a.cod_persona
   and b.tipo = 'F'
   and c.cod_persona(+) = a.cod_persona;
