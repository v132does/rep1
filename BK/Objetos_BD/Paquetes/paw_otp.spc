CREATE OR REPLACE PACKAGE IT.paw_otp IS
     g_otp_webservice VARCHAR2(150) := fug_obt_parentes(6331, 'G_OTP_WEBSERVICE');

   PROCEDURE pr_gen_importado;

   /* Obtiene la cantidad de token por estado y oficina.*/
   FUNCTION fu_obt_can_estado(p_oficina IN ba_oficinas.cod_oficina%TYPE, p_tipo IN bw_otp_seriales.tipo%TYPE, p_estado IN bw_otp_seriales.estado%TYPE) RETURN NUMBER;

   /* Actualiza el estado de la clave OTP.*/  
   FUNCTION fu_act_estado
   (
      p_cod_persona       IN ba_personas.cod_persona%TYPE DEFAULT NULL,
      p_cod_per_vinculada IN ba_personas.cod_persona%TYPE DEFAULT NULL,
      p_tipo              IN bw_otp_seriales.tipo%TYPE,
      p_nro_serial        IN bw_otp_seriales.nro_serial%TYPE,
      p_estado            IN bw_otp_seriales.estado%TYPE 
   ) RETURN VARCHAR2; 

   type typ_token  IS RECORD(
        serial varchar(20),
        tipo varchar(1),
        persona varchar(10),
        estado varchar(1)
   );


   /* Disponibiliza las solicitudes de OTPs que fueron asignados a clientes 
   y que no fueron entregados en un periodo de tiempo.*/
   PROCEDURE pr_eli_otp_ent_pen;

   /* Actualiza el indice de exportacion de las claves OTP en la tabla BW_OTP_SERIALES.*/
   PROCEDURE pr_act_exp
   (
      p_estado  IN bw_otp_seriales.exportado%TYPE,
      p_archivo IN VARCHAR2
   );

   /* Actualiza la clave a entregado, es invocado desde el workflow.*/
   PROCEDURE pr_act_entregado(p_nro_serial IN bw_otp_seriales.nro_serial%TYPE);

   /* Actualiza la clave a activo, es invocado desde el workflow.*/
   PROCEDURE pr_act_activado(p_nro_serial IN bw_otp_seriales.nro_serial%TYPE);

   /* Elimina las tareas del workflow.*/
   PROCEDURE pr_eli_tareas(p_nro_serial IN bw_otp_seriales.nro_serial%TYPE);

   FUNCTION fu_cam_nro_celular(p_cod_persona IN ba_personas.cod_persona%TYPE DEFAULT NULL, p_nro_telefono IN bw_otp_ref_medios.ref_medio%TYPE, p_nro_serial IN bw_otp_ref_medios.nro_serial%TYPE) RETURN VARCHAR2;

   FUNCTION fu_vas_exi_usuario(p_cod_persona IN ba_personas.cod_persona%TYPE, p_cod_per_vinculada IN ba_personas.cod_persona%TYPE DEFAULT NULL) RETURN NUMBER;
   FUNCTION fu_vas_nue_usuario(p_cod_persona IN ba_personas.cod_persona%TYPE, p_cod_per_vinculada IN ba_personas.cod_persona%TYPE DEFAULT NULL, p_nro_telefono IN bw_otp_ref_medios.ref_medio%TYPE, p_origen IN VARCHAR2) RETURN NUMBER;

   FUNCTION fu_vas_asi_token(p_cod_persona IN ba_personas.cod_persona%TYPE DEFAULT NULL, p_cod_per_vinculada IN ba_personas.cod_persona%TYPE DEFAULT NULL, p_nro_serial IN bw_otp_seriales.nro_serial%TYPE) RETURN VARCHAR2;

   FUNCTION fu_asi_tok_virtual(p_cod_persona IN ba_personas.cod_persona%TYPE DEFAULT NULL, p_nro_telefono IN bw_otp_ref_medios.ref_medio%TYPE, p_origen IN bw_sol_claves.cod_origen%TYPE, p_nro_serial IN bw_otp_seriales.nro_serial%type) RETURN NUMBER;

   FUNCTION fu_env_mai_clavefacil(p_nro_serial IN VARCHAR, p_cod_persona IN VARCHAR2, p_cod_oficina IN NUMBER) RETURN NUMBER;
   FUNCTION fu_ver_asi_toke_virtual(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN NUMBER;
   FUNCTION fu_obt_tok_disponible(p_tipo VARCHAR2, p_cod_oficina NUMBER) RETURN VARCHAR2;   
/*
Valida que el numero de telefono este catastrado en ITGF
*/
   FUNCTION fu_val_telefono(p_cod_persona IN ba_personas.cod_persona%TYPE, p_nro_telefono IN VARCHAR2) RETURN NUMBER;
   
/* Asignar un nuevo softoken a un cliente
   * @param p_codPersona persona asignada
   * @param p_tipo tipo de token <b>S:</b>Softoken fisica <b>E:</b> Softoken empresa
   * @param p_nroSerial Numero del token
   * @return <ul><li>0 en caso de exito</li><li> 10 en caso de exito y requiere callback por estar en otro pais</li><li> 11 exito y requiere callback por no tener tarjeta de debito </li><li>900 error tipo no valido</li></ul>
*/   
   FUNCTION fu_altaSoftoken(p_codPersona IN ba_personas.cod_persona%TYPE DEFAULT NULL,
                            p_tipo IN VARCHAR2, p_nroSerial IN bw_otp_seriales.nro_serial%TYPE,
                            p_nro_telefono IN VARCHAR2, p_can_activacion IN VARCHAR2)
     RETURN VARCHAR2 ;
   /**
   * Obtiene informacion del token asignado
   * @param p_codPersona persona asignada
   * @param p_tipo tipo de token F:token vasco fisico, V: token vasco virtual S:softoken fisica E:softoken empresa
   * @return Informacion del token asignado, null sino tiene un token asignado
   */
function fu_obtenerToken(p_codPersona  IN ba_personas.cod_persona%TYPE, p_tipo in varchar) return typ_token;

/*notifica enrrol y cambio de estado de token digital en empresas*/
PROCEDURE pr_SoftokenNotifEmpre(p_cod_empresa IN bw_td_configuraciones.cod_persona%TYPE,
                                p_cod_persona IN bw_td_configuraciones.cod_per_vinculo%TYPE,
                                p_tipoAviso   IN VARCHAR2);


function fu_obtenerTelefonoPais(p_codPersona IN ba_personas.cod_persona%TYPE) return varchar2;

   /**
   * Obtiene la cantidad de tarjetas de debito activas
   * @param p_codPersona persona asignada
   * @return numero de tarjetas en estado activo y que fecha de vencimiento mayor a hoy
   */
 
FUNCTION fu_obtenerCanTarDebito(p_codPersona IN ba_personas.cod_persona%TYPE) RETURN NUMBER;

/**
* Cambia el estado de una asignacion de softtoken
    @param p_codPersona persona asignada
    @param p_estado Estado del dispositivo OTP <ul><li>I/Inactivo </li><li>K/Pendiente de Aprobacion </li><li>D/Disponible</li><li> N/Nuevo</li><li> P/Impreso</li><li> E/Entregado</li><li> R/Rechazado Call Center</li><li> A/Activo</li><li> B/Bloqueado</li><li> X/Inutilizable</li></ul>
   * @return <ul>
   <il>0 en caso exitoso</il>
      <il>1 ocurrio una exepcion</il>
         <il>2 no se encontro</il>
   </ul>
*/
FUNCTION fu_cambiarEstadoSoftoken(p_serial in bw_otp_seriales.nro_serial%type, p_codPersona IN ba_personas.cod_persona%TYPE,
                                  p_estado IN VARCHAR2, p_motivo IN VARCHAR2, p_usuario IN VARCHAR2)
  RETURN NUMBER;
/**
* Retorna S si el cliente tiene un softtoken asignado
   * @param p_codPersona persona asignada
   * @param p_tipoAcceso Tipo de persona <ul><li>F fisica</li><li>E/Empresa</li></ul>
   * @return <ul><li>SF Tiene persona fisica</li><li>SJ Tiene persona juridica</li></ul>
*/
FUNCTION fu_obtenerAsignacionSofttoken(p_codPersona IN ba_personas.cod_persona%TYPE, 
                                       p_tipoAcceso IN VARCHAR2,
                                       p_cod_empresa IN ba_personas.cod_persona%TYPE DEFAULT NULL)
  RETURN VARCHAR2;

  FUNCTION fu_obt_inf_softtoken(p_nro_serial IN VARCHAR2,
                                p_cod_persona IN VARCHAR2,
                                p_cod_per_juridica IN VARCHAR2) 
      RETURN TYP_MAPA;

  FUNCTION fu_obt_inf_enroll(p_cod_persona IN VARCHAR2,
                             p_cod_per_juridica IN VARCHAR2) 
      RETURN TYP_MAPA;

 /**
* Cambia el estado de una asignacion de softtoken para empresas
    @param p_codPersona persona asignada
    @param p_estado Estado del dispositivo OTP <ul><li>I/Inactivo </li><li>K/Pendiente de Aprobacion </li><li>D/Disponible</li><li> N/Nuevo</li><li> P/Impreso</li><li> E/Entregado</li><li> R/Rechazado Call Center</li><li> A/Activo</li><li> B/Bloqueado</li><li> X/Inutilizable</li></ul>
   * @return <ul>
   <il>0 en caso exitoso</il>
      <il>1 ocurrio una exepcion</il>
         <il>2 no se encontro</il>
   </ul>
*/
FUNCTION fu_cambiarEstadoSoftokenEmpre(p_serial          IN bw_sof_seriales.nro_serial%TYPE, 
                                       p_estado          IN bw_sof_empresas.estado%TYPE,
                                       p_cod_persona     IN bw_sof_seriales.cod_persona%TYPE,
                                       p_cod_per_empresa IN bw_sof_empresas.cod_per_vinculada%TYPE,
                                       p_motivo          IN bw_sof_empresas.observacion%TYPE, 
                                       p_usuario         IN bw_sof_empresas.usu_activacion%TYPE) RETURN NUMBER;

 /**
   * Retorna un listado softokens para el admin persona fisica
   * @return Lista de softokens 
   **/
FUNCTION fu_obt_soft_fisica(p_fil_serial IN VARCHAR2, 
                            p_fil_estado IN VARCHAR2,  
                            p_fil_desde IN VARCHAR2,                            
                            p_fil_hasta IN VARCHAR2,               
                            p_fil_codPersona IN VARCHAR2, 
                            p_fil_documento IN VARCHAR2, 
                            p_fil_nombre IN VARCHAR2,   
                            p_fil_can_act IN VARCHAR2,
                            p_nroPagina IN NUMBER DEFAULT NULL,
                            p_cantItemsPagina     IN NUMBER DEFAULT NULL) RETURN typ_obtlistasofttokenadm;


 /**
   * Retorna un listado softokens para el admin persona juridica
   * @return Lista de softokens 
   **/
FUNCTION fu_obt_soft_empresa(p_fil_serial IN VARCHAR2, 
                            p_fil_estado IN VARCHAR2,  
                            p_fil_desde IN VARCHAR2,                            
                            p_fil_hasta IN VARCHAR2,            
                            p_fil_codPersona IN VARCHAR2, 
                            p_fil_documento IN VARCHAR2, 
                            p_fil_nombre IN VARCHAR2,             
                            p_fil_codPerVinc IN VARCHAR2, 
                            p_fil_docVinc IN VARCHAR2, 
                            p_fil_nombreVinc IN VARCHAR2,   
                            p_fil_autor IN VARCHAR2,                                                              
                            p_nroPagina IN NUMBER DEFAULT NULL,
                            p_cantItemsPagina     IN NUMBER DEFAULT NULL) RETURN typ_obtlistasofttokenadm;
  
/**
 * Funcion para activar,bloquear o desbloquear seriales de empresas.
 * @param p_serial numero serial vinculado a una empresa
 * @param p_cod_persona usuario admin
 * @param p_cod_empresa empresa a la que pertenece el admin
 * @param p_modo V-validar, C-confirmar
 * @param p_accion 'A': activar, 'D': desbloquear, 'B': bloquear
 * @return number: en caso exitoso debe retornar uno
                 : -1 user no es admin
                 : -2 serial no vinculado a la empresa
                 : 0  cambio de estado invalido
                 : 1 Ok
 */
FUNCTION fu_sof_tok_admin(p_serial       IN bw_sof_seriales.nro_serial%TYPE,
                          p_cod_persona  IN ba_personas.cod_persona%TYPE,
                          p_cod_empresa  IN ba_personas.cod_persona%TYPE,
                          p_modo         IN VARCHAR2,
                          p_accion       IN VARCHAR2) RETURN NUMBER;
                          
FUNCTION fu_cambiarCanalActivSoftoken(p_serial IN bw_otp_seriales.nro_serial%TYPE,
                                  p_codPersona IN ba_personas.cod_persona%TYPE, 
                                  p_nue_canal IN VARCHAR2) RETURN NUMBER;

/**
 * Verifica si el token digital esta activo 
 */
FUNCTION fu_sof_tok_activo(p_cod_persona IN ba_personas.cod_persona%TYPE,
                           p_cod_empresa IN ba_personas.cod_persona%TYPE DEFAULT NULL) RETURN VARCHAR2;

/**
 * Verifica si la empresa posee autorizador de token digital distinto a p_cod_persona 
 */
FUNCTION fu_tie_aut_token(p_cod_persona IN ba_personas.cod_persona%TYPE,
                          p_cod_empresa IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2;

/*
 * Determina si una persona tiene flag de autorizador de softtoken,
 * para una empresa especifica.
 * Consulta bw_td_configuraciones.autorizador
 */
 FUNCTION fu_es_aut_softoken(p_cod_persona      IN VARCHAR2,
                             p_cod_empresa      IN VARCHAR2) RETURN VARCHAR2;                
END;
/

