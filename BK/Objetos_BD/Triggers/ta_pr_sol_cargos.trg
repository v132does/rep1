CREATE OR REPLACE TRIGGER IT.TA_PR_SOL_CARGOS
 before INSERT OR DELETE OR UPDATE
 ON "IT"."PR_SOL_CARGOS"
 FOR EACH ROW
   /*
   || PCC-Exoneración y Extorno de Comisiones y Tasas
   || Comisión de Desembolso de Préstamos
   */
DECLARE
   v_val_exo_cargo ge_movimientos.val_tasa%TYPE;
   v_tip_valor     ge_tasas.tip_valor%TYPE;
   v_cod_tas_exo   ge_tasas.cod_tasa%TYPE;
   v_fec_actual    DATE := pag_cal.fu_obt_fec_actual(6);
   v_redondeo      NUMBER;
   v_cod_tas_cargo ge_movimientos.cod_tasa%TYPE;
   v_val_cargo     ge_movimientos.val_tasa%TYPE;
   v_cod_modulo    pr_solicitudes.cod_modulo%TYPE;
   v_cod_modalidad pr_solicitudes.cod_modalidad%TYPE;
   v_cod_moneda    pr_solicitudes.cod_moneda%TYPE;
   v_cod_oficina   pr_solicitudes.cod_oficina%TYPE;
   v_mto_interes   pr_solicitudes.mto_interes%TYPE;
   v_cod_persona   ba_personas.cod_persona%TYPE;
   v_nro_pedido    ge_mov_autorizaciones.nro_pedido%TYPE;
   v_tot_prestamo  pr_solicitudes.tot_prestamo%type;
   v_capital       pr_solicitudes.monto%type;
   v_tas_aplicar   ge_tasas.aplicar%type;
   v_iva_desglose  pr_solicitudes.iva_desglose%type;
   v_dia_plazo     pr_solicitudes.dia_plazo%type;
   v_val_min_cargo ge_tas_fechas.val_minimo%type;
   -- DYDMR-9486 IEC04
   v_mto_exoneracion ge_exoneraciones_tmp.mto_exoneracion%type;
   v_mto_a_cobrar    ge_exoneraciones_tmp.mto_a_cobrar%type;
   ---
   FUNCTION lf_obt_cod_tasa
   (
      p_cod_transaccion ge_transacciones.cod_transaccion%TYPE,
      p_cod_modulo      ge_transacciones.cod_modulo%TYPE,
      p_cod_modalidad   ge_transacciones.cod_modalidad%TYPE
   ) RETURN NUMBER IS
      v_cod_tasa ge_tasas.cod_tasa%TYPE;
   BEGIN
      SELECT a.cod_tasa
        INTO v_cod_tasa
        FROM ge_transacciones a
       WHERE a.cod_transaccion = p_cod_transaccion
         AND a.cod_modulo = p_cod_modulo
         AND a.cod_modalidad = p_cod_modalidad;
      RETURN v_cod_tasa;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
   FUNCTION lf_obt_dat_tasa(p_cod_tasa in number) RETURN VARCHAR2 is
     v_aplicar ge_tasas.aplicar%type;
   BEGIN
     SELECT aplicar
       INTO v_aplicar
       FROM ge_tasas
      WHERE cod_tasa = p_cod_tasa;
     RETURN v_aplicar;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
