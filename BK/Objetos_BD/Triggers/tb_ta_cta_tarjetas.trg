CREATE OR REPLACE TRIGGER IT.TB_TA_CTA_TARJETAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON "IT"."TA_CTA_TARJETAS"
 FOR EACH ROW
DECLARE
   v_cot_mon_ori    ge_cotizaciones.val_conversion%TYPE;
   v_cot_mon_des    ge_cotizaciones.val_conversion%TYPE;
   v_cod_mon_linea  pr_lineas.cod_moneda%TYPE;
   v_diferencia     ta_cta_tarjetas.lin_credito%TYPE;
   v_mto_aplicado   ta_cta_tarjetas.lin_credito%TYPE;
   v_cod_persona    ba_personas.cod_persona%TYPE;
   v_dir_cliente    ba_direcciones.direccion%TYPE;
   v_lin_cuotas     ta_cta_tarjetas.lin_cuotas%TYPE;
   v_lin_credito    ta_cta_tarjetas.lin_credito%TYPE;
   v_tip_cobro      ta_cta_tarjetas.tip_cobro%TYPE;
   v_deb_automatico ta_cta_tarjetas.deb_automatico%TYPE;
   v_nro_cta_debito ta_cta_tarjetas.nro_cta_debito%TYPE;
   v_fec_actual     ta_cta_tarjetas.fec_solicitud%type := pag_cal.fu_obt_fec_actual(5);
   --
   v_por_pag_minimo      ta_cta_tarjetas.por_pag_minimo%type;
   v_mto_min_pag_minimo  ta_cta_tarjetas.mto_min_pag_minimo%type;
   v_mto_fij_pag_minimo  ta_cta_tarjetas.mto_fij_pag_minimo%type;
   v_tas_int_corriente   ta_cta_tarjetas.tas_int_corriente%type;
   v_tas_mora            ta_cta_tarjetas.tas_mora%type;
   v_tas_int_compra      ta_cta_tarjetas.tas_int_compra%type;
   v_tas_int_mora        ta_cta_tarjetas.tas_int_mora%type;
   v_enviado             varchar2(1) := 'N';
   v_count               number;
   v_fec_novedad         ta_cta_tarjetas_nov.fecha%type;
   v_cod_procesadora     ta_tipos.cod_ent_procesadora%TYPE;
   v_max_atraso          ta_cta_tarjetas.max_atraso%type := 0;
   v_dia_atraso          ta_cta_tarjetas.dia_mora%type := 0;
   v_mar_mora            ta_cta_tarjetas.mar_mora%type := 'N';
   r_cal                 ge_calendarios%rowtype;

   CURSOR garantias IS
      SELECT cod_garantia, SUM(mto_aplicado) mto_aplicado
        FROM ta_cta_garantias
       WHERE nro_cuenta = :new.nro_cuenta
       GROUP BY cod_garantia
       ORDER BY cod_garantia;

   v_mto_apli_gar pr_lineas.mto_aplicado%TYPE;

   FUNCTION fp_fec_novedad (p_nro_cuenta  ta_cta_tarjetas_nov.nro_cuenta%TYPE,
                            p_fec_novedad ta_cta_tarjetas_nov.fecha%TYPE) RETURN NUMBER IS
          v_count NUMBER;
          BEGIN
             SELECT COUNT(1)
               INTO v_count
               FROM ta_cta_tarjetas_nov t
              WHERE t.nro_cuenta        = p_nro_cuenta
                AND t.fecha             = p_fec_novedad
                AND nvl(t.enviado, 'N') = 'S';
             RETURN v_count;

          END fp_fec_novedad;


