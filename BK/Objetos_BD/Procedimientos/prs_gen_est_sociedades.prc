CREATE OR REPLACE PROCEDURE IT.prs_gen_est_sociedades IS

  v_fec_trimestre     ge_calendarios.fec_actual%type;
  v_mes_fin_trimestre ge_calendarios.mes_fin_trimestre%type;
  v_lugar             VARCHAR2(250);
  v_saldo             ge_cuentas.sal_contable%type;
  v_moneda            ge_cuentas.cod_moneda%type;
  v_mon_local         ba_monedas.cod_moneda%type;
  v_tipo              ge_modalidades.tipo%type;
  v_cliente           ba_personas.cod_persona%type;
  v_cta_activa        varchar2(1);
  v_tot_loc_activo    ge_cuentas.sal_contable%type;
  v_tot_ext_activo    ge_cuentas.sal_contable%type;
  v_tot_loc_pasivo    ge_cuentas.sal_contable%type;
  v_tot_ext_pasivo    ge_cuentas.sal_contable%type;
  v_mto_prestamo      pr_cta_prestamos.sal_cap_batch%type;
  v_mto_loc_prestamo  pr_cta_prestamos.sal_cap_batch%type;
  v_mto_ext_prestamo  pr_cta_prestamos.sal_cap_batch%type;
  v_saldo_loc         ge_cuentas.sal_contable%type;
  v_saldo_ext         ge_cuentas.sal_contable%type;
  v_cod_persona       ba_personas.cod_persona%type := FUG_OBT_PER_ENTIDAD;

  CURSOR sociedades IS
     -- Sociedades con acciones y productos activos --
    SELECT t.cod_persona, DECODE(T.VAL_PARAMETRO,'S','TP','TN') Acciones
     FROM BA_PER_DAT_ADICIONALES T, BA_PERSONAS P
    WHERE T.COD_PERSONA = P.COD_PERSONA
      AND T.PARAMETRO = 'ACC_PORTADOR' 
      AND P.TIPO = 'J'
      AND T.VAL_PARAMETRO IS NOT NULL
      AND T.COD_PERSONA <> v_cod_persona
      AND FUG_ES_CLIENTE(T.COD_PERSONA) = 'S'
    ORDER BY 2,1; 

 
  CURSOR cuentas IS
         select cc.nro_cuenta,
                cc.cod_persona,
                cc.cod_modulo,
                cc.cod_modalidad,
                c.estado,
                c.sal_contable,
                c.cod_moneda,
                fug_obt_contingencia(c.nro_cuenta) contingencia
           from ge_est_cuentas es,
                ba_modulos mo,
                ge_modalidades ma,
                ge_cuentas c,
                ge_cta_clientes cc,
                ge_clientes cl,
                ge_sub_modalidades gg
          where es.cod_modulo(+) = c.cod_modulo
            and es.cod_modalidad(+) = c.cod_modalidad
            and es.estado(+) = c.estado
            and nvl( es.activo, 'S' ) = nvl(v_cta_activa, 'S')
            and ma.cod_modalidad = cc.cod_modalidad
            and ma.cod_modulo = cc.cod_modulo
            and ma.cod_modalidad not in(36,70) -- modalidad de bonos subordinados WA:04/04 se incluye Limite de Cambios
            and mo.cod_modulo = cc.cod_modulo
            and c.cod_modulo = cc.cod_modulo
            and c.cod_modalidad = cc.cod_modalidad
            and gg.cod_modulo(+)= c.cod_modulo
            and gg.cod_modalidad(+)= c.cod_modalidad
            and gg.cod_sub_modalidad(+) = c.cod_sub_modalidad
            and c.nro_cuenta = cc.nro_cuenta
            and cc.cod_persona = v_cliente
            and cl.cod_persona = v_cliente
