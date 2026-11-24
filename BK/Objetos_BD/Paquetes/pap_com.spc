CREATE OR REPLACE PACKAGE IT.pap_com IS

  -- Proceso Incial.
  PROCEDURE pr_pro_compra(p_tipo IN VARCHAR2 default null);

  --Guarda en el log
  PROCEDURE pr_ins_log(p_nro_error   IN pr_log_com_cartera.nro_error%TYPE, --sqlcode
                       p_men_error   IN pr_log_com_cartera.men_error%TYPE, --sqlerrm
                       p_com_error   IN pr_log_com_cartera.comentario%TYPE, --Particular
                       p_fec_proceso IN pr_log_com_cartera.fec_proceso%TYPE,
                       p_proceso     IN VARCHAR2 default null,
                       p_cod_ente    IN ge_entes.cod_ente%TYPE default null);

  -- Limpia las tablas del LOG.
  PROCEDURE pr_del_log(p_proceso     IN VARCHAR2,
                       p_cod_ente    IN pr_log_com_cartera.nro_registro%TYPE);

  -- Genera la Persona.
  PROCEDURE pr_ins_personas

  (p_nro_documento  in ba_personas.nro_documento%type,
   p_tip_documento  in ba_personas.cod_tip_documento%type,
   p_cod_pais       in ba_personas.cod_pais%type,
   p_nombre         in ba_personas.nom_completo%type, --nombre/s
   p_apellido       in ba_personas.nom_completo%type, --apellido/s
   p_tipo           in ba_personas.tipo%type,
   p_fec_nacimiento in ba_per_fisicas.fec_nacimiento%type,
   p_rub_primario   in ba_personas.cod_rub_primario%type,
   p_cod_persona    in out ba_personas.cod_persona%type,
   p_cod_sexo       in ba_per_fisicas.cod_sexo%TYPE default null);

  -- Procedimiento que Inserta las Direcciones.
  PROCEDURE pr_ins_dir_personas(p_dir_particular      IN ba_direcciones.direccion%TYPE,
                                p_dir_laboral         IN ba_direcciones.direccion%TYPE,
                                p_pais_dir_particular IN ba_direcciones.cod_pais%TYPE,
                                p_pais_dir_laboral    IN ba_direcciones.cod_pais%TYPE,
                                p_ciu_dir_part        IN ba_direcciones.cod_ciudad%TYPE,
                                p_ciu_dir_lab         IN ba_direcciones.cod_ciudad%TYPE,
                                p_bar_dir_particular  IN ba_direcciones.cod_barrio%TYPE,
                                p_bar_dir_laboral     IN ba_direcciones.cod_barrio%TYPE,
                                p_nro_dir_particular  IN ba_direcciones.numero%TYPE,
                                p_nro_dir_laboral     IN ba_direcciones.numero%TYPE,
                                p_obs_dir_particular  IN ba_direcciones.observacion%TYPE,
                                p_obs_dir_laboral     IN ba_direcciones.observacion%TYPE,
                                p_cod_persona         IN ba_personas.cod_persona%TYPE default null,
                                p_cod_ente            IN ge_entes.cod_ente%TYPE default null,
                                p_proceso             IN varchar2 default null);

  -- Procedimiento que Inserta los Telefonos.
  PROCEDURE pr_ins_tel_personas(p_tel_particular  IN ba_telefonos.telefono%TYPE,
                                p_tel_laboral     IN ba_telefonos.telefono%TYPE,
                                p_area_particular IN ba_telefonos.area%TYPE,
                                p_area_laboral    IN ba_telefonos.area%TYPE,
                                p_tip_linea_p     IN ba_telefonos.tip_linea%TYPE,
                                p_tip_linea_l     IN ba_telefonos.tip_linea%TYPE,
                                p_cod_persona     IN ba_personas.cod_persona%TYPE default null,
                                p_cod_ente        IN ge_entes.cod_ente%TYPE default null,
                                p_proceso         IN varchar2 default null);

  PROCEDURE pr_ins_ge_cliente  (p_cod_persona IN ba_personas.cod_persona%TYPE default null,
                                p_cod_oficina IN ge_clientes.cod_oficina%TYPE default null,
                                p_cod_oficial IN ge_clientes.cod_usu_oficial%TYPE default null);

  -- Procedimiento que Inserta Informacion Laboral.
  PROCEDURE pr_ins_cr_inf_laboral(p_lug_trabajo IN cr_inf_laborales.lug_trabajo%TYPE,
                                  p_mto_ingreso IN cr_inf_laborales.mto_ingreso%TYPE,
                                  p_cargo       IN cr_inf_laborales.des_puesto%TYPE,
                                  p_antiguedad  IN NUMBER,
                                  p_cod_persona IN ba_personas.cod_persona%TYPE default null,
                                  p_cod_ente    IN ge_entes.cod_ente%TYPE default null,
                                  p_proceso     IN varchar2 default null);

  -- Procedimiento que Inserta Informacion de Origen de Fondos.
  PROCEDURE pr_ins_cr_inf_fondos;

  -- Procedimiento que Inserta Informacion de Actividades Esperadas.
  PROCEDURE pr_ins_cr_act_esperadas;

  -- Procedimiento que Inserta Informacion de Tipos de Operaciones.
  PROCEDURE pr_ins_cr_per_tip_ope(p_mto_limite IN NUMBER,
                                  p_can_cuotas IN NUMBER);

  -- Procedimiento que Inserta la Solicitud.
  PROCEDURE pr_ins_pr_solicitudes(p_cod_persona         in varchar2, -- codigo de la persona,
                                  p_cod_modalidad       in number, -- tipo de credito
                                  p_cod_moneda          in varchar2, -- moneda
                                  p_monto               in number, -- monto del credito
                                  p_can_cuotas          in number, -- nro de cuotas
                                  p_fec_inicio          in date default null, -- inicio del credito
                                  p_fec_pri_vencimiento in date default null, -- primer vencimiento
                                  p_val_tasa            in number default null, -- valor de la tasa
                                  p_cod_canal           in number default null, -- codigo del canal
                                  p_cod_campana         in number default null, -- codigo de campa?a
                                  p_descripcion         in varchar2 default null, -- descripcion de la oper.
                                  p_cod_usu_promotor    in varchar2 default null, --Promotor del Credito
                                  p_tip_destino         in varchar2 default null,
                                  p_cod_banca           in number default null, --Banca
                                  p_cargo               in number default null, --Gasto Administrativo
                                  p_seguro              in number default null, --Seguro de Vida
                                  p_cod_rub_economico   in pr_rub_economicos.cod_rub_economico%type,
                                  p_nom_completo        IN ba_personas.nom_completo%TYPE,
                                  p_tip_documento       IN ba_personas.cod_tip_documento%TYPE,
                                  p_nro_documento       IN ba_personas.nro_documento%TYPE,
                                  p_nro_solicitud       out pr_solicitudes.nro_solicitud%type);

  -- Procedimiento que Actualiza la Solicitud a L - Pendiente de Liquidacion.
  PROCEDURE pr_act_est_solicitudes;

  -- Procedimiento que Inserta el Destino de la Solicitud.
  PROCEDURE pr_ins_pr_sol_destinos(p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
                                   p_monto         IN pr_sol_destinos.monto%TYPE);

  -- Procedimiento que Inserta los Documentos de las Cuotas.
  PROCEDURE pr_ins_pr_documentos(p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
                                 p_nro_documento IN ba_personas.nro_documento%TYPE,
                                 p_nom_completo  IN ba_personas.nom_completo%TYPE,
                                 p_tip_documento IN ba_personas.cod_tip_documento%TYPE,
                                 p_cod_moneda    IN ba_monedas.cod_moneda%TYPE);

  -- Procedimiento que Inserta las Cuotas de la Solicitud.
  PROCEDURE pr_ins_pr_sol_cuotas(p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
                                 p_monto         IN pr_solicitudes.monto%TYPE,
                                 p_val_tasa      IN pr_sol_tasas.val_tasa%TYPE,
                                 p_mto_interes   OUT pr_solicitudes.mto_interes%TYPE);

  -- Procedimiento que Inserta las Cuotas de la Solicitud.
  PROCEDURE pr_ins_pr_sol_garantias(p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
                                    p_monto         IN pr_solicitudes.monto%TYPE);

  -- Procedimiento que Inserta las Tasas de la Solicitud.
  PROCEDURE pr_ins_pr_sol_tasas(p_nro_solicitud   IN pr_solicitudes.nro_solicitud%TYPE,
                                p_val_tasa        IN pr_sol_tasas.val_tasa%TYPE,
                                p_per_vencimiento IN pr_sol_tasas.per_vencimiento%TYPE);

  -- Procedimiento que Inserta las Tasas de la Solicitud.
  PROCEDURE pr_pro_desembolso;

  -- Procedimiento que Inserta la Solicitud.
  PROCEDURE pr_ins_pr_sol_vencido(p_cod_persona         in varchar2, -- codigo de la persona,
                                  p_cod_modalidad       in number, -- tipo de credito
                                  p_cod_moneda          in varchar2, -- moneda
                                  p_monto               in number, -- monto del credito
                                  p_can_cuotas          in number, -- nro de cuotas
                                  p_fec_inicio          in date default null, -- inicio del credito
                                  p_fec_pri_vencimiento in date default null, -- primer vencimiento
                                  p_val_tasa            in number default null, -- valor de la tasa
                                  p_cod_canal           in number default null, -- codigo del canal
                                  p_cod_campana         in number default null, -- codigo de campa?a
                                  p_descripcion         in varchar2 default null, -- descripcion de la oper.
                                  p_cod_usu_promotor    in varchar2 default null, --Promotor del Credito
                                  p_tip_destino         in varchar2 default null,
                                  p_cod_banca           in number default null, --Banca
                                  p_cargo               in number default null, --Gasto Administrativo
                                  p_seguro              in number default null, --Seguro de Vida
                                  p_cod_rub_economico   in pr_rub_economicos.cod_rub_economico%type,
                                  p_nom_completo        IN ba_personas.nom_completo%TYPE,
                                  p_tip_documento       IN ba_personas.cod_tip_documento%TYPE,
                                  p_nro_documento       IN ba_personas.nro_documento%TYPE,
                                  p_nro_solicitud       out pr_solicitudes.nro_solicitud%type,
                                  p_tip_ptmo            IN pr_solicitudes.tipo%type);


   -- Procedimiento que Inserta las Cuotas de la Solicitud.
  PROCEDURE pr_ins_pr_sol_cuo_ven(p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
                                      p_monto         IN pr_solicitudes.monto%TYPE,
                                      p_val_tasa      IN pr_sol_tasas.val_tasa%TYPE,
                                      p_mto_interes   OUT pr_solicitudes.mto_interes%TYPE,
                                      p_can_cuotas    IN number,
                                      p_car_calculado OUT number,
                                      p_cod_modalidad IN NUMBER, -- tipo de credito
                                      p_cod_moneda    IN VARCHAR2);

  -- Procedimiento que Inserta las Tasas de la Solicitud.
  PROCEDURE pr_ins_pr_sol_tas_ven(p_nro_solicitud   IN pr_solicitudes.nro_solicitud%TYPE,
                                  p_val_tasa        IN pr_sol_tasas.val_tasa%TYPE,
                                  p_per_vencimiento IN pr_sol_tasas.per_vencimiento%TYPE);

  -- Proceso Alta Persona.
  Procedure pr_pro_persona(p_Tipo In Varchar2 Default Null);

END pap_com;
/

