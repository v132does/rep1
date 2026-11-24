CREATE OR REPLACE PACKAGE BODY IT.PAB_MAY is

-- Función que actualiza el saldo en linea
FUNCTION FU_CAL_SAL_MAY(
   p_cod_rubro   IN cb_sal_oficinas.cod_rubro%type,
   p_cod_oficina IN cb_sal_oficinas.cod_oficina%type,
   p_saldo_ml    IN cb_sal_oficinas.sal_mon_loc_ant%type,
   p_saldo_me    IN cb_sal_oficinas.sal_mon_rub_ant%type)
RETURN NUMBER IS
BEGIN
   if pab_may.g_may_cod_rubro is null
   or pab_may.g_may_cod_rubro <> p_cod_rubro then
      pab_may.g_may_cod_rubro := p_cod_rubro;
      pab_may.g_may_sal_act_ml := 0;
      pab_may.g_may_sal_act_me := 0;
   end if;
   if pab_may.g_may_cod_oficina is null
   or pab_may.g_may_cod_oficina <> p_cod_oficina then
      pab_may.g_may_cod_oficina := p_cod_oficina;
      pab_may.g_may_sal_act_ml := 0;
      pab_may.g_may_sal_act_me := 0;
   end if;
   pab_may.g_may_sal_act_ml := pab_may.g_may_sal_act_ml + nvl(p_saldo_ml,0);
   pab_may.g_may_sal_act_me := pab_may.g_may_sal_act_me + nvl(p_saldo_me,0);
   return pab_may.g_may_sal_act_ml;
END;

FUNCTION FU_OBT_SAL_ME
RETURN NUMBER IS
BEGIN
   return nvl(pab_may.g_may_sal_act_me,0);
END;

PROCEDURE PR_INI_SAL_MAYOR IS
BEGIN
   pab_may.g_may_cod_rubro   := null;
   pab_may.g_may_cod_oficina := null;
   pab_may.g_may_sal_act_ml  := 0;
   pab_may.g_may_sal_act_me  := 0;
END;


FUNCTION FU_OBT_MIN_FEC
RETURN DATE IS
   v_fec_par varchar2(10);
BEGIN
   pab_may.PR_INI_SAL_MAYOR;
   select substr(filtros, instr(lower(filtros),'to_date',1)+9,10)--dydmr-6060 - 02/02/2017
     into v_fec_par
     from ba_consultas s
    where s.cod_consulta='MAYOR_OFI';
   return to_date(v_fec_par,'DD/MM/YYYY');
EXCEPTION
   when no_data_found then
      raise_application_error(-20000,'Fecha no corresponde');
END;

end PAB_MAY;
/

