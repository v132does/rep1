CREATE OR REPLACE PACKAGE IT.PAG_VTA IS

-- Proceso Principal.
PROCEDURE PR_GEN_VTA_CARTERA;

-- Realiza la validación de las cuentas importadas.
PROCEDURE PR_VAL_VTA_CARTERA;

-- Realiza la venta de cartera de cuentas corrientes en sobregiro.
PROCEDURE PR_VTA_CAR_SOBREGIROS ( P_REF_LOTE NUMBER );

-- Realiza la venta de cartera de préstamos.
PROCEDURE PR_VTA_CAR_PRESTAMOS ( P_REF_LOTE NUMBER);

-- Realiza la venta de cartera de Operaciones Vencidas.
PROCEDURE PR_VTA_CAR_OPE_VENCIDAS ( P_REF_LOTE NUMBER );

-- PROCEDIMIENTO PARA VENTA DE Prestamos PreAprobados
PROCEDURE PR_VTA_CAR_PREAPROBADOS(P_NRO_CUENTA IN VARCHAR2, P_HORA IN OUT VARCHAR2, P_NRO_SEQ IN OUT VARCHAR2, p_exonera in varchar2);

-- Procedimiento para eliminar descuentos o exoneraciones de mora/cargos, etc registradas para la cuenta.
PROCEDURE PR_ELI_EXO_CARGOS(P_NRO_CUENTA IN VARCHAR2);

-- Procedimiento para insertar descuentos o exoneraciones de mora/cargos, etc registradas para la cuenta
-- en el modulo de exoneraciones.
PROCEDURE PR_INS_EXO_CARGOS(p_gauto IN ge_autorizaciones%rowtype);
END PAG_VTA;
/

