create or replace view it.gv_fir_firmas as
select b.cod_persona, nom_completo nombre, nro_documento documento,  nvl(c.ima_firma,'') imagen
  from ba_per_firmas c,ba_personas b
 where c.cod_persona = b.cod_persona
   and b.tipo = 'F'
   and c.est_firma = 'A';
