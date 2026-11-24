CREATE OR REPLACE PACKAGE IT.PAG_INF IS

/* Generancion de transacciones de Ahorros */
PROCEDURE PR_PRO_TRA_AHORROS;
/* Generacion de transacciones de Cuentas Corrientes */
PROCEDURE PR_PRO_TRA_CTA_CTES;
/* Generación de transacciones de Caja */
PROCEDURE PR_PRO_TRA_CAJA;
/* Generación de transacciones de Prestamos */
PROCEDURE PR_PRO_TRA_PRESTAMOS;
END PAG_INF;
/

