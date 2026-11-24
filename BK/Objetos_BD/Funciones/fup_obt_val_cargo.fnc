CREATE OR REPLACE FUNCTION IT.FUP_OBT_VAL_CARGO (
       p_nro_cuenta in varchar2,
       p_cod_transaccion in number,
       p_fec_vencimiento in date,
       p_nro_cuota in number default null,
       p_cod_seguro in number default null )
return NUMBER is
   --- BBVA- Realizado por ICL 28/06/2010. -- Recupera valor del cargo para una trasanccion
   --- atada a una tasa.
   --- VARIABLES
   v_pcpre        pr_cta_prestamos%rowtype;
   v_pcuot        pr_cuotas%rowtype;
   v_cod_tasa     ge_transacciones.cod_tasa%type;
   v_cod_tasa2    ge_transacciones.cod_tasa%type;
   v_gtasa        ge_tasas%rowtype;
   v_mto_interes  pr_cuotas.mto_interes%type;
   v_mto_equiv    pr_cta_prestamos.monto%type;
   v_redondeo     ge_parametros.parametro%type;
   v_dia_plazo    number(10);
   v_gtfec        ge_tas_fechas%rowtype;
   v_fecha        date;
   v_monto        pr_cta_prestamos.monto%type;
   v_tas_personalizada ge_cuentas.tas_personalizada%type;
begin
   v_fecha := pag_cal.FU_OBT_FEC_ACTUAL(6);
   --- Recuperar datos del prestamo
   BEGIN
      select p.* into v_pcpre
        from pr_cta_prestamos p
       where p.nro_cuenta=p_nro_cuenta;
      select sum(nvl(mto_interes,0)+nvl(mto_int_documentado,0))
        into v_mto_interes
        from pr_cuotas c
       where c.nro_cuenta=p_nro_cuenta;
   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000,'Cta. '||p_nro_cuenta||' no registrada');
   END;
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_pcpre.cod_modulo,v_pcpre.cod_modalidad,
                 v_pcpre.cod_moneda,v_pcpre.cod_modalidad,v_pcpre.cod_oficina);
   --- Recuperar tasa de la transaccion
   BEGIN
      select cod_tasa into v_cod_tasa
        from ge_transacciones
       where cod_transaccion = p_cod_transaccion
         and cod_modulo = v_pcpre.cod_modulo
         and cod_modalidad = v_pcpre.cod_modalidad;
   EXCEPTION
      when no_data_found then
         raise_application_error(-20000,'Trans. '||p_cod_transaccion||' no registrada para modalidad '||v_pcpre.cod_modalidad);
   END;
   if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                 p_cod_transaccion,
                                 v_pcpre.cod_modulo,
                                 v_pcpre.cod_modalidad) = 'N' then
     if p_nro_cuenta is not null then
        -- no tiene transaccion prohibida, se calcula
        begin
           select tas_personalizada
             into v_tas_personalizada
             from ge_cuentas
             where nro_cuenta = p_nro_cuenta;
        exception
           when no_data_found then
              raise_application_error(-20000,'Cuenta '||p_nro_cuenta||' no registrada');
        end;
     end if;
   end if;
   -- Recuperar datos de la cuota
   BEGIN
   if p_nro_cuota is not null then
      select * into v_pcuot
        from pr_cuotas o
       where o.nro_cuenta = p_nro_cuenta
         and o.nro_cuota = p_nro_cuota;
   else
      select * into v_pcuot
        from pr_cuotas o
       where o.nro_cuenta = p_nro_cuenta
         and o.nro_cuota = (select max(nro_cuota)
                              from pr_cuotas x
                             where x.nro_cuenta=o.nro_cuenta
                               and x.fec_vencimiento<=p_fec_vencimiento);
   end if;
   EXCEPTION
      when no_data_found then return null;
   END;
   if v_pcuot.nro_cuota is not null then
      v_dia_plazo := v_fecha - v_pcuot.fec_vencimiento; --- Plazo de mora
      v_monto := nvl(v_pcuot.sal_capital,0)+nvl(v_pcuot.sal_interes,0)+nvl(v_pcuot.sal_int_documentado,0);
      if v_dia_plazo <= 0 then
         return 0; --- Retornar valor 0 porque no está vencido.
      end if;
   end if;
   --- Recuperar datos de la tasa
   --- Recuperar segunda tasa
   pag_gen.pr_obt_val_tasa(v_pcpre.cod_modulo, v_pcpre.cod_modalidad, v_pcpre.cod_oficina,
                     v_pcpre.nro_cuenta, v_pcpre.cod_moneda, v_dia_plazo, v_tas_personalizada,
                     v_gtfec.cod_tasa, p_cod_transaccion, v_fecha,
                     v_gtfec.val_tasa, v_gtfec.fec_vigencia ,v_gtasa.tip_valor, v_gtasa.tipo);

