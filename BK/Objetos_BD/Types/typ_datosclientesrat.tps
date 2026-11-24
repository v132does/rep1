CREATE OR REPLACE TYPE IT."TYP_DATOSCLIENTESRAT"                                          is OBJECT
(
cod_oficina          NUMBER(3),
est_civil            VARCHAR2(1),
cod_actividad        NUMBER(3),
--INFOCHECK
sit_infocheck        VARCHAR2(1),
fec_ult_infocheck    DATE,
--INFOCHECK CHQ RECH
can_chq_rch          NUMBER(3),
--INFOCHECK CHQ INHAB
can_inhabilitaciones NUMBER(3),
--INFORMCONF
faj_buro             VARCHAR2(1),
fec_ult_informconf   DATE,
--INFORMCONF DEMANDAS
can_demandas         NUMBER(10),
can_dem_finiq        NUMBER(10),
can_dem_no_finiq     NUMBER(10),
--INFORMCONF INHIBICIONES
can_inhibiciones     NUMBER(10),
can_inhi_finiq       NUMBER(10),
can_no_inhi_finiq    NUMBER(10),
--RRR
can_pp_rrr           NUMBER(3),
--EN GUARANIES CON LA COTIZACION DEL DIA
sal_promedio_act     NUMBER(20,2),
sal_promedio_ant     NUMBER(20,2),
sal_promedio_ant2    NUMBER(20,2),
--ATRASO > 30 ULTIMO 12 MESES
dia_mora_30          NUMBER(5),
--ATRASO > 45 ULTIMO 12 MESES
dia_mora_45          NUMBER(5),
tip_persona          VARCHAR2(1),
cod_usu_oficial      VARCHAR2(10),
nom_usu_oficial      VARCHAR2(60),
--CATEGORIAS DE CLIENTE
cat_sistema          NUMBER(1),
cat_riesgo           NUMBER(1),
--DEUDAS DEL CLIENTE
TOT_DEU_SISTEMA      NUMBER(20,2),
TOT_DEU_REAL         NUMBER(20,2),
HAB_DAT_CRC          varchar2(1),
--MANEJO DE ERRORES
error                   VARCHAR2(1),   -- Indica si la respuesta es de error o no
nombreRespuesta         VARCHAR2(15),  -- Codigo de respuesta
descripcionRespuesta    VARCHAR2(200), -- Descripcion del codigo de respuesta
  CONSTRUCTOR FUNCTION TYP_DATOSCLIENTESRAT RETURN SELF AS RESULT
)
/

