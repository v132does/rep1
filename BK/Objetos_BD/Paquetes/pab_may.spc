CREATE OR REPLACE PACKAGE IT.PAB_MAY is

  -- Author  : PY00315 - Ingrid Larraín BBVA
  -- Created : 02/09/2011 03:40:10 p.m.
  -- Purpose : Paquete para Extracto de Mayor

  -- Variables Globales para uso del Mayor en Excel
  g_may_cod_oficina number(3);
  g_may_cod_rubro varchar2(15);
  g_may_sal_ant_ml number(21,2);
  g_may_sal_act_ml number(21,2);
  g_may_sal_ant_me number(21,2);
  g_may_sal_act_me number(21,2);

  -- Función que actualiza el saldo en linea
  FUNCTION FU_CAL_SAL_MAY(
     p_cod_rubro   IN cb_sal_oficinas.cod_rubro%type,
     p_cod_oficina IN cb_sal_oficinas.cod_oficina%type,
     p_saldo_ml    IN cb_sal_oficinas.sal_mon_loc_ant%type,
   p_saldo_me    IN cb_sal_oficinas.sal_mon_rub_ant%type)
  RETURN NUMBER;

  FUNCTION FU_OBT_SAL_ME RETURN NUMBER;

  PROCEDURE PR_INI_SAL_MAYOR;

  FUNCTION FU_OBT_MIN_FEC RETURN DATE;

end PAB_MAY;
/