BEGIN
   SELECT cod_modulo, cod_modalidad, cod_moneda, cod_oficina, mto_interes, cod_persona, tot_prestamo,
          iva_desglose, monto, dia_plazo
     INTO v_cod_modulo, v_cod_modalidad, v_cod_moneda, v_cod_oficina, v_mto_interes, v_cod_persona, v_tot_prestamo,
          v_iva_desglose, v_capital, v_dia_plazo
     FROM pr_solicitudes
    WHERE nro_solicitud = nvl(:new.nro_solicitud, :old.nro_solicitud);
   v_redondeo    := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                        v_cod_moneda);
   v_cod_tas_exo := lf_obt_cod_tasa(nvl(:new.cod_transaccion, :old.cod_transaccion), v_cod_modulo,
                                    v_cod_modalidad);
   IF v_cod_tas_exo IS NOT NULL AND
      nvl(:new.cod_ent_seguro, nvl(:old.cod_ent_seguro, -1)) = -1 THEN
      v_val_cargo     := nvl(:new.monto, :old.monto);
      v_cod_tas_cargo := nvl(:new.cod_tasa, :old.cod_tasa);
      v_tip_valor := fug_obt_tip_val_tasa(v_cod_tas_exo);
      v_tas_aplicar := lf_obt_dat_tasa(v_cod_tas_exo);

      -- busco el valor de la tasa
      IF v_tip_valor = 'T' THEN
        BEGIN
           v_val_exo_cargo := fug_obt_val_tasa(v_cod_modulo, v_cod_modalidad, v_cod_oficina, NULL,
                                               v_cod_moneda, v_capital, 'N', NULL,
                                               nvl(:new.cod_transaccion, :old.cod_transaccion),
                                               v_fec_actual);
           v_val_min_cargo := pag_gen.FU_OBT_VAL_MINIMO;
        EXCEPTION
           WHEN OTHERS THEN
              raise_application_error(-20000, 'Al Obt.Val.Tasa:' || SQLERRM);
        END;
      ELSE
        BEGIN
           v_val_exo_cargo := fug_obt_val_tasa(v_cod_modulo, v_cod_modalidad, v_cod_oficina, NULL,
                                               v_cod_moneda, v_mto_interes, 'N', NULL,
                                               nvl(:new.cod_transaccion, :old.cod_transaccion),
                                               v_fec_actual);
           v_val_min_cargo := pag_gen.FU_OBT_VAL_MINIMO;
        EXCEPTION
           WHEN OTHERS THEN
              raise_application_error(-20001, 'Al Obt.Val.Tasa:' || SQLERRM);
        END;
      END IF;

      IF v_tip_valor = 'V' THEN
         -- si es un valor, se toma directamente
         v_val_exo_cargo := nvl(v_val_exo_cargo, 0);
      ELSIF v_tip_valor = 'T' THEN
         -- es un codigo de tasa
         --si es un codigo de tasa hay que ir a buscar el valor con la tasa devuelta y
         --con el el p_monto2
         IF nvl(v_val_exo_cargo, 0) > 0 THEN
            v_tip_valor := fug_obt_tip_val_tasa(v_val_exo_cargo);
            -- busco el valor de la tasa
            BEGIN
               v_val_exo_cargo := fug_obt_val_tasa(v_cod_modulo, v_cod_modalidad, v_cod_oficina,
                                                   NULL, v_cod_moneda, v_dia_plazo, 'N',
                                                   v_val_exo_cargo, NULL, v_fec_actual);
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20002, 'Al Obt.Val.Tasa:' || SQLERRM);
            END;
            IF v_tip_valor = 'V' THEN
               v_val_exo_cargo := nvl(v_val_exo_cargo, 0);
            ELSIF v_tip_valor = 'C' THEN
               v_val_exo_cargo := round(v_mto_interes * nvl(v_val_exo_cargo, 0), v_redondeo);
            ELSE
               -- es un porcentaje
               v_val_exo_cargo := round(nvl(v_tot_prestamo/*v_mto_interes*/, 0) * nvl(v_val_exo_cargo, 0) / 100,
                                        v_redondeo);
               --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
               v_val_exo_cargo := round(pag_gen.fu_obt_val_final(v_val_exo_cargo), v_redondeo);
            END IF;
         ELSE
            v_val_exo_cargo := 0;
         END IF;
      ELSIF v_tip_valor = 'P' THEN--es porcentaje
         if v_tas_aplicar in ('CI','IN') then
            if nvl(v_iva_desglose,'N') = 'N' then
               v_val_exo_cargo := round(nvl(v_mto_interes,0) * nvl(v_val_exo_cargo,0) / 100, v_redondeo);
            else
               v_val_exo_cargo := 0;
            end if;
         elsif v_tas_aplicar in ('PI','IP','PT','TP') then
            if nvl(v_iva_desglose,'N') = 'N' then
               v_val_exo_cargo := round(nvl(v_mto_interes,0) * v_dia_plazo * nvl(v_val_exo_cargo,0) / 36500, v_redondeo);
            else
               v_val_exo_cargo := 0;
            end if;
         end if;
         if v_tas_aplicar in ('CA','CI','CP') then
            v_val_exo_cargo := round(nvl(v_tot_prestamo, 0) * nvl(v_val_exo_cargo, 0) / 100, v_redondeo);
         elsif v_tas_aplicar in ('PC','PT','TP') then
            v_val_exo_cargo := round(nvl(v_tot_prestamo, 0) * v_dia_plazo * nvl(v_val_exo_cargo,0) / 36500, v_redondeo);
         end if;
         if v_tas_aplicar = 'TD' then
            v_val_exo_cargo := round(nvl(v_tot_prestamo, 0) * nvl(v_val_exo_cargo,0) / 100,v_redondeo);
         end if;
         --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
         v_val_exo_cargo := pag_gen.fu_obt_val_final(v_val_exo_cargo);
      ELSIF v_tip_valor = 'I' then--es interes
         if v_tas_aplicar in ('CI','IN','PI','IP','PT','TP') then
            if v_dia_plazo < 365 then
               if nvl(v_iva_desglose,'N') = 'N' then
                  v_val_exo_cargo := round(nvl(v_mto_interes, 0) * v_dia_plazo * v_val_exo_cargo / 36500, v_redondeo);
               else
                  v_val_exo_cargo := 0;
               end if;
            else
               if nvl(v_iva_desglose,'N') = 'N' then
                  v_val_exo_cargo := round(nvl(v_mto_interes, 0) * v_val_exo_cargo / 100, v_redondeo);
               else
                  v_val_exo_cargo := 0;
               end if;
            end if;
         end if;
         if v_tas_aplicar in ('CA','CI','PC','CP','PT','TP') then
            if :new.cod_ent_seguro is not null then
               v_val_exo_cargo := round(nvl(v_tot_prestamo, 0) * v_val_exo_cargo / 100, v_redondeo);
            else
               if v_dia_plazo < 365 then
                  v_val_exo_cargo := round(nvl(v_tot_prestamo,0) * v_val_exo_cargo / 36500,v_redondeo);
               else
                  v_val_exo_cargo := round(nvl(v_tot_prestamo, 0) * v_val_exo_cargo / 100, v_redondeo);
               end if;
            end if;
         end if;
         if v_tas_aplicar = 'MO' AND nvl(:new.cod_transaccion, :old.cod_transaccion) = 704 THEN
            --Hallar valor de la tasa
            BEGIN
               v_val_exo_cargo := fug_obt_val_tasa(v_cod_modulo, v_cod_modalidad, v_cod_oficina,
                                                   NULL, v_cod_moneda, v_dia_plazo, 'N',
                                                   v_val_exo_cargo, NULL, v_fec_actual);
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20002, 'Al Obt.Val.Tasa:' || SQLERRM);
            END;
            v_val_exo_cargo := round(nvl(v_capital, 0) * nvl(v_val_exo_cargo,0) / 100,v_redondeo);
         ELSIF v_tas_aplicar = 'MO' AND nvl(:new.cod_transaccion, :old.cod_transaccion) = 1270 THEN
            v_val_exo_cargo := round(nvl(v_capital, 0) * nvl(v_val_exo_cargo,0) / 100,v_redondeo);
         end if;
         if v_tas_aplicar = 'TD' then
            v_val_exo_cargo := round(nvl(v_tot_prestamo,0) * v_val_exo_cargo / 100 ,v_redondeo);
         end if;
      END IF;
      ---
      --buscar el nro_pedido
       begin
         select a.nro_pedido
           into v_nro_pedido
           from ge_exoneraciones_tmp a
          where a.nro_sol_prestamo = nvl(:old.nro_solicitud, :new.nro_solicitud) --DYDMR-4989
            and a.cod_transaccion  = nvl(:new.cod_transaccion, :old.cod_transaccion)
            and a.cod_modulo = v_cod_modulo
            and a.cod_modalidad = v_cod_modalidad;
       exception
         when no_data_found then
           v_nro_pedido := 0;
         when too_many_rows then --DYDMR-5630
           select a.nro_pedido
             into v_nro_pedido
             from ge_exoneraciones_tmp a
            where a.nro_sol_prestamo = nvl(:old.nro_solicitud, :new.nro_solicitud)
              and a.cod_transaccion  = nvl(:new.cod_transaccion, :old.cod_transaccion)
              and a.cod_modulo = v_cod_modulo
              and a.cod_modalidad = v_cod_modalidad
              and a.fec_insercion = (select max(a.fec_insercion)
                                       from ge_exoneraciones_tmp a
                                      where a.nro_sol_prestamo = nvl(:old.nro_solicitud, :new.nro_solicitud)
                                        and a.cod_transaccion  = nvl(:new.cod_transaccion, :old.cod_transaccion)
                                        and a.cod_modulo = v_cod_modulo
                                        and a.cod_modalidad = v_cod_modalidad);
       end;
      IF (nvl(v_val_cargo, 0) <> nvl(v_val_exo_cargo, 0)) OR
         (nvl(v_val_cargo, 0) = 0 AND nvl(v_val_exo_cargo, 0) <> 0) OR
         (nvl(v_val_cargo, 0) > v_val_min_cargo) THEN --DYDMR-4989

         if (nvl(v_val_cargo, 0) > v_val_min_cargo) then
           v_val_exo_cargo := v_val_min_cargo;
         end if;

         -- DYDMR-9486 IEC04 - Relevamiento y Ajustes a Exoneraciones de Prestamos
         -- en lugar de enviar el monto a cobrar se envia el monto exonerado real
         -- igualando asi con la lógica de las demas exoneraciones
         v_mto_exoneracion := nvl(v_val_exo_cargo, 0) - nvl(:new.monto, :old.monto);
         v_mto_a_cobrar    := nvl(v_val_exo_cargo, 0);
         if inserting and nvl(v_nro_pedido,0) = 0 then
             BEGIN
                -- DYDMR-10041 IEC 06
                SELECT s_cod_autorizacion.nextval
                  INTO v_nro_pedido
                  FROM dual;
             EXCEPTION
                WHEN OTHERS THEN
                   raise_application_error(-20001, 'Al Obt.Nro.Pedido: ' || SQLERRM);
             END;
             ---
             BEGIN
                INSERT INTO ge_exoneraciones_tmp
                   (nro_pedido, cod_transaccion, cod_modulo, cod_modalidad, cod_moneda,
                    nro_sol_prestamo, cod_persona, estado, cod_tasa, mto_exoneracion, mto_a_cobrar)
                VALUES
                   (nvl(v_nro_pedido, 0), nvl(:new.cod_transaccion, :old.cod_transaccion), v_cod_modulo,
                    v_cod_modalidad, v_cod_moneda, nvl(:new.nro_solicitud, :old.nro_solicitud),
                    v_cod_persona, 'A', v_cod_tas_cargo, v_mto_exoneracion, v_mto_a_cobrar);
             EXCEPTION
                WHEN OTHERS THEN
                   raise_application_error(-20002, 'Al Ins.Exoneracion: ' || SQLERRM);
             END;
         elsif updating then
             update ge_exoneraciones_tmp a
                set a.mto_exoneracion = v_mto_exoneracion,
                    a.mto_a_cobrar = v_mto_a_cobrar,
                    a.nro_sol_prestamo = :new.nro_solicitud
              where a.nro_pedido = v_nro_pedido;
              if sql%notfound then
                 BEGIN
                   INSERT INTO ge_exoneraciones_tmp
                        (nro_pedido, cod_transaccion, cod_modulo, cod_modalidad, cod_moneda,
                         nro_sol_prestamo, cod_persona, estado, cod_tasa, mto_exoneracion, mto_a_cobrar)
                     VALUES
                        (nvl(v_nro_pedido, 0), nvl(:new.cod_transaccion, :old.cod_transaccion), v_cod_modulo,
                         v_cod_modalidad, v_cod_moneda, nvl(:new.nro_solicitud, :old.nro_solicitud),
                         v_cod_persona, 'A', v_cod_tas_cargo, v_mto_exoneracion, v_mto_a_cobrar);
                 EXCEPTION
                   WHEN OTHERS THEN
                      raise_application_error(-20003, 'Al Ins.Exoneracion: ' || SQLERRM);
                 END;
              end if;
         elsif deleting then
             delete ge_exoneraciones_tmp a
              where a.nro_pedido = v_nro_pedido;
         end if;
      END IF;
      --DYDMR-4989
      if updating then
        if v_nro_pedido is not null then
         update ge_exoneraciones_tmp a
            set a.nro_sol_prestamo = nvl(:new.nro_solicitud,:old.nro_solicitud)
          where a.nro_pedido = v_nro_pedido;
        end if;
      end if;
   END IF;
END;
/

