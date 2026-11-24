CREATE OR REPLACE TRIGGER IT.TB_GE_CLIENTES
 BEFORE DELETE OR INSERT OR UPDATE
 OF COD_PERSONA,
    COD_OFICINA,
    EXO_IMPUESTOS,
    COD_USU_OFICIAL,
    CLI_ESPECIAL,
    RESIDENTE,
    COD_SEC_CONTABLE,
    COD_TIP_DEUDOR,
    COD_DEPARTAMENTO,
    NIV_CRUZAMIENTO,
    CLAVE,
    EST_CLAVE,
    FEC_EST_CLAVE,
    CAN_INTENTOS,
    TIP_EXTRACTO,
    COD_USU_GESTION,
    FEC_INGRESO,
    COD_SEG_CLIENTE,
    CLI_CONFIDENCIAL,
    TIP_CLAVE,
    COD_PERFIL,
    FEC_ULT_ACCESO,
    COD_CANAL,
    VAL_COMERCIAL,
    COD_SEG_PREFERENTE,
    COD_SEG_PRE_ANTERIOR,
    CAT_AUTOMATICA,
    CAT_RIESGO
 ON "IT"."GE_CLIENTES"
 FOR EACH ROW
DECLARE
  v_pais          ba_paises.cod_pais%type;
  v_existe        varchar2(1) := 'N';
  v_nro_documento number(15) := 0;
  v_es_fisica     varchar2(1):= 'N';
  v_cat_anterior  ta_cta_tarjetas_nov.cat_riesgo%type;
  --v_fec_actual    ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(1);
