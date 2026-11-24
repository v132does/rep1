CREATE OR REPLACE TRIGGER IT."TA_TA_PREVISIONES"
 AFTER DELETE OR INSERT OR UPDATE
 ON TA_PREVISIONES
 FOR EACH ROW

DECLARE
   v_cod_persona        ge_clientes.cod_persona%type;
   v_cod_moneda         ge_cuentas.cod_moneda%type;
   v_cod_gru_economico  ge_clientes.cod_gru_economico%type;

PROCEDURE LP_OBT_DAT_CLIENTE
  (p_nro_cuenta in ge_cuentas.nro_cuenta%type,
   p_cod_persona in out ge_cta_clientes.cod_persona%type,
   p_cod_moneda  in out ge_cuentas.cod_moneda%type,
   p_cod_gru_economico in out ge_gru_economicos.cod_gru_economico%type)
IS
BEGIN
   select p.cod_moneda, c.cod_persona, c.cod_gru_economico
     into p_cod_moneda, p_cod_persona, p_cod_gru_economico
     from ge_cuentas p, ge_clientes c, ge_cta_clientes cc
    where p.nro_cuenta = cc.nro_cuenta
      and c.cod_persona = cc.cod_persona
      and cc.relacion   = 'P'
      and cc.nro_cuenta = p_nro_cuenta;
   exception
      when no_data_found then
         raise_application_error(-20000,
         'Cuenta '||p_nro_cuenta||' sin cliente principal');
      when too_many_rows then
        raise_application_error(-20000,
         'Cuenta '||p_nro_cuenta||' con mas de un cliente principal');
END;

BEGIN
   IF inserting or updating then
      pap_cat.v_mon_local   := pag_gen.fu_obt_mon_local;
      pap_cat.v_fec_proceso := pag_cal.fu_obt_fec_actual(6);
      lp_obt_dat_cliente(:new.nro_cuenta, v_cod_persona, v_cod_moneda, v_cod_gru_economico);
      --- Actualizar la prevision en tablas de consulta
      update ge_cla_operaciones
         set tot_prevision = PAP_CAT.FU_CON_A_GUARANIES(v_cod_moneda, nvl(:new.monto,0))
       where nro_cuenta = :new.nro_cuenta;
      --- Actualizar prevision del cliente y el grupo economico
      if inserting then
         update ge_clientes
            set tot_prevision = nvl(tot_prevision,0) + PAP_CAT.FU_CON_A_GUARANIES(v_cod_moneda, nvl(:new.monto,0))
          where cod_persona = v_cod_persona;
         if v_cod_gru_economico is not null then
            update ge_gru_economicos
               set tot_prevision = nvl(tot_prevision,0) + PAP_CAT.FU_CON_A_GUARANIES(v_cod_moneda, nvl(:new.monto,0))
             where cod_gru_economico = v_cod_gru_economico;
         end if;
      else
         update ge_clientes
            set tot_prevision = nvl(tot_prevision,0) + PAP_CAT.FU_CON_A_GUARANIES(v_cod_moneda, (nvl(:new.monto,0) - nvl(:old.monto,0)))
          where cod_persona = v_cod_persona;
         if v_cod_gru_economico is not null then
            update ge_gru_economicos
               set tot_prevision = nvl(tot_prevision,0) + PAP_CAT.FU_CON_A_GUARANIES(v_cod_moneda, (nvl(:new.monto,0)-nvl(:old.monto,0)))
             where cod_gru_economico = v_cod_gru_economico;
         end if;
      end if;

   ELSE
      pap_cat.v_mon_local   := pag_gen.fu_obt_mon_local;
      pap_cat.v_fec_proceso := pag_cal.fu_obt_fec_actual(6);
      update ge_cla_operaciones
         set tot_prevision = 0
       where nro_cuenta = :old.nro_cuenta;
      --- Actualizar prevision del cliente y el grupo economico
      lp_obt_dat_cliente(:old.nro_cuenta, v_cod_persona, v_cod_moneda, v_cod_gru_economico);
      update ge_clientes
         set tot_prevision = nvl(tot_prevision,0) - PAP_CAT.FU_CON_A_GUARANIES(v_cod_moneda, nvl(:old.monto,0))
       where cod_persona = v_cod_persona;
      if v_cod_gru_economico is not null then
         update ge_gru_economicos
            set tot_prevision = nvl(tot_prevision,0) + PAP_CAT.FU_CON_A_GUARANIES(v_cod_moneda, nvl(:old.monto,0))
          where cod_gru_economico = v_cod_gru_economico;
      end if;
   END IF;
END;
/
