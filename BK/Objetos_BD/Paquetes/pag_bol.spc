create or replace PACKAGE  IT.PAG_BOL IS
/*
  Descripcion:
  Paquete que busca encontrar las diferencias de saldos diarios tanto para saldo batch y saldo en linea.
   actualmente se encuentra desarrollado para los movimientos de tipo de saldo 'DISPONIBLE'

   AUTOR   FECHA       DESCRIPCION
   ------  ----------  ---------------------------------------------------
   MJUAREZ 05-Feb-2024 Version inicial

*/


    PROCEDURE pr_pro_dif_saldos  (P_FECHA     DATE,
                                  P_FECHA_ANT DATE);

    PROCEDURE pr_par_tab_ah_auditoria (P_FECHA        DATE,
                                       P_FECHA_ANT    DATE,
                                       P_NRO_CUENTA   VARCHAR2 DEFAULT NULL);
                                    
    PROCEDURE pr_par_tab_cc_auditoria (P_FECHA        DATE,
                                       P_FECHA_ANT    DATE,
                                       P_NRO_CUENTA   VARCHAR2 DEFAULT NULL);

    PROCEDURE pr_seg_dif_ah_cuentas (P_FECHA       DATE,
                                     P_FECHA_ANT   DATE,
                                     P_NRO_CUENTA  VARCHAR2,
                                     P_TIP_SALDO   VARCHAR2);
                                  
    PROCEDURE pr_seg_dif_cc_cuentas (P_FECHA       DATE,
                                     P_FECHA_ANT   DATE,
                                     P_NRO_CUENTA  VARCHAR2,
                                     P_TIP_SALDO   VARCHAR2);
                                  
    PROCEDURE pr_bus_segmentacion (P_FECHA     DATE,
                                   P_FECHA_ANT DATE);

    PROCEDURE pr_lim_segmentacion (P_FECHA     DATE,
                                   P_FECHA_ANT DATE);                           

    TYPE T_ROWID_R IS RECORD (ROW_ID VARCHAR2(4000));

    TYPE T_ROWID_TABLE  IS TABLE OF T_ROWID_R;
    TYPE T_ROWID_LIST IS TABLE OF VARCHAR2(18);


    PROCEDURE pr_bus_dif_cuentas;


END PAG_BOL;