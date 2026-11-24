CREATE OR REPLACE PACKAGE IT.PAB_CON is

PROCEDURE PR_GEN_CONCILIACION;

--Genera conciliacion de un rubro dado
PROCEDURE PR_GEN_RUB_CONCILIACION
(v_cod_rubro varchar2
);

--Proceso para insercion de movimientos del rubro
PROCEDURE PR_CON_CARGA
(v_cod_rubro varchar2, 
v_consulta long,
v_fec_inicio varchar2 default null);

--Proceso de conciliacion por monto, cod_moneda, nro_documento
PROCEDURE PR_CON_MTO_MON_DOC
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2);

--Proceso de conciliacion por monto, cod_moneda, nro_documento
PROCEDURE PR_CON_MTO_MON_CUENTA
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2);

--Proceso de conciliacion agrupando por creditos o débitos según el parámetro dado
PROCEDURE PR_CON_TIPOMOV
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2);

--Proceso de pase a historico de conciliados
PROCEDURE PR_CON_PAS_HIS
(v_cod_rubro varchar2) ;

--Proceso de conciliacion por total de documento y cuenta
PROCEDURE PR_CON_TOT_DOC_CTA
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2);

--Proceso de conciliacion por total de montos de una fecha dada contra total de montos de otra fecha
PROCEDURE PR_CON_TOT_FEC_MON
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2,
v_dias number);

---Proceso de conciliacion por montos iguales
PROCEDURE PR_CON_TOT_MON
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2
);

end PAB_CON;
/

