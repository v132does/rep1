CREATE OR REPLACE PACKAGE IT.PAB_COR is

--Inicializa hora de Inicio y Fin antes de procesar
PROCEDURE PR_INI_PRO_RUBRO;

--Inactiva rubro especificado en el parametro
PROCEDURE PR_INA_RUBRO(p_cod_rubro IN varchar2 default null);

--Activa rubro especificado en el parametro
PROCEDURE PR_ACT_RUBRO(p_cod_rubro IN varchar2 default null);

--Procedimiento principal de Conciliaciones
PROCEDURE PR_GEN_CON_RUB;

--Genera conciliacion de un rubro dado
PROCEDURE PR_GEN_RUB_CONC
(v_cod_rubro varchar2
);

--Proceso para insercion de movimientos del rubro
PROCEDURE PR_CON_CAR_DATOS
(v_cod_rubro varchar2, 
v_consulta long,
v_fec_inicio varchar2 default null);

--Proceso que concilia todas las partidas del rubro en caso de que el saldo actual=0
PROCEDURE PR_CER_SALDO
(v_cod_rubro varchar2);

---Proceso de conciliacion básica según la AS400
PROCEDURE PR_CON_BASICO
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2
);
---Proceso de conciliacion básica según la AS400 teniendo en cuenta el mismo concepto
PROCEDURE PR_CON_CONCEPTO
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2
);

---Proceso de conciliacion por montos iguales
PROCEDURE PR_CON_TOT_MONTO
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2
);

--Proceso de conciliacion por total de montos de una fecha dada contra total de montos de otra fecha
PROCEDURE PR_CON_TOT_FEC_MONTO
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2,
v_dias number);
--Proceso de pase a historico de conciliados
PROCEDURE PR_CON_PAS_HIS_RUB
(v_cod_rubro varchar2) ;


-- Proceso de conciliacion por montos y numero de boleta
PROCEDURE PR_CON_NRO_BOLETA
( 	 v_cod_rubro varchar2,
	 v_mov_inicial char,
	 v_mov_final 	char
);

-- Proceso de conciliacion por montos y cuenta operativa
PROCEDURE PR_CON_CTA_OPER
(  v_cod_rubro varchar2,
	 v_mov_inicial char,
	 v_mov_final 	char
);
-- Proceso de conciliacion básico con busqueda a 48 hs
PROCEDURE PR_CON_BASICO_ATM
(v_cod_rubro varchar2,
v_mov_inicial char,
v_mov_final char
);

-- Proceso de conciliacion por monto y concepto con busqueda a 48 hs
PROCEDURE PR_CON_CONCEPTO_ATM
(v_cod_rubro varchar2,
v_mov_inicial char,
v_mov_final char
);
PROCEDURE PR_CON_TOTALES_ATM
( v_cod_rubro varchar2,
v_mov_inicial char,
v_mov_final char);

end PAB_COR;
/

