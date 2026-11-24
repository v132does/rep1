CREATE OR REPLACE PACKAGE IT.PAG_ARC IS
  g_archivo     UTL_FILE.FILE_TYPE;
  g_ruta        VARCHAR2(2000);
  g_nom_archivo VARCHAR2(1000);
/* Inicializa las variables del proceso */
PROCEDURE PR_ARC_INICIO;
/* Abrir archivo */
FUNCTION FU_ARC_ABRIR
 (P_RUTA IN VARCHAR2
 ,P_ARCHIVO IN VARCHAR2
 ,P_TIPO IN VARCHAR2 DEFAULT 'R'
 )
 RETURN UTL_FILE.FILE_TYPE;
/* Obtiene una linea del archivo */
FUNCTION FU_ARC_LEER
 (P_ARCHIVO IN UTL_FILE.FILE_TYPE DEFAULT pag_arc.g_archivo
 )
 RETURN VARCHAR2;
/* Escribir una linea en un fichero */
PROCEDURE PR_ARC_ESCRIBIR
 (P_LINEA IN VARCHAR2
 ,P_ARCHIVO IN UTL_FILE.FILE_TYPE DEFAULT pag_arc.g_archivo
 );
/* Cierra el archivo */
PROCEDURE PR_ARC_CERRAR
 (P_ARCHIVO IN UTL_FILE.FILE_TYPE DEFAULT pag_arc.g_archivo
 );
 /* Procesa un archivo de texto */
PROCEDURE PR_ARC_PRO_ARCHIVO( p_referencia VARCHAR2,
                              p_directorio VARCHAR2,
                              p_fecha      DATE DEFAULT SYSDATE
                              );
/* Controla los errores del proceso de archivos */
PROCEDURE PR_ARC_ERROR
 (P_NRO_ERROR IN NUMBER DEFAULT 0
 ,P_MEN_ERROR IN VARCHAR2 DEFAULT 'NULL'
 );
PROCEDURE PR_ARC_LEE_ARCHIVO( p_referencia IN VARCHAR2,
                              p_directorio IN VARCHAR2,
                              p_archivo    IN VARCHAR2,
                              p_tabla      IN VARCHAR2,
                              p_linea_ini  IN NUMBER,
                              p_linea_fin  IN NUMBER,
                              p_fecha      IN DATE DEFAULT SYSDATE
                              );
END PAG_ARC;
/

