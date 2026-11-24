create or replace procedure it.PRG_ACT_DAT_AUT_USUARIOS is
  -- DE-2107- Actualización diaria de la tabla GE_CTA_AUT_USUARIOS - DYD-SDSL-3257
   v_py_autorizador     ba_usuarios.cod_usuario%type;        -- Código Usuario Autorizador
   v_fec_autorizacion   date;                                -- Fecha Autorizacion
   v_nro_linea          pr_cta_prestamos.nro_linea%type;     -- Nro Linea
   v_nro_sol_linea      ta_solicitudes.nro_solicitud%type;   -- Nro Solicitud
   v_cta_inicial        pr_cta_prestamos.nro_cuenta%type;    -- Nro de cuenta prestamo ó tarjeta
   v_fec_ini_pt         date;                                -- Fecha inicio del prestamo ó tarjeta
   v_fec_vencimiento    date;                                -- Fecha vencimiento del prestamo
   v_tiene_sobregiro    VARCHAR2(1);                         -- Indicador si la cuenta tiene habilitado sobregiro
   v_cta_ori_cta_cte    ov_cta_vencidas.nro_cta_origen%type; -- Variable para almacenar la cta origen de operaciones vencidas
   v_fec_pos_linea      VARCHAR2(1);                         -- Variable para verificar las fechas entre fecha de aprobacion del prestamo y fecha de aprobacion de linea. Valores posible 'S','N'
--------
   v_cta_origen        ta_cta_tarjetas.nro_cuenta%type;
   v_campana_origen    pr_solicitudes.cod_campana%type;
   v_campana           pr_solicitudes.cod_campana%type;
   v_fec_ini_origen    ta_cta_tarjetas.fec_apertura%type;
   v_usu_promotor      pr_solicitudes.cod_usu_promotor%type;
   v_canal             pr_solicitudes.cod_canal%type;
   v_des_canal         ge_canales.descripcion%type;
   v_cta_cte           cc_cta_corrientes.nro_cuenta%type; --- modulo 4
   -- DE-2594 PyR NAF JUN/2017
   v_cod_usu_apr_cuenta ba_usuarios.cod_usuario%type;
   v_nom_usu_apr_cuenta ba_usuarios.nombre%type;
   v_fec_apr_cuenta     pr_solicitudes.fec_aprobacion%type;
   v_cta_tar_original   ta_cta_tarjetas.nro_cuenta%type;
CURSOR C_CUENTAS IS
     select o.cod_modulo, o.cod_persona riesgo,
            e.cod_oficina ofi,
           e.cod_usu_oficial,  e.tipo,
           o.cod_modalidad, o.nro_cuenta,o.cod_moneda, o.cod_estado,
           s.cod_sub_modalidad,  s.cod_campana, s.mto_capital CAPITAL_INICIAL,
           e.cod_seg_cliente, s.nro_solicitud , s.cod_canal canal_prestamo
    from ge_cla_operaciones o, ge_clientes e, pr_cta_prestamos s
    where o.cod_persona=e.cod_persona
    and o.nro_cuenta = s.nro_cuenta(+)
    and not exists( select 1 from GE_CTA_AUT_USUARIOS u where u.nro_cuenta=o.nro_cuenta); -- DE-2594 omite ctas existentes
--------
  function fu_ver_cta_aut_usuarios( -- verificamos que no esté insertado en la tabla ge_cta_aut_usuarios
                            p_nro_cuenta   in ge_cuentas.nro_cuenta%type,
                            p_cod_modulo   in ge_cuentas.cod_modulo%type,
                            p_cod_modalidad ge_cuentas.cod_modalidad%type default null)
    return boolean is
    v_existe varchar2(1);
  begin
    begin
      select 'S'
        into v_existe
        from ge_cta_aut_usuarios  a
       where a.nro_cuenta    = p_nro_cuenta
         and a.cod_modulo    = nvl(p_cod_modulo, a.cod_modulo)
         and a.cod_modalidad = nvl(p_cod_modalidad, a.cod_modalidad) ;
    exception
      when others then
        v_existe := 'N';
    end;
    if v_existe = 'S' then
      return(true);
    else
      return(false);
    end if;
  end fu_ver_cta_aut_usuarios;