/*    if v_gtasa.tipo = 'V' then
       --- tipo de tasa variable  ---
       if v_gtasa.aplicar in ('PI','PC','PT','PL','CP','IP','TP') then
          if v_gtasa.aplicar in ('PI','PC','PT','PL') then
              --- El primer rango es por plazo
              ww_vldeta1 := OBTENER_VALOR_DE_TASA_VARIABLE(ww_cdtasas,:DIA_PLAZO,:wk_fcdehoy);
          else
              --- Rango de montos
              ww_vldeta1 := OBTENER_VALOR_DE_TASA_VARIABLE(ww_cdtasas,:pr_solicitudes.tot_prestamo,:wk_fcdehoy);
          end if;
          IF :SC_APLICAR IN ('CP','IP','TP')  then -- monto y plazo
             ww_vldeta1 :=  OBTENER_VALOR_DE_TASA_VARIABLE(ww_vldeta1,:DIA_PLAZO,:wk_fcdehoy);
          else  --- El segundo rango es por montos.
             ww_vldeta1 :=  OBTENER_VALOR_DE_TASA_VARIABLE(ww_vldeta1,:pr_solicitudes.tot_prestamo,:wk_fcdehoy);
          END IF;
       else
          --- tipo de tasa variable  ---
          ww_vldeta1 := OBTENER_VALOR_DE_TASA_VARIABLE(ww_cdtasas,:pr_solicitudes.tot_prestamo,:variables.wk_fcdehoy);
       end if;
    END IF;
*/
   --- Recuperar datos segunda tasa
   if v_gtfec.cod_tasa = 341 then
      --- Gastos de Cobranza son por Capital e Interes
      v_gtasa.aplicar := 'CI';
   end if;
   --- Recuperara valor final
   IF v_gtasa.tip_valor = 'P' THEN
      v_mto_equiv := 0;
        --- la tasa es un porcentaje-----------------------------------------------------
      IF v_gtasa.aplicar IN ('CI','IN','PI','IP','PT','TP') THEN
           --- aplicable al interes -----------------------------------------------------
           v_mto_equiv :=  ROUND((nvl(v_pcuot.sal_interes,0)+nvl(v_pcuot.sal_int_documentado,0)) * v_gtfec.val_tasa / 100,v_redondeo);
      END IF;
      IF v_gtasa.aplicar IN ('CA','CI','PC','CP','PT','TP') THEN
           --- es aplicable al capital --------------------------------------------------
           v_mto_equiv :=  NVL(v_mto_equiv,0) +
                           ROUND(v_pcuot.sal_capital * v_gtfec.val_tasa / 100,v_redondeo);
      END IF;
      -- moneda del cargo es igual a la moneda de la simulacion ----------------------
      return v_mto_equiv;
   ELSIF v_gtasa.tip_valor = 'I' THEN
      v_mto_equiv := 0;
      --- la tasa es un impuesto ------------------------------------------------------
      IF v_gtasa.aplicar IN ('CI','IN','PI','IP','PT','TP') THEN
         --- aplicable al interes -----------------------------------------------------
         IF v_dia_plazo < 365 THEN
            v_mto_equiv :=  ROUND(v_mto_interes * v_dia_plazo * v_gtfec.val_tasa / 36500,v_redondeo);
         ELSE
            v_mto_equiv :=  ROUND(v_mto_interes * v_gtfec.val_tasa / 100,v_redondeo);
         END IF;
      END IF;
      IF v_gtasa.aplicar IN ('CA','CI','PC','CP','PT','TP') THEN
         --- es aplicable al capital --------------------------------------------------
         IF p_cod_seguro IS NOT NULL THEN
            --- es un seguro ----------------------------------------------------------
            v_mto_equiv := NVL(v_mto_equiv,0) +
                           ROUND(v_pcpre.mto_capital * v_gtfec.val_tasa / 100,v_redondeo);
         ELSE
            --- es un impuesto sobre el capital ---------------------------------------
            IF v_dia_plazo < 365 THEN
               v_mto_equiv := NVL(v_mto_equiv,0) +
                              ROUND(v_pcpre.mto_capital * v_dia_plazo * v_gtfec.val_tasa / 36500,v_redondeo);
            ELSE
               v_mto_equiv := NVL(v_mto_equiv,0) +
                              ROUND(v_pcpre.mto_capital * v_gtfec.val_tasa / 100,v_redondeo);
            END IF;
         END IF;
      END IF;
      return v_mto_equiv;
   ELSIF v_gtasa.tip_valor = 'V' THEN
      --- es un monto valor -----------------------------------------------------------
      return 0; -- Cargo manual no calcular
   END IF;
end fup_obt_val_cargo;
/

