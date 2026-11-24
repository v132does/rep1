CREATE OR REPLACE PACKAGE IT.PAA_CDI IS
  v_mod_estado ba_modulos.estado%TYPE;
  /**
   Paquete creado por: Gladys Argana
   Fecha: 11/07/2024
   Objetivo: procesar todas las transacciones internas desde la api
  **/
  PROCEDURE pr_gen_tra_interna(p_nro_cta_debito      IN VARCHAR2, --numero cuenta debito
                               p_nro_cta_credito     IN VARCHAR2, --numero cuenta credito
                               p_cod_tra_pad_debito  IN NUMBER, --codigo transacción padre debito 
                               p_cod_tra_pad_credito IN NUMBER, --codigo transacción padre credito 
                               p_mto_operacion       IN NUMBER, --monto de la operacion
                               p_cod_tra_debito      IN NUMBER, --codigo transaccion debito
                               p_cod_tra_credito     IN NUMBER, --codigo transaccion credito
                               p_nro_documento       IN NUMBER, --numero de documento u operacion que recibe
                               p_deb_concepto        IN VARCHAR2, --concepto debito
                               p_cre_concepto        IN VARCHAR2, --concepto credito
                               p_cod_error           OUT NUMBER,
                               p_respuesta           OUT VARCHAR2,
                               p_nro_sec_debito      OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE,
                               p_nro_sec_credito     OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE);

  FUNCTION lf_ver_alfanumerico(p_string  IN VARCHAR2,
                               maxLength IN NUMBER,
                               p_espacio IN CHAR DEFAULT 'N') RETURN VARCHAR2;

  FUNCTION lf_ver_texto(p_string    IN VARCHAR2,
                        maxLength   IN NUMBER,
                        p_documento IN VARCHAR2 DEFAULT 'N') RETURN VARCHAR2;
  
  procedure pr_obt_usu_hor_tra_interna(p_usuario in varchar2,
                                       p_usu_mov out varchar2,
                                       p_hor_mov out varchar2);

END PAA_CDI;
/