-------
 FUNCTION fl_obt_cta_inicial (p_nro_cta VARCHAR2) RETURN VARCHAR2 IS
   CURSOR cur_cuentas IS
     SELECT a.nro_cuenta, LEVEL nivel
       FROM pr_cta_prestamos a
     START WITH a.nro_cuenta = p_nro_cta -- cta vigente
     CONNECT BY PRIOR a.nro_cuenta = a.nro_cta_renovada
     ORDER BY nivel ASC;
   v_nivel NUMBER(2);
   v_cta_ini pr_cta_prestamos.nro_cuenta%TYPE;
  BEGIN
    v_nivel := 0;
    FOR reg_cta IN cur_cuentas LOOP
     IF reg_cta.nivel >= v_nivel THEN
        v_cta_ini := reg_cta.nro_cuenta;
        v_nivel := reg_cta.nivel;
     END IF;
    END LOOP;
    RETURN v_cta_ini;
  EXCEPTION
     WHEN OTHERS THEN
      v_cta_ini := p_nro_cta;
      RETURN v_cta_ini;
  END;

------------- PROCESO PRINCIPAL ------------------------------------------
begin
FOR REC IN C_CUENTAS LOOP

  v_py_autorizador   :=NULL;
  v_fec_autorizacion :=NULL;
  v_nro_linea        := NULL;
  v_nro_sol_linea    :=NULL;
  v_campana          :=NULL;
  v_campana_origen   :=NULL;
  v_cta_cte          :=NULL;
  -- DE-2594 PyR NAF JUN/2017
  v_cod_usu_apr_cuenta :=NULL;
  v_nom_usu_apr_cuenta :=NULL;
  v_fec_apr_cuenta     :=NULL;
  v_cta_tar_original   :=NULL;
  v_cta_origen         :=NULL;
  v_cta_inicial        :=NULL;
  v_fec_ini_pt         :=NULL;
