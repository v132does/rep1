CREATE OR REPLACE PROCEDURE IT.PRG_GEN_MOV_SNP_HIS (p_hora           IN VARCHAR2,
                                                p_fecha          IN DATE DEFAULT NULL,
                                                p_cod_usuario    IN VARCHAR2 DEFAULT NULL,
                                                p_cod_programa   OUT VARCHAR2,
                                                p_nro_referencia OUT VARCHAR2) IS
												

  v_nro_referencia    ge_snp_transferencias.nro_referencia%type := NULL;
  v_fecha             ge_snp_transferencias.fecha%type;
  v_fec_valor         ge_snp_transferencias.fec_valor%type;
  v_cod_msj_swift     ge_snp_transferencias.cod_msj_swift%type;
  v_tip_operacion     ge_snp_transferencias.cod_tip_operacion%type;
  v_sub_tip_operacion ge_snp_transferencias.cod_sub_tip_operacion%type;
  v_ind_valor         ge_snp_transferencias.ind_valor%type := 'N';
  v_cod_swi_benef     ge_snp_transferencias.cod_swi_pte_beneficiario%type;
  v_nro_cta_benef     ge_snp_transferencias.nro_cta_beneficiario%type;
  v_prioridad         ge_snp_transferencias.prioridad%type := 20;
  v_nro_cta_sol       ge_cuentas.nro_cuenta%type;
  v_cod_modulo        ba_modulos.cod_modulo%type;
  v_cod_modalidad     ge_modalidades.cod_modalidad%type;
  v_cod_oficina       ba_oficinas.cod_oficina%type;
  v_concepto          ge_movimientos.concepto%type;
  v_con_movimiento    ge_movimientos.concepto%type;
  v_monto             ge_movimientos.monto%type;
  v_cod_moneda        ba_monedas.cod_moneda%type;
  v_cod_persona       ba_personas.cod_persona%type;
  V_USU_HOMEBANKING   ba_usuarios.cod_usuario%type;
  V_REG_EN_HISTORICO  VARCHAR2(1) := 'N';
  V_ES_SPI            VARCHAR2(1) := 'N';
  CURSOR datos IS
    SELECT m.fec_valor,
           m.nro_secuencia,
           m.cod_tra_padre,
           m.cod_mad_padre,
           m.cod_transaccion,
           m.cod_modulo,
           m.cod_modalidad,
           m.monto,
           m.cod_moneda,
           m.nro_cuenta,
           m.cod_oficina,
           m.nro_documento,
           m.nro_documento2,
           m.concepto,
           m.cod_banco,
           m.referencia
      FROM gv_movimientos m
     WHERE m.fecha = v_fecha
       AND m.hora = p_hora
       AND m.cod_usuario = p_cod_usuario
       --AND m.cod_tra_padre = 303
       AND m.cod_tra_padre in (Select distinct x.cod_tra_padre from ge_snp_par_mensajes x) -- SNP
       AND m.cod_mad_padre = 455
       AND m.nro_documento2 IS NOT NULL
       --AND PAS_SPI.fu_es_spi(M.NRO_DOCUMENTO)='N'
           union

           SELECT m.fec_valor,
           m.nro_secuencia,
           m.cod_tra_padre,
           m.cod_mad_padre,
           m.cod_transaccion,
           m.cod_modulo,
           m.cod_modalidad,
           m.monto,
           m.cod_moneda,
           m.nro_cuenta,
           m.cod_oficina,
           m.nro_documento,
           m.nro_documento2,
           m.concepto,
           m.cod_banco,
           m.referencia
      FROM gv_movimientos m
     WHERE m.fecha = v_fecha
       AND m.hora = p_hora
       AND m.cod_usuario = p_cod_usuario
       --AND m.cod_tra_padre = 303
       AND m.cod_tra_padre in (Select distinct x.cod_tra_padre from ge_snp_par_mensajes x) -- SNP
       AND m.cod_mad_padre = 455
       AND m.COD_USUARIO = V_USU_HOMEBANKING
     --  AND PAS_SPI.fu_es_spi(M.NRO_DOCUMENTO)='N'
          union
          
    SELECT m.fec_valor,
           m.nro_secuencia,
           m.cod_tra_padre,
           m.cod_mad_padre,
           m.cod_transaccion,
           m.cod_modulo,
           m.cod_modalidad,
           m.monto,
           m.cod_moneda,
           m.nro_cuenta,
           m.cod_oficina,
           m.nro_documento,
           m.nro_documento2,
           m.concepto,
           m.cod_banco,
           m.referencia
      FROM gv_movimientos m
     WHERE m.fecha = v_fecha
       AND m.hora = p_hora
       AND m.cod_usuario = p_cod_usuario
       --AND m.cod_tra_padre = 303
       AND m.cod_tra_padre in (Select distinct x.cod_tra_padre from ge_snp_par_mensajes x) -- SNP
       AND m.cod_mad_padre = 455
      -- AND PAS_SPI.fu_es_spi(M.NRO_DOCUMENTO)='S'
           union

           SELECT m.fec_valor,
           m.nro_secuencia,
           m.cod_tra_padre,
           m.cod_mad_padre,
           m.cod_transaccion,
           m.cod_modulo,
           m.cod_modalidad,
           m.monto,
           m.cod_moneda,
           m.nro_cuenta,
           m.cod_oficina,
           m.nro_documento,
           m.nro_documento2,
           m.concepto,
           m.cod_banco,
           m.referencia
      FROM gv_movimientos m
     WHERE m.fecha = v_fecha
       AND m.hora = p_hora
       AND m.cod_usuario = p_cod_usuario
       --AND m.cod_tra_padre = 303
       AND m.cod_tra_padre in (Select distinct x.cod_tra_padre from ge_snp_par_mensajes x) -- SNP
       AND m.cod_mad_padre = 455
       AND m.COD_USUARIO = V_USU_HOMEBANKING
     --  AND PAS_SPI.fu_es_spi(M.NRO_DOCUMENTO)='S'
     ORDER by nro_secuencia DESC;