union all
         select null,
                cc.cod_persona,
                cc.cod_modulo,
                cc.cod_modalidad,
                aht.estado,
                aht.capital,
                c.cod_moneda,
                fug_obt_contingencia(c.nro_cuenta) contingencia
           from ge_est_cuentas es,
                ba_modulos mo,
                ge_modalidades ma,
                ge_cuentas c,
                ge_cta_clientes cc,
                ge_clientes cl,
                AH_CTA_CERTIFICADOS AH,
                AH_TITULOS AHT,
                ge_sub_modalidades gg
          where es.cod_modulo(+) = c.cod_modulo
            and es.cod_modalidad(+) = c.cod_modalidad
            and es.estado(+) = c.estado
            and nvl( es.activo, 'S' ) = nvl(v_cta_activa, 'S')
            and ma.cod_modalidad = cc.cod_modalidad
            and ma.cod_modalidad = 36 -- modalidad de bonos subordinados
            and ma.cod_modulo   = cc.cod_modulo
            and mo.cod_modulo   = cc.cod_modulo
            and c.cod_modulo    = cc.cod_modulo
            and c.cod_modalidad = cc.cod_modalidad
            and c.nro_cuenta    = cc.nro_cuenta
            and cc.cod_persona  = v_cliente
            and cl.cod_persona  = v_cliente
            and gg.cod_modulo(+)= c.cod_modulo
            and gg.cod_modalidad(+)= c.cod_modalidad
            and gg.cod_sub_modalidad(+) = c.cod_sub_modalidad
            AND AH.NRO_CUENTA    = CC.NRO_CUENTA
            AND AH.NRO_CUENTA    = C.NRO_CUENTA
            AND AH.COD_MODULO    = ES.COD_MODULO
            AND AH.COD_MODALIDAD = ES.COD_MODALIDAD
            AND AHT.ESTADO       = ES.ESTADO
            AND AH.SER_TITULO    = AHT.SERIE
            AND AH.NRO_TITULO    = AHT.NRO_TITULO
   group by cc.cod_persona, cc.cod_oficina, cc.cod_modulo, cc.cod_modalidad, cc.relacion,
            mo.descripcion , fue_obt_titulo(ma.descripcion) , aht.estado,
            aht.capital, c.cod_moneda,
            c.fec_apertura,c.fec_cam_estado,c.cod_tasa, to_date(to_char(c.fec_insercion,'dd/mm/yyyy'),'dd/mm/yyyy'), c.tas_personalizada, -- c.val_tasa,
            es.descripcion, c.dia_atraso, c.max_atraso, c.pro_atraso, c.mto_mora, aht.capital,
            c.en_juicio, c.fec_juicio, c.cod_ent_juicio,
            decode(c.val_tasa, null, decode(c.cod_tasa, null, null, fug_obt_val_tasa( c.cod_modulo,
                                       c.cod_modalidad,
                                       c.cod_oficina,
                                       c.nro_cuenta,
                                       c.cod_moneda,
                                       c.sal_contable,
                                       c.tas_personalizada,
                                       c.cod_tasa,
                                       null,
                                       pae_cnf.fu_obt_fec_actual(nvl(cc.cod_modulo, 1)) ))),
                                       fug_obt_contingencia(c.nro_cuenta) ,
                                       cl.cat_riesgo,
                                       cl.cat_sistema,
                                       cl.fec_ult_clasif,
                                       cl.tot_deu_sistema,ah.nro_titulo,
                                       c.cod_sub_modalidad,
                                       fue_obt_titulo(gg.descripcion)
 union all
         select cc.nro_cuenta,
                cc.cod_persona,
                cc.cod_modulo,
                cc.cod_modalidad,
                c.estado,
                w.mto_utilizado ,--c.sal_contable,
                c.cod_moneda,
                fug_obt_contingencia(c.nro_cuenta) contingencia
           from ge_est_cuentas es,
                ba_modulos mo,
                ge_modalidades ma,
                ge_cuentas c,
                ge_cta_clientes cc,
                ge_clientes cl,
                ge_sub_modalidades gg,
                lc_cta_cambios w
          where es.cod_modulo(+) = c.cod_modulo
            and es.cod_modalidad(+) = c.cod_modalidad
            and es.estado(+) = c.estado
            and nvl( es.activo, 'S' ) = nvl(v_cta_activa, 'S')
            and ma.cod_modalidad = cc.cod_modalidad
            and ma.cod_modulo = cc.cod_modulo
            and ma.cod_modalidad =70 --Solo incluye Limite de Cambios
            and mo.cod_modulo = cc.cod_modulo
            and c.cod_modulo = cc.cod_modulo
            and c.cod_modalidad = cc.cod_modalidad
            and gg.cod_modulo(+)= c.cod_modulo
            and gg.cod_modalidad(+)= c.cod_modalidad
            and gg.cod_sub_modalidad(+) = c.cod_sub_modalidad
            and c.nro_cuenta = cc.nro_cuenta
            and c.nro_cuenta= w.nro_cuenta
            and cc.cod_persona = v_cliente
            and cl.cod_persona = v_cliente
        order by 4,5;

