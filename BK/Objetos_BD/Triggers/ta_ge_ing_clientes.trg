CREATE OR REPLACE TRIGGER IT.ta_ge_ing_clientes
  AFTER UPDATE ON "IT"."GE_ING_CLIENTES"
  FOR EACH ROW
DECLARE
  v_monto_ing     number(18, 2);
  v_res_cir       number;
  v_nro_secuencia cr_inf_laborales.nro_secuencia%type;
  v_actual        varchar(1) := 'N';
  v_cod_modalidad ah_cta_vistas.cod_modalidad%type;
  ----
  r_batel      ba_telefonos%rowtype;

  PROCEDURE pr_cam_mod_limite IS
  BEGIN
    If fug_obt_paradicional(:new.nro_cuenta, 'CTA_CAM_MODALIDAD') is null Then
      -- Insercion de parametro para cambio de modalidad
      Begin
        insert into ge_cta_dat_adicionales
          (nro_cuenta, parametro, val_parametro)
        values
          (:new.nro_cuenta, 'CTA_CAM_MODALIDAD', '31');
      Exception
        when others then
          null;
      End;

    End if;

    -- cambio de modalidad
    pra_act_modalidad(:new.cod_persona,
                      :new.nro_cuenta,
                      334, --origen
                      31 --destino
                      );

    -- borramos el limite de credito
    delete from ge_cta_dat_adicionales
     where nro_cuenta = :new.nro_cuenta
       and parametro = 'LIM_CRE_TRANSACCIONES';

  EXCEPTION
    When others then
      null;
  END;

  FUNCTION fu_obt_val_tas(p_monto IN NUMBER, p_cod_tasa IN NUMBER)
    RETURN number IS
    --
    v_val_tasas Ge_Tas_Fechas.Val_Tasa%TYPE;
    --
  BEGIN
    SELECT val_tasa
      INTO v_val_tasas
      FROM ge_tas_fechas f1
     WHERE f1.cod_tasa = p_cod_tasa
       AND f1.cod_modalidad IS NULL
       AND f1.cod_modulo IS NULL
       AND f1.cod_moneda = pag_gen.FU_OBT_MON_LOCAL
       AND f1.cod_oficina IS NULL
       AND f1.nro_cuenta IS NULL
       AND (p_monto between f1.val_minimo and f1.val_maximo)
       AND f1.fec_vigencia =
           (SELECT MAX(fec_vigencia)
              FROM ge_tas_fechas f2
             WHERE f1.cod_tasa = f2.cod_tasa
               AND f2.cod_modalidad IS NULL
               AND f2.cod_modulo IS NULL
               AND f2.cod_moneda = pag_gen.FU_OBT_MON_LOCAL
               AND f2.cod_oficina IS NULL
               AND (p_monto between f2.val_minimo and f2.val_maximo)
               AND f2.fec_vigencia <= pag_cal.FU_OBT_FEC_ACTUAL(1)
               AND f2.nro_cuenta IS NULL);
    RETURN v_val_tasas;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20003, 'Error al obtener tasa ' || SQLERRM);
  END;

  PROCEDURE ge_ins_log(p_cod_registro IN NUMBER,
                       p_cod_persona  IN ba_personas.cod_persona%TYPE,
                       p_cod_error    IN NUMBER,
                       p_msj_error    IN VARCHAR2) IS
  BEGIN
    INSERT INTO ba_log_per_gen_ofe
      (cod_registro, cod_persona, cod_error, msj_error)
    VALUES
      (p_cod_registro, p_cod_persona, p_cod_error, p_msj_error);
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20001, 'Error al inserta log. ' || SQLERRM);
  END;

  PROCEDURE pr_ins_reg_ofe_per IS
    v_cod_error NUMBER;
    v_msj_error VARCHAR2(2000);
    --
    v_exi_ofe         VARCHAR2(1);
    v_cod_registro    NUMBER;
    v_fec_cancelacion DATE;
    v_fec_actual      DATE;
    v_can_meses       NUMBER;
    v_fec_nacimiento  DATE;
    v_edad            NUMBER;
    v_sal_min_vig     NUMBER;
    v_mto_min_pre     NUMBER;
    v_val_tas_lim     NUMBER;
    v_mto_ingreso     NUMBER;
    --
    v_par_mes_max NUMBER := fug_obt_pardinamico('GEN_CAN_MES_MAX'); --Crear parametro dinamico
    v_min_edad    NUMBER := fug_obt_pardinamico('GEN_EDAD_MIN'); --Crear parametro dinamico
    v_max_edad    NUMBER := fug_obt_pardinamico('GEN_EDAD_MAX'); --Crear parametro dinamico
    v_min_edad_inf    NUMBER := fug_obt_pardinamico('GEN_EDAD_MIN_INF'); --Crear parametro dinamico
    v_tasa        ge_tas_fechas.cod_tasa%TYPE := fug_obt_pardinamico('BAS_COD_TAS_CAL_LIM_PRE');
  BEGIN
    v_cod_error  := null;
    v_msj_error  := null;
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
    --
    BEGIN
      SELECT s_cod_reg_onb.nextval INTO v_cod_registro FROM dual;
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_error := 10;
        v_msj_error := 'No se encuentra la secuencia del registro.';
      WHEN OTHERS THEN
        v_cod_error := 11;
        v_msj_error := 'No se encuentra la secuencia del registro.';
    END;
    --
    IF nvl(v_cod_error, '000') = '000' THEN
      --
      BEGIN
        SELECT 'S'
          INTO v_exi_ofe
          FROM pr_pre_aprobados p
         WHERE p.cod_persona = :new.cod_persona
           AND p.estado in ('C', 'G');
      EXCEPTION
        WHEN no_data_found THEN
          v_exi_ofe := 'N';
        WHEN too_many_rows THEN
          v_exi_ofe := 'S';
        WHEN OTHERS THEN
          v_exi_ofe := 'N';
      END;
      --
      IF v_exi_ofe = 'S' THEN
        v_cod_error := 1;
        v_msj_error := 'Cliente ya cuenta con oferta de préstamo vigente.';
      END IF;
      --
      IF nvl(v_cod_error, '000') <> '000' THEN
        ge_ins_log(v_cod_registro,
                   :new.cod_persona,
                   v_cod_error,
                   v_msj_error);
      ELSE
        ---
        BEGIN
          SELECT max(p.fec_cancelacion)
            INTO v_fec_cancelacion
            FROM ge_cta_clientes cl, pr_cta_prestamos p
           WHERE cl.cod_modulo = p.cod_modulo
             AND cl.cod_modalidad = p.cod_modalidad
             AND cl.nro_cuenta = p.nro_cuenta
             AND cl.cod_persona = :new.cod_persona
             AND cl.relacion = 'P';
        EXCEPTION
          WHEN no_data_found THEN
            v_fec_cancelacion := null;
          WHEN OTHERS THEN
            v_fec_cancelacion := null;
        END;
        ----
        IF v_fec_cancelacion is not null THEN
          v_can_meses := FLOOR(MONTHS_BETWEEN(TRUNC(to_date(v_fec_actual,
                                                            'dd/mm/rrrr')),
                                              TRUNC(to_date(v_fec_cancelacion,
                                                            'dd/mm/rrrr'))));
          --
          IF v_can_meses <= v_par_mes_max THEN
            v_cod_error := 2;
            v_msj_error := 'Cliente Recurrente.';
          END IF;
        END IF;
        ---
        IF nvl(v_cod_error, '000') <> '000' THEN
          ge_ins_log(v_cod_registro,
                     :new.cod_persona,
                     v_cod_error,
                     v_msj_error);
        ELSE
          BEGIN
            SELECT f.fec_nacimiento
              INTO v_fec_nacimiento
              FROM ba_per_fisicas f
             WHERE f.cod_persona = :new.cod_persona;
          EXCEPTION
            WHEN no_data_found THEN
              v_fec_nacimiento := null;
            WHEN OTHERS THEN
              v_fec_nacimiento := null;
          END;
          --
          IF v_fec_nacimiento is not null THEN
            v_edad := floor(months_between(v_fec_actual, v_fec_nacimiento) / 12);
            --
            IF (v_edad < v_min_edad OR v_edad > v_max_edad) THEN
                v_cod_error := 4;
                v_msj_error := 'Cliente fuera del rango de edad definido.';
            END IF;
            IF v_edad  <= v_min_edad_inf AND :new.tip_ingreso = 4 THEN -- LOU IF v_edad  <= 21 AND :new.tip_ingreso = 4 THEN
                v_cod_error := 24;
                v_msj_error := 'Informal con edad inferior a 21';
            END IF;
          ELSE
            v_cod_error := 3;
            v_msj_error := 'Fecha de nacimiento no definida para la persona.';
          END IF;
          --
          IF nvl(v_cod_error, '000') <> '000' THEN
            ge_ins_log(v_cod_registro,
                       :new.cod_persona,
                       v_cod_error,
                       v_msj_error);
          ELSE
            BEGIN
              SELECT pp.sal_min_vigente
                INTO v_sal_min_vig
                FROM pr_parametros pp;
            EXCEPTION
              WHEN no_data_found THEN
                v_cod_error := 12;
                v_msj_error := 'Parametro de Salario minimo vigente no definido.';
            END;
            --
          IF v_monto_ing is null then
            BEGIN
              SELECT l.mto_ingreso
                INTO v_mto_ingreso
                FROM cr_inf_laborales l
               WHERE l.cod_persona = :new.cod_persona
                 AND l.fec_salida is null
                 AND l.fec_ingreso is not null
                 AND l.actual = 'S';
            EXCEPTION
              WHEN no_data_found THEN
                v_mto_ingreso := 0;
              WHEN too_many_rows THEN
                SELECT sum(l.mto_ingreso)
                  INTO v_mto_ingreso
                  FROM cr_inf_laborales l
                 WHERE l.cod_persona = :new.cod_persona
                   AND l.fec_salida is null
                   AND l.fec_ingreso is not null
                   AND l.actual = 'S';
              WHEN OTHERS THEN
                v_mto_ingreso := 0;
            END;
           ELSE
             v_mto_ingreso := nvl(v_monto_ing,0);
           END IF;
            --
            IF v_mto_ingreso > 0 AND v_mto_ingreso < v_sal_min_vig THEN
              v_cod_error := 13;
              v_msj_error := 'Cliente con salario menor al mínimo legal vigente.';
            ELSE
              IF v_mto_ingreso = 0 THEN
                v_mto_min_pre := 0;
              ELSE
                v_val_tas_lim := fu_obt_val_tas(v_mto_ingreso, v_tasa);
                v_mto_min_pre := (v_mto_ingreso * v_val_tas_lim);
              END IF;
            END IF;
            IF nvl(v_cod_error, '000') <> '000' THEN
              ge_ins_log(v_cod_registro,
                         :new.cod_persona,
                         v_cod_error,
                         v_msj_error);
            ELSE
              IF fug_obt_es_per_inhi(:new.cod_persona) = 'S' THEN
                v_cod_error := 14;
                v_msj_error := 'Cliente se encuentra Inhibido.';
              END IF;
           END IF;
            ---
            -- buscar telefono princial
           IF nvl(v_cod_error, '000') <> '000' THEN
              ge_ins_log(v_cod_registro,
                         :new.cod_persona,
                         v_cod_error,
                         v_msj_error);
            ELSE
                begin
                   select t.*
                       into r_batel
                         from ba_telefonos t
                         where t.cod_persona=:new.cod_persona
                           and t.tipo='P'
                           and t.tip_linea='C';
                           if (trim(substr(r_batel.telefono,1,2))<>'09'
                              and (r_batel.area not like '09%' or r_batel.area is null))
                              and trim(substr(r_batel.telefono, 1, 4)) <> '+595'
                              then
                               v_msj_error:=  'El telefono principal del cliente es extranjero';
                               v_cod_error:= 16;
                           end if;


                EXCEPTION
                   WHEN OTHERS THEN
                      null;
                END;
                 IF nvl(v_cod_error, '000') <> '000' THEN
                    ge_ins_log(v_cod_registro,
                               :new.cod_persona,
                               v_cod_error,
                               v_msj_error);
                  ELSE
                    insert into ba_per_gen_ofertas
                      (cod_registro,
                       cod_persona,
                       mto_lim_prestable,
                       mto_ingreso,
                       fec_consulta)
                    values
                      (v_cod_registro,
                       :new.cod_persona,
                       v_mto_min_pre,
                       v_mto_ingreso,
                       pag_cal.FU_OBT_FEC_ACTUAL(1));
                  END IF;
            END IF;
          END IF;
        END IF;
      END IF;
    ELSE
      ge_ins_log(v_cod_registro,
                 :new.cod_persona,
                 v_cod_error,
                 v_msj_error);
    END IF;
  END;

