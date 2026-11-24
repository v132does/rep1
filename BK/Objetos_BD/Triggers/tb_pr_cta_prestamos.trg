CREATE OR REPLACE TRIGGER IT.TB_PR_CTA_PRESTAMOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON PR_CTA_PRESTAMOS
 FOR EACH ROW
DECLARE
   v_cot_mon_ori   ge_cotizaciones.val_conversion%type;
   v_cot_mon_des   ge_cotizaciones.val_conversion%type;
   v_cod_mon_linea pr_lineas.cod_moneda%type;
   v_diferencia    pr_cta_prestamos.sal_capital%type;
   v_mto_aplicado  pr_cta_prestamos.mto_lin_aplicado%type;
   v_cod_persona   ba_personas.cod_persona%type;
   v_existe        varchar2(1):='N';
cursor garantias is
  select cod_garantia,mto_aplicado, nro_garantia
   from pr_cta_garantias
   where nro_cuenta = :new.nro_cuenta;

  v_mto_apli_gar  pr_lineas.mto_aplicado%type;

function fn_obt_inh_cobro(P_COD_CAUSA   IN GE_PAR_DINAMICOS.VAL_PARAMETRO%TYPE,
                                               P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE DEFAULT NULL,
                                               P_NRO_CUENTA  IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL)
  RETURN VARCHAR2 IS
  V_EXISTE VARCHAR2(1) := 'N';
  V_ERROR VARCHAR2(100);
begin
  BEGIN
    SELECT 'S'
      INTO V_EXISTE
      FROM (SELECT B.COD_CAUSA
              FROM GE_PER_INHIBIDAS A, GE_CAUSALES B
             WHERE A.COD_CAUSA = B.COD_CAUSA
               AND A.ESTADO = 'I'
               AND A.COD_PERSONA = P_COD_PERSONA
            UNION ALL
            SELECT DISTINCT C.COD_CAUSA
              FROM GE_CUENTAS A, GE_CTA_CLIENTES B, GE_PER_INHIBIDAS C
             WHERE A.NRO_CUENTA = B.NRO_CUENTA
               AND A.NRO_CUENTA = P_NRO_CUENTA
               AND B.COD_PERSONA = C.COD_PERSONA
               AND B.COD_PERSONA = P_COD_PERSONA
               AND c.estado ='I'  -- SOLO ESTADO INHIBIDO DYDMR-11426
               AND EXISTS (SELECT 1
                      FROM GE_PER_INHIBIDAS X
                     WHERE X.COD_PERSONA = B.COD_PERSONA
                       AND X.ESTADO = 'I'))
     WHERE INSTR(P_COD_CAUSA, COD_CAUSA) > 0
       AND ROWNUM = 1;
  EXCEPTION
    WHEN OTHERS THEN
      V_EXISTE := 'N';
      V_ERROR := SQLERRM;
  END;
  RETURN V_EXISTE;
