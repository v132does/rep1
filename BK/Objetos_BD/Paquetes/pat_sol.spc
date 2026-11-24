create or replace package it.PAT_SOL is

  -- Author  : XPY0035
  -- Created : 06/05/2019 18:27:57
  -- Purpose : Paquete de utilitarios para solicitudes de tarjetas
  
  /**
   * Obtiene la modalidad y estado de una cuenta de tarjeta.
   *
   * @param p_nro_cuenta modalidad de la cuenta numero de cuenta de la tarjeta
   * @param p_cod_persona codigo cliente
   * @param p_relacion relacion de la cuenta
   * @return 0: ok
             1: cta. inexistente
             2: cta. bloqueada
             3: cta. prepaga
   */
  FUNCTION fu_val_cta_adicional(p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
                                p_cod_persona   IN ba_personas.cod_persona%TYPE,
                                p_relacion      IN VARCHAR2 DEFAULT 'P') RETURN NUMBER;

  /**
   * Indica si la modalidad de tarjeta corresponde a una prepaga.
   *
   * @param p_cod_modalidad modalidad de la cuenta
   * @return 'S' es prepaga, 'N' no es prepaga
   */
  FUNCTION fu_es_prepaga(p_cod_modalidad IN ge_modalidades.cod_modalidad%TYPE) RETURN VARCHAR2;
  
  /**
   * Obtener datos para solicitud de adicional a partir de un json.
   */
  FUNCTION fu_obt_sol_adicional(p_cod_persona       IN ba_personas.cod_persona%TYPE,
                                p_datosJson         IN VARCHAR2,
                                p_nro_cuenta        IN ta_tarjetas.nro_cuenta%TYPE,
                                p_pri_nombre        OUT ba_per_fisicas.pri_nombre%TYPE,
                                p_seg_nombre        OUT ba_per_fisicas.seg_nombre%TYPE,
                                p_pri_apellido      OUT ba_per_fisicas.pri_apellido%TYPE,
                                p_seg_apellido      OUT ba_per_fisicas.seg_apellido%TYPE,
                                p_tip_documento     OUT ba_tip_documentos.abreviatura%TYPE,
                                p_nro_doc_persona   OUT ba_personas.nro_documento%TYPE,
                                p_genero            OUT ba_per_fisicas.cod_sexo%TYPE,
                                p_cod_pais          OUT ba_per_fisicas.cod_pai_nacionalidad%TYPE,
                                p_fec_nacimiento    OUT ba_per_fisicas.fec_nacimiento%TYPE,
                                p_cod_est_civil     OUT ba_per_fisicas.est_civil%TYPE,
                                p_nom_embozo        OUT ta_tarjetas.nom_embozar%TYPE) RETURN NUMBER;

   /**
    * Verificar solicitud existente.
    * 
    * @param p_nro_cuenta nro. de cuenta de la tarjeta
    * @param p_cod_per_adicional codigo persona del adicional
    */
   FUNCTION fu_ver_sol_adi_existente(p_nro_cuenta        IN ta_cta_tarjetas.nro_cuenta%TYPE,
                                     p_cod_per_adicional IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2;

   /**
    * Notificar al usuario la solicitud de tarjeta.
    * 
    * @param p_cod_persona codigo cliente
    * @param p_nro_tarjeta numero de tarjeta
    * @param p_tip_solicitud Tipo de solicitud: 1-Solicitud adicional
    * @return number 0: exito
    */
   FUNCTION fu_not_solicitud(p_cod_persona   IN ba_personas.cod_persona%TYPE,
                             p_nro_tarjeta   IN ta_tarjetas.nro_tarjeta%TYPE,
                             p_tip_solicitud IN NUMBER) RETURN NUMBER;

end PAT_SOL;
/