---
     IF REC.COD_MODULO IN (5,6,15) or (REC.COD_MODULO = 4 and REC.COD_MODALIDAD = 41)  THEN
       -- ver si tiene cuenta madre(inicial)
       IF REC.COD_MODULO = 6 THEN
          v_cta_inicial := fl_obt_cta_inicial(rec.nro_cuenta);
       --- DE-2449 08/2016
          if v_cta_inicial <> rec.nro_cuenta then ---es RRR
            v_cta_origen := v_cta_inicial;
            begin
               select e.fec_inicio, e.cod_campana into v_fec_ini_origen, v_campana_origen
                from pr_cta_prestamos e where
                e.nro_cuenta = v_cta_inicial;
            exception
              when others then
               v_cta_origen     := null;
               v_fec_ini_origen := null;
               v_campana_origen := null;
            end;
          end if;
          ---
          -- DE-2594 PyR NAF JUN/2017 - Se agrega usuario aprobador a estado L de la cuenta actual
          -- se utiliza lógica proporcionada por GUSTAVO EULALIO FERNANDEZ ROA
          BEGIN 
             SELECT g.cod_usuario,
                    u.nombre,
                    g.fecha
               INTO v_cod_usu_apr_cuenta,
                    v_nom_usu_apr_cuenta,
                    v_fec_apr_cuenta
               FROM pr_cta_prestamos p
                    left join pr_sol_gestiones g on g.nro_solicitud = p.nro_solicitud
                    left join ba_usuarios u on g.cod_usuario = u.cod_usuario
              WHERE p.nro_cuenta = rec.nro_cuenta
                AND g.estado = 'L'
                AND g.fecha = (SELECT min(fecha)
                                 FROM pr_sol_gestiones s
                                WHERE s.nro_solicitud = p.nro_solicitud
                                  AND s.estado = 'L'
                                  AND s.fecha >= (select max(t.fecha)
                                                 from pr_sol_gestiones t
                                                 where t.estado='S'
                                                 and t.nro_solicitud=p.nro_solicitud));
          EXCEPTION
             WHEN OTHERS THEN
                v_cod_usu_apr_cuenta :=NULL;
                v_nom_usu_apr_cuenta :=NULL;
                v_fec_apr_cuenta     :=NULL;
          END;
          --
       ELSIF REC.COD_MODULO = 5 OR (REC.COD_MODULO = '15' AND rec.cod_modalidad = '151' )THEN --operaciones vencidas mod=15 and mad=151
          IF rec.cod_modulo = 5 THEN
             v_cta_inicial := rec.nro_cuenta;
             v_cta_tar_original := rec.nro_cuenta;-- DE-2594
          ELSE
             v_cta_inicial := v_cta_origen;
             -- DE-2594 PyR JUN/2017 NAF: recupera cta de tc original
             BEGIN
               select v.nro_cta_origen
               into v_cta_tar_original
               from ov_cta_vencidas v
               where v.nro_cuenta =  rec.nro_cuenta;
             EXCEPTION
                 WHEN OTHERS THEN
                      v_cta_tar_original := null;
             END;	
          END IF;
          -- DE-2594 PyR JUN/2017 NAF: recupera aprobador de tc original
          BEGIN
             select g.cod_usuario,
                   u.nombre,
                   g.fecha
              into  v_cod_usu_apr_cuenta,
                    v_nom_usu_apr_cuenta,
                    v_fec_apr_cuenta
             from ta_cta_tarjetas t
             left join ta_sol_gestiones g on g.nro_solicitud = t.nro_solicitud
             left join ba_usuarios u on g.cod_usuario = u.cod_usuario
             where t.nro_cuenta = v_cta_tar_original
             and g.cod_estado = 'APR'
             and g.fec_insercion = (select max(fec_insercion)
                                    from ta_sol_gestiones
                                     where nro_solicitud = t.nro_solicitud
                                     and cod_estado = 'APR');
          EXCEPTION
              WHEN OTHERS THEN
                    v_cod_usu_apr_cuenta := null;
                    v_nom_usu_apr_cuenta := null;
                    v_fec_apr_cuenta := null;
          END;          
       END IF;
       BEGIN
         SELECT u.usu_autorizador, u.fec_autorizacion, u.nro_linea, u.nro_solicitud
           INTO v_py_autorizador, v_fec_autorizacion, v_nro_linea,  v_nro_sol_linea
           FROM ge_cta_aut_usuarios u
          WHERE u.nro_cuenta = v_cta_inicial
            AND u.cod_modulo = nvl(rec.cod_modulo, u.cod_modulo)
            AND u.cod_modalidad = nvl(rec.cod_modalidad, u.cod_modalidad);
       EXCEPTION
           WHEN NO_DATA_FOUND THEN
             BEGIN
               SELECT u.usu_autorizador, u.fec_autorizacion, u.nro_linea, u.nro_solicitud
                 INTO v_py_autorizador, v_fec_autorizacion, v_nro_linea,  v_nro_sol_linea
                 FROM ge_cta_aut_usuarios u
                WHERE u.nro_cuenta = rec.nro_cuenta
                  AND u.cod_modulo = nvl(rec.cod_modulo, u.cod_modulo)
                  AND u.cod_modalidad = nvl(rec.cod_modalidad, u.cod_modalidad);
             EXCEPTION
                 WHEN OTHERS THEN
                  NULL;
             END;
           WHEN OTHERS THEN
            NULL;
       END;
       IF v_py_autorizador IS NULL THEN
         IF REC.COD_MODULO = 6 THEN --PRESTAMOS
           BEGIN--obtiene el nro de solicitud  y fecha inicio de prestamo
             SELECT nvl(v_nro_sol_linea,s.nro_solicitud), s.fec_inicio
               INTO v_nro_sol_linea, v_fec_ini_pt
               FROM pr_cta_prestamos s
              WHERE s.nro_cuenta = nvl(v_cta_inicial,rec.nro_cuenta)
                AND s.nro_solicitud IS NOT NULL;
           EXCEPTION
             WHEN OTHERS THEN
               NULL;
           END;
         ELSIF REC.COD_MODULO = 5 OR (REC.COD_MODULO = '15' AND rec.cod_modalidad = '151' )THEN -- tarjetas mod=5 / --operaciones vencidas mod=15 and mad=151
           -- obtenemos nro de solicitud,fecha_activación de la tarjeta, campaña, promotor, canal
           begin
                select t.fec_apertura,
                       nvl(v_nro_sol_linea,t.nro_solicitud),
                       nvl(t.cod_campana,s.cod_campana),
                       nvl(t.cod_usu_promotor, s.cod_usu_promotor),
                       nvl(t.cod_canal,s.cod_canal), ca.descripcion
                  into v_fec_ini_origen,
                       v_nro_sol_linea,
                       v_campana_origen,
                       v_usu_promotor,
                       v_canal, v_des_canal
                  from ta_cta_tarjetas t, ta_solicitudes s, ge_canales ca
                 where t.cod_modulo = '5'
                   and t.nro_cuenta = nvl(v_cta_inicial,v_cta_origen)
                   AND t.nro_solicitud = s.nro_solicitud(+)
                   and s.cod_canal     = ca.cod_canal(+);
             exception
                  when others then
                     v_fec_ini_origen := null;
                     v_canal          := null;
                     v_des_canal      := 's/d';
                   end;
           -------------------------
