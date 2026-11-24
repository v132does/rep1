CREATE OR REPLACE PACKAGE IT.PAG_DNA IS

   
  g_servidor VARCHAR2(20);
  g_puerto   NUMBER(4);
  g_tie_espera NUMBER(4)  := NULL;

  /* FUNCION QUE PROCESA EL DEPOSITO
  *  p_tipo : TDA = Pago de declaraciones, TID = Pago de IVA
  *  p_tip_operacion : R = Validar RUC, C = Deposito
  *  p_nro_caja
  *  p_nro_operacion
  *  p_ruc_importador : idBroker, solo necesita cuando tipo es TDA
  *  p_ruc_despachante : idTrader
  *  p_monto
  *  p_nom_importador
  *  p_nom_despachante
  */
  FUNCTION fu_pro_deposito(p_tipo            IN VARCHAR2,
                           p_tip_operacion   IN VARCHAR2,
                           p_nro_caja        IN VARCHAR2,
                           p_nro_operacion   IN VARCHAR2,
                           p_ruc_importador  IN VARCHAR2 DEFAULT NULL,
                           p_ruc_despachante IN VARCHAR2,
                           p_monto           IN NUMBER,
                           p_nom_importador  OUT VARCHAR2,
                           p_nom_despachante OUT VARCHAR2)
  RETURN VARCHAR2;

  /* FUNCION QUE PROCESA EL TICKET
  *  p_tipo : TCA = Pago de Canon Informatico
  *  p_tip_operacion : D = Datos de Ticket, T = Confirmar Ticket
  *  p_nro_caja
  *  p_nro_operacion
  *  p_nro_ticket : nro de boleta de deposito de canon informatico
  *  p_ruc_despachante
  *  p_nom_despachante
  *  p_mto_total
  *  p_mto_efectivo
  *  p_mto_cheques
  */
  FUNCTION fu_pro_ticket(p_tipo            IN VARCHAR2,
                         p_tip_operacion   IN VARCHAR2,
                         p_nro_caja        IN VARCHAR2,
                         p_nro_operacion   IN VARCHAR2,
                         p_nro_ticket      IN VARCHAR2,
                         p_ruc_despachante OUT VARCHAR2,
                         p_nom_despachante OUT VARCHAR2,
                         p_mto_total       in OUT NUMBER,
                         p_mto_efectivo    OUT NUMBER,
                         p_mto_cheques     OUT NUMBER)
  RETURN VARCHAR2;

  /* FUNCION QUE PROCESA EL TICKET DNA
  *  p_tipo : TLE = Liquidacion Expedientes
  *  p_tip_operacion : Q = Datos de Ticket, E = Confirmar Ticket
  *  p_nro_caja
  *  p_nro_operacion
  *  p_nro_ticket : nro de ticket
  *  p_ruc_agente1
  *  p_nom_agente1
  *  p_tip_agente1
  *  p_ruc_agente2
  *  p_nom_agente2
  *  p_tip_agente2
  *  p_monto
  */
  FUNCTION fu_pro_dna_ticket(p_tipo            IN VARCHAR2,
                             p_tip_operacion   IN VARCHAR2,
                             p_nro_caja        IN VARCHAR2,
                             p_nro_operacion   IN VARCHAR2,
                             p_nro_ticket      IN VARCHAR2,
                             p_ruc_agente1     OUT VARCHAR2,
                             p_nom_agente1     OUT VARCHAR2,
                             p_tip_agente1     OUT VARCHAR2,
                             p_ruc_agente2     OUT VARCHAR2,
                             p_nom_agente2     OUT VARCHAR2,
                             p_tip_agente2     OUT VARCHAR2,
                             p_monto           in OUT NUMBER)
  RETURN VARCHAR2;

  /* FUNCION QUE PROCESA EL TICKET DNA
  *  p_tipo : TLE = Liquidacion Expedientes
  *  p_tip_operacion : Q = Datos de Ticket, E = Confirmar Ticket
  *  p_nro_caja
  *  p_nro_operacion
  *  p_nro_ticket : nro de ticket
  *  p_ruc_agente
  *  p_nom_agente
  *  p_monto
  */
  FUNCTION fu_pro_dna_ticket(p_tipo            IN VARCHAR2,
                             p_tip_operacion   IN VARCHAR2,
                             p_nro_caja        IN VARCHAR2,
                             p_nro_operacion   IN VARCHAR2,
                             p_nro_ticket      IN VARCHAR2,
                             p_ruc_agente      OUT VARCHAR2,
                             p_nom_agente      OUT VARCHAR2,
                             p_tip_agente      OUT VARCHAR2,
                             p_monto           in OUT NUMBER)
  RETURN VARCHAR2;

  /* FUNCION QUE RECUPERA LOS DATOS DEL DEPOSITO DE LA ADUANA
  *  p_nro_deposito : identificador del deposito generado por el banco para la DNA
  *  p_monto
  */
  FUNCTION fu_rec_deposito(p_nro_deposito IN VARCHAR2,
                           p_monto        OUT NUMBER)
  RETURN VARCHAR2;

  /* FUNCION QUE RECUPERA LOS DATOS DEL DEPOSITO DE LA ADUANA POR RANGO DE FECHA
  *  p_fec_desde : fecha desde
  *  p_fec_hasta : fecha hasta
  */
  FUNCTION fu_rec_dep_rango(p_fec_desde IN DATE,
                            p_fec_hasta IN DATE)
  RETURN VARCHAR2;

  /* PROCEDIMIENTO PARA ENVIO DE EXTRACTOS A LA DNA
  *  p_nro_cuenta: cuenta a informar
  *  p_fecha: Fecha del extracto
  *  p_tip_operacion: X=Enviar Extracto A=anular extracto
  */
  PROCEDURE pr_pro_extracto(p_nro_cuenta     IN VARCHAR2,
                            p_fecha          IN DATE,
                            p_tip_operacion   IN VARCHAR2);

  /* PROCEDIMIENTO PARA ENVIO DE EXTRACTOS A LA DNA AL CIERRE
  *
  */
  PROCEDURE pr_pro_extracto;

  /* Retorna el Nro de cuenta destino en transferencias */
  FUNCTION fu_obt_cta_destino(p_fecha in date, 
                              p_cod_usuario in varchar2,
                              p_hora in varchar2,
                              p_cod_tra_padre in number,
                              p_cod_transaccion in number)
    RETURN varchar2;  

END PAG_DNA;
/