BEGIN

     v_usu_homebanking :=      fug_obt_pardinamico('COD_USU_HOMEBANKING');

  IF p_fecha IS NULL THEN
    v_fecha := pas_snp.g_fec_actual;
  ELSE
    v_fecha := p_fecha;
  END IF;

  p_cod_programa := NULL;
  BEGIN
    FOR dt IN datos LOOP
      --VERIFICA SI ESTÁ EN LA TABLA NORMAL O HISTORICA
      Begin 
          SELECT 'N'
                  into V_REG_EN_HISTORICO
                  FROM GE_SNP_TRANSFERENCIAS
                 where nro_referencia = dt.nro_documento
                   and fecha = v_fecha
                   and hora = p_hora;
      Exception 
          When no_data_found then
            V_REG_EN_HISTORICO := 'S';    
      End;
      --
      if dt.nro_documento2 is null /*and PAS_SPI.fu_es_spi(dt.nro_documento) = 'N'*/ then
        If V_REG_EN_HISTORICO = 'N' then
            Begin
                SELECT cod_msj_swift, cod_tip_operacion, cod_sub_tip_operacion
                  into v_cod_msj_swift, v_tip_operacion, v_sub_tip_operacion
                  FROM GE_SNP_TRANSFERENCIAS
                 where nro_referencia = dt.nro_documento
                   and fecha = v_fecha
                   and hora = p_hora;
            End;
        Else           
            SELECT cod_msj_swift, cod_tip_operacion, cod_sub_tip_operacion, 'S'
              into v_cod_msj_swift, v_tip_operacion, v_sub_tip_operacion,V_REG_EN_HISTORICO
              FROM GE_SNP_TRANSFERENCIAS_HIS
             where nro_referencia = dt.nro_documento
               and fecha = v_fecha
               and hora = p_hora;
        End if;                 
      elsif dt.nro_documento2 is null /*and PAS_SPI.fu_es_spi(dt.nro_documento) = 'S'*/ then
        V_ES_SPI := 'S';
      else
        v_cod_msj_swift     := substr(dt.nro_documento2, 1, 3);
        v_tip_operacion     := substr(dt.nro_documento2, 4, 3);
        v_sub_tip_operacion := substr(dt.nro_documento2, 7, 3);
      end if;
      IF v_cod_msj_swift = 104 THEN
        --Si es un MT104 solo debe mostrar la transferencia ya registrada
        IF V_REG_EN_HISTORICO = 'N' THEN
           p_cod_programa      := 'gmsnp104';
        ELSE
          p_cod_programa      := 'ghsnp104';
        END IF;   
        EXIT;
      ELSIF v_cod_msj_swift IN (102, 103, 202) AND dt.cod_modalidad = 455 THEN
        --Solo si es un DEBITO a la CTA. INTERBANCARIA en la entidad, entonces es un MT102
        v_fec_valor     := dt.fec_valor;
        v_cod_modulo    := dt.cod_modulo;
        v_cod_modalidad := dt.cod_modalidad;
        v_cod_moneda    := dt.cod_moneda;
        v_monto         := dt.monto;
        v_cod_oficina   := dt.cod_oficina;
        v_concepto      := dt.concepto;
        v_cod_persona   := fug_obt_cli_principal(dt.nro_cuenta);
        IF v_cod_msj_swift = 202 THEN
          IF v_tip_operacion != '004' THEN
            IF V_REG_EN_HISTORICO = 'N' THEN
               p_cod_programa := 'gmsnp202';
            ELSE
               p_cod_programa := 'ghsnp202';
            END IF;   
            v_ind_valor    := 'S';
          ELSE
            -- MT202, Corresponsales del Exterior.
            IF V_REG_EN_HISTORICO = 'N' THEN
               p_cod_programa := 'gmsnpcor';
            ELSE
               p_cod_programa := 'ghsnpcor';
            END IF;   
            v_ind_valor    := 'S';
          END IF;
        END IF;
      ELSIF v_cod_msj_swift IN (102, 103) AND dt.cod_modalidad <> 455 THEN
        --Si es un DEBITO evaluar si se debita solamente al cliente
        v_nro_cta_sol  := dt.nro_cuenta;
        IF V_REG_EN_HISTORICO = 'N' THEN
           p_cod_programa := 'gmsnp103';
        ELSE
           p_cod_programa := 'ghsnp103';
        END IF;   
        v_cod_persona  := fug_obt_cli_principal(dt.nro_cuenta);

        IF pae_cnf.g_programa = 'AMTRADNA' AND dt.cod_transaccion = 4030 THEN
          -- Se agrega para DNA
          v_nro_cta_benef := dt.referencia;
          BEGIN
            SELECT gv.cod_swift
              INTO v_cod_swi_benef
              FROM gv_snp_participantes gv
             WHERE gv.cod_banco = dt.cod_banco;
          EXCEPTION
            WHEN OTHERS THEN
              v_cod_swi_benef := NULL;
          END;
        END IF;

        IF v_cod_msj_swift = 102 THEN
          v_ind_valor := 'N';
        ELSE
          v_ind_valor := 'S';
        END IF;
      END IF;
      
      IF V_ES_SPI = 'S' THEN
         p_cod_programa := 'GCCONSPI'; 
      END IF;
      
    END LOOP;
  END;
  --
  IF p_cod_programa IS NOT NULL AND V_ES_SPI = 'N' THEN
    --Cargar datos mas importantes en la tabla ge_tra_interbancarias
    BEGIN
      SELECT nro_referencia
        INTO v_nro_referencia
        FROM ge_snp_transferencias t
       WHERE t.fecha = v_fecha
         AND t.hora = p_hora
         AND t.cod_usuario = nvl(p_cod_usuario, USER);
    EXCEPTION
      WHEN no_data_found THEN
          Begin
            SELECT nro_referencia
                INTO v_nro_referencia
                FROM ge_snp_transferencias_his t
               WHERE t.fecha = v_fecha
                 AND t.hora = p_hora
                 AND t.cod_usuario = nvl(p_cod_usuario, USER);      
          Exception
            WHEN no_data_found THEN     
              BEGIN
                /* Inicializa variables */
                pas_snp.g_msj := NULL;
                --
                BEGIN
                  SELECT m.prioridad
                    INTO v_prioridad
                    FROM ge_snp_par_mensajes m
                   WHERE m.cod_msj_swift = v_cod_msj_swift
                     AND m.cod_tip_operacion = v_tip_operacion
                     AND nvl(m.cod_sub_tip_operacion, 'x') = nvl(v_sub_tip_operacion, 'x')
                     AND nvl(m.cod_tra_padre,pas_snp.fu_obt_cod_tra_padre) = pas_snp.fu_obt_cod_tra_padre;
                EXCEPTION
                  WHEN others THEN
                    v_prioridad := CASE nvl(v_cod_msj_swift, 102)
                                     WHEN 102 THEN
                                      100
                                     ELSE
                                      20
                                   END; -- Cualquier error coloca la prioridad por defecto
                END;

                v_nro_referencia := pas_snp.fu_obt_sig_nro_referencia;

                pas_snp.g_msj.nro_referencia          := v_nro_referencia;
                pas_snp.g_msj.cod_modulo              := v_cod_modulo;
                pas_snp.g_msj.cod_modalidad           := v_cod_modalidad;
                pas_snp.g_msj.cod_oficina             := v_cod_oficina;
                pas_snp.g_msj.fec_valor               := v_fec_valor;
                pas_snp.g_msj.fec_ingreso             := v_fecha;
                pas_snp.g_msj.fecha                   := v_fecha;
                pas_snp.g_msj.hora                    := p_hora;
                pas_snp.g_msj.cod_usuario             := nvl(p_cod_usuario, USER);
                pas_snp.g_msj.nro_operacion           := v_nro_referencia;
                pas_snp.g_msj.cod_moneda              := v_cod_moneda;
                pas_snp.g_msj.cod_tip_operacion       := v_tip_operacion;
                pas_snp.g_msj.cod_sub_tip_operacion   := v_sub_tip_operacion;
                pas_snp.g_msj.monto                   := v_monto;
                pas_snp.g_msj.cod_swi_pte_solicitante := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
                -- Si el Nro. Cta del Solicitante tiene algún valor entonces se recupera los datos de la persona relacionada a ella.
                IF v_nro_cta_sol IS NOT NULL THEN
                  pas_snp.g_msj.cod_per_solicitante     := fug_obt_cli_principal(v_nro_cta_sol);
                  pas_snp.g_msj.nom_solicitante         := fue_obt_nom_persona(fug_obt_cli_principal(v_nro_cta_sol));
                  pas_snp.g_msj.dir_solicitante         := fue_obt_dir_principa(fug_obt_cli_principal(v_nro_cta_sol));
                  pas_snp.g_msj.cod_tip_doc_solicitante := fue_obt_doc_principal(pas_snp.g_msj.cod_per_solicitante);
                  pas_snp.g_msj.nro_doc_solicitante     := substr(fue_obt_nro_doc_persona(fug_obt_cli_principal(v_nro_cta_sol)),
                                                                  1,
                                                                  20);
                  pas_snp.g_msj.nro_cta_solicitante     := v_nro_cta_sol;
                END IF;
                --
                v_con_movimiento := 'Transf Local via BCP Ref ' ||
                                    v_nro_referencia;
                --
                pas_snp.g_msj.concepto      := nvl(v_concepto, v_con_movimiento);
                pas_snp.g_msj.cod_msj_swift := v_cod_msj_swift;
                pas_snp.g_msj.ind_valor     := v_ind_valor;
                pas_snp.g_msj.prioridad     := v_prioridad;
                pas_snp.g_msj.situacion     := 'P';
                pas_snp.g_msj.estado        := 'S';
                -- Para DNA
                IF v_nro_cta_benef IS NOT NULL THEN
                  pas_snp.g_msj.cod_swi_pte_beneficiario := v_cod_swi_benef;
                  pas_snp.g_msj.nro_cta_beneficiario     := v_nro_cta_benef;
                END IF;
                pas_snp.g_lugar := 'Insertando Mensajería.., ';
                pas_snp.pr_ins_transferencias(pas_snp.g_msj);

                --Una vez registrada la mensajería, se ACTUALIZA el movimiento con el NRO_REFERENCIA y NRO_SEC_LOTE
                BEGIN
                  UPDATE ge_movimientos m
                     SET m.nro_documento = to_number(substr(v_nro_referencia,
                                                            1,
                                                            15)),
                         m.concepto      = DECODE(m.nro_documento2,
                                                  NULL,
                                                  m.concepto,
                                                  v_con_movimiento)
                   WHERE m.hora = p_hora
                     AND m.cod_usuario = nvl(p_cod_usuario, USER)
                     AND m.fecha = v_fecha
                     --AND m.cod_tra_padre = 303
                     AND m.cod_tra_padre in (Select distinct x.cod_tra_padre from ge_snp_par_mensajes x) -- SNP
                     AND m.monto > 0;
                  IF sql%notfound THEN
                    raise_application_error(-20000,
                                            'No se ha podido RELACIONAR el movimiento con el SWIFT generado. Fecha: ' ||
                                            to_char(v_fecha, 'DD/MM/YYYY') ||
                                            ' Hora: ' || p_hora || ' Usu : ' ||
                                            nvl(p_cod_usuario, USER));
                  END IF;
                END;
                --
                pas_snp.pr_ini_workflow(pas_snp.g_msj);
                if pas_snp.fu_obt_cod_error <> 0 then
                  raise_application_error(-20001, pas_snp.fu_obt_msj_error);
                else
                  commit; -- Con esto se tiene la integridad del circuito de datos para su posterior seguimiento en el WF.
                end if;
                --
              END;        
          END;    
    END;
    -- Devuelve los datos del MT relacionado al movimiento
    p_nro_referencia := v_nro_referencia;
  ELSIF p_cod_programa IS NOT NULL AND V_ES_SPI = 'S' THEN 
       BEGIN
          SELECT nro_referencia
            INTO v_nro_referencia
            FROM ge_spi_transferencias t
           WHERE t.fecha = v_fecha
             AND t.hora = p_hora
             AND t.cod_usuario = nvl(p_cod_usuario, USER);
       END;
     p_nro_referencia := v_nro_referencia;
  END IF;
EXCEPTION
  WHEN dup_val_on_index THEN
    raise_application_error(-20001,
                            ' Ya existen registros en ge_snp_transferencias para el número de transferencia ' ||
                            p_nro_referencia || ', verifique.!');
  WHEN others then
    IF sqlcode < -20000 THEN
      raise;
    ELSE
      raise_application_error(-20002,
                              'Error en prg_gen_mov_snp' || '-' || sqlerrm);
    END IF;
END;
/

