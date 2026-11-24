CREATE OR REPLACE PROCEDURE IT.PRP_APL_LIM_CREDITO ( p_nro_linea NUMBER,
                           p_nro_cuenta VARCHAR2,
                           P_nro_secuencia in number default null,
                           p_det_error in varchar2 default null) IS
  vlin_estado     PR_LINEAS.ESTADO%TYPE;
  vlin_moneda     PR_LINEAS.COD_MONEDA%TYPE;
  vope_modulo     BA_MODULOS.COD_MODULO%TYPE;
  vope_modalidad  GE_MODALIDADES.COD_MODALIDAD%TYPE;
  vope_modalidad2 GE_MODALIDADES.COD_MODALIDAD%TYPE;
  vope_sub_modalidad GE_SUB_MODALIDADES.COD_SUB_MODALIDAD%TYPE;
  vope_moneda     BA_MONEDAS.COD_MONEDA%TYPE;
  vlin_saldo      NUMBER(18,2); -- Saldo de la linea
  vope_saldo      NUMBER(18,2); -- Saldo de la operacion
  vope_saldo_lin  NUMBER(18,2); -- Saldo de la operación en la moneda de la linea
  vsob_saldo_lin  NUMBER(18,2); -- Saldo del sobregiron en la moneda de la linea
  vgar_saldo      NUMBER(18,2); -- Saldo de las garantías de la cuenta
  vgar_limite     number(18,2);
  vmensaje        VARCHAR2(1000);
  verror          EXCEPTION;
  v_fec_ven_lin   date;
  --
  v_exi_lin_sobregiro varchar2(1) default 'S'; --DYDMR-4363 - variable para verificar si existe la linea de sobregiro vigente
  
  CURSOR sobregiros
      IS select lg.cod_garantia, ls.cod_moneda, sum( lg.mto_aplicado ) mto_aplicado
           from cc_lin_sobregiros ls, cc_lin_sob_garantias lg
          where ls.nro_secuencia = p_nro_secuencia
            and ls.nro_secuencia = lg.nro_secuencia
          group by lg.cod_garantia, ls.cod_moneda
          order by lg.cod_garantia;
  CURSOR prestamos IS
         select G.COD_GARANTIA,
                SUM(g.mto_aplicado) AS mto_aplicado
           from ge_est_cuentas b, 
                pr_gar_tipos t,
                ge_cta_clientes c,
                pr_cta_garantias g,
                pr_cta_prestamos p
          where P.nro_cuenta = C.nro_cuenta
            AND C.relacion = 'P'
            AND P.ESTADO <> 'N'
            AND p.nro_sol_renovada IS NULL
            AND P.ESTADO = B.ESTADO
            AND P.COD_MODULO = B.COD_MODULO
            AND P.COD_MODALIDAD = B.COD_MODALIDAD
            AND P.NRO_CUENTA = G.NRO_CUENTA
            AND G.COD_GARANTIA = T.COD_GARANTIA
            AND G.COD_GARANTIA != 28
            AND p.nro_cuenta = p_nro_cuenta
          GROUP BY G.COD_GARANTIA
          ORDER BY G.COD_GARANTIA
          ;

  CURSOR sol_prestamos
      IS select cod_garantia, sum( mto_aplicado ) mto_aplicado
           from pr_sol_garantias
          where nro_solicitud = to_number(replace(p_nro_cuenta, 'Prop.Nro. ',''))
            and cod_garantia <> 28 -- LA Garantía Fogapy No debe Afectar a los Límites.
          group by cod_garantia
          order by cod_garantia;
  CURSOR tarjetas
      IS select cod_garantia, sum( mto_aplicado ) mto_aplicado
           from ta_sol_garantias
          where nro_solicitud = to_number(replace(p_nro_cuenta, 'Sol.Nro. ',''))
          group by cod_garantia
         union all
         select cod_garantia, sum( mto_aplicado ) mto_aplicado
           from ta_cta_garantias
          where nro_cuenta = p_nro_cuenta
          group by cod_garantia
          order by cod_garantia;
  CURSOR comex
      IS select cod_garantia, sum( mto_aplicado ) mto_aplicado
           from cx_cta_garantias
          where nro_cuenta = p_nro_cuenta
          group by cod_garantia
          order by cod_garantia;
  CURSOR finanzas
  is select cod_garantia as cod_garantia, sum( monto ) mto_aplicado
             from md_garantias
            where nro_cuenta = p_nro_cuenta
            group by cod_garantia
            order by cod_garantia;

  CURSOR cambios
      IS select b.cod_garantia, sum(b.MTO_APLICADO) mto_aplicado
           from pv_operaciones_det b
          where b.nro_cuenta = p_nro_cuenta
            and b.cod_modulo = vope_modulo
          group by cod_garantia
          order by cod_garantia;

  FUNCTION f_verifica_detalle( p_cod_garantia  NUMBER,
                               p_mto_lim_garantia number,
                               p_cod_modulo    NUMBER,
                               p_cod_modalidad NUMBER,
                               p_monto         NUMBER
                               ) RETURN BOOLEAN IS
    v_cantidad NUMBER(10) := 0;
    v_saldo number(20,2);
  BEGIN
    select nvl( count(*), 0 )
      into v_cantidad
      from pr_lin_tip_gar_mad
     where nro_linea = p_nro_linea
       and cod_garantia = p_cod_garantia;
    IF v_cantidad > 0 THEN
      BEGIN
        select ( nvl( mto_limite, p_mto_lim_garantia ) - nvl( mto_aplicado, 0 ) ) - nvl( p_monto, 0 )
          into v_saldo
          from pr_lin_tip_gar_mad
         where nro_linea = p_nro_linea
           and cod_garantia = p_cod_garantia
           and cod_modulo = p_cod_modulo
           and ( cod_modalidad IS NULL OR cod_modalidad = p_cod_modalidad );
      EXCEPTION
        when NO_DATA_FOUND then
          --RAISE_APPLICATION_ERROR(-20012, 'Limite para el tipo de Garantía '||fup_obt_des_tip_garantia(p_cod_garantia)||' de la Cuenta: '||p_nro_cuenta);
          v_saldo := 0;
        when others then
          v_saldo := -1;
      END;
    END IF;
  if p_det_error is null THEN
    IF nvl(v_saldo, 0 ) >= 0 THEN
      return TRUE;
    ELSE
      RAISE_APPLICATION_ERROR(-20011, 'Saldo de la operación: '||p_nro_cuenta||' supera al del tipo de producto en la garantia '||fup_obt_des_tip_garantia(p_cod_garantia));
      return FALSE;
    END IF;
  else
   return TRUE;
  end if;
  EXCEPTION
    when others then
      if sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR( -20300, 'Error en la función de verificación. Gar. ' || to_char( p_cod_garantia ) ||
                                       ' Modul.' || to_char( p_cod_modulo ) || ' Modal.' || to_char( p_cod_modalidad ) ||
                                       ' Mont.' || to_char( p_monto ) || '; ' || sqlerrm );
      end if;
  END;