BEGIN

  IF UPDATING THEN

    IF :new.tip_ingreso = 1 THEN
      --Funcionario Publico

      pr_cam_mod_limite;

      IF nvl(:new.mon_ingreso, 0) > 0 Then

        Begin
          select nvl(max(nro_secuencia), 0) + 1
            into v_nro_secuencia
            from cr_inf_laborales
           where cod_persona = :new.cod_persona;
        Exception
          when no_data_found then
            v_nro_secuencia := 0;
        End;

        -- si es la primera informacion entonces es la actual
        if nvl(v_nro_secuencia, 0) = 1 then
          v_actual := 'S';
        end if;

        --Actualizamos el importe de la tabla cr_inf_laborales si no, se insertan los datos
        update cr_inf_laborales t
           set t.mto_ingreso = :new.mon_ingreso
         where t.cod_persona = :new.cod_persona;

          if sql%notfound then

                  Begin
                    insert into it.cr_inf_laborales
                      (cod_persona,
                       nro_secuencia,
                       lug_trabajo,
                       fec_ingreso,
                       mto_ingreso,
                       cod_moneda,
                       tip_cargo,
                       tip_ingreso,
                       actual)
                    values
                      (:new.cod_persona,
                       v_nro_secuencia,
                       'FUNCIONARIO PUBLICO ONBORDING',
                       trunc(SYSDATE),
                       nvl(:new.mon_ingreso, 0),
                       pag_gen.fu_obt_mon_local,
                       'E', --Empleado
                       23, --Sueldo
                       v_actual);
                  Exception
                    when others then
                      null;
                  End;
           End if;
      End if;

    ELSIF :new.tip_ingreso = 2 THEN
      --IPS

      pr_cam_mod_limite; --334 ---31

      If :new.ran_ingreso is not null then

        Begin
          v_monto_ing := to_number(fue_obt_val_max_referencia('RAN_INGRESO',
                                                              :new.ran_ingreso));
        Exception
          when others then
            v_monto_ing := 0;
        End;

      End if;

      IF nvl(v_monto_ing, 0) > 0 Then

        Begin
          select nvl(max(nro_secuencia), 0) + 1
            into v_nro_secuencia
            from cr_inf_laborales
           where cod_persona = :new.cod_persona;
        Exception
          when no_data_found then
            v_nro_secuencia := 0;
        End;

        -- si es el primer registro entonces es la actual
        if nvl(v_nro_secuencia, 0) = 1 then
          v_actual := 'S';
        end if;
        --Actualizamos el importe de la tabla cr_inf_laborales si no, se insertan los datos
        update cr_inf_laborales t
           set t.mto_ingreso = v_monto_ing
         where t.cod_persona = :new.cod_persona;

        if sql%notfound then
                Begin
                  insert into it.cr_inf_laborales
                    (cod_persona,
                     nro_secuencia,
                     lug_trabajo,
                     fec_ingreso,
                     mto_ingreso,
                     cod_moneda,
                     tip_cargo,
                     tip_ingreso,
                     actual)
                  values
                    (:new.cod_persona,
                     v_nro_secuencia,
                     'IPS ONBORDING',
                     trunc(SYSDATE),
                     v_monto_ing,
                     pag_gen.fu_obt_mon_local,
                     'E', --Empleado
                     23, --Sueldo
                     v_actual);
                Exception
                  When others then
                    null;
                End;
         End if;
      End if;

    ELSIF :new.tip_ingreso = 3 THEN
      --Contribuyente

      pr_cam_mod_limite;
      
      --Se valida que la persona tenga rango de ingreso en la tabla ge_ing_clientes. 
      IF :new.ran_ingreso is not null then
       --Si la persona posee datos de rango de ingreso se toma la parametrización de rangos para asignar monto de ingreso. 
      Begin
          v_monto_ing := 0;
        Exception
          when others then
            v_monto_ing := 0;
        End;
     ELSIF :new.mon_ingreso = 0 or :new.mon_ingreso is null THEN
          v_monto_ing := 0;
     END IF;
      v_res_cir := paw_cir.FU_INI_CIRCUITO(p_cod_tip_circuito => 51, --        
                                           p_referencia       => :new.nro_cuenta, --nro_cuenta--
                                           p_cod_persona      => :new.cod_persona);

       if v_res_cir != 0 then
          raise_application_error(-20000, 'Error en al Crear Circuito 51 ' || sqlerrm);
       end if;


    ELSIF :new.tip_ingreso = 4 THEN
      -- Otros ingresos
      --Se valida que la persona tenga rango de ingreso en la tabla ge_ing_clientes. 
      IF :new.ran_ingreso is not null then
       --Si la persona posee datos de rango de ingreso se toma la parametrización de rangos para asignar monto de ingreso. 
      Begin
          v_monto_ing := 0;
        Exception
          when others then
            v_monto_ing := 0;
        End;
       ELSIF :new.mon_ingreso = 0 or :new.mon_ingreso is null THEN
          v_monto_ing := 0;
     END IF;

      v_res_cir := paw_cir.FU_INI_CIRCUITO(p_cod_tip_circuito => 82, --Datos de Ingresos y Otros
                                           p_referencia       => :new.nro_cuenta, --nro_cuenta--
                                           p_cod_persona      => :new.cod_persona);

       if v_res_cir != 0 then
          raise_application_error(-20000, 'Error en al Crear Circuito 82 ' || sqlerrm);
       end if;
       -- JFF verificacion de modalidad
       begin
         select v.cod_modalidad
         into v_cod_modalidad
         from ah_cta_vistas v
         where v.nro_cuenta=:new.nro_cuenta;
         exception
           when others then
               v_cod_modalidad := null;
       end;
       If nvl(v_cod_modalidad,0) = 334 Then -- JFF  DA-6711
           update ge_cta_dat_adicionales t
              set t.val_parametro = fug_obt_pardinamico('ONB_LIM_ACT', 3, 334,'GS')
            where t.nro_cuenta = :new.nro_cuenta
            and t.parametro = 'LIM_CRE_TRANSACCIONES' ;

           if sql%notfound then

                  begin
                      insert into ge_cta_dat_adicionales
                        (nro_cuenta, parametro, val_parametro)
                      values
                        (:new.nro_cuenta ,
                         'LIM_CRE_TRANSACCIONES',
                         fug_obt_pardinamico('ONB_LIM_ACT', 3, 334,'GS'));
                  exception
                   when dup_val_on_index then
                     null;
                  end;
            end if;
        END IF;
    END IF;

    IF :new.estado = 'V' THEN
      --
      pr_ins_reg_ofe_per;
    END IF;

  END IF;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,
                            'Error en TA_GE_ING_CLIENTES ' || sqlerrm);

END;
/
