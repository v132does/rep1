create or replace force view it.gv_sol_ren_seguros as
select r.nro_renovacion, r.fec_confirmacion fecha, p.nom_completo, j.raz_social, null ci, p.nro_documento ruc, d.direccion, ba.descripcion des_barrio,
       ci.descripcion des_ciudad, FUE_OBT_TEL_REN_SEG(r.cod_persona, 'P', null, null ) tel_principal,
       FUE_OBT_TEL_REN_SEG(r.cod_persona, 'B', 'L', null ) tel_laboral, FUE_OBT_TEL_REN_SEG(r.cod_persona, 'C', 'P', null ) tel_celular, null sexo, null est_civil, null fec_nacimiento,
       b.descripcion ramo, p.dir_correo, null grupo, TO_CHAR(r.mto_capital, '999G999G999G999G999D99') mto_capital, TO_CHAR(r.mto_cuota, '999G999G999G999G999D99') mto_cuota,
       dt.direccion dir_trabajo, bal.descripcion des_bar_trabajo, cil.descripcion des_ciu_trabajo, a.descripcion actividad,
       r.cod_ente, en.descripcion des_ente, null edad, r.nro_poliza,
       fue_obt_denominacion(r.mto_capital) mto_cap_letras, null nacionalidad,
       null tot_ingreso, r.nro_cta_debito, 'X' es_juridica, null es_fisica,
       r.cod_moneda, decode(r.cod_moneda, 'GS', 'X') es_guaranies, decode(r.cod_moneda, 'USD', 'X') es_usd,
       null profesion, null es_femenino, null es_masculino, r.cod_tip_seguro
from ge_ren_pol_seguros r, ba_personas p, ba_per_juridicas j,
     ba_direcciones d, ba_barrios ba, ba_ciudades ci,
     ba_ramos b, ge_actividades a,
     ba_direcciones dt, ba_ciudades cil, ba_barrios bal,
     ge_entes en
where r.cod_persona = p.cod_persona
and r.cod_ente = en.cod_ente
--and r.estado = 'P'
and p.cod_persona = j.cod_persona
and j.cod_ramo = b.cod_ramo(+)
and p.cod_actividad = a.cod_actividad(+)
and p.cod_persona = d.cod_persona(+)
and d.principal(+) = 'S'
and ci.cod_pais(+) = d.cod_pais
and ci.cod_ciudad(+) = d.cod_ciudad
and ba.cod_pais(+) = d.cod_pais
and ba.cod_ciudad(+) = d.cod_ciudad
and ba.cod_barrio(+) = d.cod_barrio
and p.cod_persona = dt.cod_persona
and dt.cod_direccion = fue_obt_cod_dir_tipo(r.cod_persona, 'L')
and cil.cod_pais(+) = dt.cod_pais
and cil.cod_ciudad(+) = dt.cod_ciudad
and bal.cod_pais(+) = dt.cod_pais
and bal.cod_ciudad(+) = dt.cod_ciudad
and bal.cod_barrio(+) = dt.cod_barrio
union all
-- Persona Juridica sin direccion laboral
select r.nro_renovacion, r.fec_confirmacion fecha, p.nom_completo, j.raz_social, null ci, p.nro_documento ruc, d.direccion, ba.descripcion, ci.descripcion, FUE_OBT_TEL_REN_SEG(r.cod_persona, 'P', null, null) tel_principal,
       FUE_OBT_TEL_REN_SEG(r.cod_persona, 'B', 'L', null ) tel_laboral, FUE_OBT_TEL_REN_SEG(r.cod_persona, 'C', 'P', null ) tel_celular, null sexo, null est_civil, null fec_nacimiento,
       b.descripcion, p.dir_correo, null grupo, TO_CHAR(r.mto_capital, '999G999G999G999G999D99') mto_capital, TO_CHAR(r.mto_cuota, '999G999G999G999G999D99') mto_cuota,
       null, null, null, a.descripcion actividad,
       r.cod_ente, en.descripcion des_ente, null edad, r.nro_poliza,
       fue_obt_denominacion(r.mto_capital) mto_cap_letras, null nacionalidad,
       null tot_ingreso, r.nro_cta_debito, 'X' es_juridica, null es_fisica,
       r.cod_moneda, decode(r.cod_moneda, 'GS', 'X') es_guaranies, decode(r.cod_moneda, 'USD', 'X') es_usd,
       null profesion, null es_femenino, null es_masculino, r.cod_tip_seguro
