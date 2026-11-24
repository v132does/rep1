CREATE OR REPLACE PACKAGE IT.PAB_INV IS
   --- Tipos de saldos a cuadrarse
   --- C = Capital
   --- F = Capital AFD
   --- I = Interes
   --- A = A devengar
   --- P = Pignoracion
   --- T = Sobregiro Transitorio
   --- B = Bancos del Pais
   --- D = Devengado
   --- S = Devengado en Suspenso
   --- Z = Saldo Iva vencido en suspenso
   --- G = Gastos
   --- V = Prevision
   --- S = Saldo en (COMEX) --> Repetido
   --- B = Act. Fijo: Depreciacion Acumulada
   --- L = Valuacion --> Valuacion
   --- E = Garantias Computables
   --- J = Garantias No Computables
   --- N = Intereses no documentados
   --- R = Retenido
   --- O = Saldo Contingente
   --- K = Cuentas de resultados
   --- Q = BloQueos por Embargos

   PROCEDURE pr_gen_sal_inventarios;
   ---Obtiene el rubro contable
   PROCEDURE fu_obt_cod_rubro
   (
      p_cod_modulo       IN NUMBER,
      p_cod_modalidad    IN NUMBER,
      p_cod_transaccion  IN NUMBER,
      p_cod_moneda       IN VARCHAR2,
      p_cod_sec_contable IN VARCHAR2,
      p_cod_tip_deudor   IN NUMBER,
      p_residente        IN VARCHAR2,
      p_cod_plazo        IN VARCHAR2,
      p_tip_movimiento   IN VARCHAR2,
      p_cod_rubro        IN OUT VARCHAR2,
      p_est_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_tip_renovacion   IN VARCHAR2 DEFAULT NULL,
      p_cat_automatica   IN NUMBER DEFAULT NULL,
      p_tip_interes      IN VARCHAR2 DEFAULT NULL,
      p_tip_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_cod_sit_contable IN NUMBER DEFAULT NULL,
      p_cod_sec_credito  IN NUMBER DEFAULT NULL
   );

   --Obtiene el rubro contable caso especial de Transferencias recibidas
   PROCEDURE fu_obt_tra_cod_rubro
   (
      p_cod_modulo       IN NUMBER,
      p_cod_modalidad    IN NUMBER,
      p_cod_transaccion  IN NUMBER,
      p_cod_moneda       IN VARCHAR2,
      p_cod_sec_contable IN VARCHAR2,
      p_cod_tip_deudor   IN NUMBER,
      p_residente        IN VARCHAR2,
      p_cod_plazo        IN VARCHAR2,
      p_tip_movimiento   IN VARCHAR2,
      p_cod_rubro        IN OUT VARCHAR2,
      p_est_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_cod_rub          IN VARCHAR2 DEFAULT NULL,
      p_tip_renovacion   IN VARCHAR2 DEFAULT NULL,
      p_cat_automatica   IN NUMBER DEFAULT NULL,
      p_tip_interes      IN VARCHAR2 DEFAULT NULL,
      p_tip_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_cod_sit_contable IN NUMBER DEFAULT NULL,
      p_cod_sec_credito  IN NUMBER DEFAULT NULL
   );

   --Transferencias recibidas (libranzas a pagar)
   PROCEDURE pr_gen_inv_libranza;

   --Transferencias recibidas (cuentas de orden)
   PROCEDURE pr_tra_rec_cta_orden;

   --Documentos pendientes de confirmación moneda local
   PROCEDURE pr_inv_doc_pendientes;

   --Documentos pendientes de confirmacion cámara extranjera
   PROCEDURE pr_inv_cam_ext;

   --Cheques Recibidos Cámara Interna
   PROCEDURE pr_inv_cam_interna;

   -- Transferencias a Emitir
   PROCEDURE pr_inv_trans_emi;

   -- Créditos Incobrables Préstamos
   PROCEDURE pr_inv_pres_inc;

   -- Cheques Recibidos 48 hs.
   PROCEDURE pr_inv_cam_48;

   -- Cheques Compensación 24hs. Activo Cargo Otro
   PROCEDURE pr_inv_cam_act_24;

   -- Cheques Compensación 24hs. Pasivo Cargo Nuestro
   PROCEDURE pr_inv_cam_pas_24;

   -- Prestamos a utilizar mediante tarjetas de credito
   PROCEDURE pr_inv_tar_noutilizada;

   -- Cargos por Sobregiros en Suspenso.
   PROCEDURE pr_inv_car_sobregiros;

   -- Cheques a compensar camara local 24hs.
   PROCEDURE pr_inv_cam_loc_24h;

   -- Cheques recibidos a compensar 24hs. camara Extranjera
   PROCEDURE pr_inv_cam_ext_24h;

   -- Comercio exterior partidas acreedoras.
   PROCEDURE pr_inv_com_exterior;

   -- Contigencia de Cuentas Corrientes.
   PROCEDURE pr_inv_cta_cte_contingencia;

   -- Ingresos varios por caja Clearing
   PROCEDURE pr_ing_var_caja;

   -- Documentos pendientes de confirmacion en camara local extranjera
   PROCEDURE pr_inv_cam_local;

   -- Operaciones a Cancelar Venta de Cheques
   PROCEDURE pr_inv_ope_can_ven_cheques;

   -- Datos de Cheques Recibido de Camara Interna
   PROCEDURE pr_inv_che_cam_interna;

   --Inventario de pago a proveedores pendientes.
   PROCEDURE pr_inv_pag_proveedores;

   --Inventario de Comisiones Diferidas - A Devengar.
   PROCEDURE pr_inv_com_diferidas;

   -- Datos de Inventario de Valores en Custodia
   PROCEDURE pr_inv_val_custodia;

   -- Devengados de Plusvalía y Minusvalía de los Bonos Subordinados.
   PROCEDURE pr_inv_dev_bon_subordinados;

   -- Previsiones Comex
   PROCEDURE lp_acu_prev_comex;

   -- Inventario de cuentas embargadas.
   PROCEDURE pr_inv_embargos;

   -- Inventario de Comisiones Seguros Vida Incendio
   PROCEDURE pr_inv_com_seguros;

  -- Datos de Inventario Custodia de Cheques
   PROCEDURE pr_inv_cus_cheq;
   
  -- Datos de Inventario de cheques horario extendido
  PROCEDURE pr_inv_hor_extendido;
  
  -- Inventario de Comisiones Seguros Fraude Tarjetas Débito.
  PROCEDURE pr_inv_seg_fra;
  
  -- Inventario Venta de Cartera.
  PROCEDURE pr_inv_vta_cartera;
  
  -- Transferencias Recibidas Cuentas de Orden en la 52
  PROCEDURE pr_tra_rec_ord_par;
  
END PAB_INV;
/

