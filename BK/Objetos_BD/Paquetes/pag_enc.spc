CREATE OR REPLACE PACKAGE IT.PAG_ENC AS
--**********************************************************************************************************
--** OBJETIVO             : CONTIENE LAS UTILIDADES DE ENCRIPCION Y DESENCRIPCION
--** NOMBRE               : PAG_ENC
--** AUTOR                : VICTOR VELAZTIQUI
--** FECHA CREACION       : 07/FEBRERO/2018
--**********************************************************************************************************

   -------------------- FUNCION QUE ENCRIPTA UN TEXTO------------------------
   FUNCTION FU_ENCRIPTAR(P_ENCRIPTAR VARCHAR2) RETURN RAW;


   ------------------- FUNCION QUE DESCENCRIPTA UN TEXTO----------------------
   FUNCTION FU_DESCENCRIPTAR(P_DESCENCRIPTAR VARCHAR2) RETURN VARCHAR2;

END PAG_ENC;
/

