CREATE OR REPLACE FORCE VIEW IT.TV_ASC_SOLICITUDES AS
SELECT  rpad(i.lug_trabajo,40,' ')|| -- empresa, --Agente
       rpad(de.direccion,40,' ')||-- dir_empresa,
       rpad(' ',3,' ')|| -- moneda,
       rpad(p.cod_actividad,4,' ')||-- nro_registro,--actbcp
       rpad(decode(p.cod_tip_documento,1,'CI',5,'CI',38,'CI',39,'CI',40,'CI',41,'CI',2,'PAS',3,'CRP',6,'RUC'),3,' ')||-- tipo_doc,
       rpad(substr(p.nro_documento,1,15),15,' ')|| -- nro_documento,
       rpad(' ',2,' ')||-- pais,
       rpad(substr(pf.pri_apellido,1,15),15,' ')||-- pri_apellido,
       rpad(substr(pf.seg_apellido,1,15),15,' ')||-- seg_apellido,
       rpad(' ',15,' ')||-- ape_casada,
       rpad(substr(pf.pri_nombre||' '||pf.seg_nombre,1,15),15,' ')||-- nombres,
       rpad(to_char(pf.fec_nacimiento,'DDMMYYYY'),10,' ')||-- fec_naci,
       rpad(decode(pf.est_civil,'B','C',pf.est_civil),1,' ')||-- est_civil,
       rpad(' ',2,' ')||-- nacio,
       rpad(pf.cod_sexo,1,' ')||-- sexo,
       rpad(substr(di.direccion,1,40),40,' ')||-- direccion,
       rpad(substr(t.telefono,1,11),11,' ')|| --telefono,
       rpad(fue_obt_des_ciudad(di.cod_pais,di.cod_ciudad),20,' ')|| --ciudad,
       rpad(' ',10,' ')||-- fec_ant_lab,
       rpad(' ',20,' ')||-- profesion,
       rpad(' ',9,' ')||-- ing_bruto,
       rpad(' ',30,' ')||-- conyuge,
       rpad(decode(pf.est_civil,'B','S','N'),1,' ')||-- sep_bienes,
       rpad(' ',1,' ')||-- a_hb,
       rpad(' ',50,' ')||-- dirmail,
       rpad(substr(p.cod_persona,1,6),6,' ')||-- nro_riesgo,
       rpad(' ',1,' ') linea_pagsue, --i_cta,
       p.cod_persona
from ba_personas p, ba_per_fisicas pf, ba_direcciones di, ba_telefonos t, ge_clientes g, cr_inf_laborales i,
     ge_entes e, ba_direcciones de, ta_solicitudes_tmp n
where p.cod_persona = pf.cod_persona
  and p.cod_persona = di.cod_persona
  and p.cod_persona = t.cod_persona
  and p.cod_persona = g.cod_persona
  and nvl(di.principal,'N') = 'S'
  and nvl(t.principal,'N') = 'S'
  and i.cod_persona = p.cod_persona
  and i.actual = 'S'
  and i.lug_trabajo = e.descripcion
 -- and e.tipo = 'SU'
  and e.cod_persona = de.cod_persona
  and nvl(de.principal,'N') = 'S'
  and n.nro_documento = p.nro_documento
;

