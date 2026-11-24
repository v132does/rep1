CREATE OR REPLACE PACKAGE IT.PAB_SIM IS

/*Genera el devengado de las operaciones futuras.*/
PROCEDURE PR_DEV_OPE_FUTURAS(p_fecha in ge_calendarios.fec_actual%type);

/* Calcula el Devengado de Ahorro Vista */
PROCEDURE PR_DEV_AHORROS(p_fecha in ge_calendarios.fec_actual%type);

/* Calcula el Devengado de CDA. */
PROCEDURE PR_DEV_CERTIFICADOS(p_fecha in ge_calendarios.fec_actual%type);

/* Calcula el Devengado de Préstamos. */
PROCEDURE PR_PRO_DEV_PRESTAMOS(p_fecha in ge_calendarios.fec_actual%type);

/* Calcula el Devengado de Mesa de Dinero. */
PROCEDURE PR_PRO_DEV_MESA(p_fecha in ge_calendarios.fec_actual%type);

/* Calcula el comision por Bajo Promedio Ahorro. */
PROCEDURE PR_DEB_SAL_MIN_AHORRO(p_fecha in ge_calendarios.fec_actual%type);

/* Calcula el comision por Bajo Promedio Cuentas Corrientes. */
PROCEDURE PR_DEB_SAL_MIN_CTACTE(p_fecha in ge_calendarios.fec_actual%type);

/* Calcula cargos por Sobregiros. */
PROCEDURE PR_LIQ_CAR_SOBREGIROS(p_fecha in ge_calendarios.fec_actual%type,
                                p_nro_cuenta in ge_cuentas.nro_cuenta%type default null);

/* Proceso Principal - Genera el Balance Proyectado. */
PROCEDURE PR_GEN_BALANCE;

END PAB_SIM;
/