Begin
        BEGIN
          select estado, cod_moneda, nvl( monto, 0 ) - nvl( mto_aplicado, 0 ), fec_vencimiento
            into vlin_estado, vlin_moneda, vlin_saldo, v_fec_ven_lin
            from pr_lineas
           where nro_linea = p_nro_linea;
        EXCEPTION
          when verror then
               raise verror;
          when others then
               vmensaje := 'ERROR. Al buscar la línea '||SQLERRM;
               raise verror;
        END;

        IF nvl( vlin_estado, 'P' ) not in ('P','A','B') THEN
           raise_application_error(-20000, 'Estado de la linea debe ser Pendiente o Aprobada');
        END IF;

        IF p_nro_cuenta like 'Prop.Nro.%' then
            -- Si es una propuesta
            BEGIN
              select cod_modulo , cod_modalidad , cod_moneda, cod_sub_modalidad
                into vope_modulo, vope_modalidad, vope_moneda, vope_sub_modalidad
                from pr_solicitudes
               where nro_solicitud = to_number(replace(p_nro_cuenta, 'Prop.Nro. ',''))
                 and p_nro_cuenta like 'Prop.Nro.%';
            EXCEPTION
              when verror then
                   raise verror;
              when others then
                   vmensaje := 'ERROR. No se pudo encontrar la ' || p_nro_cuenta || '; ' || sqlerrm;
                   raise verror;
            END;
        elsif p_nro_cuenta like 'Sol.Nro%' then
            -- es solicitud de tarjetas
            BEGIN
              select cod_modulo, cod_modalidad, cod_moneda
                into vope_modulo, vope_modalidad, vope_moneda
                from ta_solicitudes
               where nro_solicitud = to_number(replace(p_nro_cuenta, 'Sol.Nro. ',''))
                 and p_nro_cuenta like 'Sol.Nro.%';
            EXCEPTION
              when verror then
                raise verror;
              when others then
                vmensaje := 'ERROR. No se pudo encontrar la ' || p_nro_cuenta || '; ' || sqlerrm;
                raise verror;
            END;
        Else
            BEGIN
              select cod_modulo, cod_modalidad, cod_moneda, cod_sub_modalidad
                into vope_modulo, vope_modalidad, vope_moneda, vope_sub_modalidad
                from ge_cuentas
               where nro_cuenta = p_nro_cuenta
                 and p_nro_cuenta not like 'Prop.Nro.%';
            EXCEPTION
              when verror then
                raise verror;
              when others then
                vmensaje := 'ERROR. No se pudo encontrar la cuenta ' || p_nro_cuenta || '; ' || sqlerrm;
                raise verror;
            END;
        End if;
        IF vope_modulo = 4 THEN    -- Sobregiros
          begin
            select ls.cod_moneda, ls.monto into vope_moneda, vope_saldo
              from cc_lin_sobregiros ls
             where ls.nro_secuencia = p_nro_secuencia;
          exception
            When NO_DATA_FOUND then
                v_exi_lin_sobregiro := 'N'; --DYDMR-4363 - la linea de sobregiro no está vigente
            when others then
              vmensaje := 'ERROR. No se pudo encontrar la Linea de Sobregiro ' || p_nro_cuenta || '; ' || sqlerrm;
              raise verror;
          end;
        ELSIF vope_modulo = 5 THEN -- Tarjetas
          BEGIN
            if p_nro_cuenta like 'Sol.Nro%' then
               select nvl(monto,0)
                 into vope_saldo
                 from ta_solicitudes
                where nro_solicitud = to_number(replace(p_nro_cuenta, 'Sol.Nro. ',''))
                  and p_nro_cuenta like 'Sol.Nro.%';
            else
              select nvl(lin_credito, 0 )+nvl(lin_cuotas,0)
                into vope_saldo
                from ta_cta_tarjetas
               where nro_cuenta = p_nro_cuenta;
            end if;
          EXCEPTION
            when verror then
              raise verror;
            when others then
              vmensaje := 'ERROR. No se pudo encontrar la cuenta de tarjeta ' || p_nro_cuenta || '; ' || sqlerrm;
              raise verror;
          END;
        ELSIF vope_modulo = 6 THEN -- Prestamos
            If p_nro_cuenta like 'Prop.Nro.%' then
                BEGIN
                  select nvl( tot_prestamo, 0 )
                    into vope_saldo
                    from pr_solicitudes
                   where nro_solicitud = to_number(replace(p_nro_cuenta, 'Prop.Nro. ',''));
                EXCEPTION
                  when verror then
                    raise verror;
                  when others then
                    vmensaje := 'ERROR. No se pudo encontrar la cuenta de préstamo ' || p_nro_cuenta || '; ' || sqlerrm;
                    raise verror;
                END;
            Else
                BEGIN
                  select nvl( sal_capital, 0 ) + nvl( sal_int_adelantado, 0 )
                    into vope_saldo
                    from pr_cta_prestamos
                   where nro_cuenta = p_nro_cuenta;
                EXCEPTION
                  when verror then
                    raise verror;
                  when others then
                    vmensaje := 'ERROR. No se pudo encontrar la cuenta de préstamo ' || p_nro_cuenta || '; ' || sqlerrm;
                    raise verror;
                END;
            End if;
        ELSIF vope_modulo = 7 THEN    -- Cta Cambios  RABP-CNF:17-06-2015
            Begin
              Select nvl(c.mto_limite,0)
                into vope_saldo
                from lc_cta_cambios c
               Where c.nro_cuenta = p_nro_cuenta
                 And c.estado != 'C';
            exception
              When NO_DATA_FOUND then
                   vope_saldo := 0;
              when others then
                vmensaje := 'ERROR. No se pudo encontrar la Cuenta de Cambios ' || p_nro_cuenta || '; ' || sqlerrm;
                raise verror;
            end;
        ELSIF vope_modulo = 8 THEN -- Comercio Exterior
          IF vope_modalidad = 81 then  -- CARTA DE CREDITO DE IMPORTACION
              BEGIN
                select nvl(saldo,0)
                  into vope_saldo
                  from cx_cta_importaciones
                 where nro_cuenta = p_nro_cuenta;
              EXCEPTION
                when verror then
                  raise verror;
                when others then
                  vmensaje := 'ERROR. No se pudo encontrar carta de credito importacion ' || p_nro_cuenta || '; ' || sqlerrm;
                  raise verror;
              END;
          Elsif vope_modalidad = 82  then --CARTA DE CREDITO DE EXPORTACION
              BEGIN
                select nvl(saldo,0)
                  into vope_saldo
                  from cx_cta_exportaciones
                 where nro_cuenta = p_nro_cuenta;
              EXCEPTION
                when verror then
                  raise verror;
                when others then
                  vmensaje := 'ERROR. No se pudo encontrar carta de credito exportacion ' || p_nro_cuenta || '; ' || sqlerrm;
                  raise verror;
              END;
          Elsif vope_modalidad in (88, 89) then --  FIANZAS LOCALES y FIANZAS EXTERIOR
              BEGIN
                select nvl(monto,0)
                  into vope_saldo
                  from cx_fianzas
                 where nro_cuenta = p_nro_cuenta;
              EXCEPTION
                when verror then
                  raise verror;
                when others then
                  vmensaje := 'ERROR. No se pudo encontrar la fianza ' || p_nro_cuenta || '; ' || sqlerrm;
                  raise verror;
              END;
          End if;
        END IF;


        IF nvl( vope_moneda, 'x' ) <> nvl( vlin_moneda, 'x' ) THEN
           vope_saldo_lin := pag_gen.fu_con_mon_a_moneda( vope_moneda,
                                                          vlin_moneda,
                                                          nvl( vope_saldo, 0 ) );
        ELSE
           vope_saldo_lin := nvl( vope_saldo, 0 );
        END IF;


        IF nvl( vope_saldo_lin, 0 ) > nvl( vlin_saldo, 0 ) THEN --> Controla que el monto de la operacion no supere el saldo de la Linea
          if p_det_error is null then
            raise_application_error(-20001, 'Operacion '||p_nro_cuenta||' Saldo: '||vope_saldo_lin || ' Saldo Linea: '||vlin_saldo);
          end if;
        END IF;

        IF vope_modulo = 4 THEN    -- Sobregiros
          FOR s IN sobregiros LOOP
            BEGIN
              select ( nvl( mto_limite, 0) - nvl( mto_aplicado, 0 ) ), mto_limite
                into vgar_saldo, vgar_limite
                from pr_lin_tip_garantias
               where nro_linea = p_nro_linea
                 and cod_garantia = s.cod_garantia;
            EXCEPTION
              when verror then
                raise verror;
              when no_data_found then
                raise_application_error(-20002, 'Linea por tipo de Garantía ('||fup_obt_des_tip_garantia(s.cod_garantia)||') no encontrada '||p_nro_linea);
              when others then
                vmensaje := 'ERROR. Al verificar el saldo de la garantía ' || s.cod_garantia || ' por sobregiros ' || sqlerrm;
                raise verror;
            END;
            IF nvl( s.cod_moneda, 'x' ) <> nvl( vlin_moneda, 'x' ) THEN
              vsob_saldo_lin := pag_gen.fu_con_mon_a_moneda( s.cod_moneda,
                                                             vlin_moneda,
                                                             nvl( s.mto_aplicado, 0 ) );
            ELSE
              vsob_saldo_lin := s.mto_aplicado;
            END IF;
            IF nvl( vsob_saldo_lin, 0 ) > nvl( vgar_saldo, 0 ) THEN
               if p_det_error is null then
                  raise_application_error(-20003, 'Saldo de la operacion: '||p_nro_cuenta||' supera al del tipo de garantía: '||fup_obt_des_tip_garantia(s.cod_garantia));
               end if;
            END IF;
            IF NOT f_verifica_detalle( s.cod_garantia, vgar_limite, vope_modulo, vope_modalidad, vsob_saldo_lin ) THEN
              raise verror;
            END IF;
          END LOOP;
        ELSIF vope_modulo = 5 THEN -- Tarjetas
          FOR t IN tarjetas LOOP
            BEGIN
              select ( nvl( mto_limite, 0 ) - nvl( mto_aplicado, 0 ) ), mto_limite
                into vgar_saldo, vgar_limite
                from pr_lin_tip_garantias
               where nro_linea = p_nro_linea
                 and cod_garantia = t.cod_garantia;
            EXCEPTION
              when verror then
                raise verror;
              when no_data_found then
                raise_application_error(-20004, 'Tipo de Garantía no encontrada '||p_nro_linea);
              when others then
                vmensaje := 'ERROR. Al verificar el saldo de la garantía ' ||fup_obt_des_tip_garantia(t.cod_garantia) || ' por tarjetas ' || sqlerrm;
                raise verror;
            END;
            IF nvl( vope_moneda, 'x' ) <> nvl( vlin_moneda, 'x' ) THEN
              vsob_saldo_lin := pag_gen.fu_con_mon_a_moneda( vope_moneda,
                                                             vlin_moneda,
                                                             nvl( t.mto_aplicado, 0 ) );
            ELSE
              vsob_saldo_lin := t.mto_aplicado;
            END IF;
            IF nvl( vsob_saldo_lin, 0 ) > nvl( vgar_saldo, 0 ) THEN
              if p_det_error is null then
                 raise_application_error(-20005, 'Saldo de la operacion: '||p_nro_cuenta||' supera al del tipo de garantía: '||fup_obt_des_tip_garantia(t.cod_garantia));
              end if;
            END IF;
            IF NOT f_verifica_detalle( t.cod_garantia, vgar_limite, vope_modulo, vope_modalidad, vsob_saldo_lin ) THEN
              raise verror;
            END IF;
          END LOOP;
        ELSIF vope_modulo = 6 THEN -- Prestamos
          If p_nro_cuenta like 'Prop.Nro.%' then
            FOR p IN sol_prestamos LOOP
              BEGIN
                    select (nvl(mto_limite,0 ) - nvl(mto_aplicado,0)), mto_limite
                      into                 vgar_saldo                , vgar_limite
                      from pr_lin_tip_garantias
                     where nro_linea    = p_nro_linea
                       and cod_garantia = p.cod_garantia;
              EXCEPTION
                    when verror then
                         raise verror;
                    when no_data_found then
                         raise_application_error(-20004, 'Tipo de Garantía no encontrada: '||fup_obt_des_tip_garantia(p.cod_garantia)||p_nro_linea);
                    when others then
                         vmensaje := 'ERROR. Al verificar el saldo de la garantía ' || fup_obt_des_tip_garantia(p.cod_garantia) || ' por préstamos ' || sqlerrm;
                         raise verror;
              END;

              IF nvl( vope_moneda, 'x' ) <> nvl( vlin_moneda, 'x' ) THEN
                 vsob_saldo_lin := pag_gen.fu_con_mon_a_moneda( vope_moneda,
                                                                vlin_moneda,
                                                                nvl( p.mto_aplicado, 0 ) );
              ELSE
                 vsob_saldo_lin := p.mto_aplicado;
              END IF;

              IF nvl( vsob_saldo_lin, 0 ) > nvl( vgar_saldo, 0 ) THEN
                if p_det_error is null then
                  raise_application_error(-20005, 'Saldo de la operacion: '||p_nro_cuenta||' supera al del tipo de garantía: '||fup_obt_des_tip_garantia(p.cod_garantia));
                end if;
              End If;

              IF NOT f_verifica_detalle( p.cod_garantia, vgar_limite, vope_modulo, vope_modalidad, vsob_saldo_lin ) THEN
                raise verror;
              END IF;

            END LOOP;

          Else
            FOR p IN prestamos LOOP
              BEGIN
                select ( nvl( mto_limite, 0 ) - nvl( mto_aplicado, 0 ) ), mto_limite
                  into vgar_saldo, vgar_limite
                  from pr_lin_tip_garantias
                 where nro_linea = p_nro_linea
                   and cod_garantia = p.cod_garantia;
              EXCEPTION
                when verror then
                  raise verror;
                when no_data_found then
                  --vc 02-08-2010
                  --ya no debe dar error, si la asignación automática de garantías le asignó un tipo no existente en el límite se debe insertar
                  --raise_application_error(-20004, 'Tipo de Garantía no encontrada: '||fup_obt_des_tip_garantia(p.cod_garantia)||p_nro_linea);
                  insert into pr_lin_tip_garantias
                         (nro_linea, cod_garantia, mto_limite, mto_aplicado, rel_garantia)
                  values (p_nro_linea, p.cod_garantia, 0, 0, 1);
                when others then
                  vmensaje := 'ERROR. Al verificar el saldo de la garantía ' || fup_obt_des_tip_garantia(p.cod_garantia) || ' por préstamos ' || sqlerrm;
                  raise verror;
              END;
              IF nvl( vope_moneda, 'x' ) <> nvl( vlin_moneda, 'x' ) THEN
                vsob_saldo_lin := pag_gen.fu_con_mon_a_moneda( vope_moneda,
                                                               vlin_moneda,
                                                               nvl( p.mto_aplicado, 0 ) );
              ELSE
                vsob_saldo_lin := p.mto_aplicado;
              END IF;
              IF nvl( vsob_saldo_lin, 0 ) > nvl( vgar_saldo, 0 ) THEN
                if p_det_error is null then
                  raise_application_error(-20005, 'Saldo de la operacion: '||p_nro_cuenta||' supera al del tipo de garantía: '||fup_obt_des_tip_garantia(p.cod_garantia));
                end if;
              End If;
              IF NOT f_verifica_detalle( p.cod_garantia, vgar_limite, vope_modulo, vope_modalidad, vsob_saldo_lin ) THEN
                raise verror;
              END IF;
            END LOOP;
          End if;
        ELSIF vope_modulo = 7 THEN -- Cuenta de Cambios.  RABP-CNF:17-06-2015
          FOR c IN cambios LOOP
              BEGIN
                select ( nvl( mto_limite, 0 ) - nvl( mto_aplicado, 0 ) ), mto_limite
                  into vgar_saldo, vgar_limite
                  from pr_lin_tip_garantias
                 where nro_linea = p_nro_linea
                   and cod_garantia = c.cod_garantia;
              EXCEPTION
                when verror then
                  raise verror;
                when no_data_found then
                  raise_application_error(-20004, 'Tipo de Garantía no encontrada '||p_nro_linea);
                when others then
                  vmensaje := 'ERROR. Al verificar el saldo de la garantía ' || fup_obt_des_tip_garantia(c.cod_garantia) || ' por Cta. Cambios ' || sqlerrm;
                  raise verror;
              END;
              IF nvl( vope_moneda, 'x' ) <> nvl( vlin_moneda, 'x' ) THEN
                vsob_saldo_lin := pag_gen.fu_con_mon_a_moneda( vope_moneda,
                                                               vlin_moneda,
                                                               nvl( c.mto_aplicado, 0 ) );
              ELSE
                vsob_saldo_lin := c.mto_aplicado;
              END IF;
              IF nvl( vsob_saldo_lin, 0 ) > nvl( vgar_saldo, 0 ) THEN
                if p_det_error is null then
                  raise_application_error(-20005, 'Saldo de la operacion: '||p_nro_cuenta||' supera al del tipo de garantía: '||fup_obt_des_tip_garantia(c.cod_garantia));
                end if;
              End If;
              IF NOT f_verifica_detalle( c.cod_garantia, vgar_limite, vope_modulo, vope_modalidad, vsob_saldo_lin ) THEN
                raise verror;
              END IF;
          END LOOP;
        ELSIF vope_modulo = 8 THEN -- Comercio Exterior.
          FOR t IN comex LOOP
            BEGIN
              select ( nvl( mto_limite, 0 ) - nvl( mto_aplicado, 0 ) ), mto_limite
                into vgar_saldo, vgar_limite
                from pr_lin_tip_garantias
               where nro_linea = p_nro_linea
                 and cod_garantia = t.cod_garantia;
            EXCEPTION
              when verror then
                raise verror;
              when no_data_found then
                --raise_application_error(-20004, 'Tipo de Garantía no encontrada '||p_nro_linea);
                --DYDMR-5047 / Adecuacion para evitar caida del Cierre similar a Prestamos--
                --Definido por Operaciones (lalmiron) / Modificado por rpavon 21.09.2016--
                  insert into pr_lin_tip_garantias
                         (nro_linea, cod_garantia, mto_limite, mto_aplicado, rel_garantia)
                  values (p_nro_linea, t.cod_garantia, 0, 0, 1);
              when others then
                vmensaje := 'ERROR. Al verificar el saldo de la garantía ' ||fup_obt_des_tip_garantia(t.cod_garantia) || ' por Comex ' || sqlerrm;
                raise verror;
            END;
            IF nvl( vope_moneda, 'x' ) <> nvl( vlin_moneda, 'x' ) THEN
              vsob_saldo_lin := pag_gen.fu_con_mon_a_moneda( vope_moneda,
                                                             vlin_moneda,
                                                             nvl( t.mto_aplicado, 0 ) );
            ELSE
              vsob_saldo_lin := t.mto_aplicado;
            END IF;
            IF nvl( vsob_saldo_lin, 0 ) > nvl( vgar_saldo, 0 ) THEN
              if p_det_error is null then
              raise_application_error(-20005, 'Saldo de la operacion: '||p_nro_cuenta||' supera al del tipo de garantía: '||fup_obt_des_tip_garantia(t.cod_garantia));
              end if;
            END IF;
            IF NOT f_verifica_detalle( t.cod_garantia, vgar_limite, vope_modulo, vope_modalidad, vsob_saldo_lin ) THEN
              raise verror;
            END IF;
          END LOOP;
        END IF;
        -- Si paso todas las validaciones...
        -- Entonces sí puede actualizar la linea de credito
        IF vope_modulo = 4 THEN    -- Sobregiros
          FOR s IN sobregiros LOOP
            IF nvl( s.cod_moneda, 'x' ) <> nvl( vlin_moneda, 'x' ) THEN
              vsob_saldo_lin := pag_gen.fu_con_mon_a_moneda( s.cod_moneda,
                                                             vlin_moneda,
                                                             nvl( s.mto_aplicado, 0 ) );
            ELSE
              vsob_saldo_lin := s.mto_aplicado;
            END IF;
            pap_gar.pr_act_mad_limite( p_nro_linea,
                                       s.cod_garantia,
                                       vsob_saldo_lin,
                                       vope_modulo,
                                       vope_modalidad );
            pap_gar.pr_act_tip_limite( p_nro_linea,
                                       s.cod_garantia,
                                       vsob_saldo_lin );

          END LOOP;
        if v_exi_lin_sobregiro = 'S' then --DYDMR-4363 - controla que esté vigente la linea de sobregiro
          Declare
            v_tip_sobregiro     cc_lin_sobregiros.tipo%type;
            v_est_sobregiro     cc_lin_sobregiros.estado%type;
            v_nro_lin_sobregiro cc_lin_sobregiros.nro_linea%type;
          BEGIN
            --  Obtiene los datos originales para saber si es que va a grabar en el historico o no
            Begin
              Select tipo, estado, nro_linea
                into v_tip_sobregiro, v_est_sobregiro, v_nro_lin_sobregiro
                from cc_lin_sobregiros
               where nro_secuencia = p_nro_secuencia;
            Exception
              When NO_DATA_FOUND then
                 raise_application_error(-20008, 'Linea de Sobregiro '||p_nro_secuencia||' no encontrada');
              When TOO_MANY_ROWS Then
                 raise_application_error(-20009, 'Linea de Sobregiro '||p_nro_secuencia||' duplicada');
              When OTHERS then
                 raise_application_error(-20010, 'Error al buscar Linea de Sobregiro '||p_nro_secuencia||' '||sqlerrm);
            End;
            -- Pasa de Transitorio a Permanente
            update cc_lin_sobregiros ls
               set ls.nro_linea = p_nro_linea,
                   ls.tipo = 'P',
                   ls.estado = 'A',
                   ls.fec_vencimiento = decode(ls.estado, 'A', v_fec_ven_lin, ls.fec_vencimiento)
             where ((ls.nro_secuencia = p_nro_secuencia and nro_cuenta is null)
                 or (ls.nro_sec_padre = p_nro_secuencia and nro_cuenta is not null))
                and estado in ('A');
            If sql%notfound then
               raise_application_error(-20011, 'No actualizo ninguna linea de sobregiro '||p_nro_secuencia||' estado '||v_est_sobregiro);
            End if;
            -- inserta antes el historico.
            If v_tip_sobregiro != 'P' or nvl(v_nro_lin_sobregiro,0) != p_nro_linea Then
               -- pasa al historico.
               prc_ins_his_sobregiro(p_nro_secuencia);
            End if;
          EXCEPTION
            when verror then
              raise verror;
            when others then
              vmensaje := 'ERROR. Al actualizar la linea de sobregiro ' || sqlerrm;
              raise verror;
          END;
        end if;
        ELSIF vope_modulo = 5 THEN -- Tarjetas
          FOR t IN tarjetas LOOP
            IF nvl( vope_moneda, 'x' ) <> nvl( vlin_moneda, 'x' ) THEN
              vope_saldo_lin := pag_gen.fu_con_mon_a_moneda( vope_moneda,
                                                             vlin_moneda,
                                                             nvl( t.mto_aplicado, 0 ) );
            ELSE
              vope_saldo_lin := t.mto_aplicado;
            END IF;
            -- Las actualizaciones se hacen por trigger...
            pap_gar.pr_act_mad_limite( p_nro_linea,
                                       t.cod_garantia,
                                       vope_saldo_lin,--p.mto_aplicado,
                                       vope_modulo,
                                       vope_modalidad );
            pap_gar.pr_act_tip_limite( p_nro_linea,
                                       t.cod_garantia,
                                       vope_saldo_lin);

          END LOOP;
          BEGIN
            if p_nro_cuenta like 'Sol%' then
              update ta_solicitudes
                 set nro_linea = p_nro_linea
               where nro_solicitud  = to_number(replace(p_nro_cuenta, 'Sol.Nro. ',''));
            else
              update ta_cta_tarjetas
                 set nro_linea = p_nro_linea
               where nro_cuenta = p_nro_cuenta;
            end if;
          EXCEPTION
            when verror then
              raise verror;
            when others then
              vmensaje := 'ERROR. Al actualizar cuenta de tarjetas ' || sqlerrm;
              raise verror;
          END;
        ELSIF vope_modulo = 6 THEN -- Prestamos
          -- SDMALICR-1
          IF nvl(fug_obt_pardinamico('FAD_LIN_PCP_SUB_MAD',vope_modulo,vope_modalidad,null,null,vope_sub_modalidad),'N') = 'S' THEN
             vope_modalidad2 := nvl(fug_obt_pardinamico('FAD_LIN_PCP_MAD',vope_modulo,vope_modalidad), vope_modalidad);
          ELSIF vope_modalidad IN (645,646) THEN
             vope_modalidad2 := nvl(fug_obt_pardinamico('FAD_LIN_FOGAPY_MAD',vope_modulo,vope_modalidad), vope_modalidad);
          ELSE
             vope_modalidad2 := vope_modalidad;
          END IF;
          If p_nro_cuenta like 'Prop.Nro.%' then
            FOR p IN sol_prestamos LOOP
              IF nvl( vope_moneda, 'x' ) <> nvl( vlin_moneda, 'x' ) THEN
                vsob_saldo_lin := pag_gen.fu_con_mon_a_moneda( vope_moneda,
                                                               vlin_moneda,
                                                               nvl( p.mto_aplicado, 0 ) );
              ELSE
                vsob_saldo_lin := p.mto_aplicado;
              END IF;
              vope_saldo_lin := vsob_saldo_lin;
              -- Las actualizaciones se hacen por trigger...
              pap_gar.pr_act_mad_limite( p_nro_linea,
                                         p.cod_garantia,
                                         vsob_saldo_lin,--p.mto_aplicado,
                                         vope_modulo,
                                         vope_modalidad2 );
              pap_gar.pr_act_tip_limite( p_nro_linea,
                                         p.cod_garantia,
                                         vsob_saldo_lin );

            END LOOP;
            BEGIN
              update pr_solicitudes
                 set nro_linea = p_nro_linea
               where nro_solicitud = to_number(replace(p_nro_cuenta, 'Prop.Nro. ',''));
            EXCEPTION
              when verror then
                raise verror;
              when others then
                vmensaje := 'ERROR. Al actualizar Solicitud de prestamos ' || sqlerrm;
                raise verror;
            END;
          Else
            FOR p IN prestamos LOOP
              IF nvl( vope_moneda, 'x' ) <> nvl( vlin_moneda, 'x' ) THEN
                vsob_saldo_lin := pag_gen.fu_con_mon_a_moneda( vope_moneda,
                                                               vlin_moneda,
                                                               nvl( p.mto_aplicado, 0 ) );
              ELSE
                vsob_saldo_lin := p.mto_aplicado;
              END IF;
              vope_saldo_lin := vsob_saldo_lin;
              -- Las actualizaciones se hacen por trigger...
              pap_gar.pr_act_mad_limite( p_nro_linea,
                                         p.cod_garantia,
                                         vsob_saldo_lin,--p.mto_aplicado,
                                         vope_modulo,
                                         vope_modalidad2 );
              pap_gar.pr_act_tip_limite( p_nro_linea,
                                         p.cod_garantia,
                                         vsob_saldo_lin );

            END LOOP;
            BEGIN
              update pr_cta_prestamos
                 set nro_linea = p_nro_linea
               where nro_cuenta = p_nro_cuenta;
            EXCEPTION
              when verror then
                raise verror;
              when others then
                vmensaje := 'ERROR. Al actualizar cuenta de prestamos ' || sqlerrm;
                raise verror;
            END;
          End if;
        ELSIF vope_modulo = 7 THEN -- Cuenta de Cambios.  RABP-CNF:17-06-2015
          FOR c IN cambios LOOP
            IF nvl( vope_moneda, 'x' ) <> nvl( vlin_moneda, 'x' ) THEN
              vsob_saldo_lin := pag_gen.fu_con_mon_a_moneda( vope_moneda,
                                                             vlin_moneda,
                                                             nvl( c.mto_aplicado, 0 ) );
            ELSE
              vsob_saldo_lin := c.mto_aplicado;
            END IF;
            vope_saldo_lin := vsob_saldo_lin;
            -- Las actualizaciones se hacen por trigger...
            pap_gar.pr_act_mad_limite( p_nro_linea,
                                       c.cod_garantia,
                                       vsob_saldo_lin,--p.mto_aplicado,
                                       vope_modulo,
                                       vope_modalidad );
            pap_gar.pr_act_tip_limite( p_nro_linea,
                                       c.cod_garantia,
                                       vsob_saldo_lin );

          END LOOP;
        ELSIF vope_modulo = 8 THEN -- Comercio Exterior
          FOR t IN comex LOOP
            IF nvl( vope_moneda, 'x' ) <> nvl( vlin_moneda, 'x' ) THEN
              vope_saldo_lin := pag_gen.fu_con_mon_a_moneda( vope_moneda,
                                                             vlin_moneda,
                                                             nvl( t.mto_aplicado, 0 ) );
            ELSE
              vope_saldo_lin := t.mto_aplicado;
            END IF;
            -- Las actualizaciones se hacen por trigger...
            pap_gar.pr_act_mad_limite( p_nro_linea,
                                       t.cod_garantia,
                                       vope_saldo_lin,--p.mto_aplicado,
                                       vope_modulo,
                                       vope_modalidad );
            pap_gar.pr_act_tip_limite( p_nro_linea,
                                       t.cod_garantia,
                                       vope_saldo_lin);

          END LOOP;
          BEGIN
            IF vope_modalidad = 81 then  -- CARTA DE CREDITO DE IMPORTACION
               Update cx_cta_importaciones
                  set nro_linea = p_nro_linea
                where nro_cuenta = p_nro_cuenta;
            Elsif vope_modalidad = 82  then --CARTA DE CREDITO DE EXPORTACION
               Update cx_cta_exportaciones
                  set nro_linea = p_nro_linea
                where nro_cuenta = p_nro_cuenta;
            Elsif vope_modalidad in (88, 89) then --  FIANZAS LOCALES y FIANZAS EXTERIOR
               Update cx_fianzas
                  set nro_linea = p_nro_linea
                where nro_cuenta = p_nro_cuenta;
            End if;
          EXCEPTION
            when verror then
              raise verror;
            when others then
              vmensaje := 'ERROR. Al actualizar cuenta de comercio exterior ' || sqlerrm;
              raise verror;
          END;
        ELSIF vope_modulo = 10 THEN -- Finanzas
                FOR t IN finanzas LOOP
                    IF nvl( vope_moneda, 'x' ) <> nvl( vlin_moneda, 'x' ) THEN
                      vope_saldo_lin := pag_gen.fu_con_mon_a_moneda( vope_moneda,
                                                                     vlin_moneda,
                                                                     nvl( t.mto_aplicado, 0 ) );
                    ELSE
                      vope_saldo_lin := t.mto_aplicado;
                    END IF;
                    -- Las actualizaciones se hacen por trigger...
                    pap_gar.pr_act_mad_limite( p_nro_linea,
                                               t.cod_garantia,
                                               vope_saldo_lin,--p.mto_aplicado,
                                               vope_modulo,
                                               vope_modalidad );
                    pap_gar.pr_act_tip_limite( p_nro_linea,
                                               t.cod_garantia,
                                               vope_saldo_lin);

              END LOOP;
              BEGIN
                update md_cta_documentos m
                   set m.nro_linea = p_nro_linea
                 where m.nro_cuenta = p_nro_cuenta;
              EXCEPTION
                when verror then
                  raise verror;
                when others then
                  vmensaje := 'ERROR. Al actualizar cuenta de comercio exterior ' || sqlerrm;
                  raise verror;
              END;
        END IF;
EXCEPTION
        when verror then
          if sqlcode <= -20000 then
             raise;
          else
             RAISE_APPLICATION_ERROR( -20200, vmensaje );
          end if;
        when others then
          if sqlcode <= -20000 then
             raise;
          else
             RAISE_APPLICATION_ERROR( -20202, 'ERROR. En el proceso de verificación de límite '||sqlerrm );
          end if;
END ;
/