BEGIN
-- Inicio de Procesos --
 v_fec_trimestre := pae_cnf.fu_obt_fec_actual(1); -- Hallamos la fecha del modulo 1 (general)  
  
-- Final de trimestre --
 begin
   select distinct lpad(a.mes_fin_trimestre,2,0)
     into v_mes_fin_trimestre
     from ge_calendarios a
    where a.fec_actual = v_fec_trimestre;
 exception
   when others then
     v_lugar := 'Error buscando mes final de trimestre. ';
     RAISE_APPLICATION_ERROR(-20002,v_lugar||' '||SQLERRM);
 end;
-- Moneda Local --
v_mon_local := pag_gen.fu_obt_mon_local; 
 --------------------------------------------------------------------------  
 -- Si la fecha coincide con el final de trimestre se debe generar datos --
 IF to_char(v_fec_trimestre,'MM') = v_mes_fin_trimestre THEN
 
    FOR soc IN sociedades LOOP  
      
      v_cliente    := soc.cod_persona;
      v_cta_activa := 'S'; -- Cuentas Activas

      v_tot_loc_activo := 0;
      v_tot_ext_activo := 0;
      v_tot_loc_pasivo := 0;
      v_tot_ext_pasivo := 0;
      v_mto_loc_prestamo := 0;
      v_mto_ext_prestamo := 0;

      FOR cta IN cuentas  LOOP 
        v_moneda               := cta.cod_moneda;
        v_saldo                := cta.sal_contable;
        v_saldo_loc            := 0;
        v_saldo_ext            := 0;
        --
        IF v_mon_local = v_moneda THEN
          v_saldo_loc := v_saldo;
        ELSE
          IF v_moneda = 'USD' THEN
             v_saldo_ext := v_saldo;
          ELSE
             v_saldo_ext := pag_gen.fu_con_mon_a_moneda(v_moneda,'USD',v_saldo);
          END IF;
        END IF;

         IF cta.cod_modulo = 5 and v_saldo > 0 then
           IF v_mon_local = v_moneda THEN
             v_tot_loc_activo := v_tot_loc_activo + v_saldo_loc;
           ELSE
             v_tot_ext_activo := v_tot_ext_activo + v_saldo_ext;
           END IF;
           ----
        ELSIF cta.cod_modulo = 6 then
          
          begin
            select nvl(p.sal_cap_batch,0)
              into v_mto_prestamo
              from pr_cta_prestamos p
             where p.nro_cuenta = cta.nro_cuenta;
          exception
            when no_data_found then
              v_mto_prestamo := 0; 
            when others then
              v_lugar := 'Error buscando monto prestamo. ';
              RAISE_APPLICATION_ERROR(-20002,v_lugar||' '||SQLERRM);
          end;
           
          --v_tot_activo := v_tot_activo + v_saldo_loc;
          IF v_mon_local = v_moneda THEN
             v_tot_loc_activo := v_tot_loc_activo + v_saldo_loc;
             v_mto_loc_prestamo := v_mto_loc_prestamo + v_mto_prestamo;
             
             --BSEVOCORE-880 Modificar Informe Estadístico de Sociedades - Criterio GNBPY (ALV)
             v_lugar := 'Actualizar en la tabla de Detalle - Local. ';
             begin
               update sb_est_sociedades_det d
                  set d.mto_loc_prestamo = v_mto_prestamo
                where d.fecha = v_fec_trimestre
                  and d.cod_persona = v_cliente
                  and d.nro_cuenta = cta.nro_cuenta;
                
               If SQL%NOTFOUND then
                  --Insertar en la tabla de Detalle
                  insert into sb_est_sociedades_det
                   (fecha,
                    cod_persona,
                    nro_cuenta,
                    mto_loc_prestamo,
                    mto_ext_prestamo)
                 values
                   (v_fec_trimestre,
                    v_cliente,
                    cta.nro_cuenta,
                    v_mto_prestamo,
                    null);
               end if;
             end;
             --Fin BSEVOCORE-880 
           ELSE
             v_tot_ext_activo := v_tot_ext_activo + v_saldo_ext;
             v_mto_ext_prestamo := v_mto_ext_prestamo + v_mto_prestamo;
             
             --BSEVOCORE-880 Modificar Informe Estadístico de Sociedades - Criterio GNBPY (ALV)
             v_lugar := 'Actualizar en la tabla de Detalle - Extranjera. ';
             begin
               update sb_est_sociedades_det d
                  set d.mto_loc_prestamo = v_mto_prestamo
                where d.fecha = v_fec_trimestre
                  and d.cod_persona = v_cliente
                  and d.nro_cuenta = cta.nro_cuenta;
                
               If SQL%NOTFOUND then
                  --Insertar en la tabla de Detalle
                  insert into sb_est_sociedades_det
                   (fecha,
                    cod_persona,
                    nro_cuenta,
                    mto_loc_prestamo,
                    mto_ext_prestamo)
                 values
                   (v_fec_trimestre,
                    v_cliente,
                    cta.nro_cuenta,
                    null,
                    v_mto_prestamo);
               end if;
             end;
             --Fin BSEVOCORE-880
           END IF;
           
        ELSIF cta.cod_modulo = 7 then
          --v_tot_activo := v_tot_activo + v_saldo_loc;
          IF v_mon_local = v_moneda THEN
            v_tot_loc_activo := v_tot_loc_activo + v_saldo_loc;
          ELSE
            v_tot_ext_activo := v_tot_ext_activo + v_saldo_ext;
          END IF;

        ELSIF cta.cod_modulo = 8 then
          --v_tot_activo := v_tot_activo + v_saldo_loc;
          IF v_mon_local = v_moneda THEN
            v_tot_loc_activo := v_tot_loc_activo + v_saldo_loc;
          ELSE
            v_tot_ext_activo := v_tot_ext_activo + v_saldo_ext;
          END IF;

        ELSIF (cta.cod_modulo = 3) THEN --or (cta.cod_modulo = 10 and cta.cod_modalidad = 145)  THEN
         -- v_tot_pasivo := v_tot_pasivo + v_saldo_loc;
          IF v_mon_local = v_moneda THEN
            v_tot_loc_pasivo := v_tot_loc_pasivo + v_saldo_loc;
          ELSE
            v_tot_ext_pasivo := v_tot_ext_pasivo + v_saldo_ext;
          END IF;

        ELSIF cta.cod_modulo = 15 THEN
          --v_tot_activo :=  round(v_tot_activo + v_saldo_loc);
          IF v_mon_local = v_moneda THEN
            v_tot_loc_activo := round(v_tot_loc_activo + v_saldo_loc);
          ELSE
            v_tot_ext_activo := round(v_tot_ext_activo + v_saldo_ext);
          END IF;

        ELSIF cta.cod_modulo = 10 THEN
             Begin
                select nvl(a.tipo, 'X')
                  into v_tipo
                  from ge_modalidades a
                 Where a.cod_modulo = cta.cod_modulo
                   and a.cod_modalidad = cta.cod_modalidad;
             Exception
                When others then
                   v_lugar := 'Error buscando sector contable para el producto. ';
                   RAISE_APPLICATION_ERROR(-20002,v_lugar||' '||SQLERRM);
             End;

             --> A=> Activo, P=> Pasivo, C=> Contingencia, I=> Indistinto
             If v_tipo in ('A', 'C', 'I') then
                --v_tot_activo := round(v_tot_activo + v_saldo_loc);
                IF v_mon_local = v_moneda THEN
                  v_tot_loc_activo := round(v_tot_loc_activo + v_saldo_loc);
                ELSE
                  v_tot_ext_activo := round(v_tot_ext_activo + v_saldo_ext);
                END IF;

             Elsif v_tipo in ('X') then
                 null;

             Else
                 --v_tot_pasivo := round(v_tot_pasivo + v_saldo_loc);
                 IF v_mon_local = v_moneda THEN
                   v_tot_loc_pasivo := round(v_tot_loc_pasivo + v_saldo_loc);
                 ELSE
                   v_tot_ext_pasivo := round(v_tot_ext_pasivo + v_saldo_ext);
                 END IF;

             End If;

        ELSIF cta.cod_modulo = 4 THEN
          IF v_saldo < 0 THEN -- Sobregiro
            --v_tot_activo := v_tot_activo + (v_saldo_loc *-1);
            IF v_mon_local = v_moneda THEN
              v_tot_loc_activo := v_tot_loc_activo + (v_saldo_loc *-1);
            ELSE
              v_tot_ext_activo := v_tot_ext_activo + (v_saldo_ext *-1);
            END IF;

          ELSE
            --v_tot_pasivo := v_tot_pasivo + v_saldo_loc;
            IF v_mon_local = v_moneda THEN
              v_tot_loc_pasivo := v_tot_loc_pasivo + v_saldo_loc;
            ELSE
              v_tot_ext_pasivo := v_tot_ext_pasivo + v_saldo_ext;
            END IF;

          END IF;

        END IF;


      END LOOP;
      
      -- Insertamos en la tabla de estadisticas --
      begin       
        update sb_est_sociedades s
           set s.pos_loc_activo   = nvl(s.pos_loc_activo,0) + v_tot_loc_activo,
               s.pos_ext_activo   = nvl(s.pos_ext_activo,0) + v_tot_ext_activo,
               s.pos_loc_pasivo   = nvl(s.pos_loc_pasivo,0) + v_tot_loc_pasivo,
               s.pos_ext_pasivo   = nvl(s.pos_ext_pasivo,0) + v_tot_ext_pasivo,
               s.mod_loc_prestamo = nvl(s.mod_loc_prestamo,0) + v_mto_loc_prestamo,
               s.mod_ext_prestamo = nvl(s.mod_ext_prestamo,0) + v_mto_ext_prestamo
         where s.fecha = v_fec_trimestre
           and s.cod_persona = v_cliente
           and s.tip_accion = soc.acciones;
           
         If SQL%NOTFOUND then
            begin
                 insert into sb_est_sociedades
                         (fecha, cod_persona, tip_accion, pos_loc_activo, pos_ext_activo, 
                          pos_loc_pasivo, pos_ext_pasivo, mod_loc_prestamo, mod_ext_prestamo)
                 values (v_fec_trimestre, v_cliente, soc.acciones, v_tot_loc_activo, v_tot_ext_activo, 
                         v_tot_loc_pasivo, v_tot_ext_pasivo, v_mto_loc_prestamo, v_mto_ext_prestamo);
             exception
               when others then 
                  v_lugar := 'Error al insertar en sb_est_sociedades. ';
                  RAISE_APPLICATION_ERROR(-20002,v_lugar||' '||SQLERRM);
             end;
         end if;
           
      exception       
        when others then
          v_lugar := 'Error al modificar montos en sb_est_sociedades. ';
          RAISE_APPLICATION_ERROR(-20002,v_lugar||' '||SQLERRM);
      end;         

    END LOOP;

 END IF;

EXCEPTION
  when no_data_found then
    v_lugar := 'Error. no existen datos en ';
    RAISE_APPLICATION_ERROR(-20002,v_lugar||' '||SQLERRM);
    
  when too_many_rows then
    v_lugar := 'Error. existen varios registros en ';
    RAISE_APPLICATION_ERROR(-20002,v_lugar||' '||SQLERRM);

  when others then
    v_lugar := 'Error lugar ';
    RAISE_APPLICATION_ERROR(-20002,v_lugar||' '||SQLERRM);

END prs_gen_est_sociedades;
/