begin
  If (inserting or updating )and nvl(pae_cnf.G_PROGRAMA,'x') <> 'GMPROARC'then

    begin
         select 'S','S'
           into v_existe, v_es_fisica
           from BA_PER_FISICAS
          where cod_persona = :new.cod_persona ;
      exception
        when no_data_found then
          null;
    end;
    /*if :new.cod_seg_cliente is null then
        raise_application_error(-20000,
--        'Ingrese el Segmento del Cliente.');
        'Ingrese el Area de Negocio del Cliente.');
    end if; */
    if :new.cod_sec_contable = 'F' and :new.cod_tip_deudor = 7  then
      begin
        select a.cod_pais
          into v_pais
          from ba_personas a
         where a.cod_persona = :new.cod_persona;
      exception
       when no_data_found then
         null;
       when others then
         null;
      end;
      if v_pais = 1 then -- no puede ser Py.
        raise_application_error(-20000,
        'Para el Tipo Deudor Banco del Exterior, el Pais Origen no puede ser Paraguay.');
      end if;
    end if;
    If inserting then
      If v_existe = 'S' then
        If :new.cod_sec_contable <> 'N' then
          raise_application_error(-20000,
          'El sector economico debe ser no financiero ni publico(privado)');
        End if;
        --MDCV Evolutivo nro.3049
        if :new.cod_seg_preferente is not null then
          insert into GE_CLI_INFORMACIONES (cod_persona, informacion, dat_informacion, usu_mod_informacion, fec_mod_informacion)
          values (:new.cod_persona, 'SEGMENTO', :new.cod_seg_preferente, user, pag_cal.FU_OBT_FEC_ACTUAL(1));
        end if;
      elsif :old.cli_especial <> :new.cli_especial then
         raise_application_error(-20000,
         'No puede marcar como Cliente Preferente a una persona jurídica.');
      End if;
    End if;
    If updating then
      If v_existe = 'S' then
        If :new.cod_sec_contable <> :old.cod_sec_contable then
           If :new.cod_sec_contable <> 'N' then
             raise_application_error(-20000,
             'El sector economico debe ser no financiero ni publico(privado)');
           End if;
        End if;
      End if;
      -- inicio circuito de aprobacion de clave
      Begin
         select 'S'
           into v_existe
           from ba_usuarios a, ba_areas b
          where a.cod_area = b.cod_area
            and a.cod_usuario = substr(user,1,10)
            and b.descripcion = 'CALL CENTER';
      Exception
        when others then
          v_existe := 'N';
      End;

      If :new.est_clave IN ('N','M') and :new.clave <> nvl(:old.clave,'x') and v_existe = 'N' then
          DECLARE
           v_cod_error number;
          BEGIN
             :new.est_clave := 'N';
             -- solo para pruebas de circuitos
                v_cod_error := paw_cir.FU_INI_CIRCUITO(996, :new.cod_persona, :new.cod_persona); -- 996 es el tipo de circuito
                if v_cod_error <> 0 then
                   raise_application_error(-20067,'Error al generar Circuito. '||sqlerrm);
                end if;

          END;
      Elsif v_existe = 'S' and :new.clave is not null THEN -- Call Center - Habilitación de PIN
         --Agrego el registro en bw_movimientos
         select s_nro_documento.nextval into v_nro_documento from dual;
         insert into bw_movimientos
           (nro_documento,cod_per_principal  , cod_per_ingreso,   clave,  fec_hora, nro_caja    ,  cod_tip_mensaje , dir_ip,
            cod_respuesta, observacion,etiqueta, dato)
         values
           (v_nro_documento,:new.cod_persona,:new.cod_persona,:new.clave, sysdate, '888', '080', sys_context('USERENV','IP_ADDRESS'),
            '000','Generacion de Pin IVR Temporal','Call Center', substr(user,1,10));
      End If;
      --
      If v_es_fisica <> 'S' then
         if :old.cli_especial <> :new.cli_especial then
            raise_application_error(-20000,
            'No puede marcar como Cliente Preferente a una persona jurídica.');
         end if;
      end if;

      IF :old.cod_seg_preferente <> :new.cod_seg_preferente then
        :new.cod_seg_pre_anterior  := :old.cod_seg_preferente;
      END IF;
      --MDCV Evolutivo nro.3049
      if :new.cod_seg_preferente is not null then
        Begin
         select 'S'
           into v_existe
           from ge_cli_informaciones p
          where p.cod_persona = :old.cod_persona;
        Exception
          when others then
            v_existe := 'N';
        End;
        if v_existe = 'N' then
           insert into GE_CLI_INFORMACIONES (cod_persona, informacion, dat_informacion, usu_mod_informacion, fec_mod_informacion)
           values (:new.cod_persona, 'SEGMENTO', :new.cod_seg_preferente, user, pag_cal.FU_OBT_FEC_ACTUAL(1));
        elsif :old.cod_seg_preferente <> :new.cod_seg_preferente then
             update GE_CLI_INFORMACIONES p
               set p.dat_informacion         = :new.cod_seg_preferente,
                   p.usu_mod_informacion     = user,
                   p.fec_mod_informacion     = pag_cal.FU_OBT_FEC_ACTUAL(1),
                   p.dat_informacion_ant     = :old.cod_seg_preferente,
                   p.usu_mod_informacion_ant = p.usu_mod_informacion,
                   p.fec_mod_informacion_ant = p.fec_mod_informacion
             where p.cod_persona             = :old.cod_persona;
        end if;
      end if;
    End if;

    
     /**Genera Novedad por cambio de Categoría para BANCARD*/
     IF fug_obt_pardinamico('ENV_MOD_TARJETA') = 'S' THEN
        --Se comenta para pruebas.
        IF nvl(pae_cnf.G_PROGRAMA,'X') = 'GPPROFIN' THEN
          IF nvl(:new.cat_automatica,1) <> nvl(:old.cat_automatica,1) then
           BEGIN
              --Ultima novedad informada a BANCARD.
              SELECT distinct n.cat_riesgo
                INTO v_cat_anterior
                FROM ge_cta_clientes     c,
                     ta_cta_tarjetas     t,
                     ta_cta_tarjetas_nov n
               WHERE c.cod_persona = :new.cod_persona
                 AND c.nro_cuenta  = t.nro_cuenta
                 AND c.relacion    = 'P'
                 AND t.estado      <> 'C'
                 AND n.nro_cuenta  = t.nro_cuenta
                 AND n.cat_riesgo  IS NOT NULL
                 AND n.fecha       = (SELECT MAX(nn.fecha)
                                        FROM ge_cta_clientes     cc,
                                             ta_cta_tarjetas     tt,
                                             ta_cta_tarjetas_nov nn
                                       WHERE cc.cod_persona = :new.cod_persona
                                         AND cc.nro_cuenta  = tt.nro_cuenta
                                         AND cc.relacion    = 'P'
                                         AND tt.estado      <> 'C'
                                         AND nn.nro_cuenta  = tt.nro_cuenta
                                         AND nn.cat_riesgo  IS NOT NULL);
           EXCEPTION
              --Nuevas Solicitudes de Tarjetas Informadas.
              WHEN no_data_found THEN
                 BEGIN
                    SELECT distinct n.bcp_calificacion
                      INTO v_cat_anterior
                      FROM ta_env_cuentas_his n,
                           ta_solicitudes     s
                     WHERE n.cod_persona      = :new.cod_persona
                       AND n.situacion        = 'I'
                       AND n.bcp_calificacion IS NOT NULL
                       AND s.cod_persona      = n.cod_persona
                       AND n.fec_novedad      = (SELECT MAX(nn.fec_novedad)
                                                   FROM ta_env_cuentas_his nn,
                                                        ta_solicitudes     ss
                                                  WHERE nn.cod_persona      = :new.cod_persona
                                                    AND nn.situacion        = 'I'
                                                    AND nn.bcp_calificacion IS NOT NULL
                                                    AND ss.cod_persona      = nn.cod_persona);
                 EXCEPTION
                    WHEN others THEN
                       v_cat_anterior := null;
                 END;
              WHEN others THEN
                 v_cat_anterior := null;
           END;

          IF nvl(v_cat_anterior, 0) <> nvl(:new.cat_automatica, 0) THEN
              DECLARE
                v_fec_actual DATE := pag_cal.fu_obt_fec_actual(5);

                CURSOR cuentas
                    IS select c.nro_cuenta
                         from ge_cta_clientes c,
                              ta_cta_tarjetas t
                        where c.cod_persona = :new.cod_persona
                          and c.nro_cuenta  = t.nro_cuenta
                          and c.relacion    = 'P'
                          and t.estado      <> 'C'
                          AND fut_obt_procesadora(c.nro_cuenta) != (select a.val_parametro
                                                                          from ge_par_dinamicos a
                                                                         where parametro = 'COD_ENT_GLOBAL');
              BEGIN
                FOR d IN cuentas LOOP
                  BEGIN
                    update ta_cta_tarjetas_nov
                       set cat_riesgo     = :new.cat_automatica,
                           enviado        = 'N',
                           aprobado       = 'N',
                           nro_acta       = null,
                           niv_aprobacion = null
                     where nro_cuenta = d.nro_cuenta
                       and fecha      = v_fec_actual;

                    IF SQL%NOTFOUND THEN
                        BEGIN
                           update ta_cta_tarjetas_nov
                               set cat_riesgo     = :new.cat_automatica,
                                   enviado        = 'N',
                                   aprobado       = 'N',
                                   nro_acta       = null,
                                   niv_aprobacion = null
                             where nro_cuenta = d.nro_cuenta
                               and fecha     != v_fec_actual
                               and enviado    = 'N';
                        END;
                        IF SQL%NOTFOUND THEN
                          BEGIN
                            insert into ta_cta_tarjetas_nov( nro_cuenta,
                                                             fecha,
                                                             cat_riesgo,
                                                             enviado )
                                                     values( d.nro_cuenta,
                                                             v_fec_actual,
                                                             :new.cat_automatica,
                                                             'N' );
                          EXCEPTION
                            when others then
                              IF sqlcode <= -20000 THEN
                                RAISE;
                              ELSE
                                RAISE_APPLICATION_ERROR( -20312, 'No se pudo insertar la novedad para la tarjeta ' || sqlerrm );
                              END IF;
                          END;
                        END IF;
                      END IF;
                  EXCEPTION
                    when others then
                      IF sqlcode <= -20000 THEN
                        RAISE;
                      ELSE
                        RAISE_APPLICATION_ERROR( -20313, 'No se pudo actualizar la novedad para la tarjeta ' || sqlerrm );
                      END IF;
                  END;
                END LOOP;
              END;
          END IF;
          END IF;
        END IF;
     END IF;
  End if;
end;
/