from ge_ren_pol_seguros r, ba_personas p, ba_per_juridicas j,
     ba_direcciones d, ba_barrios ba, ba_ciudades ci,
     ba_ramos b, ge_actividades a,ge_entes en
where r.cod_persona = p.cod_persona
and r.cod_ente = en.cod_ente
--and r.estado = 'P'
and p.cod_persona = j.cod_persona
and j.cod_ramo = b.cod_ramo(+)
and p.cod_actividad = a.cod_actividad(+)
and p.cod_persona = d.cod_persona(+)
and d.principal(+) = 'S'
and ci.cod_pais(+) = d.cod_pais
and ci.cod_ciudad(+) = d.cod_ciudad
and ba.cod_pais(+) = d.cod_pais
and ba.cod_ciudad(+) = d.cod_ciudad
and ba.cod_barrio(+) = d.cod_barrio
and fue_obt_cod_dir_tipo(r.cod_persona, 'L') = 0
union all
-- Persona Fisica con direccion laboral
select r.nro_renovacion, r.fec_confirmacion  fecha, p.nom_completo, p.nom_completo, p.nro_documento ci, FUE_OBT_DAT_PERSONAS (r.cod_persona, 'RUC'),
       d.direccion, ba.descripcion, ci.descripcion, FUE_OBT_TEL_REN_SEG(r.cod_persona, 'P', null, null) tel_principal,
       FUE_OBT_TEL_REN_SEG(r.cod_persona, 'B', 'L', null ) tel_laboral, FUE_OBT_TEL_REN_SEG(r.cod_persona, 'C', 'P', null ) tel_celular,
       decode(f.cod_sexo, 'F', 'Femenino', 'Masculino')  sexo, e.significado est_civil, to_char(f.fec_nacimiento, 'dd/mm/yyyy') fec_nacimiento,
       null, p.dir_correo, null grupo, TO_CHAR(r.mto_capital, '999G999G999G999G999D99') mto_capital, TO_CHAR(r.mto_cuota, '999G999G999G999G999D99') mto_cuota,
      dt.direccion dir_trabajo, bal.descripcion des_bar_trabajo, cil.descripcion des_ciu_trabajo, a.descripcion actividad,
       r.cod_ente, en.descripcion des_ente, TRUNC(MONTHS_BETWEEN(SYSDATE, f.fec_nacimiento)/12) edad, r.nro_poliza,
       fue_obt_denominacion(r.mto_capital) mto_cap_letras, pa.nacionalidad,
       TO_CHAR(fug_obt_ing_cliente(r.cod_persona, 'F'), '999G999G999G999G999D99') tot_ingreso, r.nro_cta_debito,
       null es_juridica, 'X' es_fisica,
       r.cod_moneda, decode(r.cod_moneda, 'GS', 'X') es_guaranies, decode(r.cod_moneda, 'USD', 'X') es_usd,
       pr.descripcion, decode(f.cod_sexo, 'F', 'X', null)  es_femenino, decode(f.cod_sexo, 'M', 'X', null) es_masculino, r.cod_tip_seguro
from ge_ren_pol_seguros r, ba_personas p, ba_per_fisicas f,
     ba_direcciones d, ba_barrios ba, ba_ciudades ci,
     ge_actividades a,
     ba_direcciones dt, ba_ciudades cil, ba_barrios bal,
     ba_cod_referencias e,ge_entes en, ba_paises pa, Ba_Profesiones pr
