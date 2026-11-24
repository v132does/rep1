CREATE OR REPLACE PACKAGE IT.pab_asi IS

   -- Author  : AGUSTIN MEZA
   -- Created : 23/05/2009 10:43:02 a.m.
   -- Purpose : Definicion de parametros para asientos

   -- función que retorna la lista de valores
   FUNCTION fu_lis_sit_contable RETURN tyb_tab_sit_contable
      PIPELINED;

   -- función que retorna un número registrado de la situación contable exacta de la operación
   FUNCTION fu_obt_sit_contable(p_nro_cuenta IN VARCHAR2) RETURN NUMBER;

   -- función que retorna un número calculado que identifica la situación contable actual de la operación
   FUNCTION fu_cal_sit_contable(p_nro_cuenta IN VARCHAR2) RETURN NUMBER;

   -- función que retorna la descripción de la situación contable
   FUNCTION fu_obt_des_sit_contable(p_cod_sit_contable IN NUMBER) RETURN VARCHAR2;

   -- función que retorna la cuenta contable del CB_SAL_INVENTARIOS a partir del Tipo de Saldo.
   FUNCTION fu_obt_rub_contable
   (
      p_nro_cuenta IN VARCHAR2,
      p_tip_saldo  IN VARCHAR2,
      p_sit_deuda  IN VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2;

   -- función que retorna la cuenta contable del CB_SAL_INVENTARIOS_HIS a partir del Tipo de Saldo.
   FUNCTION fu_obt_rub_con_his
   (
      p_nro_cuenta IN VARCHAR2,
      p_tip_saldo  IN VARCHAR2,
      p_fecha      IN DATE,
      p_sit_deuda  IN VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2;

END pab_asi;
/

