create or replace force view it.tv_tar_modificadas as
select t.nro_cuenta, t.nro_tarjeta, t.cod_persona, c.nro_documento, c.cod_tip_documento, b.nro_solicitud,
       b.cod_modulo, b.cod_modalidad, b.cod_oficina, x.cod_ent_procesadora
  from ta_tipos x, ba_personas c, ta_cta_tarjetas b, ta_tarjetas t,(select clave from ba_auditorias a
                                                         where a.tabla = 'BA_PERSONAS'
                                                           and fec_calendario = pag_cal.fu_obt_fec_actual(5)
                                                           and a.detalle like '%NRO_DOCUMENTO%') b
where b.clave = t.cod_persona
  and c.cod_persona = t.cod_persona
  and b.nro_cuenta = t.nro_cuenta
  and b.cod_modulo = x.cod_modulo
  and b.cod_modalidad = x.cod_modalidad
  and b.afinidad      = x.afinidad
  and nvl(b.sub_afinidad,'XX') = nvl(x.sub_afinidad,'XX')
  and (b.cod_oficina = x.cod_oficina or x.cod_oficina is null)
  and x.cod_campana is null
  and b.estado <> 'C';

