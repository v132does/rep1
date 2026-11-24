create or replace package it.pag_sad is

  g_cod_tip_circuito    number(5) := to_number(fug_obt_pardinamico('COD_TIP_CIR_DAT_SENSIBLES'));
  g_cod_error           number(5) := 0;
  g_msg_error           varchar2(300) := null;
  procedure pr_ins_datos( p_cod_persona IN ba_personas.cod_persona%TYPE, p_nro_solicitud in number default null);

  --elimina solicitudes cuyos datos no fueron modificados
  procedure pr_eli_solicitud( p_nro_solicitud IN ge_sol_act_datos.nro_solicitud%TYPE);

  -- genera circuito.
  function fu_gen_circuito(p_cod_persona in varchar2, p_nro_solicitud in number) return number;

  -- eliminar registros insertados inicialmente y que no fueron modificados
  -- se ejecuta cuando se solicita aprobacion de la solicitud
  procedure pr_eli_reg_solicitud(p_cod_persona in varchar2, p_nro_solicitud in number, p_msg_error out varchar2);

  procedure pr_act_est_solicitud(p_nro_solicitud in number,p_cod_estado in varchar2,p_msg in out varchar2);
  -- aprobacion de solicitudes
  procedure pr_apr_solicitud(p_nro_solicitud in number, p_cod_persona in varchar2, p_msg_error in out varchar2);

  function fu_tie_modificaciones(p_nro_solicitud in number) return varchar2;

  -- notificacion por nuevo correo registrado o cambio de direccion de correo.
  procedure pr_env_notificacion(p_cod_persona in varchar2, p_dir_correo_ant in varchar2, p_dir_correo_new in varchar2);

  -- vencimiento de las solicitudes no aprobadas ni canceladas
  procedure pr_ven_solicitudes;
  
  --Obtiene el codigo de error del registro del paquete.
  FUNCTION fu_obt_cod_error return number;

  -- Obtiene el mensaje de error contenido en el registro del paquete.
  FUNCTION fu_obt_msj_error return varchar2;
  
  -- inicializamos las variables globales
  procedure pr_ini_var_globales;

end pag_sad;
/

