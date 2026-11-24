CREATE OR REPLACE PACKAGE IT.PAW_CIR is

  -- Author  : AGUSTIN MEZA
  -- Created : 08/02/2009 03:42:15 p.m.
  -- Purpose : Control del Circuito de WorkFlow
  G_LUGAR VARCHAR2(250);
  G_MSJ_ERROR VARCHAR2(1000);--(250);
  G_COD_ERROR NUMBER(3) default 0;
  G_MSJ_ALERTA VARCHAR2(3000);
  v_fecha      VARCHAR2(10) := to_char(pag_cal.FU_OBT_FEC_ACTUAL(1),'ddmmyyyy');
  v_hor_actual VARCHAR2(8);
  v_fec_actual DATE;

  /* Obtiene el codigo de error del registro del paquete. */
  FUNCTION FU_OBT_COD_ERROR
   RETURN NUMBER;
  /* Obtener el lugar en el que quedo cargado el registro del paquete. */
  FUNCTION FU_OBT_LUGAR
   RETURN VARCHAR2;
  /* Obtiene el mensaje de error contenido en el registro del paquete. */
  FUNCTION FU_OBT_MSJ_ERROR
   RETURN VARCHAR2;
  /* CANCELA UN CIRCUITO */
  FUNCTION FU_CAN_CIRCUITO(p_cod_circuito in number,
                           p_cod_tar_actual in number,
                           p_cod_tip_circuito in number,
                           p_cod_tip_tar_actual in number,
                           p_comentario in varchar2 default null,
                           p_cod_cau_rechazo    in ge_causales.cod_causa%type default null)
    RETURN NUMBER;
  /* CANCELA UN CIRCUITO */
  FUNCTION FU_CAN_CIRCUITO(p_cod_circuito in number)
    RETURN NUMBER;

  /* Obtiene el mensaje de alerta contenido en el registro del paquete. */
  FUNCTION FU_OBT_MSJ_ALERTA RETURN VARCHAR2;

   /* Genera el siguiente paso dependiendo de la tarea actual y las condiciones */
  FUNCTION FU_GEN_SIG_TAREA(p_cod_circuito in number,
                            p_cod_tar_actual in number,
                            p_cod_tip_circuito in number,
                            p_cod_tip_tar_actual in number,
                            p_comentario in varchar2 default null,
                            p_tar_excepcion      in wf_tip_cir_tar_sig.tar_excepcion%type default null)
    RETURN NUMBER;
  /* Genera la tarea por el rechazo de una tarea. Por ahora se genera una tarea para el anterior grupo */
  FUNCTION FU_GEN_TAR_RECHAZO(p_cod_circuito in number,
                              p_cod_tar_actual in number,
                              p_cod_tip_circuito in number,
                              p_cod_tip_tar_actual in number,
                              p_comentario in varchar2 default null,
                              p_cod_cau_rechazo    in ge_causales.cod_causa%type default null)
    RETURN NUMBER;
  -- inicia un circuito
  FUNCTION FU_INI_CIRCUITO(p_cod_tip_circuito in wf_circuitos.cod_tip_circuito%TYPE,
                           p_referencia       in wf_circuitos.referencia%TYPE,
                           p_cod_persona      in wf_circuitos.cod_persona%type default NULL,
                           p_comentario       in wf_cir_tareas.comentario%type default NULL)
    RETURN NUMBER;
  -- Genera una hoja con los datos de la operacion asociada para visualizarlo en el seguimiento
  FUNCTION FU_OBT_DAT_OPERACION(p_cod_circuito in number)
    RETURN VARCHAR2;

  /* retorna el tiempo insumido por una tarea, en la misma escala de tiempo definida
     para la tarea*/
  FUNCTION FU_OBT_TIEMPO(p_cod_tip_circuito in number,
                         p_cod_tip_tarea    in number,
                         p_fec_inicio       in date,
                         p_fec_final        in date)
    RETURN NUMBER;
  /* retorna tiempo excedido de una tarea dada. Si no esta excedido en tiempo retorna 0(cero)*/
  FUNCTION FU_TIE_EXCEDIDO(p_cod_circuito in number, p_cod_tarea in number)
    RETURN NUMBER;

  -- Obtiene el periodo de tiempo de una tarea
   FUNCTION FU_OBT_PERIODO(p_fec_insercion in wf_circuitos.fec_insercion%type,
                           p_tip_tiempo in varchar2)
     RETURN NUMBER;

  --Obtiene la oficina de la operacion
  FUNCTION FU_OBT_OFICINA(p_cod_tip_circuito in wf_circuitos.cod_tip_circuito%type,
                          p_referencia in wf_circuitos.referencia%type)
    RETURN NUMBER;

  -- Verifica si el usuario puede ver todas las oficinas
  FUNCTION FU_VE_OFICINA(p_cod_circuito wf_circuitos.cod_circuito%TYPE,
                         p_cod_tarea   wf_cir_tareas.cod_tip_tarea%TYPE)
	 RETURN VARCHAR2;

  /*Verifica si el circuito tiene asociado una referencia*/
  FUNCTION FU_VER_VAL_REFERENCIA( p_cod_obj_base     in wf_tip_circuitos.cod_obj_base%type,
                                  p_referencia       in wf_tip_circuitos.referencia%type,
                                  p_val_referencia   in wf_circuitos.referencia%type,
                                  p_cod_tip_circuito in wf_circuitos.cod_tip_circuito%type default null
                                ) RETURN VARCHAR2;

  --Cancela un circuito automaticamente
  PROCEDURE PR_CAN_AUT_CIRCUITO;

  /* Indica si el usuario pertenece o no al grupo */
  FUNCTION FU_EXI_GRU_USUARIO ( p_cod_grupo   in wf_grupos.cod_grupo%type,
                                p_cod_usuario in ba_usuarios.cod_usuario%type
                              ) RETURN VARCHAR2 DETERMINISTIC;

  /*Obtiene el usuario responsable para una tarea*/
  FUNCTION FU_OBT_USU_RESPONSABLE( p_cod_circuito       in wf_circuitos.cod_circuito%type,
                                    p_cod_tip_circuito   in wf_tip_circuitos.cod_tip_circuito%type,
                                    p_cod_tip_tar_actual in wf_tip_cir_tar_sig.cod_tip_tarea%type) RETURN VARCHAR2;

 /* Veriifica si tiene tareas pendiente y cancela*/
  FUNCTION FU_CAN_CIR_PENDIENTES(p_cod_tip_circuito in wf_circuitos.cod_tip_circuito%type,
                                 p_cod_persona      in wf_circuitos.cod_persona%type) RETURN NUMBER;
 /* Veriifica si tiene tareas pendiente y finaliza*/
  FUNCTION FU_FIN_CIR_PENDIENTES(p_cod_tip_circuito in wf_circuitos.cod_tip_circuito%type,
                                 p_cod_persona      in wf_circuitos.cod_persona%type) RETURN NUMBER;

  FUNCTION FU_FIN_CIR_PEN_COD (p_cod_tip_circuito in wf_circuitos.cod_tip_circuito%type,
                               p_cod_circuito     in wf_circuitos.cod_circuito%type,
                               p_estado           in wf_circuitos.estado%type) RETURN NUMBER;

end paw_cir;
/

