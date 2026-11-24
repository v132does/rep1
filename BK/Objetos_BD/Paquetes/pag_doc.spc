CREATE OR REPLACE PACKAGE IT.pag_doc IS
   /**********************
   -- Author  : RBATTAGLIA
   -- Created : 12/03/2012 05:27:12 p.m.
   -- Purpose : Manejo de todo lo relacionado con las operaciones de Números de Documentos
   ***********************/

   /*Obtiene el número más próximo con estado 'D'-Disponible*/
   FUNCTION fu_obt_min_documento
   (
      p_tipo        ge_inv_documentos.tipo%TYPE,
      p_cod_oficina ge_inv_documentos.cod_oficina%TYPE
   ) RETURN NUMBER;

   /*Obtiene el estado del número de documento*/
   FUNCTION fu_obt_estado
   (
      p_tipo          ge_inv_documentos.tipo%TYPE,
      p_cod_oficina   ge_inv_documentos.cod_oficina%TYPE,
      p_nro_documento ge_inv_documentos.nro_inicial%TYPE
   ) RETURN VARCHAR2;

   /*Obtiene la cantidad de Números de hojas que tienen un estado especifico enviado como parámetro*/
   FUNCTION fu_obt_can_documentos
   (
      p_tipo          ge_inv_documentos.tipo%TYPE,
      p_cod_oficina   ge_inv_documentos.cod_oficina%TYPE,
      p_estado        VARCHAR2,
      p_est_hojas     ge_inv_documentos.estado%TYPE,
      p_nro_secuencia ge_inv_documentos.nro_secuencia%TYPE DEFAULT NULL
   ) RETURN NUMBER;

   /*Actualiza el estado del número de documento*/
   PROCEDURE pr_act_estado
   (
      p_tipo          IN ge_inv_documentos.tipo%TYPE,
      p_cod_oficina   IN ge_inv_documentos.cod_oficina%TYPE,
      p_nro_documento IN ge_inv_documentos.nro_inicial%TYPE,
      p_estado        IN VARCHAR2,
      p_nro_ini       IN NUMBER DEFAULT NULL,
      p_cod_causa     IN ge_causales.cod_causa%TYPE DEFAULT NULL,
      p_observacion   IN ge_inv_doc_anulados.observacion%TYPE DEFAULT NULL
   );

   /*Verifica si se puede o no pasar a un estado dado*/
   PROCEDURE pr_ver_estado
   (
      p_tipo          IN ge_inv_documentos.tipo%TYPE,
      p_cod_oficina   IN ge_inv_documentos.cod_oficina%TYPE,
      p_nro_documento IN ge_inv_documentos.nro_inicial%TYPE,
      p_estado        IN VARCHAR2
   );

   /*Reversa el estado de un número de documento*/
   PROCEDURE pr_rev_estado
   (
      p_cod_oficina   IN ge_inv_documentos.cod_oficina%TYPE,
      p_tipo          IN ge_inv_documentos.tipo%TYPE,
      p_nro_documento IN ge_inv_doc_anulados.nro_documento%TYPE
   );

END pag_doc;
/