where r.cod_persona = p.cod_persona
and r.cod_ente = en.cod_ente
--and r.estado = 'P'
and p.cod_persona = f.cod_persona
and p.cod_actividad = a.cod_actividad(+)
and p.cod_persona = d.cod_persona(+)
and d.principal(+) = 'S'
and ci.cod_pais(+) = d.cod_pais
and ci.cod_ciudad(+) = d.cod_ciudad
and ba.cod_pais(+) = d.cod_pais
and ba.cod_ciudad(+) = d.cod_ciudad
and ba.cod_barrio(+) = d.cod_barrio
and p.cod_persona = dt.cod_persona
and dt.cod_direccion = fue_obt_cod_dir_tipo(r.cod_persona, 'L')
and cil.cod_pais(+) = dt.cod_pais
and cil.cod_ciudad(+) = dt.cod_ciudad
and bal.cod_pais(+) = dt.cod_pais
and bal.cod_ciudad(+) = dt.cod_ciudad
and bal.cod_barrio(+) = dt.cod_barrio
and e.dominio = 'COD_EST_CIVIL'
and e.val_minimo = f.est_civil
and f.cod_pai_nacionalidad = pa.cod_pais
and f.cod_profesion = pr.cod_profesion
union all
-- Persona Fisica con direccion laboral
select r.nro_renovacion, r.fec_confirmacion fecha, p.nom_completo, p.nom_completo, p.nro_documento ci, FUE_OBT_DAT_PERSONAS (r.cod_persona, 'RUC'),
       d.direccion, ba.descripcion, ci.descripcion, FUE_OBT_TEL_REN_SEG(r.cod_persona, 'P', null, null) tel_principal,
       FUE_OBT_TEL_REN_SEG(r.cod_persona, 'B', 'L', null ) tel_laboral, FUE_OBT_TEL_REN_SEG(r.cod_persona, 'C', 'P', null ) tel_celular,
       decode(f.cod_sexo, 'F', 'Femenino', 'Masculino')  sexo, e.significado est_civil, to_char(f.fec_nacimiento, 'dd/mm/yyyy') fec_nacimiento,
       null, p.dir_correo, null grupo, TO_CHAR(r.mto_capital, '999G999G999G999G999D99') mto_capital, TO_CHAR(r.mto_cuota, '999G999G999G999G999D99') mto_cuota,
       null, null, null, a.descripcion actividad,
       r.cod_ente, en.descripcion des_ente, TRUNC(MONTHS_BETWEEN(SYSDATE, f.fec_nacimiento)/12) edad, r.nro_poliza,
       fue_obt_denominacion(r.mto_capital) mto_cap_letras, pa.nacionalidad,
       TO_CHAR(fug_obt_ing_cliente(r.cod_persona, 'F'), '999G999G999G999G999D99') tot_ingreso, r.nro_cta_debito,
       null es_juridica, 'X' es_fisica,
       r.cod_moneda, decode(r.cod_moneda, 'GS', 'X') es_guaranies, decode(r.cod_moneda, 'USD', 'X') es_usd,
       pr.descripcion, decode(f.cod_sexo, 'F', 'X', null)  es_femenino, decode(f.cod_sexo, 'M', 'X', null) es_masculino, r.cod_tip_seguro
from ge_ren_pol_seguros r, ba_personas p, ba_per_fisicas f,
     ba_direcciones d, ba_barrios ba, ba_ciudades ci,
     ge_actividades a,
     ba_cod_referencias e,ge_entes en, ba_paises pa, ba_profesiones pr
where r.cod_persona = p.cod_persona
and r.cod_ente = en.cod_ente
--and r.estado = 'P'
and p.cod_persona = f.cod_persona
and p.cod_actividad = a.cod_actividad(+)
and p.cod_persona = d.cod_persona(+)
and d.principal(+) = 'S'
and ci.cod_pais(+) = d.cod_pais
and ci.cod_ciudad(+) = d.cod_ciudad
and ba.cod_pais(+) = d.cod_pais
and ba.cod_ciudad(+) = d.cod_ciudad
and ba.cod_barrio(+) = d.cod_barrio
and fue_obt_cod_dir_tipo(r.cod_persona, 'L') =0
and e.dominio = 'COD_EST_CIVIL'
and e.val_minimo = f.est_civil
and f.cod_pai_nacionalidad = pa.cod_pais
and f.cod_profesion = pr.cod_profesion
;

