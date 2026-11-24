CREATE OR REPLACE PACKAGE IT.PAS_PLA IS

/*genera los datos de moneda ext. arbitrada en usd*/
PROCEDURE PR_GEN_6100
(p_sector_desde  in  varchar2,
 p_sector_hasta  in  varchar2
 );
/*genera los datos de moneda extranjera*/
PROCEDURE PR_GEN_6200
(SECTOR_DESDE  IN  VARCHAR2,
 SECTOR_HASTA  IN  VARCHAR2
 );
/*genera los datos en moneda local*/
PROCEDURE PR_GEN_6900
(SECTOR_DESDE  IN  VARCHAR2,
 SECTOR_HASTA  IN  VARCHAR2
 );
/*genera promedio en moneda local (6900)*/
PROCEDURE PR_GEN_6400
(SECTOR_DESDE  IN  VARCHAR2,
 SECTOR_HASTA  IN  VARCHAR2
 );
/*genera promedio moneda ext. en usd (6100)*/
PROCEDURE PR_GEN_6500
(SECTOR_DESDE  IN  VARCHAR2,
 SECTOR_HASTA  IN  VARCHAR2
 );
/*genera promedio en moneda ext (6200)*/
PROCEDURE PR_GEN_6600
(SECTOR_DESDE  IN  VARCHAR2,
 SECTOR_HASTA  IN  VARCHAR2
 );
/*genera datos 6100 a partir de la 6200*/
PROCEDURE PR_GEN_6100_RESULTADO
(SECTOR_DESDE  IN  VARCHAR2,
 SECTOR_HASTA  IN  VARCHAR2
 );
/*genera datos moneda local 6900*/
PROCEDURE PR_GEN_6900_RESULTADO
(SECTOR_DESDE  IN  VARCHAR2,
 SECTOR_HASTA  IN  VARCHAR2
 );
/*genera datos moneda ext. 6200*/
PROCEDURE PR_GEN_6200_RESULTADO
(SECTOR_DESDE  IN  VARCHAR2,
 SECTOR_HASTA  IN  VARCHAR2
 );
/*proceso q genera datos para el estado de resultado*/
PROCEDURE PR_GEN_EST_RESULTADO;
/*proceso q genera datos para el estado de situación*/
PROCEDURE PR_GEN_EST_SITUACION;
/*proceso de sumarización de datos*/
PROCEDURE PR_PRO_SUMARIZACION
(SECTOR_DESDE  IN  VARCHAR2 DEFAULT 1, --- agregado por Teresita 21/09/2007
 SECTOR_HASTA  IN  VARCHAR2 DEFAULT 9 --- agregado por Teresita 21/09/2007
 );
/*proceso q genera datos para el archivo de riesgos*/
PROCEDURE PR_PRO_RIESGO;
/* Genera archivos ASCII a partir de tablas de planinfo */
PROCEDURE PR_GEN_ASCII;
/*proceso principal de genearación de arhivos de planinfo*/
PROCEDURE PR_PRO_PLANINFO;
/*proceso para generar el archivo ID, informe diario de rubros*/
PROCEDURE PR_PRO_ARCHIVO_ID;
/*proceso de verificación del informe de planinfo*/
PROCEDURE PR_AJU_CTA_CONTABLES;
/*Proceso que realiza la validación del informe de planinfo.*/
PROCEDURE PR_VAL_PLANINFO;

END PAS_PLA;
/