BEGIN
   ---- Control de Utilización de Línea
   IF updating THEN
     IF :new.nro_linea IS NOT NULL AND (nvl(:new.lin_credito, 0) + nvl(:new.lin_cuotas, 0) <>
       nvl(:old.lin_credito, 0) + nvl(:old.lin_cuotas, 0)) THEN
       --- Hallar monto de linea (positivo) o reversado (negativo)
       v_diferencia := (nvl(:old.lin_credito, 0) + nvl(:old.lin_cuotas, 0)) -
                       (nvl(:new.lin_credito, 0) + nvl(:new.lin_cuotas, 0));
       --- Actualizar mto aplicado de linea utilizado
       -- Recuperar moneda de la linea
       v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:new.nro_linea);
       -- Convertir el monto a moneda de la linea en la cotizacion actual
       pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea, v_diferencia, v_mto_aplicado,
                                   v_cot_mon_ori, v_cot_mon_des);
       -- Actualizar linea de crédito y mto aplicado del crédito en moneda de la linea
       -- obs: se cambia de signo porque los pagos deben descontar el aplicado
       pap_gar.pr_act_lin_aplicado(:new.nro_linea, (v_mto_aplicado * -1));
     END IF;
     --- Si no estaba asociado a una linea y se asocia debe tener mismo trato que insert
     IF :new.nro_linea IS NOT NULL AND :old.nro_linea IS NULL THEN
       v_diferencia := (nvl(:old.lin_credito, 0) + nvl(:old.lin_cuotas, 0)) -
                       (nvl(:new.lin_credito, 0) + nvl(:new.lin_cuotas, 0));
       -- Recuperar moneda de la linea
       v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:new.nro_linea);
       -- Convertir el monto a moneda de la linea en la cotizacion actual
       pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea, v_diferencia, v_mto_aplicado,
                                   v_cot_mon_ori, v_cot_mon_des);
       -- Actualizar linea de crédito y mto aplicado del crédito en moneda de la linea
       -- obs: se cambia de signo porque los pagos deben descontar el aplicado
       pap_gar.pr_act_lin_aplicado(:new.nro_linea, (v_mto_aplicado * -1));
     END IF;
     --- Si se desasocia la linea
     IF :new.nro_linea IS NULL AND :old.nro_linea IS NOT NULL THEN
       -- Recuperar moneda de la linea
       v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:old.nro_linea);
       -- Convertir el monto a moneda de la linea en la cotizacion actual
       pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea,
                                   nvl(:old.lin_credito, 0) + nvl(:old.lin_cuotas, 0),
                                   v_mto_aplicado, v_cot_mon_ori, v_cot_mon_des);
       pap_gar.pr_act_lin_aplicado(:old.nro_linea, (nvl(v_mto_aplicado, 0) * -1));
       FOR gar IN garantias LOOP
         pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea, nvl(gar.mto_aplicado, 0),
                                     v_mto_apli_gar, v_cot_mon_ori, v_cot_mon_des);
         --Actualizar el mto aplicado de tipos de garantia por limite
         pap_gar.pr_act_tip_limite(:old.nro_linea, gar.cod_garantia, nvl(v_mto_apli_gar, 0) * -1);
         --Actualizar el mto aplicado de garantias por Modalidad
         pap_gar.pr_act_mad_limite(:old.nro_linea, gar.cod_garantia, nvl(v_mto_apli_gar, 0) * -1,
                                   5, :new.cod_modalidad);
       END LOOP;
     END IF;
     /*Busco la procesadora de la cuenta*/
     BEGIN
       SELECT b.cod_ent_procesadora
         INTO v_cod_procesadora
         FROM ta_tipos b
        WHERE b.cod_modalidad = :new.cod_modalidad 
          AND b.afinidad = :new.afinidad
          and rownum=1;
     EXCEPTION
       WHEN no_data_found THEN
         v_cod_procesadora := fug_obt_pardinamico('COD_PRO_BANCARD');
     END;
     
     /*Solo cambios TCs Bancard*/  
     IF v_cod_procesadora != fug_obt_pardinamico('COD_ENT_GLOBAL') THEN
       -------PRT_CAL_ATRASOS------
       v_max_atraso := :old.max_atraso;
       v_dia_atraso := nvl( :new.dia_mora, 0 );
       if nvl(v_dia_atraso,0) > 0 then
         v_mar_mora := 'S';
       else
         v_mar_mora := 'N';
       end if;
       r_cal := pag_cal.fu_obt_reg_cal(5);
       if r_cal.fec_actual = r_cal.ult_dia_mes_habil then
         if nvl( v_dia_atraso, 0 ) > 0 then
           v_dia_atraso := nvl( v_dia_atraso, 0 ) + ( r_cal.ult_dia_mes - r_cal.ult_dia_mes_habil );
         end if;
       end if;
       if v_max_atraso < v_dia_atraso then
         v_max_atraso := v_dia_atraso;
       end if;
       :new.max_atraso := v_max_atraso;
       :new.dia_mora   := v_dia_atraso;
       :new.mar_mora   := v_mar_mora;
       IF fug_obt_pardinamico('ENV_MOD_TARJETA') = 'S' THEN
         IF nvl(pae_cnf.g_programa    , 'X') NOT IN ('GPPROFIN', 'GPPROIND') THEN

            IF nvl(:old.lin_cuotas        , 0  ) <> nvl(:new.lin_cuotas        , 0  ) OR
               nvl(:old.lin_credito       , 0  ) <> nvl(:new.lin_credito       , 0  ) OR
               nvl(:old.tip_cobro         , 'X') <> nvl(:new.tip_cobro         , 'X') OR
               nvl(:old.deb_automatico    , 'X') <> nvl(:new.deb_automatico    , 'X') OR
               nvl(:old.nro_cta_debito    , 'X') <> nvl(:new.nro_cta_debito    , 'X') OR
               nvl(:old.cod_tip_cierre    , 0  ) <> nvl(:new.cod_tip_cierre    , 0  ) OR
               nvl(:old.por_pag_minimo    , 0  ) <> nvl(:new.por_pag_minimo    , 0  ) OR
               nvl(:old.mto_min_pag_minimo, 0  ) <> nvl(:new.mto_min_pag_minimo, 0  ) OR
               nvl(:old.mto_fij_pag_minimo, 0  ) <> nvl(:new.mto_fij_pag_minimo, 0  ) OR
               nvl(:old.tas_int_corriente , 0  ) <> nvl(:new.tas_int_corriente , 0  ) OR
               nvl(:old.tas_mora          , 0  ) <> nvl(:new.tas_mora          , 0  ) OR
               nvl(:old.tas_int_compra    , 0  ) <> nvl(:new.tas_int_compra    , 0  ) OR
               nvl(:old.tas_int_mora      , 0  ) <> nvl(:new.tas_int_mora      , 0  ) THEN

               IF nvl(:old.lin_cuotas, 0) <> nvl(:new.lin_cuotas, 0) THEN
                  v_lin_cuotas := :new.lin_cuotas;
               END IF;
               IF nvl(:old.lin_credito, 0) <> nvl(:new.lin_credito, 0) THEN
                  v_lin_credito := :new.lin_credito;
               END IF;
               IF nvl(:old.tip_cobro, 'X') <> nvl(:new.tip_cobro, 'X') THEN
                  v_tip_cobro := :new.tip_cobro;
               END IF;
               IF nvl(:old.deb_automatico, 'X') <> nvl(:new.deb_automatico, 'X') THEN
                  v_deb_automatico := :new.deb_automatico;
               END IF;
               IF nvl(:old.nro_cta_debito, 'X') <> nvl(:new.nro_cta_debito, 'X') THEN
                  v_nro_cta_debito := :new.nro_cta_debito;
               END IF;
               --
               IF (nvl(:old.por_pag_minimo    , 0  ) <> nvl(:new.por_pag_minimo    , 0  ) )
                  OR (nvl(:old.tas_int_corriente , 0  ) <> nvl(:new.tas_int_corriente , 0 )
                      OR nvl(:old.tas_int_mora   , 0  ) <> nvl(:new.tas_int_mora      , 0 )
                      OR nvl(:old.tas_int_compra , 0  ) <> nvl(:new.tas_int_compra    , 0 ) )THEN
                  v_por_pag_minimo := :new.por_pag_minimo;
               END IF;

               IF (nvl(:old.mto_min_pag_minimo, 0  ) <> nvl(:new.mto_min_pag_minimo, 0  ) )
                  OR (nvl(:old.tas_int_corriente , 0  ) <> nvl(:new.tas_int_corriente , 0 )
                      OR nvl(:old.tas_int_mora   , 0  ) <> nvl(:new.tas_int_mora      , 0 )
                      OR nvl(:old.tas_int_compra , 0  ) <> nvl(:new.tas_int_compra    , 0 ) ) THEN
                  v_mto_min_pag_minimo := :new.mto_min_pag_minimo;
               END IF;
               IF (nvl(:old.mto_fij_pag_minimo, 0  ) <>  nvl(:new.mto_fij_pag_minimo, 0  ) )
                  OR (nvl(:old.tas_int_corriente , 0  ) <> nvl(:new.tas_int_corriente , 0 )
                      OR nvl(:old.tas_int_mora   , 0  ) <> nvl(:new.tas_int_mora      , 0 )
                      OR nvl(:old.tas_int_compra , 0  ) <> nvl(:new.tas_int_compra    , 0 ) ) THEN
                  v_mto_fij_pag_minimo := :new.mto_fij_pag_minimo;

               END IF;
               -- Tasas
               IF nvl(:old.tas_int_corriente , 0  ) <> nvl(:new.tas_int_corriente , 0  ) THEN
                  IF nvl(:new.tas_int_corriente , 0) >= 100 Then
                     raise_application_error(-20000,'La Tasa Máxima Configurable es de 99,9%');
                  End IF;
                  v_tas_int_corriente := :new.tas_int_corriente;
               END IF;
               IF nvl(:old.tas_mora, 0) <> nvl(:new.tas_mora, 0) THEN
                  IF nvl(:new.tas_mora, 0) >= 100 Then
                     raise_application_error(-20000,'La Tasa Máxima Configurable es de 99,9%');
                  End IF;
                  v_tas_mora := :new.tas_mora;
               END IF;
               IF nvl(:old.tas_int_compra    , 0  ) <> nvl(:new.tas_int_compra    , 0  ) THEN
                  IF nvl(:new.tas_int_compra , 0) >= 100 Then
                     raise_application_error(-20000,'La Tasa Máxima Configurable es de 99,9%');
                  End IF;
                  v_tas_int_compra := :new.tas_int_compra;
               END IF;
               IF nvl(:old.tas_int_mora, 0  ) <> nvl(:new.tas_int_mora      , 0  ) THEN
                  IF nvl(:new.tas_int_mora, 0) >= 100 Then
                     raise_application_error(-20000,'La Tasa Máxima Configurable es de 99,9%');
                  End IF;
                  v_tas_int_mora := :new.tas_int_mora;
               END IF;
               --
               ---- controlar que tenga direccion valida
               -- se comenta esta validacion ya que desde la implantacion del proyecto Extracto Click no es un requisito obligatorio
               -- tener una direccion de envío de extractos. DYDMR-11792 Oct/2019
             /*  BEGIN
                  -- Verificar que tenga direccion sea correcta para envio de extracto -- RI 17-02-2010
                  BEGIN
                     SELECT cod_persona
                       INTO v_cod_persona
                       FROM ge_cta_clientes
                      WHERE nro_cuenta = :new.nro_cuenta
                        AND relacion   = 'P';
                  EXCEPTION
                     WHEN OTHERS THEN
                        raise_application_error(-20000,
                                                'La cuenta no tiene definida relacion Principal en GE_CTA_CLIENTES ' ||
                                                 SQLERRM);
                  END;

                  SELECT substr(decode(e.tip_envio, 'D',
                                       d.direccion || decode(numero, NULL, '', ' ' || numero),
                                       -- Direccion
                                       'R', o.descripcion), 1, 50) dir_envio
                    INTO v_dir_cliente
                    FROM ba_barrios         b,
                         ba_ciudades        c,
                         ba_paises          p,
                         ba_direcciones     d,
                         ge_dir_retenciones o,
                         ge_dir_envios      e
                   WHERE p.cod_pais         (+) = d.cod_pais
                     AND c.cod_pais         (+) = d.cod_pais
                     AND c.cod_ciudad       (+) = d.cod_ciudad
                     AND b.cod_pais         (+) = d.cod_pais
                     AND b.cod_ciudad       (+) = d.cod_ciudad
                     AND b.cod_barrio       (+) = d.cod_barrio
                     AND d.cod_persona      (+) = e.cod_persona
                     AND d.cod_direccion    (+) = e.referencia
                     AND o.cod_dir_retencion(+) = e.referencia
                     AND e.cod_persona          = v_cod_persona
                     AND e.nro_cuenta           IS NULL;

                  IF v_dir_cliente IS NULL THEN
                     RAISE no_data_found;
                  END IF;
               EXCEPTION
                  WHEN no_data_found THEN
                     raise_application_error(-20000,
                                             'Cliente no tiene definida una direccion Valida para el envio del Extracto. ' ||
                                              'Verifique en la carpeta de la persona');

               END;*/
               ---
               BEGIN
                  UPDATE ta_cta_tarjetas_nov
                     SET lin_cuotas         = v_lin_cuotas        ,
                         lin_credito        = v_lin_credito       ,
                         tip_cobro          = v_tip_cobro         ,
                         deb_automatico     = v_deb_automatico    ,
                         nro_cta_debito     = v_nro_cta_debito    ,
                         enviado            = 'N'                 ,
                         aprobado           = 'N'                 ,
                         nro_acta           = NULL                ,
                         niv_aprobacion     = NULL                ,
                         cod_tip_cierre     = :new.cod_tip_cierre ,
                         --
                         por_pag_minimo     = v_por_pag_minimo    ,
                         mto_min_pag_minimo = v_mto_min_pag_minimo,
                         mto_fij_pag_minimo = v_mto_fij_pag_minimo,
                         tas_int_corriente  = v_tas_int_corriente ,
                         tas_mora           = v_tas_mora          ,
                         tas_int_compra     = v_tas_int_compra    ,
                         tip_relacion       = 'P'                 ,
                         tas_int_mora       = v_tas_int_mora
                   WHERE nro_cuenta  = :new.nro_cuenta
                     AND fecha       = pag_cal.fu_obt_fec_actual(5)
                     and enviado     != 'S';

                  IF SQL%NOTFOUND THEN
                     BEGIN
                          Select distinct('S')
                            into v_enviado
                            from ta_cta_tarjetas_nov a
                           Where a.nro_cuenta  = :new.nro_cuenta
                             and a.fecha       = pag_cal.fu_obt_fec_actual(5)
                             and a.enviado     = 'S';
                     EXCEPTION
                           When No_data_found then
                                v_enviado := 'N';
                           When Others Then
                                raise_application_error(-20000,'Error Buscando Datos Enviados '||sqlerrm);
                     END;

                     If v_enviado = 'S' then
                         v_fec_novedad := pag_cal.fu_obt_fec_actual(5);
                         v_count       := fp_fec_novedad(:new.nro_cuenta,v_fec_novedad);
                         while v_count > 0 loop
                               v_fec_novedad := v_fec_novedad + 1;
                               v_count       := fp_fec_novedad(:new.nro_cuenta,v_fec_novedad);
                         end loop;
                     End If;

                     BEGIN
                        INSERT INTO ta_cta_tarjetas_nov (nro_cuenta        ,
                                                         fecha             ,
                                                         lin_cuotas        ,
                                                         lin_credito       ,
                                                         tip_cobro         ,
                                                         deb_automatico    ,
                                                         nro_cta_debito    ,
                                                         enviado           ,
                                                         por_pag_minimo    ,
                                                         mto_min_pag_minimo,
                                                         mto_fij_pag_minimo,
                                                         tas_int_corriente ,
                                                         tas_mora          ,
                                                         tas_int_compra    ,
                                                         tip_relacion      ,
                                                         tas_int_mora      )

                                                  VALUES(:new.nro_cuenta     ,
                                                         decode(v_enviado,'S',v_fec_novedad,pag_cal.fu_obt_fec_actual(5)),
                                                         v_lin_cuotas        ,
                                                         v_lin_credito       ,
                                                         v_tip_cobro         ,
                                                         v_deb_automatico    ,
                                                         v_nro_cta_debito    ,
                                                         'N'                 ,
                                                         v_por_pag_minimo    ,
                                                         v_mto_min_pag_minimo,
                                                         v_mto_fij_pag_minimo,
                                                         v_tas_int_corriente ,
                                                         v_tas_mora          ,
                                                         v_tas_int_compra    ,
                                                         'P'                 ,
                                                         v_tas_int_mora      );
                     EXCEPTION
                        WHEN OTHERS THEN
                           IF SQLCODE <= -20000 THEN
                              RAISE;
                           ELSE
                              raise_application_error(-20550,
                                                      'No se pudo insertar las novedades de tarjetas ' ||
                                                       SQLERRM);
                           END IF;
                     END;
                  END IF;
               EXCEPTION
                  WHEN OTHERS THEN
                     IF SQLCODE <= -20000 THEN
                        RAISE;
                     ELSE
                        raise_application_error(-20551,
                                                'No se pudo actualizar las novedades de tarjetas ' ||
                                                 SQLERRM);
                     END IF;
               END;
            END IF;
         END IF;
      END IF;
    END IF;
      -->17/05/2013-DI-MB: Modificado para Registrar la Fecha de Activación de las Cuentas de Tarjetas.
      /*IF :old.estado = 'C' AND :new.estado = 'N' THEN -- RE DE-1494 se comenta ya que la fecha activacion
         :new.fec_activacion := v_fec_actual;           -- se obtendra del archivo bancard.
      END IF;*/
      /*  ELSIF inserting THEN
      DECLARE
        v_es_bancard VARCHAR2(1);
        v_dir_envio  VARCHAR2(500);
      BEGIN
        BEGIN
          select 'S'
            into v_es_bancard
            from ta_tipos
           where cod_modulo = :new.cod_modulo
             and cod_modalidad = :new.cod_modalidad
             and cod_ent_procesadora = fug_obt_pardinamico( 'COD_PRO_BANCARD' )
             and (cod_oficina = :new.cod_oficina or cod_oficina is null);
        EXCEPTION
          when others then
            v_es_bancard := 'N';
        END;
        IF nvl( v_es_bancard, 'N' ) = 'S' THEN
          BEGIN
            select substr( decode( e.tip_envio, 'D', d.direccion||decode(numero,null,'',' '||numero) || ' - ' || c.descripcion, -- Direccion
                                                'C', 'CASILLERO: ' || e.referencia, -- Casillero
                                                'A', 'CASILLA DE CORREO: ' || e.referencia, -- Casilla de correo
                                                'R', 'RETENER EN '|| o.descripcion ), 1, 50 ) dir_envio
              into v_dir_envio
              from ge_cta_clientes l, ba_barrios b, ba_ciudades c, ba_paises p,
                   ba_direcciones d, ge_dir_retenciones o, ge_dir_envios e
             where p.cod_pais(+) = d.cod_pais
               and c.cod_pais(+) = d.cod_pais
               and c.cod_ciudad(+) = d.cod_ciudad
               and b.cod_pais(+) = d.cod_pais
               and b.cod_ciudad(+) = d.cod_ciudad
               and b.cod_barrio(+) = d.cod_barrio
               and d.cod_persona(+) = e.cod_persona
               and d.cod_direccion(+) = e.referencia
               and o.cod_dir_retencion(+) = e.referencia
               and l.nro_cuenta = :new.nro_cuenta
               and l.cod_persona = e.cod_persona
               and l.relacion = 'P'
               and rownum = 1;
          EXCEPTION
            when others then
              v_dir_envio := NULL;
          END;
          IF nvl( length( v_dir_envio ), 0 ) > 35 THEN
            BEGIN
              insert into ta_cta_tarjetas_nov( nro_cuenta,
                                               fecha,
                                               dir_envio,
                                               enviado )
                                       values( :new.nro_cuenta,
                                               pag_cal.fu_obt_fec_actual(6),
                                               v_dir_envio,
                                               'N' );
            EXCEPTION
              when others then
                IF sqlcode <= -20000 THEN
                  RAISE;
                ELSE
                  RAISE_APPLICATION_ERROR( -20552, 'No se pudo insertar la dirección extendida para las novedades de tarjetas ' || sqlerrm );
                END IF;
            END;
          END IF;
        END IF;
      END;*/
   END IF;
END;
/