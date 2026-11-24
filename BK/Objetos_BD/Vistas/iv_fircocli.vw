create or replace force view it.iv_fircocli as
select 'BANCO;0007'||
       ';CODIGO DE CLIENTE;'|| nvl(rpad(b.cod_persona,10,' '),rpad(' ',10,' '))||
       ';TIPO DE CLIENTE;'|| b.tipo ||
       ';NUMERO DE DOCUMENTO DE IDENTIDAD;'||nvl(rpad(b.nro_documento,15,' '),rpad(' ',15,' '))||
       ';NOMBRE DEL CLIENTE;'||nvl(rpad(b.nom_completo,40,' '),rpad(' ',40,' '))||
       decode(b.tipo,
       'F',';FECHA DE NACIMIENTO;'||nvl(to_char(a.fec_nacimiento,'dd-mm-yyyy'),rpad(' ',10,' ')),
       'J',';FECHA DE NACIMIENTO;'||nvl(to_char(c.fec_apertura,'dd-mm-yyyy'),rpad(' ',10,' ')) )||
       decode(b.tipo,
       'F',';LUGAR DE NACIMIENTO;'||rpad(' ',15,' '),
       'J',';LUGAR DE NACIMIENTO;'||rpad(' ',15,' '))||
       ';PAIS DE NACIMIENTO;'||NVL(rpad(PAI_DTM.FU_OBT_NOM_PAIS(b.cod_pais),20,' '),RPAD(' ',20,' '))||

       ';DOMICILIO;'||nvl(rpad(replace(FUE_OBT_DIR_PRINCIPA(b.cod_persona),chr(10),''),50,' '),rpad(' ',50,' '))||
       ';CIUDAD;'||nvl(rpad(PAI_DTM.FU_OBT_NOM_CIUDAD(PAI_DTM.FU_OBT_PAIS(B.COD_PERSONA),
                                                      PAI_DTM.FU_OBT_CIUDAD(B.COD_PERSONA)),20,' '),rpad(' ',20,' '))||
       ';DEPARTAMENTO;'||nvl(rpad(pai_dtm.fu_obt_nom_departamento(PAI_DTM.FU_OBT_PAIS(B.COD_PERSONA),
                                                                  PAI_DTM.FU_OBT_CIUDAD(B.COD_PERSONA) ),20,' ') ,rpad(' ',20,' '))||
       ';PAIS DE RESIDENCIA;'||NVL(rpad(PAI_DTM.FU_OBT_NOM_PAIS(PAI_DTM.FU_OBT_PAIS(B.COD_PERSONA)),20,' '),RPAD(' ',20,' '))||
       ';PAIS DE NACIONALIDAD;'||NVL(rpad(PAI_DTM.FU_OBT_NOM_PAIS(b.cod_pai_documento),20,' '),RPAD(' ',20,' ')) cadena
from ba_personas b,
     ba_per_fisicas a,
     ba_per_juridicas c, ge_calendarios d

where fug_es_cliente(b.cod_persona)='S'
and a.cod_persona(+)=b.cod_persona
and c.cod_persona(+)=b.cod_persona
-- PN 13/03/2015 DYDMR-1651
and trunc(b.fec_insercion) = d.fec_actual --EGC - 17/03/2015 - DYDMR-1672 - Cambio de alias. Cambio a ba_personas.
and d.cod_modulo = 1
union
select 'BANCO;0007'||
       ';CODIGO DE CLIENTE;'|| nvl(rpad(b.cod_persona,10,' '),rpad(' ',10,' '))||
       ';TIPO DE CLIENTE;'|| b.tipo ||
       ';NUMERO DE DOCUMENTO DE IDENTIDAD;'||nvl(rpad(b.nro_documento,15,' '),rpad(' ',15,' '))||
       ';NOMBRE DEL CLIENTE;'||nvl(rpad(b.nom_completo,40,' '),rpad(' ',40,' '))||
       decode(b.tipo,
       'F',';FECHA DE NACIMIENTO;'||nvl(to_char(a.fec_nacimiento,'dd-mm-yyyy'),rpad(' ',10,' ')),
       'J',';FECHA DE NACIMIENTO;'||nvl(to_char(c.fec_apertura,'dd-mm-yyyy'),rpad(' ',10,' ')) )||
       decode(b.tipo,
       'F',';LUGAR DE NACIMIENTO;'||rpad(' ',15,' '),
       'J',';LUGAR DE NACIMIENTO;'||rpad(' ',15,' '))||
       ';PAIS DE NACIMIENTO;'||NVL(rpad(PAI_DTM.FU_OBT_NOM_PAIS(b.cod_pais),20,' '),RPAD(' ',20,' '))||

       ';DOMICILIO;'||nvl(rpad(replace(FUE_OBT_DIR_PRINCIPA(b.cod_persona),chr(10),''),50,' '),rpad(' ',50,' '))||
       ';CIUDAD;'||nvl(rpad(PAI_DTM.FU_OBT_NOM_CIUDAD(PAI_DTM.FU_OBT_PAIS(B.COD_PERSONA),
                                                      PAI_DTM.FU_OBT_CIUDAD(B.COD_PERSONA)),20,' '),rpad(' ',20,' '))||
       ';DEPARTAMENTO;'||nvl(rpad(pai_dtm.fu_obt_nom_departamento(PAI_DTM.FU_OBT_PAIS(B.COD_PERSONA),
                                                                  PAI_DTM.FU_OBT_CIUDAD(B.COD_PERSONA) ),20,' ') ,rpad(' ',20,' '))||
       ';PAIS DE RESIDENCIA;'||NVL(rpad(PAI_DTM.FU_OBT_NOM_PAIS(PAI_DTM.FU_OBT_PAIS(B.COD_PERSONA)),20,' '),RPAD(' ',20,' '))||
       ';PAIS DE NACIONALIDAD;'||NVL(rpad(PAI_DTM.FU_OBT_NOM_PAIS(b.cod_pai_documento),20,' '),RPAD(' ',20,' ')) cadena
from ba_personas b,
     ba_per_fisicas a,
     ba_per_juridicas c, ge_calendarios d

where fug_es_cliente(b.cod_persona)='S'
and a.cod_persona(+)=b.cod_persona
and c.cod_persona(+)=b.cod_persona
and trunc(b.fec_insercion) <> d.fec_actual --EGC - 17/03/2015 - DYDMR-1672 - Cambio de alias. Cambio a ba_personas.
and trunc(b.fec_modificacion) = d.fec_actual --EGC - 17/03/2015 - DYDMR-1672 - Cambio de alias. Cambio a ba_personas.
and d.cod_modulo = 1
;