END;
BEGIN
   if nvl(PAE_CNF.G_PROGRAMA,'x') <> 'PRP_DEV_PRE_FIN' then --si se está ejecutando el devengado diario no debe entrar
      ---- Control de Utilización de Línea
      if :new.per_vto_interes is null and (inserting or updating) then
         :new.per_vto_interes := 0;
      end if;
      if updating then 
         if  :new.nro_linea is not null
         and (nvl(:new.sal_capital,0)+nvl(:new.sal_int_adelantado,0) <> nvl(:old.sal_capital,0)+nvl(:old.sal_int_adelantado,0)) then
            --- Hallar monto pagado (positivo) o reversado (negativo)
            v_diferencia := ((nvl(:old.sal_capital,0)+nvl(:old.sal_int_adelantado,0)) - (nvl(:new.sal_capital,0)+nvl(:new.sal_int_adelantado,0)));
            --- Actualizar mto aplicado de linea utilizado
            -- Recuperar moneda de la linea
            v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:new.nro_linea);
            -- Convertir el monto a moneda de la linea en la cotizacion actual
            pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea,
               v_diferencia, v_mto_aplicado,
               v_cot_mon_ori, v_cot_mon_des);
            -- Actualizar linea de crédito y mto aplicado del crédito en moneda de la linea
            -- obs: se cambia de signo porque los pagos deben descontar el aplicado
            pap_gar.pr_act_lin_aplicado(:new.nro_linea, (v_mto_aplicado*-1));
            -- Actualizar campo de la propia tabla
            :new.mto_lin_aplicado := nvl(:new.mto_lin_aplicado,0) + (v_mto_aplicado*-1);
         end if;
         --- Si no estaba asociado a una linea y se asocia debe tener mismo trato que insert
         if :new.nro_linea is not null and :old.nro_linea is null then
            v_diferencia := (nvl(:new.sal_capital,0) + nvl(:new.sal_int_adelantado,0));
            --v_diferencia := nvl(:new.sal_capital,0)+nvl(:new.sal_int_adelantado,0);
            -- Recuperar moneda de la linea
            v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:new.nro_linea);
            -- Convertir el monto a moneda de la linea en la cotizacion actual
            pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea,
               v_diferencia, v_mto_aplicado,
               v_cot_mon_ori, v_cot_mon_des);
            -- Actualizar linea de crédito y mto aplicado del crédito en moneda de la linea
            -- obs: se cambia de signo porque los pagos deben descontar el aplicado

            pap_gar.pr_act_lin_aplicado(:new.nro_linea, (v_mto_aplicado));
            -- Actualizar campo de la propia tabla
            :new.mto_lin_aplicado := nvl(:new.sal_capital,0)+nvl(:new.sal_int_adelantado,0);
         End if;
         --- Si se desasocia la linea o se cambia el numero de linea.
         if (:new.nro_linea is null and :old.nro_linea is not null) or
            (:new.nro_linea is not null and :old.nro_linea is not null and :new.nro_linea != :old.nro_linea) then
           -- Recuperar moneda de la linea
            v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:old.nro_linea);
            -- Convertir el monto a moneda de la linea en la cotizacion actual
            pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea,
               (nvl(:old.sal_capital,0)+nvl(:old.sal_int_adelantado,0)), v_mto_aplicado,
               v_cot_mon_ori, v_cot_mon_des);
            pap_gar.pr_act_lin_aplicado(:old.nro_linea, (nvl(v_mto_aplicado,0)*-1));
            for gar in garantias loop
              pag_gen.pr_con_mon_a_moneda(:new.cod_moneda,v_cod_mon_linea,
                                          nvl(gar.mto_aplicado,0), v_mto_apli_gar,
                                          v_cot_mon_ori, v_cot_mon_des);
              --Actualizar el mto aplicado de tipos de garantia por limite
              pap_gar.pr_act_tip_limite(:old.nro_linea,gar.cod_garantia,nvl(v_mto_apli_gar,0)*-1);
              --Actualizar el mto aplicado de garantias por Modalidad
              pap_gar.pr_act_mad_limite(:old.nro_linea,gar.cod_garantia,nvl(v_mto_apli_gar,0)*-1,6,:new.cod_modalidad);
            end loop;
            If :new.nro_linea is null then
               :new.mto_lin_aplicado := null;
            End if;
         end if;

          /**CROCLIJUD-5**/
          -- se incluye el programa EPMANPRE en la lista, desde esta pantalla no se puede modificar la deuda del cliente, por lo tanto, no debe restringir la act. de datos por inhibición DYDMR-11792 Oct/2019
         if (inserting or updating) and nvl(PAE_CNF.G_PROGRAMA,'x') not in ('GPPROFIN', 'OPVENCAR', 'OPRECACL', 'EPMANPRE') then --CROPVNDC-1 Hojeda -> Se incluye la pantalla de venta de cartera en el If, para que permita desvincular deb_automatico, por ser paso para la cancelacion de cuentas corrientes/sobregiros
           v_cod_persona :=fug_obt_cli_principal(:new.nro_cuenta);
         -- Verifica si el Cliente está inhibido y la causa es por Demanda Judicial
           if fug_obt_inhibicion(fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL'),v_cod_persona,:new.nro_cuenta) then
                raise_application_error(-20000,'Cliente Principal o Vinculados a la Cuenta con Demanda Judicial. Consulte con el asesor Jurídico');
           end if;
           if fn_obt_inh_cobro(fug_obt_pardinamico('GEN_COD_CAU_INH_COBRO'),v_cod_persona,:new.nro_cuenta) = 'S' then
                raise_application_error(-20000,'Cliente Principal o Vinculados a la Cuenta están inhibidos de cobro automatico-Demanda Judicial. Consulte con el asesor Jurídico');
           end if;
         end if;
      end if;
      /*Tasa Variable 10/2018*/
      if (inserting or updating) then 
         if :new.nro_solicitud is not null
           and :new.nro_cuenta is not null then
              --Verificamos si es Tasa Variable
              begin
                select 'S'
                  into v_existe
                  from pr_tas_variables a
                 where a.nro_solicitud= :new.nro_solicitud
                   and rownum=1;
              exception
                when no_data_found then
                  v_existe:= 'N';
                when others then
                  v_existe:= 'N';
              end;
              If v_existe = 'S' then
                 --Actualizamos el Nro de cuenta
                 update pr_tas_variables a
                    set a.nro_cuenta = :new.nro_cuenta
                  where a.nro_solicitud= :new.nro_solicitud
                    and rownum=1;
              end if;
         end if;
      end if;
   end if;
exception
   when others then
      raise_application_error(-20000,'Error en tb_pr_Cta_prestamos '||:new.nro_cuenta||' lin '||:old.nro_linea||' v_mto_apl '||v_mto_aplicado||sqlerrm);
END;
/
