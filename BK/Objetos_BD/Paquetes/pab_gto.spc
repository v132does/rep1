CREATE OR REPLACE PACKAGE IT.PAB_GTO IS

-- Fecha: 03/09/2013 DI.
-- REG-BBVA-0128-ETRA-DSIS-02-FATD.01-DER_GASTOS 

-- Obtiene la relación de los códigos de centros de costos.
FUNCTION FU_OBT_REL_CEN_COSTOS(p_cod_cen_costos in ba_areas.cod_area%type) 
RETURN NUMBER;

-- Obtiene los movimientos del modulo de Proveedores.
PROCEDURE PR_GEN_PROVEEDORES;

-- Validación del proceso de importación de la parametrización de los tipos de distribución.
PROCEDURE PR_VAL_PAR_GASTOS;

-- Validación del proceso de importación de la parametrización del destino del proceso de derrama de gastos.
PROCEDURE PR_VAL_TIP_GASTOS;

-- Proceso que realiza la derrama de gastos.
PROCEDURE PR_PRO_DIS_GASTOS;

-- Obtiene los movimientos de asientos manuales registrados antes de ejecutar el proceso de distribución.
PROCEDURE PR_GEN_ASI_MANUALES;

-- Obtiene los asientos manuales registrados antes de ejecutar el proceso de distribución.
PROCEDURE PR_OBT_ASI_MANUALES;

--  Movimientos de Apuntes Masivos.
--  Requerimiento: CNFDEEVO-46.
PROCEDURE PR_GEN_APU_MASIVOS;

END PAB_GTO;
/