--- modulo 4
         ELSIF rec.cod_modulo= 4 THEN
            BEGIN
              SELECT e.nro_cuenta
                 INTO v_cta_cte
                 FROM cc_cta_corrientes e
                 WHERE e.nro_cuenta = rec.nro_cuenta
                 AND e.acu_sobregiro = 'S';
            EXCEPTION
              WHEN OTHERS THEN
               v_cta_cte := NULL;
            END;

              IF v_cta_cte is not null THEN
                     --busco la linea
                     BEGIN
                       SELECT h.nro_linea, nvl(h.cod_usu_autoriza, h.usu_insercion), nvl(h.fec_inicio, h.fec_insercion)
                         INTO v_nro_linea, v_py_autorizador, v_fec_autorizacion
                         FROM cc_lin_sobregiros_his h
                        WHERE h.nro_cuenta = v_cta_cte;
 --                         AND h.nro_linea IS NOT NULL;
                     EXCEPTION
                       WHEN no_data_found THEN
                         BEGIN
                           SELECT h1.nro_linea, nvl(h1.cod_usu_autoriza, h1.usu_insercion), nvl(h1.fec_inicio, h1.fec_insercion)
                             INTO v_nro_linea, v_py_autorizador, v_fec_autorizacion
                             FROM cc_lin_sobregiros h1
                            WHERE h1.nro_cuenta = v_cta_cte;
--                             AND h1.nro_linea IS NOT NULL;
                         EXCEPTION
                           WHEN OTHERS THEN
                            NULL;
                         END;
                       WHEN OTHERS THEN
                         NULL;
                     END;
              END IF;
         END IF;
---- modulo 4
         END IF;
         --SI NO EXISTE EN LA TABLA GE_CTA_AUT_USUARIOS
         IF v_nro_linea IS NULL THEN
           --2do buscar de la tabla pr_lin_vin_productos_his donde se
           --registran las que no estan activas
           BEGIN
             SELECT a.cod_usuario, a.nro_linea
               INTO v_py_autorizador, v_nro_linea
               FROM pr_lin_vin_productos_his a
              WHERE a.nro_cuenta = nvl(v_cta_inicial,rec.nro_cuenta)
                AND a.fecha || a.hora = (SELECT MIN(a1.fecha || a1.hora)
                                             FROM pr_lin_vin_productos_his a1
                                            WHERE a1.nro_cuenta = a.nro_cuenta);
           EXCEPTION
             WHEN no_data_found THEN
               --3ro buscar de la tabla pr_lin_aplicaciones_his donde se encuentran los registros
               --historticos de las lineas aplicadas a una cuenta
               BEGIN
                  SELECT DISTINCT h.nro_linea
                       INTO v_nro_linea
                       FROM pr_lin_aplicaciones_his h
                      WHERE h.nro_cuenta = nvl(v_cta_inicial,rec.nro_cuenta)
                        AND h.fec_insercion =(SELECT MIN (h1.fec_insercion)
                                                FROM pr_lin_aplicaciones_his h1
                                               WHERE h1.nro_cuenta = h.nro_cuenta);
               EXCEPTION
                 WHEN no_data_found THEN
                   --4to buscar de la tabla pr_lin_aplicaciones donde se encuentran los registros
                   --de las lineas aplicadas a una cuenta
                   BEGIN
                      Select H.NRO_LINEA
                       INTO v_nro_linea
                       FROM pr_lin_aplicaciones h
                       Where H.NRO_CUENTA = NVL(V_CTA_INICIAL, REC.NRO_CUENTA)
                         And H.NRO_LINEA =(SELECT Min(H1.NRO_LINEA)
                                              FROM PR_LIN_APLICACIONES H1
                                             WHERE H1.NRO_CUENTA = H.NRO_CUENTA);
                   EXCEPTION
                     WHEN no_data_found THEN
                       --5to buscar en la tabla pr_cta_prestamos y ta_cta_tarjetas si tiene una linea asignada
                       BEGIN
                         IF REC.COD_MODULO = 6 THEN
                           --prestamos
                           SELECT p.nro_linea
                             INTO v_nro_linea
                             FROM pr_cta_prestamos p
                            WHERE p.nro_cuenta = nvl(v_cta_inicial,rec.nro_cuenta);
                         ELSIF REC.COD_MODULO = 5 OR (REC.COD_MODULO = '15' AND rec.cod_modalidad = '151' ) THEN
                           --tarjetas
                           SELECT t.nro_linea
                             INTO v_nro_linea
                             FROM ta_cta_tarjetas t
                            WHERE t.nro_cuenta = nvl(v_cta_inicial,rec.nro_cuenta);
                         END IF;
                       EXCEPTION
                         WHEN OTHERS THEN
                           NULL;
                       END;
                      WHEN OTHERS THEN
                       NULL;
                   END;
                WHEN OTHERS THEN
                 NULL;
               END;
              WHEN OTHERS THEN
                NULL;
           END;
         END IF;
         ---si hay linea
         IF v_nro_linea IS NOT NULL THEN
           BEGIN-- usu_insercion es el que aprobó
             SELECT nvl(l.usu_insercion, v_py_autorizador), nvl(l.fec_aprobacion,v_fec_autorizacion), nvl(l.fec_vencimiento,v_fec_vencimiento)
               INTO v_py_autorizador, v_fec_autorizacion, v_fec_vencimiento
               FROM pr_lineas_his l
              WHERE l.nro_linea = v_nro_linea
                AND l.estado = 'A' -- estado aprobado
                AND l.fec_insercion = (SELECT MIN(h.fec_insercion)
                                         FROM pr_lineas_his h
                                        WHERE h.nro_linea = l.nro_linea
                                          AND h.estado = 'A');
           EXCEPTION
             WHEN no_data_found THEN
               BEGIN-- usu_insercion es el que aprobó
                 SELECT nvl(l.usu_insercion, v_py_autorizador), nvl(l.fec_aprobacion,v_fec_autorizacion), nvl(l.fec_vencimiento,v_fec_vencimiento)
                   INTO v_py_autorizador, v_fec_autorizacion, v_fec_vencimiento
                   FROM pr_lineas l
                  WHERE l.nro_linea = v_nro_linea
                    AND l.estado = 'A'-- estado aprobado
                    AND l.fec_insercion = (SELECT MIN(h.fec_insercion)
                                             FROM pr_lineas h
                                            WHERE h.nro_linea = l.nro_linea
                                              AND h.estado = 'A');
               EXCEPTION
                 WHEN OTHERS THEN
                   NULL;
               END;
             WHEN OTHERS THEN
               NULL;
           END;
         END IF;
         -- si no tiene linea aplicada o el prestamo fue aprobado antes que la linea
         -- tambien verificar que la linea no haya vencido antes del otorgamiento del prestamo
        IF v_fec_ini_pt IS NOT NULL THEN
         IF  v_nro_linea IS NOT NULL THEN
             IF v_fec_ini_pt >= v_fec_autorizacion AND v_fec_ini_pt <= v_fec_vencimiento THEN
             v_fec_pos_linea := 'N';
             ELSIF v_fec_ini_pt > v_fec_autorizacion AND v_fec_ini_pt > v_fec_vencimiento THEN
               v_fec_pos_linea := 'S';
             ELSIF v_fec_ini_pt <  v_fec_autorizacion THEN
             v_fec_pos_linea := 'S';
             END IF;
           ELSE
             v_fec_pos_linea := 'S';
           END IF;
         ELSE
          if rec.cod_modulo <> 4 then
           v_fec_pos_linea := 'N';
           V_PY_AUTORIZADOR   := NULL;
           V_FEC_AUTORIZACION := NULL;
           V_NRO_LINEA        := NULL;
          end if;
         END IF;
         IF  v_fec_pos_linea = 'S' THEN
           --en caso que entre por diferencia de fecha
            if rec.cod_modulo <> 4 then
              v_nro_linea        := NULL;
              v_py_autorizador   := NULL;
            end if;

             IF rec.cod_modulo = 6 THEN
               v_fec_autorizacion := v_fec_ini_pt;
                 BEGIN -- obtenemos usuario autorizador que liquidó el prestamo
                   SELECT g.cod_usuario
                     INTO v_py_autorizador
                     FROM pr_sol_gestiones   g,
                          pr_solicitudes     p
                    WHERE p.nro_solicitud = g.nro_solicitud
                      AND g.nro_solicitud = v_nro_sol_linea
                      AND g.estado = 'L'
                      AND g.fecha = (SELECT MAX(g1.fecha)
                                       FROM pr_sol_gestiones g1,
                                            pr_solicitudes   p1
                                      WHERE p1.nro_solicitud = g1.nro_solicitud
                                        AND g1.nro_solicitud = g.nro_solicitud
                                        AND g1.estado = 'L');
                 EXCEPTION
                   WHEN OTHERS THEN
                     NULL;
                 END;
             ELSIF rec.cod_modulo = 5 OR (REC.COD_MODULO = '15' AND rec.cod_modalidad = '151' ) THEN
               v_fec_autorizacion := v_fec_ini_pt;
                 Begin
                   SELECT g.cod_usuario
                     INTO v_py_autorizador
                     FROM ta_sol_gestiones g,
                          ta_solicitudes   p
                    WHERE p.nro_solicitud = g.nro_solicitud
                      AND g.nro_solicitud = v_nro_sol_linea
                      AND g.cod_estado In ('APR')
                      AND g.fecha = (SELECT MAX(g1.fecha)
                                       FROM ta_sol_gestiones g1,
                                            ta_solicitudes   p1
                                      WHERE p1.nro_solicitud = g1.nro_solicitud
                                        AND g1.nro_solicitud = g.nro_solicitud
                                        AND g1.cod_estado In ('APR'));
                 Exception
                   When Others Then
                     NULL;
                 End;
             ELSIF rec.cod_modulo = '15' AND rec.cod_modalidad = 152 THEN
               --busca cta origen
                 BEGIN
                   SELECT v.nro_cta_origen
                     INTO v_cta_ori_cta_cte
                     FROM ov_cta_vencidas v
                    WHERE v.nro_cuenta = rec.nro_cuenta;
                 EXCEPTION
                   WHEN OTHERS THEN
                     v_cta_ori_cta_cte := NULL;
                 END;
                 --
                 --
                 IF v_cta_ori_cta_cte IS NOT NULL THEN
                   --verifica la si la cta tiene sobregiro y luego busca la linea
                   BEGIN
                     SELECT 'S'
                       INTO v_tiene_sobregiro
                       FROM cc_cta_corrientes T
                      WHERE T.NRO_CUENTA = v_cta_ori_cta_cte
                        AND T.ACU_SOBREGIRO = 'S';
                   EXCEPTION
                    WHEN OTHERS THEN
                      v_tiene_sobregiro := 'N';
                   END;
                   IF v_tiene_sobregiro = 'S' THEN
                     --busco la linea
                     BEGIN
                       SELECT h.nro_linea, nvl(h.cod_usu_autoriza, h.usu_insercion), nvl(h.fec_inicio, h.fec_insercion)
                         INTO v_nro_linea, v_py_autorizador, v_fec_autorizacion
                         FROM cc_lin_sobregiros_his h
                        WHERE h.nro_cuenta = v_cta_ori_cta_cte
                          AND h.nro_linea IS NOT NULL;
                     EXCEPTION
                       WHEN no_data_found THEN
                         BEGIN
                           SELECT h1.nro_linea, nvl(h1.cod_usu_autoriza, h1.usu_insercion), nvl(h1.fec_inicio, h1.fec_insercion)
                             INTO v_nro_linea, v_py_autorizador, v_fec_autorizacion
                             FROM cc_lin_sobregiros h1
                            WHERE h1.nro_cuenta = v_cta_ori_cta_cte
                             AND h1.nro_linea IS NOT NULL;
                         EXCEPTION
                           WHEN OTHERS THEN
                            NULL;
                         END;
                       WHEN OTHERS THEN
                         NULL;
                     END;
                   END IF;
                 END IF;
             END IF;
         END IF;
       END IF;

       IF v_py_autorizador IS NOT NULL or v_cod_usu_apr_cuenta IS NOT NULL THEN -- DE-2594
           if not fu_ver_cta_aut_usuarios(rec.nro_cuenta,rec.cod_modulo,rec.cod_modalidad) then
              insert into ge_cta_aut_usuarios
                (nro_cuenta,
                 cod_modulo,
                 cod_modalidad,
                 usu_autorizador,
                 fec_autorizacion,
                 nro_linea,
                 nro_solicitud,
                 campanha,
                 campanha_origen,
                 cod_usu_apr_cuenta,
                 nom_usu_apr_cuenta,
                 fec_apr_cuenta)
              values
                 (rec.nro_cuenta,
                  rec.cod_modulo,
                  rec.cod_modalidad,
                  v_py_autorizador,
                  v_fec_autorizacion,
                  v_nro_linea,
                  v_nro_sol_linea,
                  v_campana,
                  v_campana_origen,
                  v_cod_usu_apr_cuenta,
                  v_nom_usu_apr_cuenta,
                  v_fec_apr_cuenta);
                  
           end if;
----
       end if;

EXIT WHEN c_cuentas%NOTFOUND;
END LOOP;
-------------------------------------------------------------------------------
Exception
  when others then
      raise_application_error(-20005,'PRG_ACT_DAT_AUT_USUARIOS - ' || sqlerrm);
end PRG_ACT_DAT_AUT_USUARIOS;
/

